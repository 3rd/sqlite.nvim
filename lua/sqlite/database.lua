local utils = require("sqlite.utils")

local uv = vim.loop
local EOF_MARKER = "--EOF--"

---@class Database
---@field path string
---@field handle uv_process_t|nil
---@field stdio { stdin: uv_pipe_t, stdout: uv_pipe_t, stderr: uv_pipe_t }|nil
---@field debug boolean
---@field timeout number
---@field output string
---@field error__output string
---@field ready boolean
---@field log fun(...)
local Database = {}
Database.__index = Database

---@param path string
---@param options? { debug?: boolean, timeout?: number }
function Database.open(path, options)
  local self = setmetatable({
    path = path,
    debug = options and options.debug or false,
    timeout = options and options.timeout or 5000,
    ready = false,
    output = "",
  }, { __index = Database })
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

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

  self.handle = uv.spawn("sqlite3", {
    args = { path },
    stdio = { stdin, stdout, stderr },
  }, function(code, signal)
    stdin:close()
    stdout:close()
    stderr:close()
    self.log("SQLite process closed with code:", code, "and signal:", signal)
  end)

  if not self.handle then error("Failed to spawn SQLite process. Is sqlite3 installed and in your PATH?") end

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
    if data then
      self.log("Received stderr data:", data)
      self.error_output = self.error_output .. data
    end
  end)

  -- bootstrap
  self:execute(".mode json")
  self:execute("PRAGMA busy_timeout = 5000;")

  return self
end

function Database:assert_open()
  assert(self.handle, "Database connection is closed or not initialized.")
end

---@param command string
---@param raw? boolean
---return table|string|nil
function Database:execute(command, raw)
  self:assert_open()

  self.output = ""
  self.error_output = ""
  self.ready = false

  self.log("Executing command:", command)

  self.stdio.stdin:write(command .. "\n")
  self.stdio.stdin:write(".print '" .. EOF_MARKER .. "'\n")

  local start_time = uv.now()
  while not self.ready do
    if uv.now() - start_time > self.timeout then
      error(string.format("SQLite query timed out after %d ms: %s", self.timeout, command))
    end
    uv.run("once")
  end

  if self.error_output ~= "" then
    --
    error("SQLite error: " .. self.error_output)
  end

  local trimmed_output = vim.trim(vim.fn.substitute(self.output, EOF_MARKER, "", ""))
  if trimmed_output == "" then
    self.log("Debug: Query yielded no output.")
    return nil
  else
    self.log("Received output:", trimmed_output)
  end

  if raw then return trimmed_output end

  local ok, json_output = pcall(vim.fn.json_decode, trimmed_output)
  if not ok then error("Failed to decode JSON from SQLite output: " .. trimmed_output) end

  if json_output ~= nil and type(json_output) ~= "table" then
    error("Expected JSON output to be a table, got: " .. type(json_output))
  end

  self.log("Parsed JSON:", json_output)
  return json_output
end

---@param sql string
---@return table|nil
function Database:sql(sql)
  self:assert_open()
  if not vim.endswith(sql, ";") then sql = sql .. ";" end
  ---@diagnostic disable-next-line: return-type-mismatch
  return self:execute(sql)
end

function Database:close()
  self.log("Closing database connection.")
  if not self.handle then error("Database is already closed or not initialized.") end
  self.stdio.stdin:write(".exit\n")
  self.stdio.stdin:close()
  self.stdio.stdout:close()
  self.stdio.stderr:close()
  uv.close(self.handle)
  self.log("Handle closed.")
  self.handle = nil
end

---@param tableName string
---@param data table
function Database:insert(tableName, data)
  self:assert_open()
  local keys = {}
  local values = {}
  for key, value in pairs(data) do
    table.insert(keys, key)
    if type(value) == "string" then
      table.insert(values, utils.escape_sql_string(value))
    else
      table.insert(values, tostring(value))
    end
  end

  local sql = string.format(
    "INSERT INTO %s (%s) VALUES (%s); SELECT last_insert_rowid();",
    tableName,
    table.concat(keys, ", "),
    table.concat(values, ", ")
  )
  self.log("Inserting into", tableName, ":", sql)
  local result = self:execute(sql)
  if type(result) == "table" and #result > 0 then return result[1]["last_insert_rowid()"] end
  return result
end

---@param tableName string
---@param condition? string
---@param columns? string
---@return table|nil
function Database:select(tableName, condition, columns)
  self:assert_open()
  columns = columns or "*"
  if type(columns) == "table" then columns = table.concat(columns, ", ") end
  local sql = string.format("SELECT %s FROM %s", columns, tableName)
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Selecting from", tableName, "with condition:", condition or "None")
  local result = self:execute(sql)
  assert(type(result) == "table" or result == nil, "Expected table or nil, got " .. type(result))
  return result
end

---@param tableName string
---@param condition? string
---@param data table
function Database:update(tableName, condition, data)
  self:assert_open()
  local updates = {}
  for key, value in pairs(data) do
    local updatePart = string.format("%s = ", key)
    if type(value) == "string" then
      updatePart = updatePart .. utils.escape_sql_string(value)
    else
      updatePart = updatePart .. tostring(value)
    end
    table.insert(updates, updatePart)
  end

  local sql = string.format("UPDATE %s SET %s", tableName, table.concat(updates, ", "))
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Updating", tableName, "with condition:", condition or "None")
  return self:execute(sql)
end

---@param tableName string
---@param condition? string
function Database:delete(tableName, condition)
  self:assert_open()
  local sql = string.format("DELETE FROM %s", tableName)
  if condition then sql = sql .. " WHERE " .. condition end
  sql = sql .. ";"
  self.log("Deleting from", tableName, "with condition:", condition or "None")
  return self:execute(sql)
end

---@param tableName string
---@param columns string[]
function Database:create_table(tableName, columns)
  self:assert_open()
  local sql = string.format("CREATE TABLE %s (%s);", tableName, table.concat(columns, ", "))
  self.log("Creating table", tableName, ":", sql)
  return self:execute(sql)
end

---@param tableName string
function Database:drop_table(tableName)
  self:assert_open()
  local sql = string.format("DROP TABLE %s;", tableName)
  self.log("Dropping table", tableName, ":", sql)
  return self:execute(sql)
end

---@return table<{ name: string }>|nil
function Database:get_tables()
  self:assert_open()
  local sql_with_columns = "SELECT name FROM sqlite_master WHERE type='table';"
  self.log("Getting tables:", sql_with_columns)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self:execute(sql_with_columns)
end

---@return table<{ name: string, type: string }>|nil
function Database:get_columns(tableName)
  self:assert_open()
  local sql_with_columns = string.format("PRAGMA table_info(%s);", tableName)
  self.log("Getting columns for", tableName, ":", sql_with_columns)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self:execute(sql_with_columns)
end

return Database
