local Database = require("sqlite").Database

local db = Database.open(":memory:", { debug = true })
