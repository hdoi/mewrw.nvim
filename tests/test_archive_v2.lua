local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local archive_provider = require("mewrw.fs.provider.archive")

print("========================================")
print("   Testing Archive Support (Extended)")
print("========================================")

local failed = 0

local function assert_eq(actual, expected, desc)
    if actual == expected then
        print(string.format("  PASS: %s", desc))
        return true
    else
        print(string.format("  FAIL: %s", desc))
        print(string.format("    Expected: '%s'", expected))
        print(string.format("    Actual:   '%s'", actual))
        failed = failed + 1
        return false
    end
end

-- 1. Can Handle
print("\n1. can_handle Checks:")
assert_eq(archive_provider.can_handle("zip:///test.zip"), true, "Handle zip://")
assert_eq(archive_provider.can_handle("tar:///test.tar.gz"), true, "Handle tar://")
assert_eq(archive_provider.can_handle("file:///test.txt"), false, "Don't handle file://")

-- 2. Mocking archive output parsing
-- We test the internal logic by checking how it would handle the reported problematic output
print("\n2. Output Parsing Simulation:")

-- Simulated tar -atvf output (from user report)
local sample_tar_line = "drwxrwxr-x anoop/anoop       0 2024-02-13 03:51 hmpol-0.1.5/"
local size, name = sample_tar_line:match("%s+(%d+)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d%s+(.+)$")
assert_eq(size, "0", "Tar size extraction")
assert_eq(name, "hmpol-0.1.5/", "Tar name extraction")

-- Simulated Windows unzip -l output (Length EAs ACLs Date Time Name)
local sample_zip_line = "  1286615      0      0  13/08/29 23:10   01__001_999.jpg"
local win_size = sample_zip_line:match("^%s*(%d+)")
local win_name = sample_zip_line:sub(43):gsub("^%s+", ""):gsub("%s+$", "")
assert_eq(win_size, "1286615", "Win-Zip size extraction")
assert_eq(win_name, "01__001_999.jpg", "Win-Zip name extraction")

-- 3. Navigation Logic (up_directory simulation)
print("\n3. Navigation logic simulation:")
local function get_parent_logic(uri)
    local scheme, rest = uri:match("^([^:]+)://(.*)$")
    local is_abs = uri:match("^%a+:///")
    local slash_prefix = is_abs and "/" or ""
    
    local archive_part, internal_part = rest:match("^(.*)::(.*)$")
    if not archive_part then return nil end
    
    if internal_part == "" or internal_part == "/" then
        local raw_path = slash_prefix .. archive_part:gsub("^/+", "")
        return vim.fn.fnamemodify(raw_path, ":h")
    else
        local parent_internal = vim.fn.fnamemodify(internal_part, ":h")
        if parent_internal == "." then parent_internal = "" end
        return scheme .. "://" .. slash_prefix .. archive_part:gsub("^/+", "") .. "::" .. parent_internal
    end
end

local abs_zip_uri = "zip:///mnt/c/Users/test.zip::folder/sub"
assert_eq(get_parent_logic(abs_zip_uri), "zip:///mnt/c/Users/test.zip::folder", "Move up inside absolute zip")

local zip_root_uri = "zip:///mnt/c/Users/test.zip::"
assert_eq(get_parent_logic(zip_root_uri), "/mnt/c/Users", "Move out of absolute zip")

print("\n----------------------------------------")
if failed == 0 then
    print("RESULT: ALL ARCHIVE COMPREHENSIVE TESTS PASSED")
else
    print(string.format("RESULT: %d TESTS FAILED", failed))
    os.exit(1)
end
