-- local dbpath = "/Users/cary/workspace/github/dotfiles/tests/lua/test.db"
local dbpath = "/Users/cary/.config/emacs/org-roam.db"
local sqlite = require("sqlite")
local sqliteDB = require("sqlite.db")
local table_name = "example_table"

describe("sql", function()
	it("test", function()
		local db = sqlite:open(dbpath)
		-- local records = db:select("projects", { where = { title = "sqlite" } })
		if not db:exists(table_name) then
			db:create(table_name, {
				id = { "int", "primary", "key" },
				filepath = "text",
				fileid = "text",
				idlinks = "text",
			})
		else
			db:insert(table_name, { id = 123455, filepath = "123", fileid = "123", idlinks = "adf" })
		end
		db:close()
	end)
end)
