-- local dbpath = "/Users/cary/workspace/github/dotfiles/tests/lua/test.db"
-- local dbpath = "/Users/cary/.config/emacs/org-roam.db"
local dbpath = "~/.config/emacs/org-roam.db"
local sqlite = require("sqlite")
local sqliteDB = require("sqlite.db")
local table_name = "example_table"
local roam_folder = "~/OrgRoam"
local utils = require("org-roam.utils")

describe("sql", function()
	-- TODO: use sha1 to cache
	it("build database for id links of files", function()
		utils.build_database(dbpath, roam_folder, table_name)
	end)
	it("with open", function()
		-- TODO: db:close should be put at the end
		-- I dont know why I cannot get with_open to work
	end)

	it("get backlinks", function()
		local current_file_id = "C6DDDD61-9A5B-4BD6-BD65-C521B71D5D35"
		local back_links = utils.get_back_links(current_file_id, dbpath, table_name)
	end)
end)
