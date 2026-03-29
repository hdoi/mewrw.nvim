local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing Filter ---")
mewrw.setup()
mewrw.open(root)

vim.wait(1000, function()
	return engine.get_state() and #engine.get_state().filtered_entries > 0
end)

local state = engine.get_state()
local initial_count = #state.filtered_entries
print("Initial entries: " .. initial_count)

-- 1. Apply filter "md" (should match mewrw_spec.md)
print("\nStep 1: Apply filter 'md'")
vim.ui.input = function(opts, on_confirm)
	on_confirm("md")
end

engine.open_filter()

print("Entries after filter 'md': " .. #state.filtered_entries)
local found_spec = false
for _, e in ipairs(state.filtered_entries) do
	print(" - " .. e.name)
	if e.name:match("md") then
		found_spec = true
	end
end

if found_spec and #state.filtered_entries < initial_count then
	print("SUCCESS: Filter applied correctly.")
else
	print("FAILURE: Filter did not work as expected.")
end

-- 2. Clear filter
print("\nStep 2: Clear filter")
vim.ui.input = function(opts, on_confirm)
	on_confirm("")
end

engine.open_filter()
print("Entries after clearing filter: " .. #state.filtered_entries)

if #state.filtered_entries == initial_count then
	print("SUCCESS: Filter cleared correctly.")
else
	print("FAILURE: Filter clearing failed.")
end
