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

local function is_org_file(filepath)
    return string.sub(filePath, -4) == ".org" and true or false
end

local function processFile(filepath)
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
        file:close()
    else
        print("Cannot open file")
    end

    return #matches == 0 and nil or matches
end

local function processFolder(folderPath)
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
                    processFile(filePath)
                elseif entry.type == "directory" then
                    processFolder(filePath)
                end
            end
        end
        vim.loop.fs_closedir(handle)
    end
end

describe("read all files from OrgRoam", function()
    it("all files", function()
        processFolder("/Users/cary/OrgRoam")
    end)
end)
