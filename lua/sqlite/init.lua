local Database = require("sqlite.database")

local M = {}

function M.open(path, options)
  return Database.open(path, options)
end

return M
