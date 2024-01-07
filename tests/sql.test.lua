local id_link_with_desc_pattern = "%[%[id:[^%]]+%]%[?.-%]%]"
local id_link_without_desc_pattern = "%[%[id:[^%]]+%]%]"

local function org_id_link_match(link)
    return string.match(link, id_link_with_desc_pattern) or string.match(link, id_link_without_desc_pattern)
end

local link = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34][id link]]"
local link2 = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34]]"
local link3 = "[[file:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34]]"

describe("match id link", function()
    it("id link", function()
        assert.equals(org_id_link_match(link), link)
        assert.equals(org_id_link_match(link2), link2)
        assert.equals(org_id_link_match(link3) ~= link3, true)
    end)
end)

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

local file_content1 = [[
:PROPERTIES:
:ID:        C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34
:END:

* Your first headline
  Some content here.

** Subheadline
   More content.

* Another headline
  Different content.
]]

local file_content2 = [[
:PROPERTIES:
:TAGS:       :Shopping:
:ID:        C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34
:END:

* Your first headline
  Some content here.

** Subheadline
   More content.

* Another headline
  Different content.
]]

describe("match file id", function()
    it("file id", function()
        assert.equals(find_file_id(file_content1), "C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34")
        assert.equals(find_file_id(file_content2), "C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34")
    end)
end)
