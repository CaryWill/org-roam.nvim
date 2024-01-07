-- local dbpath = "/Users/cary/workspace/github/dotfiles/tests/lua/test.db"
-- local dbpath = "/Users/cary/.config/emacs/org-roam.db"
local dbpath = "~/.config/emacs/org-roam.db"
local sqlite = require("sqlite")
local sqliteDB = require("sqlite.db")
local table_name = "example_table"
local roam_folder = "~/OrgRoam"
local utils = require("org-roam.utils")

describe("sql", function()
	it("build database for id links of files", function()
		local db = sqlite:open(dbpath)
		utils.process_folder(roam_folder, function(matches)
			if not db:exists(table_name) then
				db:create(table_name, {
					id = { "int", "primary", "key" },
					file_path = "text",
					file_id = "text",
					id_links = "text",
				})
			end

			if matches.file_id ~= nil then
				local records = db:select(table_name, { where = { file_id = matches.file_id } })

				if #records == 0 then
					db:insert(table_name, {
						id = matches.file_id,
						file_id = matches.file_id,
						file_path = matches.file_path,
						id_links = vim.json.encode(matches.id_links),
					})
				else
					-- NOTE: some times I could not update
					-- because it says the database is locked
					-- I guess, because there's an ongoing
					-- connection connected to the database
					-- which I opened using an App(DB Browser for SQLite)
					-- to view the  data
					db:update(table_name, {
						where = { file_id = matches.file_id },
						set = {
							file_id = matches.file_id,
							file_path = matches.file_path,
							id_links = vim.json.encode(matches.id_links),
						},
					})
					-- TODO: I dont know why I cannot get with_open to work
					-- db:close should be put at the end
				end
			end
		end)
		db:close()
	end)
	it("with open", function()
		-- TODO: db:close should be put at the end
		-- I dont know why I cannot get with_open to work
	end)

	it("get backlinks", function()
		local current_file_id = "C6DDDD61-9A5B-4BD6-BD65-C521B71D5D35"
		local current_file_path = "/Users/cary/OrgRoam/20240104201813_test2.org"
		local db = sqlite:open(dbpath)
		local back_links = {}
		local records = db:select(table_name)
		for index, value in ipairs(records) do
			local id_links = vim.json.decode(value.id_links)
			for _, id_link in ipairs(id_links) do
				if id_link.id == current_file_id then
					table.insert(back_links, id_link)
				end
			end
		end
		print(vim.inspect(back_links))
		db:close()
	end)
end)
