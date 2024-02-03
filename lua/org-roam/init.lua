local utils = require("org-roam.utils")
local default_args = require("org-roam.default-args")
local sqlite = require("sqlite")
local luv = require("luv")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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

	-- capture zettles
	-- TODO: default value, when you can just press enter
	local selected_zettle_path = ""
	local choice_name = ""
	if user_config.org_roam_zettle_paths ~= nil then
		local org_roam_zettle_paths = user_config.org_roam_zettle_paths
		for i, item in ipairs(org_roam_zettle_paths) do
			org_roam_zettle_paths[i] = string.format("%d. %s", i, item)
		end
		-- Prompt the user with a selection list
		local choice = vim.fn.inputlist(org_roam_zettle_paths)
		choice_name = org_roam_zettle_paths[choice]:match("%d+%. (.+)")
		selected_zettle_path = choice_name .. "/"
	end

	-- Replace all non-alphanumeric characters with an underscore
	-- local filename = title:gsub("%A", "_") .. "_" .. os.date("%Y%m%d%H%M%S")
	-- Replace all alphanumeric characters with an underscore
	local filename = title:gsub("%a", "_")
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
	-- other properties
	local other_properties = ""
	-- i dont know what to call it, like #+filetags
	local others = ""
	if choice_name ~= nil and choice_name == "main" then
		other_properties = ""
		others = "\n#+filetags: :draft:\n"
	end

	local node_head = ":PROPERTIES:\n:ID: "
		.. uuid
		.. "\n"
		.. other_properties
		.. ":END:\n#+title: "
		.. title
		.. "\n#+date: "
		.. date_str
		.. others
	local file_path = (user_config.org_roam_capture_directory or user_config.org_roam_directory)
		.. selected_zettle_path
		.. filename
	-- TODO: make directory if directory not exist(you can use the fn in utils.lua file)
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
		-- local buf = vim.api.nvim_get_current_buf()
		-- local line_count = vim.api.nvim_buf_line_count(buf)
		-- Add two new empty lines
		-- vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { "", "" })
		-- Move the cursor to the new empty line
		-- vim.api.nvim_win_set_cursor(0, { line_count + 2, 0 })
		-- vim.api.nvim_input("i")
	end
end

-- find all backlinks
local function org_roam_buffer_toggle(opts)
	opts = opts or {}
	local open_loc = opts.open_loc
	if open_loc == nil then
		open_loc = true
	end
	-- build the database
	utils.build_database(user_config.org_roam_database_file, user_config.org_roam_directory, "example_table")

	-- TODO: I can just update tables inside this function
	-- although the first time to build up the database
	-- maybe slow but I will use sha1 to cache

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")
	local id = utils.find_file_id(content)
	local current_file_path = vim.api.nvim_buf_get_name(0)
	local filename = utils.get_filename_from_path(current_file_path)
	local fallback_title = filename
	local title = utils.find_file_title(content, fallback_title)
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

	vim.g.locations = locations
	-- Add new entries to the location list
	for _, loc in ipairs(locations) do
		vim.fn.setloclist(0, { loc }, "a")
	end

	if #locations ~= 0 and open_loc then
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

-- find all nodes
local function org_roam_node_find(opts)
	-- if you use it when in node insert
	opts = opts or {}
	local link_type = opts.link_type or nil

	local db = sqlite:open(user_config.org_roam_database_file)
	local nodes = db:select("example_table")
	db:close()

	for i, item in ipairs(nodes) do
		nodes[i].title = nodes[i].title
		nodes[i].file = nodes[i].file_path
		nodes[i].pos = 0
	end

	local telescope_picker = function(telescope_picker_opts)
		telescope_picker_opts = telescope_picker_opts or {}
		pickers
			.new(telescope_picker_opts, {
				prompt_title = "Find Node",
				finder = finders.new_table({
					results = nodes,
					entry_maker = function(entry)
						-- because of the way org-roam stores these in database
						-- entry.title = string.sub(entry.title, 2, -2)
						-- entry.file = string.sub(entry.file, 2, -2)

						return {
							value = entry,
							display = entry.title,
							ordinal = entry.title,
						}
					end,
				}),

				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						if selection == nil then
							local title = action_state.get_current_line()
							org_roam_capture(title)
						else
							local file = selection.value.file
							local pos = selection.value.pos
							local row = 1

							for line in io.lines(file) do
								if pos < line:len() then
									break
								else
									pos = pos - line:len()
								end
								row = row + 1
							end

							-- insert link
							if link_type then
								local buffer = 0
								local text = "[["
									.. link_type
									.. ":"
									.. selection.value.id
									.. "]["
									.. selection.value.title
									.. "]]"
								utils.insert_text_at(buffer, text)
							else
								vim.cmd.edit(selection.value.file)
							end
							-- TODO Set the cursor in correct place
							-- aka mimic emacs `goto-char' function
							-- vim.api.nvim_win_set_cursor(0, { row, 0 })
						end
					end)
					return true
				end,
				sorter = conf.generic_sorter(telescope_picker_opts),
			})
			:find()
	end
	telescope_picker()
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
	},
	links = {
		{
			source = "2BFBA6D5-5D41-481C-BC75-C81F23291505",
			target = "2BFBA6D5-5D41-481C-BC75-C81F23291506",
			type = "bad",
		},
	},
	tags = {},
}

-- select link type(like id link type)
-- select node
local function org_roam_node_insert()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local link_types = { "id", "file", "cite" }
	local selected_link_type = link_types[1]
	for i, item in ipairs(link_types) do
		link_types[i] = string.format("%d. %s", i, item)
	end
	-- Prompt the user with a selection list
	local choice = vim.fn.inputlist(link_types)
	selected_link_type = link_types[choice]:match("%d+%. (.+)")
	org_roam_node_find({ link_type = selected_link_type, line = line, col = col })
end

_G.GetLatestGraphData = function()
	-- TODO: build database will be time consuming if your notes grow larger?
	-- for now just rebuild everytime this function is called
	utils.build_database(user_config.org_roam_database_file, user_config.org_roam_directory, "example_table")
	local db = sqlite:open(user_config.org_roam_database_file)
	local records = db:select("example_table")
	db:close()
	return vim.json.encode(records)
end

-- it will be used in orgmode id link
vim.fn.open_id_link_at = function(id)
	local db = sqlite:open(user_config.org_roam_database_file)
	local records = db:select("example_table", { where = { file_id = id } })
	if #records > 0 then
		vim.cmd.edit(records[1].file_path)
	else
		print("not found:" .. id)
	end
end

return {
	setup = setup,
	org_roam_capture = org_roam_capture,
	org_roam_buffer_toggle = org_roam_buffer_toggle,
	org_roam_node_find = org_roam_node_find,
	org_roam_node_insert = org_roam_node_insert,
}
