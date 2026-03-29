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

-- バッファに内容が表示されるのを待つ
vim.wait(5000, function() 
    return vim.bo.filetype == "mewrw" and vim.api.nvim_buf_line_count(0) >= 8
end)

local bufnr = vim.api.nvim_get_current_buf()
-- 6, 7, 8行目をマーク
vim.api.nvim_win_set_cursor(0, {6, 0}); engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, {7, 0}); engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, {8, 0}); engine.toggle_mark()

-- 一括リネーム起動
engine.batch_rename()

vim.wait(3000, function() return vim.bo.filetype == "mewrw_rename" end)
local rename_buf = vim.api.nvim_get_current_buf()
print("SUCCESS: Batch rename buffer opened.")

-- 名前を変更
vim.api.nvim_buf_set_lines(rename_buf, 0, -1, false, { "renamed1.txt", "renamed2.txt", "renamed3.txt" })
vim.fn.confirm = function() return 1 end

-- 適用 (apply 関数を直接呼ぶ)
require("mewrw.ui.batch_rename").apply(rename_buf)

-- ディスク確認
vim.wait(5000, function() 
    return vim.fn.filereadable(test_dir .. "/renamed1.txt") == 1 
end)

if vim.fn.filereadable(test_dir .. "/renamed1.txt") == 1 then
    print("SUCCESS: Files renamed on disk.")
else
    print("FAILURE: Files NOT renamed on disk.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
print("Test finished.")
