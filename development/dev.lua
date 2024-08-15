local sqlite = require("sqlite")

-- open a database
local db = sqlite.open("test.db", { debug = true })

-- execute a query
local result = db:sql("SELECT sqlite_version()")
print(result[1]["sqlite_version()"])
