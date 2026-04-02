-- Set package.path
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local fs = require("mewrw.fs")

print("--- Testing FS Manager ---")

local function test_list(uri)
	print("Attempting to list: " .. uri)
	_G.test_done = false
	fs.list(uri, function(err, entries)
		if err then
			print("Error for " .. uri .. ": " .. tostring(err))
		else
			print("Success for " .. uri .. "! Found " .. #entries .. " entries.")
		end
		_G.test_done = true
	end)
	vim.wait(1000, function()
		return _G.test_done
	end)
end

-- 1. Regular path
test_list(".")

-- 2. With file:// scheme
test_list("file://" .. root)

-- 3. Unsupported scheme (should fail)
test_list("unknown://path")
