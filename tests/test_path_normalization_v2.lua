local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local path_utils = require("mewrw.utils.path")

print("========================================")
print("   Testing Path Normalization (Robust)")
print("========================================")

local function assert_eq(actual, expected, desc)
    if actual == expected then
        print(string.format("  PASS: %s", desc))
        return true
    else
        print(string.format("  FAIL: %s", desc))
        print(string.format("    Expected: '%s'", expected))
        print(string.format("    Actual:   '%s'", actual))
        return false
    end
end

local failed = 0

-- 1. Local Path Normalization
print("\n1. Local Paths:")
if not assert_eq(path_utils.normalize("."), root:gsub("\\", "/"), "Current directory") then failed = failed + 1 end
if not assert_eq(path_utils.normalize("tests/./"), root:gsub("\\", "/") .. "/tests", "Subdir with dot/slash") then failed = failed + 1 end
if not assert_eq(path_utils.normalize("tests/. "), root:gsub("\\", "/") .. "/tests", "Subdir with dot/space") then failed = failed + 1 end

-- 2. Windows Specific (Simulated logic)
print("\n2. Windows Specific:")
if path_utils.is_windows then
    if not assert_eq(path_utils.normalize("C://Program Files//"), "C:/Program Files", "Windows double slash + space") then failed = failed + 1 end
    if not assert_eq(path_utils.normalize("/"), "/", "Windows virtual root") then failed = failed + 1 end
    if not assert_eq(path_utils.normalize("D:"), "D:/", "Drive letter only") then failed = failed + 1 end
end

-- 3. URI & Schemes (Should be preserved)
print("\n3. URI & Schemes:")
if not assert_eq(path_utils.normalize("sftp://user@host/path//to"), "sftp://user@host/path/to", "SFTP path cleaning") then failed = failed + 1 end
if not assert_eq(path_utils.normalize("zip:///mnt/c/test.zip::internal/path"), "zip:///mnt/c/test.zip::internal/path", "Archive URI preservation") then failed = failed + 1 end

-- 4. Archive Component Parsing (via engine logic simulation)
print("\n4. Archive Component Parsing:")
local archive_uri = "zip:///mnt/c/test.zip::folder/file.txt"
local scheme, rest = archive_uri:match("^([^:]+)://(.*)$")
local archive_path, internal = rest:match("^(.*)::(.-)$")
if not assert_eq(scheme, "zip", "Scheme extraction") then failed = failed + 1 end
if not assert_eq(archive_path, "/mnt/c/test.zip", "Archive path extraction (absolute)") then failed = failed + 1 end
if not assert_eq(internal, "folder/file.txt", "Internal path extraction") then failed = failed + 1 end

print("\n----------------------------------------")
if failed == 0 then
    print("RESULT: ALL PATH NORMALIZATION TESTS PASSED")
else
    print(string.format("RESULT: %d TESTS FAILED", failed))
    os.exit(1)
end
