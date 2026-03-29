local tests = {
	"tests/test_local_provider.lua",
	"tests/test_fs_manager.lua",
	"tests/test_ui_render.lua",
	"tests/test_navigation.lua",
	"tests/test_file_ops.lua",
	"tests/test_config.lua",
	"tests/test_sort_natural.lua",
	"tests/test_sort_extension.lua",
	"tests/test_sort_reverse.lua",
	"tests/test_filter.lua",
	"tests/test_archive.lua",
	"tests/test_bookmarks.lua",
	"tests/test_tree_view.lua",
	"tests/test_marks.lua",
}

print("========================================")
print("   Running All mewrw Tests")
print("========================================\n")

local pass_count = 0
local fail_count = 0
local failed_tests = {}

for _, test_file in ipairs(tests) do
	print("Running: " .. test_file)
	print("----------------------------------------")
	
	-- Neovim をサブプロセスで実行してテストを実行
	local cmd = string.format("~/bin/nvim-linux-x86_64.appimage --headless -c 'luafile %s' -c 'qa!' 2>&1", test_file)
	local handle = io.popen(cmd)
	local output = handle:read("*a")
	handle:close()
	
	print(output)
	
	if output:find("FAILURE") or output:find("Error detected") or output:find("stack traceback") then
		fail_count = fail_count + 1
		table.insert(failed_tests, test_file)
		print("Result: FAILED\n")
	else
		pass_count = pass_count + 1
		print("Result: PASSED\n")
	end
end

print("========================================")
print(string.format("Summary: %d Passed, %d Failed", pass_count, fail_count))
if fail_count > 0 then
	print("Failed Tests:")
	for _, t in ipairs(failed_tests) do
		print("  - " .. t)
	end
	os.exit(1)
else
	print("ALL TESTS PASSED!")
	os.exit(0)
end
