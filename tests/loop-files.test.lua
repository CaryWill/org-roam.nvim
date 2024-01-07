local utils = require("org-roam.utils")

describe("read all files from OrgRoam", function()
    it("all files", function()
        utils.process_folder("/Users/cary/OrgRoam")
    end)
end)
