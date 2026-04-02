local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

-- Test directory
local test_dir = root .. "/tests/sandbox_marks"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

-- Create multiple files
for i = 1, 3 do
	local f = io.open(test_dir .. "/file" .. i .. ".txt", "w")
	if f then
		f:write("content " .. i)
		f:close()
	end
end

print("--- Testing Mark & Bulk Delete ---")
mewrw.setup()

-- Helper to find the mewrw buffer
local function find_mewrw_buf()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[bufnr] and vim.bo[bufnr].filetype == "mewrw" then
			return bufnr
		end
	end
	return nil
end

engine.open(test_dir)
vim.wait(1000, function()
	return find_mewrw_buf() ~= nil
end, 100, false)
local bufnr = find_mewrw_buf()
assert(bufnr, "mewrw buffer was not created")

-- Wait for initial load
vim.wait(1000, function()
	local s = vim.b[bufnr].mewrw_state_id and require("mewrw.core.engine").get_state()
	return s and #s.filtered_entries == 3
end, 100, false)

-- Set buffer to current window
vim.api.nvim_win_set_buf(0, bufnr)
local state = engine.get_state()
print("Initial entries: " .. #state.filtered_entries)

-- 1. Mark first two files
print("\nStep 1: Marking file1.txt and file2.txt")
-- With 5-line header (0-4), first file is on line 6 (index 5)
vim.api.nvim_win_set_cursor(0, { 6, 0 })
engine.toggle_mark()
vim.api.nvim_win_set_cursor(0, { 7, 0 })
engine.toggle_mark()

local marked_count = 0
for _, marked in pairs(engine.get_global_marks()) do
	if marked then
		marked_count = marked_count + 1
	end
end
print("Marked count: " .. marked_count)

if marked_count == 2 then
	print("SUCCESS: 2 files marked.")
else
	print("FAILURE: Incorrect marked count: " .. marked_count)
end

-- 2. Bulk Delete
print("\nStep 2: Testing Bulk Delete")
-- Mock vim.fn.confirm (1 = Yes)
vim.fn.confirm = function(msg, choices, default)
	print("Mocked confirm (" .. msg:gsub("\n", " ") .. "): Yes")
	return 1
end

engine.delete_under_cursor()

-- Wait for reload after deletion (engine.open is called and creates a new buffer)
local final_buf
vim.wait(1000, function()
	final_buf = find_mewrw_buf()
	if not final_buf or final_buf == bufnr then
		return false
	end
	vim.api.nvim_win_set_buf(0, final_buf)
	local s = engine.get_state()
	return s and #s.filtered_entries == 1
end, 100, false)

state = engine.get_state()
print("Remaining entries: " .. #state.filtered_entries)
if #state.filtered_entries == 1 then
	print("SUCCESS: Bulk delete completed. Only 1 file remains.")
else
	print("FAILURE: Bulk delete failed.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
if final_buf then
	pcall(vim.api.nvim_buf_delete, final_buf, { force = true })
end
if bufnr and final_buf ~= bufnr then
	pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end
print("Test finished.")
