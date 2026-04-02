-- Set package.path
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing Navigation ---")

mewrw.setup()

-- Helper to find a mewrw buffer, optionally excluding one
local function find_mewrw_buf(exclude)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if bufnr ~= exclude and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "mewrw" then
			return bufnr
		end
	end
	return nil
end

-- 1. Setup
engine.open(".")
local bufnr
vim.wait(1000, function()
	bufnr = find_mewrw_buf()
	return bufnr ~= nil
end)
assert(bufnr, "mewrw buffer was not created")

-- Wait for initial render
vim.wait(1000, function()
	return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) >= 6
end)

print("Initial list rendered.")

-- 2. Find "lua/" directory and move cursor
-- Use regex that matches the name anywhere in the line to be flexible with view modes
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local target_line = -1
for i, line in ipairs(lines) do
	if line:match("lua/") then
		target_line = i
		break
	end
end

if target_line == -1 then
	print("FAILURE: 'lua/' directory not found in list.")
	for i, l in ipairs(lines) do
		print(string.format("%2d: %s", i, l))
	end
	return
end

vim.api.nvim_win_set_buf(0, bufnr)
vim.api.nvim_win_set_cursor(0, { target_line, 0 })
print("Moved cursor to line " .. target_line .. " (lua/)")

-- 3. Simulate 'l' (open_under_cursor)
print("\nStep 3: Testing 'l' to enter directory")
engine.open_under_cursor()

-- Wait for next render
local new_buf
vim.wait(1000, function()
	new_buf = find_mewrw_buf(bufnr)
	if not new_buf then
		return false
	end
	vim.api.nvim_win_set_buf(0, new_buf)
	local state = engine.get_state()
	local uri = state and state.uri:gsub("[\\/]$", "") or ""
	return uri:match("/lua$") and #state.filtered_entries > 0
end)

local state = engine.get_state()
print("New URI: " .. tostring(state and state.uri))

-- 4. Verification
if state and state.uri:gsub("[\\/]$", ""):match("/lua$") and #state.filtered_entries > 0 then
	print("SUCCESS: Navigated to lua/ directory via 'l'.")
else
	print("FAILURE: Navigation via 'l' failed.")
	if state then
		print("Current URI: " .. state.uri)
	end
end

-- 5. Simulate 'h' (up_directory)
print("\nStep 5: Testing 'h' to go up")
engine.up_directory()

local final_buf
vim.wait(1000, function()
	final_buf = find_mewrw_buf(new_buf)
	if not final_buf or final_buf == bufnr then
		return false
	end
	vim.api.nvim_win_set_buf(0, final_buf)
	local s = engine.get_state()
	local uri = s and s.uri:gsub("[\\/]$", "") or ""
	return s and not uri:match("/lua$") and #s.filtered_entries > 0
end)

local final_state = engine.get_state()
print("Back to: " .. tostring(final_state and final_state.uri))
local normalized_root = root:gsub("[\\/]$", "")
local normalized_final = final_state and final_state.uri:gsub("[\\/]$", "") or ""

if normalized_final == normalized_root then
	print("SUCCESS: Returned to root directory via 'h'.")
else
	print("FAILURE: Failed to return to root via 'h'.")
end

-- Cleanup
if final_buf then
	pcall(vim.api.nvim_buf_delete, final_buf, { force = true })
end
if new_buf then
	pcall(vim.api.nvim_buf_delete, new_buf, { force = true })
end
if bufnr then
	pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end
print("Test finished.")
