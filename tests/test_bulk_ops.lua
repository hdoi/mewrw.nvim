local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local fs = require("mewrw.fs")
local uv = vim.loop

-- Setup sandbox
local base_dir = root .. "/tests/sandbox_bulk"
local src_dir = base_dir .. "/src"
local dest_dir = base_dir .. "/dest"

vim.fn.delete(base_dir, "rf")
vim.fn.mkdir(src_dir, "p")
vim.fn.mkdir(dest_dir, "p")

local function create_file(path, content)
	local f = io.open(path, "w")
	if f then
		f:write(content)
		f:close()
	end
end

create_file(src_dir .. "/item1.txt", "one")
create_file(src_dir .. "/item2.txt", "two")
create_file(src_dir .. "/item3.txt", "three")

print("--- Testing Bulk Copy & Move with Visual Mark ---")
mewrw.setup()

-- 1. Test Bulk Copy
print("\nStep 1: Testing Bulk Copy")
engine.open(src_dir)
vim.wait(1000, function()
	return engine.get_state() and #engine.get_state().filtered_entries == 3
end)

-- Mock visual selection for item1 & item2
print("Simulating visual selection for copy...")
-- Mocking vim.fn.line for toggle_mark(true)
local original_line = vim.fn.line
vim.fn.line = function(p)
	if p == "v" then
		return 6
	end -- Start at item1 (line 6)
	if p == "." then
		return 7
	end -- End at item2 (line 7)
	return original_line(p)
end

engine.toggle_mark(true)

-- Navigate to destination and execute copy
engine.open(dest_dir)
vim.wait(1000, function()
	local s = engine.get_state()
	return s and s.uri == dest_dir
end)
vim.fn.confirm = function()
	return 1
end
engine.bulk_action("copy")

-- Wait for files to actually appear on disk
local copy_success = vim.wait(3000, function()
	return vim.fn.filereadable(dest_dir .. "/item1.txt") == 1 and
	       vim.fn.filereadable(dest_dir .. "/item2.txt") == 1
end)

if copy_success then
	print("SUCCESS: Bulk Copy works.")
else
	print("FAILURE: Bulk Copy failed (timeout).")
end

-- Wait a bit more to ensure background re-rendering is done
vim.wait(1000, function() return false end)

-- 2. Test Bulk Move
print("\nStep 2: Testing Bulk Move")
engine.open(src_dir)
vim.wait(2000, function()
	local s = engine.get_state()
	return s and s.uri == src_dir and #s.filtered_entries == 3
end)

-- Mark all three files for move
engine.clear_marks()
vim.fn.line = function(p)
	if p == "v" then
		return 6
	end
	if p == "." then
		return 8
	end -- Mark items 1, 2, 3 (lines 6, 7, 8)
	return original_line(p)
end
engine.toggle_mark(true)

-- Navigate and execute move
engine.open(dest_dir)
vim.wait(1000, function()
	local s = engine.get_state()
	return s and s.uri == dest_dir
end)
engine.bulk_action("move")

-- Wait for files to move on disk
local move_success = vim.wait(3000, function()
	return vim.fn.filereadable(dest_dir .. "/item3.txt") == 1 and
	       vim.fn.filereadable(src_dir .. "/item1.txt") == 0
end)

if move_success then
	print("SUCCESS: Bulk Move works.")
else
	print("FAILURE: Bulk Move failed (timeout).")
end

-- Cleanup
vim.fn.delete(base_dir, "rf")
vim.fn.line = original_line -- Restore original
print("\nBulk ops test finished.")
