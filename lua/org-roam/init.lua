local utils = require("org-roam.utils")
local default_args = require("org-roam.default-args")
local sqlite = require("sqlite")
local luv = require("luv")

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

	user_config.org_roam_capture_directory = luv.fs_realpath(
		utils.expand_file_name(user_config.org_roam_capture_directory or user_config.org_roam_directory)
	) .. "/"

	user_config.org_roam_directory = luv.fs_realpath(utils.expand_file_name(user_config.org_roam_directory)) .. "/"
	-- Why concatenate '/' ?
	-- Because `fs_realpath' return something like `/path/to/dir'
	-- And when creating new nodes(files) we concatenate file name with it like:
	--   /path/to/dir .. file_name
	-- Which is not what we assume there, what we assume is:
	--   /path/to/dir/ .. file_name
	-- And so concatenate '/' at the end

	-- other plugin can use this config
	vim.g.org_roam_config = user_config
end

-- capture is for creating files by templates
local function org_roam_capture(title)
	if title == nil then
		title = vim.fn.input("Enter the title: ")
	end

	-- Replace all non-alphanumeric characters with an underscore
	-- local filename = title:gsub("%A", "_") .. "_" .. os.date("%Y%m%d%H%M%S")
	local filename = title:gsub("%A", "_")
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
	local date_str = os.date("[%Y-%m-%d %a %H:%M]")
	-- TODO: support template, you can refer to neovim orgmode's template impl
	local node_head = ":PROPERTIES:\n:ID: " .. uuid .. "\n:END:\n#+title: " .. title .. "\n#+date: " .. date_str
	local file_path = (user_config.org_roam_capture_directory or user_config.org_roam_directory) .. filename
	local fp, err = io.open(file_path, "w")
	if fp == nil then
		print("Error: " .. err)
	else
		fp:write(node_head)
		fp:close()

		-- TODO: maybe refactor to this structure
		-- id = uuid,
		-- evel = level,
		-- os = pos,
		-- ile = file_path,
		-- itle = title,
		-- roperties = properties,
		-- Source: emacs-29.1/src/timefns.c:582

		-- File nodes have level 0
		-- Heading nodes have their heading level as level
		-- local level = 0

		-- Position of the node
		-- File nodes at pos 1
		-- Heading nodes have different position at file depending on where the
		-- first character is of that heading
		-- local pos = 1

		-- go to the created file editing
		vim.cmd.edit(file_path)
	end
end

local function org_roam_node_find()
	-- build the database
	utils.build_database(user_config.org_roam_database_file, user_config.org_roam_directory, "example_table")

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

	if #locations ~= 0 then
		vim.cmd("lopen")
	else
		vim.print("no backlink found!")
	end

	-- NOTE: moved to a global function
	-- for other plugin to call, like my nodejs neovim plugin
	-- local db = sqlite:open(user_config.org_roam_database_file)
	-- local records = db:select("example_table")
	-- db:close()
	-- vim.fn.UpdateGraphData(vim.json.encode(records))

	-- TODO: use telescope or location list
	-- the author use telescope here, for simplicity
	-- I use location list first here
end

-- NOTE: data should look like this
local orgRoamGraphData = {
	nodes = {
		{
			id = "DECE55A6-D4C9-40ED-BF9A-D7AA86D9AA3B",
			file = "/Users/cary/Library/Mobile Documents/com~apple~CloudDocs/Plain Org/zettelkasten/fleeting/How_to_learn_English_20240107210714.org",
			title = "How to learn English",
			level = 0,
			pos = 0,
			properties = {},
			tags = {},
			olp = nil,
		},
		{
			id = "2BFBA6D5-5D41-481C-BC75-C81F23291505",
			file = "/Users/cary/Library/Mobile Documents/com~apple~CloudDocs/Plain Org/zettelkasten/fleeting/Go_to_canada_20240107210453.org",
			title = "How to learn English 2",
			level = 0,
			pos = 0,
			properties = {},
			tags = {},
			olp = nil,
		},
		{
			id = "2BFBA6D5-5D41-481C-BC75-C81F23291506",
			file = "/Users/cary/Library/Mobile Documents/com~apple~CloudDocs/Plain Org/zettelkasten/fleeting/Go_to_canada_20240107210453.org",
			title = "How to learn English 3",
			level = 0,
			pos = 0,
			properties = {},
			tags = {},
			olp = nil,
		},
	},
	links = {
		{
			source = "2BFBA6D5-5D41-481C-BC75-C81F23291505",
			target = "DECE55A6-D4C9-40ED-BF9A-D7AA86D9AA3B",
			type = "bad",
		},
		{
			source = "2BFBA6D5-5D41-481C-BC75-C81F23291505",
			target = "2BFBA6D5-5D41-481C-BC75-C81F23291506",
			type = "bad",
		},
	},
	tags = {},
}

_G.GetLatestGraphData = function()
	-- TODO: build database will be time consuming if your notes grow larger?
	-- for now just rebuild everytime this function is called
	utils.build_database(user_config.org_roam_database_file, user_config.org_roam_directory, "example_table")
	local db = sqlite:open(user_config.org_roam_database_file)
	local records = db:select("example_table")
	db:close()
	return vim.json.encode(records)
end

return {
	setup = setup,
	org_roam_capture = org_roam_capture,
	org_roam_node_find = org_roam_node_find,
}
