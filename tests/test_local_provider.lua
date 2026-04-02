-- Set package.path to include the lua directory
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

print("Working directory: " .. root)
local local_provider = require("mewrw.fs.provider.local")

print("Type of local_provider: " .. type(local_provider))

if type(local_provider) ~= "table" then
	print("Error: local_provider is not a table. Value: " .. tostring(local_provider))
	return
end

print("--- Testing LocalProvider.list('.') ---")
_G.test_done = false
local_provider.list(".", function(err, entries)
	if err then
		print("Error: " .. tostring(err))
		_G.test_done = true
		return
	end

	print("Found " .. #entries .. " entries:")
	for _, entry in ipairs(entries) do
		print(
			string.format(
				"  [%s] %-20s (Size: %d, MTime: %d)",
				entry.type,
				entry.name,
				entry.size or 0,
				entry.mtime or 0
			)
		)
	end

	-- Test completion flag
	_G.test_done = true
end)

-- Wait for async operation to complete
vim.wait(1000, function()
	return _G.test_done
end)

if not _G.test_done then
	print("Timeout or failed to complete async call.")
end
