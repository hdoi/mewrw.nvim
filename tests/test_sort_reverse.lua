local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing Sort Reverse ---")

-- 1. Setup sandbox with 3 files of different sizes/names
local test_dir = root .. "/tests/sandbox_sort_rev"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

local f1 = test_dir .. "/a_small.txt"
local f2 = test_dir .. "/m_medium.txt"
local f3 = test_dir .. "/z_large.txt"

local io1 = io.open(f1, "w"); if io1 then io1:write("small"); io1:close() end
local io2 = io.open(f2, "w"); if io2 then io2:write("medium content"); io2:close() end
local io3 = io.open(f3, "w"); if io3 then io3:write("very large content indeed"); io3:close() end

mewrw.setup()

-- Helper to find the mewrw buffer
local function find_mewrw_buf()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then
            return bufnr
        end
    end
    return nil
end

engine.open(test_dir)
local bufnr
vim.wait(3000, function() bufnr = find_mewrw_buf(); return bufnr ~= nil end)
vim.api.nvim_win_set_buf(0, bufnr)

vim.wait(3000, function()
    local s = engine.get_state()
    return s and #s.filtered_entries == 3
end)
local state = engine.get_state()

-- Helper to get current names in order
local function get_names()
	local names = {}
	for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
	return table.concat(names, ", ")
end

-- 1. Name Ascending (Default)
print("\nStep 1: Name Ascending")
print("Order: " .. get_names())
if state.filtered_entries[1].name == "a_small.txt" and state.filtered_entries[3].name == "z_large.txt" then
	print("SUCCESS: Name Ascending correct.")
else
	print("FAILURE: Name Ascending incorrect.")
end

-- 2. Name Descending
print("\nStep 2: Name Descending (Toggle S)")
engine.toggle_sort_reverse()
print("Order: " .. get_names())
if state.filtered_entries[1].name == "z_large.txt" and state.filtered_entries[3].name == "a_small.txt" then
	print("SUCCESS: Name Descending correct.")
else
	print("FAILURE: Name Descending incorrect.")
end

-- 3. Size Ascending
print("\nStep 3: Size Ascending (Cycle sort to size, Toggle S back to normal)")
engine.cycle_sort() -- name -> numerical
engine.cycle_sort() -- numerical -> extension
engine.cycle_sort() -- extension -> size
engine.toggle_sort_reverse() -- back to ascending
print("Order (by size asc): " .. get_names())
if state.filtered_entries[1].name == "a_small.txt" and state.filtered_entries[3].name == "z_large.txt" then
	print("SUCCESS: Size Ascending correct.")
else
	print("FAILURE: Size Ascending incorrect.")
end

-- 4. Size Descending
print("\nStep 4: Size Descending (Toggle S)")
engine.toggle_sort_reverse()
print("Order (by size desc): " .. get_names())
if state.filtered_entries[1].name == "z_large.txt" and state.filtered_entries[3].name == "a_small.txt" then
	print("SUCCESS: Size Descending correct.")
else
	print("FAILURE: Size Descending incorrect.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
print("Test finished.")
