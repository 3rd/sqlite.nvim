# sqlite.nvim

Library for working with SQLite databases in Neovim.
\
Requires `sqlite3` in `PATH`.

### Usage - Database

```lua
local sqlite = require("sqlite")

-- open and close a database
local db = sqlite.open("test.db") -- or ":memory:"
db:close()

-- execute commands with db:exec         command   raw (don't parse as JSON)
local result = db:exec("SELECT sqlite_version();", false)
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
local users = db:select("users", "name = 'John Doe'", "*")

-- update a record
db:sql("UPDATE users SET name = 'Jane Doe' WHERE id = 1")
-- or
db:update("users", "id = 1", { name = "Jane Doe" })

-- delete a record
db:sql("DELETE FROM users WHERE id = 1")
-- or
db:delete("users", "id = 1")

-- drop a table
db:sql("DROP TABLE users")
-- or
db:drop_table("users")

-- get tables and columns
local tables = db:get_tables()
local columns = db:get_columns("users")
```

### Usage - ORM

The plugin also provides a tiny ORM that you might find useful.

```lua
local orm = require("sqlite.orm")

-- define a model
local User = orm.define("users", {
  id = orm.integer({ primary_key = true, auto_increment = true }),
  name = orm.text({ not_null = true }),
  email = orm.text({ unique = true }),
  age = orm.integer(),
})

-- connect to a database
User:connect(":memory:")

-- create a new record
local id = User:create({ name = "John Doe", email = "john@example.com", age = 30 })

-- read records
local users = User:all()
local users = User:find("age < 30")
local user = User:find_by_id(1)
local user = User:find_one("name = 'John Doe'")

-- update a record
User:update({ age = 36 }, "id = " .. id)

-- delete a record
User:delete("id = " .. id)

-- query builder
local young_users = User:query():select({ "name", "age" }):where("age < 50"):order_by("age DESC"):limit(1):execute()
```

### API

#### Database

When you execute `sqlite.open("test.db")`, a new `sqlite3` process is spawned and you get back a `Database` object.

| Method                                       | Description                                                                               |
| -------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `db:open(path, options)`                     | Opens a new database connection, options defaults to `{ debug = false, timeout = 5000 }`. |
| `db:close()`                                 | Closes the database connection.                                                           |
| `db:exec(command, raw?)`                     | Executes a command and returns the output as a `table`, `string` or `nil`.                |
| `db:sql(command)`                            | Like `Database:exec`, but ensures trailing `;` and JSON parsing.                          |
| `db:get_tables()`                            | Returns a list of tables.                                                                 |
| `db:get_columns(tableName)`                  | Returns a list of columns for a table.                                                    |
| `db:create_table(tableName, columns)`        | Syntactic sugar for creating a table.                                                     |
| `db:drop_table(tableName)`                   | Syntactic sugar for dropping a table.                                                     |
| `db:insert(tableName, data)`                 | Syntactic sugar for inserting a record.                                                   |
| `db:select(tableName, condition?, columns?)` | Syntactic sugar for selecting records.                                                    |
| `db:update(tableName, condition?, data)`     | Syntactic sugar for updating records.                                                     |
| `db:delete(tableName, condition?)`           | Syntactic sugar for deleting records.                                                     |

#### ORM

| Method                                   | Description                                       |
| ---------------------------------------- | ------------------------------------------------- |
| `orm.define(name, schema)`               | Defines a new model.                              |
| `orm.integer(opts?)`                     | Helper for defining an integer field.             |
| `orm.text(opts?)`                        | Helper for defining a text field.                 |
| `orm.real(opts?)`                        | Helper for defining a real field.                 |
| `model:connect(db_or_path, db_options?)` | Connects the model to a database.                 |
| `model:get_primary_keys()`               | Returns the primary keys for the model.           |
| `model:create(data)`                     | Creates a new record.                             |
| `model:find(condition?)`                 | Finds records.                                    |
| `model:find_one(condition?)`             | Finds a single record.                            |
| `model:find_by_id(id)`                   | Finds a record by its ID (must have a single PK). |
| `model:all()`                            | Gets all records.                                 |
| `model:update(condition?, data)`         | Updates records.                                  |
| `model:delete(condition?)`               | Deletes records.                                  |
| `model:query()`                          | Returns a query builder.                          |
| `query:select(fields?)`                  | Selects specific fields.                          |
| `query:where(condition?)`                | Filters records with a condition.                 |
| `query:order_by(fields?)`                | Orders records by a field.                        |
| `query:limit(n)`                         | Limits the number of records returned.            |
| `query:execute()`                        | Executes the query and returns the result.        |

### Development

```sh
git clone --recurse-submodules https://github.com/3rd/sqlite.nvim
cd sqlite.nvim
make # you'll see all the available commands
```
