function org_link_is_id_link(link)
    return string.match(link, "%[%[id:[^%]]+%]%[?.-%]%]")
end

-- Example usage:
local link = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34][id link]]"
local link2 = "[[id:C6DDDD61-9A5B-4BD6-BD65-C521B71D5D34]]"

describe("match", function()
    it("id link", function()
        assert.equals(org_link_is_id_link(link), link)
        assert.equals(org_link_is_id_link(link2), link2)
    end)
end)
