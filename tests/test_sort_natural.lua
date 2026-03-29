local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local uv = vim.loop

local test_dir = root .. "/tests/tmp_sort"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

-- テスト用ファイルの作成
uv.fs_open(test_dir .. "/file10.txt", "w", 438, function(err, fd) uv.fs_close(fd) end)
uv.fs_open(test_dir .. "/file2.txt", "w", 438, function(err, fd) uv.fs_close(fd) end)
uv.fs_open(test_dir .. "/file1.txt", "w", 438, function(err, fd) uv.fs_close(fd) end)

print("--- Testing Natural Sort ---")
mewrw.setup()
mewrw.open(test_dir)

vim.wait(2000, function() return engine.get_state() and #engine.get_state().filtered_entries == 3 end)

local state = engine.get_state()

-- 1. Alphabetical (Default)
print("\nStep 1: Alphabetical (Expect: 1, 10, 2)")
local names = {}
for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
print("Order: " .. table.concat(names, ", "))

-- 2. Numerical
print("\nStep 2: Numerical (Expect: 1, 2, 10)")
engine.cycle_sort() -- name -> numerical
names = {}
for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
print("Order: " .. table.concat(names, ", "))

if names[1] == "file1.txt" and names[2] == "file2.txt" and names[3] == "file10.txt" then
  print("SUCCESS: Numerical sort works.")
else
  print("FAILURE: Numerical sort failed.")
end

-- 3. Reverse Numerical
print("\nStep 3: Reverse Numerical (Expect: 10, 2, 1)")
engine.toggle_sort_reverse()
names = {}
for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
print("Order: " .. table.concat(names, ", "))

if names[1] == "file10.txt" and names[2] == "file2.txt" and names[3] == "file1.txt" then
  print("SUCCESS: Reverse Numerical sort works.")
else
  print("FAILURE: Reverse Numerical sort failed.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
