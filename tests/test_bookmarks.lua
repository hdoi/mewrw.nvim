local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

-- Override bookmark path for testing
local test_b_path = root .. "/tests/test_bookmarks_file"
os.remove(test_b_path)

-- We need to mock stdpath to point to our test file, or
-- manually inject the path into engine.lua for testing.
-- Since engine.lua has a local function get_bookmarks_path,
-- we'll have to rely on the actual path but ensure it's clean.
local actual_b_path = vim.fn.stdpath("data") .. "/mewrw_bookmarks"
os.remove(actual_b_path)

print("--- Testing Bookmarks (Add/Remove/Persistence) ---")
mewrw.setup()
engine.clear_bookmarks_for_test()

-- 1. Add current directory as bookmark
print("\nStep 1: Adding current directory to bookmarks")
engine.open(root)
vim.wait(1000, function()
	local s = engine.get_state()
	return s and s.uri ~= ""
end)

local uri = engine.get_state().uri
print("URI to bookmark: " .. tostring(uri))
engine.add_bookmark()

-- Check if file was created
if vim.fn.filereadable(actual_b_path) == 1 then
	print("SUCCESS: Bookmarks file created.")
else
	print("FAILURE: Bookmarks file not created at " .. actual_b_path)
end

-- 2. Check bookmark list
print("\nStep 2: Checking bookmark list")
local selected_choice = nil
vim.ui.select = function(items, opts, on_choice)
	print("Mocked select (" .. opts.prompt .. "): " .. (items[1] or "nil"))
	selected_choice = items[1]
	on_choice(items[1])
end

engine.list_bookmarks()
if selected_choice == uri or selected_choice == uri .. "/" then
	print("SUCCESS: Bookmark correctly listed.")
else
	print("FAILURE: Incorrect bookmark: " .. tostring(selected_choice))
end

-- 3. Delete bookmark
print("\nStep 3: Deleting bookmark")
vim.ui.select = function(items, opts, on_choice)
	print("Mocked select for deletion (" .. opts.prompt .. "): " .. (items[1] or "nil"))
	on_choice(items[1])
end

engine.remove_bookmark()

-- 4. Verify deletion
print("\nStep 4: Verifying deletion")
local bookmarks_count = 0
vim.ui.select = function(items, opts, on_choice)
	bookmarks_count = #items
end

engine.list_bookmarks()
if bookmarks_count == 0 then
	print("SUCCESS: Bookmark deleted and list is empty.")
else
	print("FAILURE: List not empty after deletion. Count: " .. bookmarks_count)
end

-- Cleanup
os.remove(actual_b_path)
