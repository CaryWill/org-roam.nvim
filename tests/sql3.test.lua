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
		utils.process_folder(roam_folder, function(matches)
			local db = sqlite:open(dbpath)
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
				print(records, matches.file_id, 123213)

				if #records == 0 then
					db:insert(table_name, {
						id = matches.file_id,
						file_id = matches.file_id,
						file_path = matches.file_path,
						id_links = vim.json.encode(matches.id_links),
					})
				else
					-- db:update(table_name, {
					-- 	where = { file_id = matches.file_id },
					-- 	set = {
					-- 		file_id = matches.file_id,
					-- 		file_path = matches.file_path,
					-- 		id_links = vim.json.encode(matches.id_links),
					-- 	},
					-- })
					-- update
					-- create a record
					-- db:insert(table_name, {
					-- 	file_id = matches.file_id,
					-- 	file_path = matches.file_path,
					-- 	id_links = vim.json.encode(matches.id_links),
					-- })
					-- TODO: db:close should be put at the end
					-- I dont know why I cannot get with_open to work
					db:close()
				end
			end
		end)

		-- vim.print(vim.inspect(records))
		-- assert.equals(records, true)
		-- db:insert(table_name, { id = 1234556, filepath = "1234", fileid = "1234", idlinks = "adf2" })
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
