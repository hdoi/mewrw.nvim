local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local fs = require("mewrw.fs")
local uv = vim.loop

-- テスト用のディレクトリを固定
local test_dir = root .. "/tests/sandbox_archive"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

local content_path = test_dir .. "/content.txt"
local zip_path = test_dir .. "/test.zip"

-- 1. Create a dummy file and zip it
local f = io.open(content_path, "w")
f:write("hello archive")
f:close()

print("Creating zip at: " .. zip_path)
vim.fn.system(string.format("cd %s && zip test.zip content.txt", test_dir))

if vim.fn.filereadable(zip_path) == 0 then
	print("FAILURE: Zip file not created by system command.")
	return
end

print("--- Testing Archive Support (zip) ---")
mewrw.setup()

local archive_uri = "zip://" .. zip_path
engine.open(archive_uri)

-- Wait for initial load
vim.wait(1000, function()
	local state = engine.get_state()
	return state and #state.filtered_entries > 0
end)

local state = engine.get_state()
print("Initial URI: " .. tostring(state.uri))

-- Step 2: Test reading
print("\nStep 2: Testing reading from archive")
local target_uri = archive_uri .. "::content.txt"
_G.read_done = false
fs.read(target_uri, function(err, data)
	if err then
		print("Read error: " .. err)
	else
		print("Read content: " .. data)
		_G.read_data = data
	end
	_G.read_done = true
end)
vim.wait(1000, function()
	return _G.read_done
end)

if _G.read_data and _G.read_data:match("hello archive") then
	print("SUCCESS: Content read correctly.")
else
	print("FAILURE: Read data: " .. tostring(_G.read_data))
end

-- Step 3: Test writing
print("\nStep 3: Testing writing to archive")
local new_content = "updated content in zip"
_G.write_done = false
fs.write(target_uri, new_content, function(err)
	if err then
		print("FAILURE: Write to archive failed: " .. err)
	else
		print("Write command completed successfully.")
		-- Verify by re-reading
		fs.read(target_uri, function(read_err, data)
			if read_err then
				print("Re-read error: " .. read_err)
			else
				print("Re-read content: " .. data)
				if data:match("updated content") then
					print("SUCCESS: Archive updated correctly.")
				else
					print("FAILURE: Archive content mismatch.")
				end
			end
			_G.write_done = true
		end)
	end
end)

vim.wait(5000, function()
	return _G.write_done
end)

-- Cleanup (optional, keep for debugging)
-- vim.fn.delete(test_dir, "rf")
print("\nTest finished.")
