local sqlite = require("sqlite")
local utils = require("sqlite.utils")

---@class ORMFieldOptions
---@field primary_key? boolean
---@field auto_increment? boolean
---@field default? any
---@field not_null? boolean
---@field unique? boolean

---@class ORMFieldDefinition
---@field type string
---@field options ORMFieldOptions

---@param type string
---@param opts? ORMFieldOptions
---@return ORMFieldDefinition
local function define_field(type, opts)
  opts = opts or {}
  local field_def = {
    type = type,
    options = opts,
  }
  return field_def
end

---@param db Database
---@param name string
---@param schema table<string, ORMFieldDefinition>
local function create_table_if_not_exists(db, name, schema)
  local columns = {}
  for field_name, def in pairs(schema) do
    local column = string.format("%s %s", field_name, def.type)

    if def.options.primary_key then column = column .. " PRIMARY KEY" end
    if def.options.auto_increment then column = column .. " AUTOINCREMENT" end
    if def.options.not_null then column = column .. " NOT NULL" end
    if def.options.unique then column = column .. " UNIQUE" end
    if def.options.default ~= nil then
      local default_value = type(def.options.default) == "string" and utils.escape_sql_string(def.options.default)
        or tostring(def.options.default)
      column = column .. " DEFAULT " .. default_value
    end

    table.insert(columns, column)
  end
  local sql = string.format("CREATE TABLE IF NOT EXISTS %s (%s);", name, table.concat(columns, ", "))
  db:sql(sql)
end

---@class ORMModel
---@field name string
---@field schema table<string, ORMFieldDefinition>
---@field db Database
local Model = {}
Model.__index = Model

function Model:connect(db_or_path, db_options)
  if type(db_or_path) == "string" then
    self.db = sqlite.open(db_or_path, db_options)
  else
    self.db = db_or_path
  end
  create_table_if_not_exists(self.db, self.name, self.schema)
  return self
end

function Model:get_primary_keys()
  local fields_with_primary_key = {}
  for field, def in pairs(self.schema) do
    if def.options.primary_key then table.insert(fields_with_primary_key, field) end
  end
  return fields_with_primary_key
end

function Model:create(data)
  assert(self.db, "Database not connected. Call :connect(db_or_path) first.")
  return self.db:insert(self.name, data)
end

function Model:find(condition)
  assert(self.db, "Database not connected. Call :connect(db_or_path) first.")
  return self.db:select(self.name, condition)
end

function Model:find_one(condition)
  local results = self:find(condition)
  return results and results[1] or nil
end

function Model:find_by_id(id)
  local primary_keys = self:get_primary_keys()
  assert(#primary_keys == 1, "Model must have exactly one primary key.")
  local primary_key = primary_keys[1]
  return self:find_one(string.format("%s = %d", primary_key, id))
end

function Model:all()
  return self:find()
end

function Model:update(condition, data)
  assert(self.db, "Database not connected. Call :connect(db_or_path) first.")
  return self.db:update(self.name, condition, data)
end

function Model:delete(condition)
  assert(self.db, "Database not connected. Call :connect(db_or_path) first.")
  return self.db:delete(self.name, condition)
end

function Model:query()
  assert(self.db, "Database not connected. Call :connect(db_or_path) first.")
  return {
    _model = self,
    _select = "*",
    _where = nil,
    _order_by = nil,
    _limit = nil,

    select = function(s, fields)
      s._select = type(fields) == "table" and table.concat(fields, ", ") or fields
      return s
    end,

    where = function(s, condition)
      s._where = condition
      return s
    end,

    order_by = function(s, fields)
      s._order_by = type(fields) == "table" and table.concat(fields, ", ") or fields
      return s
    end,

    limit = function(s, n)
      s._limit = tonumber(n)
      return s
    end,

    execute = function(s)
      local sql = string.format("SELECT %s FROM %s", s._select, s._model.name)
      if s._where then sql = sql .. " WHERE " .. s._where end
      if s._order_by then sql = sql .. " ORDER BY " .. s._order_by end
      if s._limit then sql = sql .. " LIMIT " .. s._limit end
      return s._model.db:sql(sql)
    end,
  }
end

local ORM = {}
ORM.__index = ORM

---@param opts? ORMFieldOptions
ORM.integer = function(opts)
  return define_field("INTEGER", opts)
end
---@param opts? ORMFieldOptions
ORM.text = function(opts)
  return define_field("TEXT", opts)
end
---@param opts? ORMFieldOptions
ORM.real = function(opts)
  return define_field("REAL", opts)
end

function ORM.define(name, schema)
  local model = setmetatable({}, Model)
  model.name = name
  model.schema = schema
  model.db = nil
  return model
end

return ORM
