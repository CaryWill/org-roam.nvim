local id_link_with_desc_pattern = "%[%[id:[^%]]+%]%[?.-%]%]"
local id_link_without_desc_pattern = "%[%[id:[^%]]+%]%]"

local function org_link_is_id_link(link)
    return string.match(link, id_link_with_desc_pattern) or string.match(link, id_link_without_desc_pattern)
end

local link = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34][id link]]"
local link2 = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34]]"
local link3 = "[[file:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34]]"

describe("match", function()
    it("id link", function()
        assert.equals(org_link_is_id_link(link), link)
        assert.equals(org_link_is_id_link(link2), link2)
        assert.equals(org_link_is_id_link(link3) ~= link3, true)
    end)
end)
