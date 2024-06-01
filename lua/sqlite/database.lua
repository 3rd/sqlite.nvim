local EOF_MARKER = "--EOF--"

---@class Database
---@field path string
---@field handle uv_process_t|nil
---@field stdio { stdin: uv_pipe_t, stdout: uv_pipe_t, stderr: uv_pipe_t }|nil
---@field debug boolean
---@field output string
---@field ready boolean
---@field log fun(...)
local Database = {}

---@param path string
---@param options? { debug?: boolean }
function Database.open(path, options)
  local self = setmetatable({
    path = path,
    debug = options and options.debug or false,
    ready = false,
    output = "",
  }, { __index = Database })
  local stdin = vim.loop.new_pipe(false)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  self.log = function(...)
    if not self.debug then return end
    local line = ""
    for _, v in ipairs({ ... }) do
      if type(v) ~= "string" then v = vim.inspect(v) end
      line = line .. v .. " "
    end
    print(line)
  end

  self.log("Opening database at path:", path)

  self.handle = vim.loop.spawn("sqlite3", {
    args = { path },
    stdio = { stdin, stdout, stderr },
  }, function(code, signal)
    stdin:close()
    stdout:close()
    stderr:close()
    self.log("SQLite process closed with code:", code, "and signal:", signal)
  end)
  self.stdio = {
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
  }

  stdout:read_start(function(err, data)
    if err then
      self.log("Error reading from stdout:", err)
      return
    end
    if data then
      self.log("Received stdout data:", data)
      self.output = self.output .. data
      if data:find(EOF_MARKER) then
        self.log("EOF marker found in stdout.")
        self.ready = true
      end
    else
      self.log("No more data to read from stdout.")
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      self.log("Error reading from stderr:", err)
      return
    end
    if data then self.log("Received stderr data:", data) end
  end)

  -- bootstrap
  self:execute(".mode json")

  return self
end

---@param sql string
---@param as_json? boolean
---return table|string|nil
function Database:execute(sql, as_json)
  self.output = ""
  self.ready = false
  self.log("Executing SQL:", sql)

  self.stdio.stdin:write(sql .. "\n")
  self.stdio.stdin:write(".print '" .. EOF_MARKER .. "'\n")

  vim.wait(5000, function()
    return self.ready
  end, 100)

  if not self.ready then error("SQLite query timed out.") end

  local trimmed_output = vim.trim(vim.fn.substitute(self.output, EOF_MARKER, "", ""))
  if trimmed_output == "" then
    self.log("Debug: Query yielded no output.")
    return nil
  end
  if as_json == false then return trimmed_output end
  local json_output = vim.fn.json_decode(trimmed_output)
  self.log("Parsed JSON output:", json_output)
  return json_output
end

function Database:close()
  self.log("Closing database connection.")
  self.stdio.stdin:write(".exit\n")
  self.stdio.stdin:close()
  self.stdio.stdout:close()
  self.stdio.stderr:close()
  if self.handle then
    vim.loop.close(self.handle)
    self.log("Handle closed.")
    self.handle = nil
  end
end

---@param tableName string
---@param data table
function Database:insert(tableName, data)
  local keys = {}
  local values = {}
  for key, value in pairs(data) do
    table.insert(keys, key)
    if type(value) == "string" then
      table.insert(values, "'" .. value:gsub("'", "''") .. "'")
    else
      table.insert(values, tostring(value))
    end
  end

  local sql =
    string.format("INSERT INTO %s (%s) VALUES (%s);", tableName, table.concat(keys, ", "), table.concat(values, ", "))
  self.log("Inserting into", tableName, ":", sql)
  return self:execute(sql)
end

---@param tableName string
---@param columns? string
---@param condition? string
function Database:fetch(tableName, columns, condition)
  columns = columns or "*"
  local sql = string.format("SELECT %s FROM %s", columns, tableName)
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Fetching from", tableName, "with condition:", condition)
  return self:execute(sql, true) -- true to parse output as JSON
end

---@param tableName string
---@param data table
function Database:update(tableName, data, condition)
  local updates = {}
  for key, value in pairs(data) do
    local updatePart = string.format("%s = ", key)
    if type(value) == "string" then
      updatePart = updatePart .. "'" .. value:gsub("'", "''") .. "'"
    else
      updatePart = updatePart .. tostring(value)
    end
    table.insert(updates, updatePart)
  end

  local sql = string.format("UPDATE %s SET %s", tableName, table.concat(updates, ", "))
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Updating", tableName, ":", sql)
  return self:execute(sql)
end

---@param tableName string
---@param condition? string
function Database:delete(tableName, condition)
  local sql = string.format("DELETE FROM %s", tableName)
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Deleting from", tableName, "with condition:", condition)
  return self:execute(sql)
end

---@param tableName string
---@param columns string[]
function Database:create_table(tableName, columns)
  local sql = string.format("CREATE TABLE %s (%s);", tableName, table.concat(columns, ", "))
  self.log("Creating table", tableName, ":", sql)
  return self:execute(sql)
end

---@param tableName string
function Database:drop_table(tableName)
  local sql = string.format("DROP TABLE %s;", tableName)
  self.log("Dropping table", tableName, ":", sql)
  return self:execute(sql)
end

---@return table<{ name: string }>|nil
function Database:get_tables()
  local sql_with_columns = "SELECT name FROM sqlite_master WHERE type='table';"
  self.log("Getting tables:", sql_with_columns)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self:execute(sql_with_columns)
end

---@return table<{ name: string, type: string }>|nil
function Database:get_columns(tableName)
  local sql_with_columns = string.format("PRAGMA table_info(%s);", tableName)
  self.log("Getting columns for", tableName, ":", sql_with_columns)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self:execute(sql_with_columns)
end

return Database
