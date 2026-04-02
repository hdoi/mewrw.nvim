-- Set package.path
local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing UI Rendering ---")

-- 1. Setup
mewrw.setup()
print("Setup completed.")

-- Helper to find the mewrw buffer
local function find_mewrw_buf()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[bufnr] and vim.bo[bufnr].filetype == 'mewrw' then
            return bufnr
        end
    end
    return nil
end

-- 2. Open current directory
engine.open(".")
vim.wait(1000, function() return find_mewrw_buf() ~= nil end, 100, false)
local bufnr = find_mewrw_buf()
assert(bufnr, "mewrw buffer was not created")
print("Open command issued.")

-- 3. Wait for the async list and schedule to complete
vim.wait(5000, function()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
  return lines[1] and lines[1]:match('^" Directory:')
end)

-- 4. Verify results
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
print("Buffer Content:")
for i, line in ipairs(lines) do
  if i <= 10 then -- Limit output
    print(string.format("%2d: %s", i, line))
  end
end

-- Check if expected lines are present
local found_header = false
local found_files = false
for _, line in ipairs(lines) do
  if line:match('^" Directory:') then found_header = true end
  if line:match("lua/") or line == "mewrw_spec.md" then found_files = true end
end

if found_header and found_files then
  print("\nSUCCESS: UI rendered correctly.")
else
  print("\nFAILURE: UI rendering missing expected content.")
  if not found_header then print("- Header not found.") end
  if not found_files then print("- Expected files/directories not found.") end
end

-- Cleanup
vim.cmd("bdelete! " .. bufnr)
print("Test finished.")
