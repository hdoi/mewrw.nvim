local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local local_provider = require("mewrw.fs.provider.local")

print("========================================")
print("   Testing Path Normalization (Engine Sync)")
print("========================================")

--- Test a path input and verify it normalizes correctly and can be listed
---@param input_uri string The raw URI or path input from the user
---@return boolean success
local function test_path(input_uri)
    -- Emulate the latest logic from lua/mewrw/core/engine.lua
    local uri = input_uri
    
    -- 1. Trim whitespace
    uri = uri:gsub("^%s*(.-)%s*$", "%1")
    
    -- 2. Resolve to absolute path and normalize slashes
    uri = vim.fn.fnamemodify(uri, ":p"):gsub("\\", "/")
    
    -- 3. Aggressively remove trailing slashes, dots, and trailing spaces
    uri = uri:gsub("[\\/]%.?%s*$", "")
    
    -- 4. Handle root directory case
    if uri == "" then uri = "/" end
    
    print(string.format("Input: '%s'", input_uri))
    print(string.format("  -> Normalized: '%s'", uri))
    
    -- Verification: Ensure no trailing dots remain (unless it's exactly ".")
    if uri:match("%.%s*$") and uri ~= "." then
        print(string.format("  FAILURE: Normalized path still contains trailing dot: '%s'", uri))
        return false
    end
    
    -- Verification: Ensure LocalProvider can successfully list this path
    local success = false
    _G.test_done = false
    local_provider.list(uri, function(err, entries)
        if err then
            print(string.format("  ERROR: LocalProvider.list failed: %s", err))
        else
            print(string.format("  SUCCESS: Found %d entries", #entries))
            success = true
        end
        _G.test_done = true
    end)
    
    vim.wait(2000, function() return _G.test_done end)
    return success
end

local test_cases = {
    { input = ".",           desc = "Current directory" },
    { input = "tests/.",     desc = "Subdirectory with dot" },
    { input = "tests/. ",    desc = "Subdirectory with dot and trailing space" },
    { input = "./ ",         desc = "Current directory with trailing space" },
    { input = "/",           desc = "Root directory" },
    { input = "/etc/. ",     desc = "System directory with trailing dot/space" },
}

local failed_count = 0
for _, case in ipairs(test_cases) do
    print(string.format("\nTest Case: %s", case.desc))
    if not test_path(case.input) then
        failed_count = failed_count + 1
    end
end

print("\n----------------------------------------")
if failed_count == 0 then
    print("RESULT: ALL PATH NORMALIZATION TESTS PASSED")
else
    print(string.format("RESULT: %d TESTS FAILED", failed_count))
    os.exit(1)
end
print("----------------------------------------")
