local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")
local uv = vim.loop

local test_dir = root .. "/tests/tmp_ext_sort"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

-- テスト用ファイルの作成 (拡張子バラバラ)
uv.fs_open(test_dir .. "/z.lua", "w", 438, function(err, fd) uv.fs_close(fd) end)
uv.fs_open(test_dir .. "/a.txt", "w", 438, function(err, fd) uv.fs_close(fd) end)
uv.fs_open(test_dir .. "/b.lua", "w", 438, function(err, fd) uv.fs_close(fd) end)

print("--- Testing Extension Sort ---")
mewrw.setup()
mewrw.open(test_dir)

vim.wait(2000, function() return engine.get_state() and #engine.get_state().filtered_entries == 3 end)

local state = engine.get_state()

-- 1. Name Sort (Default)
print("\nStep 1: Name Sort (Expect: a.txt, b.lua, z.lua)")
local names = {}
for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
print("Order: " .. table.concat(names, ", "))

-- 2. Extension Sort
print("\nStep 2: Extension Sort (Expect: b.lua, z.lua, a.txt)")
-- name -> numerical -> extension
engine.cycle_sort() 
engine.cycle_sort() 
print("Current sort_by: " .. state.sort_by)

names = {}
for _, e in ipairs(state.filtered_entries) do table.insert(names, e.name) end
print("Order: " .. table.concat(names, ", "))

if names[1] == "b.lua" and names[2] == "z.lua" and names[3] == "a.txt" then
  print("SUCCESS: Extension sort works (grouped by .lua, then .txt).")
else
  print("FAILURE: Extension sort failed.")
end

-- Cleanup
vim.fn.delete(test_dir, "rf")
