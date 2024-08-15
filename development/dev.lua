local orm = require("sqlite.orm")
local sqlite = require("sqlite")

-- open a database
local db = sqlite.open("test.db", { debug = true })

-- execute a query
local result = db:sql("SELECT sqlite_version()")
print(result[1]["sqlite_version()"])

User = orm.define("users", {
  id = orm.integer({ primary_key = true, auto_increment = true }),
  name = orm.text({ not_null = true }),
  email = orm.text({ unique = true }),
  age = orm.integer(),
})
User:connect(":memory:", { debug = true })
User:create({ name = "User1", email = "user1@example.com", age = 20 })
User:create({ name = "User2", email = "user2@example.com", age = 30 })
User:create({ name = "User3", email = "user3@example.com", age = 40 })
