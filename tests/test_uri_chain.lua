local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local fs = require("mewrw.fs")
local uri_parser = require("mewrw.utils.uri")
local path_utils = require("mewrw.utils.path")

print("========================================")
print("   Testing URI Chains & Navigation")
print("========================================\n")

mewrw.setup()

-- Helper to find a buffer by filetype and URI
local function find_mewrw_buf(uri_pattern)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then
            vim.api.nvim_set_current_buf(bufnr)
            local state = engine.get_state()
            if state and (not uri_pattern or state.uri:match(uri_pattern)) then
                return bufnr
            end
        end
    end
    return nil
end

local failed = 0
local function assert_condition(cond, desc)
    if cond then
        print("  PASS: " .. desc)
    else
        print("  FAIL: " .. desc)
        failed = failed + 1
    end
end

-- 1. Test Archive Exit Navigation (-)
print("Step 1: Testing Archive Exit (Pressing '-' at zip root)")
local zip_path = root .. "/tests/sandbox_archive/test.zip"
local zip_uri = zip_path .. ":::zip://"

engine.open(zip_uri)
vim.wait(2000, function() return find_mewrw_buf(":::zip://") ~= nil end)
local zip_buf = find_mewrw_buf(":::zip://")
assert(zip_buf, "Failed to open zip URI")

-- Simulate pressing '-'
vim.api.nvim_set_current_buf(zip_buf)
engine.up_directory()

-- Expect to return to the directory containing the zip file
vim.wait(3000, function() 
    local s = engine.get_state()
    return s and s.uri == root .. "/tests/sandbox_archive" 
end)

local current_state = engine.get_state()
assert_condition(current_state.uri == root .. "/tests/sandbox_archive", "Returned to parent directory from archive root")

-- Normalize both sides for comparison
local actual_focus = path_utils.normalize(current_state.focus_uri)
local expected_focus = path_utils.normalize(zip_path)
assert_condition(actual_focus == expected_focus, "Focus correctly set to the zip file itself")

-- 2. Test Single Compression Listing (.gz)
print("\nStep 2: Testing Single Compression (.gz)")
local gz_path = root .. "/tests/sandbox_extended/test.gz"
local gz_uri = gz_path .. ":::compress://"

engine.open(gz_uri)
vim.wait(2000, function() return find_mewrw_buf(":::compress://") ~= nil end)
local gz_buf = find_mewrw_buf(":::compress://")
assert(gz_buf, "Failed to open gz URI")

local state = engine.get_state()
assert_condition(#state.filtered_entries == 1, "Single entry found in .gz list")
assert_condition(state.filtered_entries[1].name == "test", "Correct virtual filename extracted for .gz")

-- 3. Test SFTP Chaining Prototype (Simulated)
print("\nStep 3: Testing Chain Parsing Logic")
local chain_uri = "sftp://user@host/work.zip:::zip://subfolder/file.txt"
local chain = uri_parser.parse_chain(chain_uri)
assert_condition(#chain == 2, "Chain parsed into 2 layers")
assert_condition(chain[1].scheme == "sftp" and chain[1].host == "host", "Layer 1 correctly parsed as SFTP")
assert_condition(chain[2].scheme == "zip" and chain[2].path == "/subfolder/file.txt", "Layer 2 correctly parsed as Zip internal")

print("\n----------------------------------------")
if failed == 0 then
    print("RESULT: ALL URI CHAIN TESTS PASSED")
else
    print(string.format("RESULT: %d TESTS FAILED", failed))
    os.exit(1)
end
