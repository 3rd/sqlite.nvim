---@diagnostic disable: need-check-nil

local orm = require("sqlite.orm")

describe("orm", function()
  ---@type ORMModel
  local User

  before_each(function()
    User = orm.define("users", {
      id = orm.integer({ primary_key = true, auto_increment = true }),
      name = orm.text({ not_null = true }),
      email = orm.text({ unique = true }),
      age = orm.integer(),
    })
    User:connect(":memory:")
    User:create({ name = "User1", email = "user1@example.com", age = 20 })
    User:create({ name = "User2", email = "user2@example.com", age = 30 })
    User:create({ name = "User3", email = "user3@example.com", age = 40 })
  end)

  it("should create a model with the correct schema", function()
    expect(User.name).toBe("users")
    expect(User.schema.id.type).toBe("INTEGER")
    expect(User.schema.name.type).toBe("TEXT")
  end)

  it("should create a new record", function()
    local id = User:create({ name = "John Doe", email = "john@example.com", age = 30 })
    expect(id).toBe(4)

    local user = User:find_by_id(id)
    expect(user.id).toBe(4)
    expect(user.name).toBe("John Doe")
    expect(user.email).toBe("john@example.com")
    expect(user.age).toBe(30)
  end)

  it("should read records", function()
    User:create({ name = "Jane Doe", email = "jane@example.com", age = 25 })
    User:create({ name = "Bob Smith", email = "bob@example.com", age = 40 })

    local users = User:all()
    expect(#users).toBe(5)

    local young_users = User:find("age < 30")
    expect(#young_users).toBe(2)
    expect(young_users[2].name).toBe("Jane Doe")
  end)

  it("should update records", function()
    local id = User:create({ name = "Alice Brown", email = "alice@example.com", age = 35 })

    User:update("id = " .. id, { age = 36 })
    expect(User:find_by_id(id).age).toBe(36)

    User:update("name = 'Alice Brown'", { age = 37 })
    expect(User:find_one("name = 'Alice Brown'").age).toBe(37)
  end)

  it("should delete records", function()
    User:create({ name = "Charlie Green", email = "charlie@example.com", age = 45 })
    expect(User:find_one("name = 'Charlie Green'").age).toBe(45)

    User:delete("name = 'Charlie Green'")
    expect(User:find_one("name = 'Charlie Green'")).toBe(nil)
  end)

  it("should select specific fields", function()
    local result = User:query():select({ "name", "age" }):execute()
    expect(#result).toBe(3)
    local keys = vim.tbl_keys(result[1])
    table.sort(keys)
    expect(keys).toEqual({ "age", "name" })
  end)

  it("should filter with where clause", function()
    local result = User:query():where("age > 25"):execute()
    expect(#result).toBe(2)
    expect(result[1].name).toBe("User2")
  end)

  it("should order results", function()
    local result = User:query():order_by("age DESC"):execute()
    expect(result[1].name).toBe("User3")
    expect(result[3].name).toBe("User1")
  end)

  it("should limit results", function()
    local result = User:query():limit(2):execute()
    expect(#result).toBe(2)
  end)

  it("should chain methods", function()
    local result = User:query():select({ "name", "age" }):where("age > 25"):order_by("age DESC"):limit(1):execute()

    expect(#result).toBe(1)
    expect(result[1].name).toBe("User3")
    local keys = vim.tbl_keys(result[1])
    table.sort(keys)
    expect(keys).toEqual({ "age", "name" })
  end)

  it("should throw an error when trying to use an unconnected model", function()
    local UnconnectedModel = orm.define("unconnected", {
      id = orm.integer({ primary_key = true, auto_increment = true }),
      name = orm.text(),
    })

    expect(function()
      UnconnectedModel:create({ name = "Test" })
    end).toThrow("Database not connected. Call :connect(db_or_path) first.")
  end)
end)
