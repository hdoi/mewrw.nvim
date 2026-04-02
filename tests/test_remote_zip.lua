local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local fs = require("mewrw.fs")
local mewrw = require("mewrw")

print("========================================")
print("   Testing Remote Zip (SFTP Chain)")
print("========================================\n")

mewrw.setup()

local user = os.getenv("USER") or "root"
-- Adjust path to be an absolute path reachable via sftp
local zip_file_path = root .. "/tests/sandbox_archive/test.zip"
local remote_uri = string.format("sftp://%s@localhost/%s:::zip://", user, zip_file_path)

print("Target Remote URI: " .. remote_uri)

_G.test_done = false
fs.list(remote_uri, function(err, entries)
    if err then
        print("FAILURE: Remote Zip list failed: " .. tostring(err))
    else
        print(string.format("SUCCESS: Found %d entries in remote zip.", #entries))
        for _, e in ipairs(entries) do
            print(" - " .. e.name .. " (" .. e.type .. ")")
            if e.name:match("Archive:") or e.name:match("Length") or e.name:match("-") then
                print("   !! ERROR: Header info detected as filename: " .. e.name)
                _G.test_failed = true
            end
        end
    end
    _G.test_done = true
end)

vim.wait(10000, function() return _G.test_done end)

if _G.test_failed then
    os.exit(1)
else
    print("\nRESULT: REMOTE ZIP TEST PASSED")
end
