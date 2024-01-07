local M = {}

-- Credits: https://github.com/kkharji/sqlite.lua
-- MIT License
-- Copyright (c) 2021 kkharji
M.expand_file_name = function(path)
	local expanded
	if string.find(path, "~") then
		expanded = string.gsub(path, "^~", os.getenv("HOME"))
	elseif string.find(path, "^%.") then
		expanded = luv.fs_realpath(path)
		if expanded == nil then
			error("Path not valid")
		end
	elseif string.find(path, "%$") then
		local rep = string.match(path, "([^%$][^/]*)")
		local val = os.getenv(string.upper(rep))
		if val then
			expanded = string.gsub(string.gsub(path, rep, val), "%$", "")
		else
			expanded = nil
		end
	else
		expanded = path
	end
	return expanded and expanded or error("Path not valid")
end

-- Credits: https://github.com/TrevorS/uuid-nvim
-- No Licence (as of Aug 27, 2023)
M.get_uuid = function()
	math.randomseed(os.time())
	return string
		.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(c)
			local r = math.random()
			local v = c == "x" and math.floor(r * 0x10) or (math.floor(r * 0x4) + 8)
			return string.format("%x", v)
		end)
		:upper()
end

local id_link_with_desc_pattern = "%[%[id:([^%]]+)%]%[?(.-)%]%]"
local id_link_without_desc_pattern = "%[%[id:([^%]]+)%]%]"
local function org_id_link_match(link)
	local start_col, end_col, content, id, desc = string.find(link, "(" .. id_link_with_desc_pattern .. ")")
	if start_col then
		return { content = content, start_col = start_col, end_col = end_col, id = id, desc = desc }
	end

	start_col, end_col, content, id, desc = string.find(link, "(" .. id_link_without_desc_pattern .. ")")
	if start_col then
		return { content = content, start_col = start_col, end_col = end_col, id = id, desc = desc }
	end

	-- no match found
	return nil
end

local function is_org_file(filePath)
	return string.sub(filePath, -4) == ".org"
end

local function read_file_content(filepath)
	local file = io.open(filepath, "r") -- Open the file for reading
	if not file then
		print("Error: Could not open file at path " .. filepath)
		return nil
	end

	local content = file:read("*a") -- Read the entire content of the file
	file:close() -- Close the file
	return content
end

local function find_file_id(file_content)
	local properties = file_content:match(":PROPERTIES:(.-):END:")
	if properties then
		local id_pattern = ":ID:%s+(%S+)"
		local id = properties:match(id_pattern)
		return id
	else
		return nil
	end
end

local function process_file(filepath, post_hook)
	-- process orgfile only
	if is_org_file(filepath) == false then
		return nil
	end

	local file = io.open(filepath, "r")
	-- TODO: performance
	local file_content = read_file_content(filepath)
	local matches = {}
	local line_number = 0
	local file_id = find_file_id(file_content)
	local returned = {
		file_path = filepath,
		file_id = file_id,
		id_links = matches,
	}

	if file then
		for line in file:lines() do
			local line_content = line
			line_number = line_number + 1
			local match = org_id_link_match(line_content)
			if match ~= nil then
				match.start_row = line_number
				match.end_row = line_number
				match.file_id = file_id
				match.file_path = filepath
				table.insert(matches, match)
			end
		end
		file:close()

		if post_hook ~= nil then
			post_hook(returned)
		end
	else
		print("Cannot open file")
	end

	return returned
end

local function process_folder(folderPath, post_hook)
	local expanded_folder = vim.fn.expand(folderPath)
	local handle = vim.loop.fs_opendir(expanded_folder, nil, 100)
	if handle then
		while true do
			local entries = vim.loop.fs_readdir(handle)
			if not entries then
				break
			end
			for _, entry in ipairs(entries) do
				local filePath = expanded_folder .. "/" .. entry.name
				if entry.type == "file" then
					process_file(filePath, post_hook)
				elseif entry.type == "directory" then
					process_folder(filePath, post_hook)
				end
			end
		end
		vim.loop.fs_closedir(handle)
	end
end

local sqlite = require("sqlite")
local function get_back_links(current_file_id, dbpath, table_name)
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
	-- TODO: maybe save to vim location list
	db:close()
	return back_links
end

M.get_back_links = get_back_links

local function build_database(dbpath, roam_folder, table_name)
	local db = sqlite:open(dbpath)
	if not db:exists(table_name) then
		db:create(table_name, {
			id = { "int", "primary", "key" },
			file_path = "text",
			file_id = "text",
			id_links = "text",
		})
	end

	process_folder(roam_folder, function(matches)
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
				-- to view the data
				-- I finnally found it's because I made change using the App
				-- but did not click the `Write Changes` button
				--
				db:update(table_name, {
					where = { file_id = matches.file_id },
					set = {
						file_id = matches.file_id,
						file_path = matches.file_path,
						id_links = vim.json.encode(matches.id_links),
					},
				})
				--
				-- TODO: I dont know why I cannot get with_open to work
				-- db:close should be put at the end
			end
		end
	end)
	db:close()
end

function read_lines_from_file(filepath, start_row, end_row)
	local lines = {}
	local line_number = 0

	for line in io.lines(filepath) do
		line_number = line_number + 1
		if line_number >= start_row and line_number <= end_row then
			table.insert(lines, line)
		end
	end

	return lines
end

M.read_lines_from_file = read_lines_from_file
M.build_database = build_database
M.process_folder = process_folder
M.find_file_id = find_file_id

return M
