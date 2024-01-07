-- local dbpath = "/Users/cary/workspace/github/dotfiles/tests/lua/test.db"
-- local dbpath = "/Users/cary/.config/emacs/org-roam.db"
local dbpath = "~/.config/emacs/org-roam.db"
local sqlite = require("sqlite")
local sqliteDB = require("sqlite.db")
local table_name = "example_table"
local roam_folder = "~/OrgRoam"
local utils = require("org-roam.utils")

describe("sql", function()
	it("open", function()
		local db = sqlite:open(dbpath)
		if not db:exists(table_name) then
			db:create(table_name, {
				id = { "int", "primary", "key" },
				filepath = "text",
				fileid = "text",
				idlinks = "text",
			})
		else
			local records = db:select(table_name)
			utils.process_folder(roam_folder, function(matches)
				vim.print(matches)
			end)
			-- vim.print(vim.inspect(records))
			-- assert.equals(records, true)
			-- db:insert(table_name, { id = 1234556, filepath = "1234", fileid = "1234", idlinks = "adf2" })
		end
		-- TODO: db:close should be put at the end
		-- I dont know why I cannot get with_open to work
		db:close()
	end)
	it("with open", function()
		-- FIXME: Still couldn'tget it to work
		--
		-- local records = sqlite:with_open(dbpath, function(db)
		-- return sqlite:select(table_name, { where = { fileid = "123" } })
		-- TODO: db:close should be put at the end
		-- I dont know why I cannot get with_open to work
		-- end)
		-- assert.equals(records, true)
	end)
end)
