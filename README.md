# sqlite.nvim

This is a toy Lua library for working with SQLite libraries through the `sqlite` CLI.
\
It's just a personal experiment, don't to use it.

### Requirements

- `sqlite3` in `PATH`

### Usage

```lua
local Database = require('sqlite.database')

-- raw
local db = Database.open(":memory:")
db:execute("SELECT sqlite_version()")
db:close()

-- table helpers
local tables = db:get_tables()
local columns = db:get_columns("users")
db:create_table("users", {
  "id INTEGER PRIMARY KEY",
  "name TEXT NOT NULL",
  "email TEXT NOT NULL"
})
db:drop_table("users")

-- record helpers
local users = db:fetch("users", "*", "name = 'John Doe'")
db:insert("users", {
  id = 1,
  name = "John Doe",
  email = "john.doe@example.com"
})
db:update("users", { name = "Jane Doe" }, "id = 1")
db:delete("users", "id = 1")
```
