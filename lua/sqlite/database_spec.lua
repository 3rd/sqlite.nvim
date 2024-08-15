---@diagnostic disable: need-check-nil

local Database = require("sqlite.database")

describe("database", function()
  ---@type Database
  local db

  before_each(function()
    db = Database.open(":memory:")
  end)

  it("should open a database", function()
    local result = db:execute(".mode", true)
    expect(result).toBe("current output mode: json")
  end)

  it("should execute a query", function()
    local result = db:execute("SELECT sqlite_version();")
    expect(type(result)).toBe("table")
    expect(type(result[1]["sqlite_version()"])).toBe("string")
  end)

  it("should close the database", function()
    db:close()
    expect(db.handle).toBe(nil)
  end)

  it("should create a table", function()
    db:create_table("users", { "id", "name" })

    local result = db:get_tables()
    expect(result[1]["name"]).toBe("users")
  end)

  it("should insert a record", function()
    db:create_table("users", { "id", "name" })

    db:insert("users", { id = 1, name = "John Doe" })

    local result = db:select("users")
    expect(result).toEqual({ { id = 1, name = "John Doe" } })
  end)

  it("should update a record", function()
    db:create_table("users", { "id", "name" })
    db:insert("users", { id = 1, name = "John Doe" })

    local result = db:select("users")
    expect(result).toEqual({ { id = 1, name = "John Doe" } })

    db:update("users", { name = "Jane Doe" }, "id = 1")
    result = db:select("users")
    expect(result).toEqual({ { id = 1, name = "Jane Doe" } })
  end)

  it("should delete a record", function()
    db:create_table("users", { "id", "name" })
    db:insert("users", { id = 1, name = "John Doe" })

    local result = db:select("users")
    expect(result).toEqual({ { id = 1, name = "John Doe" } })

    db:delete("users", "id = 1")
    result = db:select("users")
    expect(result).toBe(nil)
  end)

  it("should drop a table", function()
    db:create_table("users", { "id", "name" })

    local result = db:get_tables()
    expect(result[1]["name"]).toBe("users")

    db:drop_table("users")
    result = db:get_tables()
    expect(result).toBe(nil)
  end)

  it("should get columns for a table", function()
    db:create_table("users", { "id INTEGER PRIMARY KEY", "name TEXT NOT NULL" })

    local result = db:get_columns("users")
    expect(#result).toBe(2)
    expect(result[1]["name"]).toBe("id")
    expect(result[1]["type"]).toBe("INTEGER")
    expect(result[2]["name"]).toBe("name")
    expect(result[2]["type"]).toBe("TEXT")
  end)
end)
