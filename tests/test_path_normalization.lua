local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local path_utils = require("mewrw.utils.path")
local local_provider = require("mewrw.fs.provider.local")

print("========================================")
print("   Testing Path Utils & Normalization")
print("========================================")

--- Verify that a path normalizes as expected
---@param input string
---@return boolean
local function verify_normalization(input)
    local normalized = path_utils.normalize(input)
    print(string.format("Input: '%s'", input))
    print(string.format("  -> Normalized: '%s'", normalized))

    -- Cross-platform basic check: No trailing dots or double slashes
    if normalized:match("%.%s*$") and normalized ~= "." then
        print(string.format("  FAILURE: Trailing dot remains in: '%s'", normalized))
        return false
    end
    
    if normalized:match("//") and not normalized:match("^//") then -- Allow UNC start //
        print(string.format("  FAILURE: Double slashes found in: '%s'", normalized))
        return false
    end

    -- If we are on the actual OS, try listing it
    if not path_utils.is_windows and not input:match("^%a:") then
        local success = false
        _G.test_done = false
        local_provider.list(normalized, function(err, entries)
            if err then
                print(string.format("  INFO: Provider could not list (expected if path virtual): %s", err))
            else
                print(string.format("  SUCCESS: Provider listed %d entries", #entries))
            end
            success = true -- Mark as tested
            _G.test_done = true
        end)
        vim.wait(1000, function() return _G.test_done end)
    end

    return true
end

local test_cases = {
    -- Linux / Universal cases
    { input = ".",           desc = "Current directory" },
    { input = "tests/.",     desc = "Subdirectory with dot" },
    { input = "tests/. ",    desc = "Subdirectory with dot and space" },
    { input = "/",           desc = "Unix Root" },
    
    -- Windows specific cases (Testing logic even on Linux)
    { input = "C:\\Users",   desc = "Windows Backslashes" },
    { input = "D:/Data/.",   desc = "Windows Drive with dot" },
    { input = "E:",          desc = "Windows Drive only" },
    { input = "F:/",         desc = "Windows Drive with slash" },
}

local failed_count = 0
for _, case in ipairs(test_cases) do
    print(string.format("\nTest Case: %s", case.desc))
    if not verify_normalization(case.input) then
        failed_count = failed_count + 1
    end
end

print("\n----------------------------------------")
print("   Testing path_utils.is_root")
print("----------------------------------------")

local root_cases = {
    { path = "/", expected = true },
    { path = "/home", expected = false },
    { path = "C:/", expected = true },
    { path = "D:", expected = true },
}

for _, case in ipairs(root_cases) do
    local result = path_utils.is_root(case.path)
    print(string.format("is_root('%s') -> %s (Expected: %s)", case.path, result, case.expected))
    if result ~= case.expected and (not path_utils.is_windows and case.path:match("^%a:")) then
        -- Skip Windows root check if on Linux unless we implement mockable OS
        print("  (Note: Windows root check skipped/failed due to actual OS being Linux)")
    elseif result ~= case.expected then
        failed_count = failed_count + 1
    end
end

print("\n----------------------------------------")
if failed_count == 0 then
    print("RESULT: ALL PATH UTILS TESTS PASSED")
else
    print(string.format("RESULT: %d TESTS FAILED", failed_count))
    os.exit(1)
end
print("----------------------------------------")
