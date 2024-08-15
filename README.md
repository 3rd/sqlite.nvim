# sqlite.nvim

Lua library for working with SQLite databases.
\
Requires `sqlite3` in `PATH`.

## Usage

```lua
local sqlite = require("sqlite")

-- open and close a database
local db = sqlite.open("test.db") -- or ":memory:"
db:close()

-- execute commands with db:exec         command   as_json
local result = db:exec("SELECT sqlite_version();", true)
-- or with db:sql (appends ";", parses JSON)
local result = db:sql("SELECT sqlite_version()")

-- create a table
db:sql("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
-- or
db:execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")
-- or
db:create_table("users", {
    "id INTEGER PRIMARY KEY",
    "name TEXT NOT NULL",
})

-- insert a record
db:sql("INSERT INTO users (id, name) VALUES (1, 'John Doe')")
-- or
db:insert("users", { id = 1, name = "John Doe" })

-- fetch records
local users = db:sql("SELECT * FROM users WHERE name = 'John Doe'")
-- or
local users = db:fetch("users", "*", "name = 'John Doe'")

-- update a record
db:sql("UPDATE users SET name = 'Jane Doe' WHERE id = 1")
-- or
db:update("users", { name = "Jane Doe" }, "id = 1")

-- delete a record
db:sql("DELETE FROM users WHERE id = 1")
-- or
db:delete("users", "id = 1")

-- drop a table
db:sql("DROP TABLE users")
-- or
db:drop_table("users")

-- get tables and columns
local tables = db:sql("SELECT name FROM sqlite_master WHERE type='table';")
local columns = db:sql("PRAGMA table_info(users);")
-- or
local tables = db:get_tables()
local columns = db:get_columns("users")
```

## API

### Database

When you execute `sqlite.open("test.db")`, a new `sqlite3` process is spawned and you get back a `Database` object.

| Method                                       | Description                                                                               |
| -------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `db:open(path, options)`                     | Opens a new database connection, options defaults to `{ debug = false, timeout = 5000 }`. |
| `db:close()`                                 | Closes the database connection.                                                           |
| `db:exec(command, as_json)`                  | Executes a command and returns the output as a `table`, `string` or `nil`.                |
| `db:sql(command)`                            | Like `Database:exec`, but ensures trailing `;` and JSON parsing.                          |
| `db:get_tables()`                            | Returns a list of tables.                                                                 |
| `db:get_columns(tableName)`                  | Returns a list of columns for a table.                                                    |
| `db:create_table(tableName, columns)`        | Syntactic sugar for creating a table.                                                     |
| `db:drop_table(tableName)`                   | Syntactic sugar for dropping a table.                                                     |
| `db:insert(tableName, data)`                 | Syntactic sugar for inserting a record.                                                   |
| `db:select(tableName, columns?, condition?)` | Syntactic sugar for selecting records.                                                    |
| `db:update(tableName, data, condition?)`     | Syntactic sugar for updating records.                                                     |
| `db:delete(tableName, condition?)`           | Syntactic sugar for deleting records.                                                     |
