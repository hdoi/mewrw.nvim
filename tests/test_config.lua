local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing Configuration (Sort/Hidden) ---")

-- Create hidden file before opening
local hidden_file = root .. "/.hidden_test"
local f = io.open(hidden_file, "w")
if f then
	f:write("hidden content")
	f:close()
end

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

-- Open mewrw and wait for it to be ready
engine.open(root)
vim.wait(1000, function()
	return find_mewrw_buf() ~= nil
end, 100, false)
local bufnr = find_mewrw_buf()
assert(bufnr, "mewrw buffer was not created")

-- Wait until the state is initialized and populated
local state
vim.wait(1000, function()
	if vim.b[bufnr] and vim.b[bufnr].mewrw_state_id then
		-- Switch to buffer to get state correctly
		local original_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_set_current_buf(bufnr)
		state = engine.get_state()
		vim.api.nvim_set_current_buf(original_buf)
		if state and #state.filtered_entries > 0 then
			return true
		end
	end
	return false
end, 100, false)
assert(state, "mewrw state was not created or retrieved")

-- 1. Test Hidden
print("\nStep 1: Check hidden files (should be off)")
local function has_hidden_file(s)
	for _, e in ipairs(s.filtered_entries) do
		if e.name == ".hidden_test" then
			return true
		end
	end
	return false
end

assert(not has_hidden_file(state), "Hidden file was visible initially")
print("Has .hidden_test: false")

print("Toggling hidden...")
local original_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_set_current_buf(bufnr)
engine.toggle_hidden()
vim.api.nvim_set_current_buf(original_buf)

assert(has_hidden_file(state), "Hidden file toggle did not show .hidden_test")
print("Has .hidden_test after toggle: true")
print("SUCCESS: Hidden file toggle works.")

-- 2. Test Sorting
print("\nStep 2: Check sorting by size")
vim.api.nvim_set_current_buf(bufnr)
engine.cycle_sort() -- name -> numerical
engine.cycle_sort() -- numerical -> extension
engine.cycle_sort() -- extension -> size
vim.api.nvim_set_current_buf(original_buf)
assert(state.sort_by == "size", "Sort cycle did not result in 'size'")
print("Current sort_by: size")
print("SUCCESS: Sorting works.")

-- 3. Test View Mode
print("\nStep 3: Check view mode cycling")
vim.api.nvim_set_current_buf(bufnr)
engine.cycle_view_mode() -- list -> detailed
vim.api.nvim_set_current_buf(original_buf)

-- With 5 header lines, first entry is at line 6 (index 5)
local lines = vim.api.nvim_buf_get_lines(bufnr, 5, 6, false)
print("Detailed line sample: '" .. (lines[1] or "N/A") .. "'")
if lines[1] and lines[1]:match("%d+%.?%d*%s*[KMGT]?B") then
	print("SUCCESS: Detailed view shows size.")
else
	print("FAILURE: Detailed view doesn't show size.")
end

-- Cleanup
os.remove(hidden_file)
vim.cmd("bdelete! " .. bufnr)
print("Test finished.")
