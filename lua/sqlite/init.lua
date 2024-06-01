local Database = require("sqlite.database")

local setup = function()
  print("setup")
end

return {
  setup = setup,
  Database = Database,
}
