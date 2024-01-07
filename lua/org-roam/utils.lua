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

local function process_file(filepath)
    -- process orgfile only
    if is_org_file(filepath) == false then
        return
    end

    local file = io.open(filepath, "r")
    local matches = {}
    local line_number = 0

    if file then
        for line in file:lines() do
            print(line)
            local line_content = line
            line_number = line_number + 1
            local match = org_id_link_match(line_content)
            if match ~= nil then
                match.start_row = line_number
                match.end_row = line_number
                table.insert(matches, match)
            end
        end
        -- print(vim.inspect(matches))
        -- print(vim.json.encode(matches))
        -- print(vim.inspect(vim.json.decode(vim.json.encode(matches))))
        file:close()
    else
        print("Cannot open file")
    end
    return #matches == 0 and nil or matches
end

local function process_folder(folderPath)
    local handle = vim.loop.fs_opendir(folderPath, nil, 100)
    if handle then
        while true do
            local entries = vim.loop.fs_readdir(handle)
            if not entries then
                break
            end
            for _, entry in ipairs(entries) do
                local filePath = folderPath .. "/" .. entry.name
                if entry.type == "file" then
                    process_file(filePath)
                elseif entry.type == "directory" then
                    processFolder(filePath)
                end
            end
        end
        vim.loop.fs_closedir(handle)
    end
end

M.process_folder = process_folder

return M
