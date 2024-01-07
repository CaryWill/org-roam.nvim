local utils = require("org-roam.utils")
local default_args = require("org-roam.default-args")

local luv = require("luv")
local sqlite = require("sqlite.db")
local sha1 = require("sha1")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local file_table = "org_roam_file_table"
local id_table = "org_roam_id_table"

-- TODO:
-- 1. Find all id links in containing file,
-- 2. Iterate through all id links, create a SQL record for each id
-- with this format { [linkId]: { fileId, id, filePath, idStartPos, idEndPos, idRow } }
-- 3. Backlink. Get all records in SQL and through all to see if current file id exist in { [linkId] ... } this table

local user_config = {}

local function setup(args)
	user_config = args or default_args
	if user_config.org_roam_directory == nil then
		print("Org Roam Error: Please provide `org_roam_directory`")
	end

	user_config.org_roam_directory = luv.fs_realpath(utils.expand_file_name(user_config.org_roam_directory)) .. "/"
	-- Why concatenate '/' ?
	-- Because `fs_realpath' return something like `/path/to/dir'
	-- And when creating new nodes(files) we concatenate file name with it like:
	--   /path/to/dir .. file_name
	-- Which is not what we assume there, what we assume is:
	--   /path/to/dir/ .. file_name
	-- And so concatenate '/' at the end
end

-- capture is for creating files by templates
local function org_roam_capture(title)
	if title == nil then
		title = vim.fn.input("Enter the title: ")
	end

	-- Replace all non-alphanumeric characters with an underscore
	local filename = os.date("%Y%m%d%H%M%S") .. "_" .. title:gsub("%A", "_")
	local category = ""
	-- TODO: is this OS limit or?
	if filename:len() > 251 then
		category = filename:sub(1, 251)
		filename = category .. ".org"
	else
		category = filename
		filename = category .. ".org"
	end

	local uuid = utils.get_uuid()
	local node_head = ":PROPERTIES:\n:ID:        " .. uuid .. "\n:END:\n#+title: " .. title .. "\n"

	local file_path = user_config.org_roam_directory .. filename
	local fp, err = io.open(file_path, "w")
	if fp == nil then
		print("Error: " .. err)
	else
		fp:write(node_head)
		fp:close()

		-- Do we need to update the hash when file changes?
		-- Is this verified in any way?
		local hash = sha1.sha1(node_head)

		local stat = luv.fs_stat(file_path)
		if not stat then
			print("ERROR: unable to get file stats")
		end

		-- Source: emacs-29.1/src/timefns.c:582
		local s = stat.atime.sec
		local ns = stat.atime.nsec
		local atime = "("
			.. bit.rshift(s, 16)
			.. " "
			.. bit.band(s, bit.lshift(1, 16) - 1)
			.. " "
			.. math.floor(ns / 1000)
			.. " "
			.. ns % 1000 * 1000
			.. ")"

		s = stat.mtime.sec
		ns = stat.atime.nsec
		local mtime = "("
			.. bit.rshift(s, 16)
			.. " "
			.. bit.band(s, bit.lshift(1, 16) - 1)
			.. " "
			.. math.floor(ns / 1000)
			.. " "
			.. ns % 1000 * 1000
			.. ")"

		-- File nodes have level 0
		-- Heading nodes have their heading level as level
		local level = 0

		-- Position of the node
		-- File nodes at pos 1
		-- Heading nodes have different position at file depending on where the
		-- first character is of that heading
		local pos = 1

		-- Why so complicated?
		local properties = '(("CATEGORY . "'
			.. category
			.. '") ("ID" . "'
			.. uuid
			.. '") ("BLOCKED" . "") ("FILE" . "'
			.. filename
			.. '") ("PRIORITY" . "B"))'

		sqlite.with_open(user_config.org_roam_database_file, function(db)
			local ok = db:eval(
				"INSERT INTO files(file, title, hash, atime, mtime) " .. "VALUES(:file, :title, :hash, :atime, :mtime);",
				{
					file = file_path,
					title = title,
					hash = hash,
					atime = atime,
					mtime = mtime,
				}
			)
			if not ok then
				-- TODO: it should have an early return?
				print("ERROR: Something went wrong with inserting data into `files' table")
			end
			ok = db:eval(
				"INSERT INTO nodes(id, level, pos, file, title, properties) "
					.. "VALUES(:id, :level, :pos, :file, :title, :properties);",
				{
					id = uuid,
					level = level,
					pos = pos,
					file = file_path,
					title = title,
					properties = properties,
				}
			)
			if not ok then
				print("ERROR: Something went wrong with inserting data into `nodes' table")
			end
		end)

		-- go to the created file editing
		vim.cmd.edit(file_path)
	end
end

local function org_roam_node_find()
	-- TODO: I can just update tables inside this function
	-- although the first time to build up the database
	-- maybe slow but I will use sha1 to cache

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")
	local id = utils.find_file_id(content)
	local back_links = utils.get_back_links(id, user_config.org_roam_database_file, "example_table")
	local locations = {}
	for _, back_link in ipairs(back_links) do
		local line_content = utils.read_lines_from_file(back_link.file_path, back_link.start_row, back_link.end_row)[1]
		table.insert(locations, {
			filename = back_link.file_path,
			lnum = back_link.start_row,
			col = back_link.start_col,
			text = line_content,
		})
	end

	-- Clear existing location list
	vim.fn.setloclist(0, {})

	-- Add new entries to the location list
	for _, loc in ipairs(locations) do
		vim.fn.setloclist(0, { loc }, "a")
	end
	vim.cmd("lopen")

	-- TODO: use telescope or location list
	-- the author use telescope here, for simplicity
	-- I use location list first here
end

return {
	setup = setup,
	org_roam_capture = org_roam_capture,
	org_roam_node_find = org_roam_node_find,
}
