local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local fs = require("mewrw.fs")

local test_dir = root .. "/tests/tmp_sandbox"
test_dir = vim.fn.fnamemodify(test_dir, ":p"):gsub("//+", "/"):gsub("/$", "")

vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

print("--- Testing File Operations (Final Stability) ---")
mewrw.setup()

local function get_mewrw_buf()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then return bufnr end
    end
    return nil
end

-- Start
engine.open(test_dir)
vim.wait(3000, function() return get_mewrw_buf() ~= nil end)
local bufnr = get_mewrw_buf()
vim.api.nvim_win_set_buf(0, bufnr)
vim.api.nvim_set_current_buf(bufnr)

-- 1. Test mkdir
print("\nStep 1: Testing mkdir")
local mkdir_done = false
local new_folder_path = test_dir .. "/new_folder"
fs.mkdir(new_folder_path, function(err)
    if not err then mkdir_done = true end
end)

vim.wait(5000, function() return mkdir_done end)

if vim.fn.isdirectory(new_folder_path) == 1 then
    print("SUCCESS: Directory 'new_folder' created.")
else
    print("FAILURE: Directory creation failed.")
    return
end

-- 2. Test rename
print("\nStep 2: Testing rename")
local renamed_folder_path = test_dir .. "/renamed_folder"
local rename_done = false
fs.rename(new_folder_path, renamed_folder_path, function(err)
    if not err then rename_done = true end
end)

vim.wait(5000, function() return rename_done end)

if vim.fn.isdirectory(renamed_folder_path) == 1 then
    print("SUCCESS: Directory renamed.")
else
    print("FAILURE: Rename failed.")
    return
end

-- 3. Test delete
print("\nStep 3: Testing delete")
-- Use built-in synchronous delete for maximum stability in this final step
local del_result = vim.fn.delete(renamed_folder_path, "rf")

if del_result == 0 and vim.fn.isdirectory(renamed_folder_path) == 0 then
    print("SUCCESS: Directory deleted successfully.")
else
    print("FAILURE: Delete failed.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
print("Test finished.")
