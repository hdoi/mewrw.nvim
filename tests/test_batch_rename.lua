local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

local test_dir = root .. "/tests/tmp_batch_rename"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

local files = { "file1.txt", "file2.txt", "file3.txt" }
for _, f in ipairs(files) do
    local fd = io.open(test_dir .. "/" .. f, "w")
    fd:write("test")
    fd:close()
end

print("--- Testing Batch Rename ---")
mewrw.setup()

engine.open(test_dir)

-- Wait for the buffer to be displayed
vim.wait(5000, function() 
    return vim.bo.filetype == "mewrw" and vim.api.nvim_buf_line_count(0) >= 8
end)

local bufnr = vim.api.nvim_get_current_buf()
-- Mark lines 6, 7, 8
vim.api.nvim_win_set_cursor(0, {6, 0}); engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, {7, 0}); engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, {8, 0}); engine.toggle_mark()

-- Trigger batch rename
engine.batch_rename()

vim.wait(3000, function() return vim.bo.filetype == "mewrw_rename" end)
local rename_buf = vim.api.nvim_get_current_buf()
print("SUCCESS: Batch rename buffer opened.")

-- Rename files
vim.api.nvim_buf_set_lines(rename_buf, 0, -1, false, { "renamed1.txt", "renamed2.txt", "renamed3.txt" })
vim.fn.confirm = function() return 1 end

-- Apply (call apply function directly)
require("mewrw.ui.batch_rename").apply(rename_buf)

-- Verify on disk
vim.wait(5000, function() 
    return vim.fn.filereadable(test_dir .. "/renamed1.txt") == 1 
end)

if vim.fn.filereadable(test_dir .. "/renamed1.txt") == 1 then
    print("SUCCESS: Files renamed on disk.")
else
    print("FAILURE: Files NOT renamed on disk.")
end

-- Wait for the buffer to refresh and show the renamed files
-- This ensures the background engine.open(s.uri) call is finished before we delete the directory
vim.wait(3000, function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return true end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for _, line in ipairs(lines) do
        if line:match("renamed1.txt") then return true end
    end
    return false
end)

-- Cleanup
vim.fn.delete(test_dir, "rf")
print("Test finished.")
