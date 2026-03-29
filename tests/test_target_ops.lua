local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local fs = require("mewrw.fs")

print("--- Testing Target Operations (TT, Tc, Tm) ---")

local test_root = root .. "/tests/sandbox_target"
local src_dir = test_root .. "/source"
local dst_dir = test_root .. "/destination"

src_dir = vim.fn.fnamemodify(src_dir, ":p"):gsub("[\\/]$","")
dst_dir = vim.fn.fnamemodify(dst_dir, ":p"):gsub("[\\/]$","")

vim.fn.delete(test_root, "rf")
vim.fn.mkdir(src_dir, "p")
vim.fn.mkdir(dst_dir, "p")

local io_f1 = io.open(src_dir .. "/file1.txt", "w"); if io_f1 then io_f1:write("hello 1"); io_f1:close() end
local io_f2 = io.open(src_dir .. "/file2.txt", "w"); if io_f2 then io_f2:write("hello 2"); io_f2:close() end

mewrw.setup()

local function find_mewrw_buf(path_pattern)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then
            local original_buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_set_current_buf(bufnr)
            local state = engine.get_state()
            vim.api.nvim_set_current_buf(original_buf)
            if state and state.uri:gsub("[\\/]$","") == path_pattern:gsub("[\\/]$","") then
                return bufnr
            end
        end
    end
    return nil
end

-- 1. Set Target
print("\nStep 1: Setting target")
engine.open(dst_dir)
vim.wait(2000, function() return find_mewrw_buf(dst_dir) ~= nil end)
local dst_buf = find_mewrw_buf(dst_dir)
vim.api.nvim_win_set_buf(0, dst_buf)
engine.set_target()

-- 2. Copy
print("\nStep 2: Copying (Tc)")
engine.open(src_dir)
vim.wait(2000, function() 
    local b = find_mewrw_buf(src_dir)
    if b then vim.api.nvim_win_set_buf(0, b) return true end
    return false
end)
local src_buf_1 = find_mewrw_buf(src_dir)
vim.wait(1000, function() return #engine.get_state().filtered_entries >= 2 end)

vim.api.nvim_win_set_cursor(0, {6, 0})
engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, {7, 0})
engine.toggle_mark()

vim.fn.confirm = function() return 1 end
engine.bulk_action("copy")

-- Wait for refresh after copy: old buffer should be deleted or replaced
vim.wait(5000, function()
    local b = find_mewrw_buf(src_dir)
    return b ~= nil and b ~= src_buf_1 and vim.fn.filereadable(dst_dir .. "/file1.txt") == 1
end)
print("SUCCESS: Files copied.")

-- 3. Move
print("\nStep 3: Moving (Tm)")
local src_buf_2 = find_mewrw_buf(src_dir)
vim.api.nvim_win_set_buf(0, src_buf_2)
vim.wait(1000, function() return #engine.get_state().filtered_entries >= 2 end)

vim.api.nvim_win_set_cursor(0, {6, 0})
engine.toggle_mark()

engine.bulk_action("move")

-- Wait for refresh after move
vim.wait(5000, function()
    local b = find_mewrw_buf(src_dir)
    return b ~= nil and b ~= src_buf_2 and vim.fn.filereadable(src_dir .. "/file1.txt") == 0
end)

if vim.fn.filereadable(src_dir .. "/file1.txt") == 0 then
    print("SUCCESS: File moved.")
else
    print("FAILURE: Move failed.")
end

-- Cleanup
vim.fn.delete(test_root, "rf")
print("Test finished.")
