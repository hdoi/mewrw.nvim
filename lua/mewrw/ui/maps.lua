local M = {}

--- Set key mappings for the mewrw buffer
---@param bufnr number
function M.setup(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- Navigation
	vim.keymap.set("n", "<CR>", function() require("mewrw.core.engine").open_under_cursor() end, opts)
	vim.keymap.set("n", "x", function() require("mewrw.core.engine").open_external() end, opts)
	vim.keymap.set("n", "-", function() require("mewrw.core.engine").up_directory() end, opts)
	vim.keymap.set("n", "<BS>", function() require("mewrw.core.engine").up_directory() end, opts)
	vim.keymap.set("n", "R", function() require("mewrw.core.engine").open() end, opts)

	-- View Options
	vim.keymap.set("n", "i", function() require("mewrw.core.engine").cycle_view_mode() end, opts)
	vim.keymap.set("n", "a", function() require("mewrw.core.engine").toggle_hidden() end, opts)
	vim.keymap.set("n", "A", function() require("mewrw.core.engine").toggle_full_path() end, opts)
	vim.keymap.set("n", "s", function() require("mewrw.core.engine").cycle_sort() end, opts)
	vim.keymap.set("n", "S", function() require("mewrw.core.engine").toggle_sort_reverse() end, opts)
	vim.keymap.set("n", "C", function() require("mewrw.core.engine").collapse_all() end, opts)
	vim.keymap.set("n", "E", function() require("mewrw.core.engine").expand_all() end, opts)
	vim.keymap.set("n", "?", function() require("mewrw.core.engine").open_filter() end, opts)

	-- Marks & Bookmarks
	vim.keymap.set("n", "mf", function() require("mewrw.core.engine").toggle_mark() end, opts)
	vim.keymap.set("v", "mf", function() require("mewrw.core.engine").toggle_mark(true) end, opts)
	vim.keymap.set("n", "mt", function() require("mewrw.core.engine").clear_marks() end, opts)
	vim.keymap.set("n", "ma", function() require("mewrw.core.engine").show_marked_items() end, opts)
	vim.keymap.set("n", "TT", function() require("mewrw.core.engine").set_target() end, opts)
	vim.keymap.set("n", "m", function() require("mewrw.core.engine").add_bookmark() end, opts)
	vim.keymap.set("n", "b", function() require("mewrw.core.engine").list_bookmarks() end, opts)
	vim.keymap.set("n", "B", function() require("mewrw.core.engine").remove_bookmark() end, opts)

	-- Operations
	vim.keymap.set("n", "D", function() require("mewrw.core.engine").delete_under_cursor() end, opts)
	vim.keymap.set("v", "D", function() require("mewrw.core.engine").delete_under_cursor(true) end, opts)
	vim.keymap.set("n", "r", function() require("mewrw.core.engine").rename_under_cursor() end, opts)
	vim.keymap.set("n", "mr", function() require("mewrw.core.engine").batch_rename() end, opts)
	vim.keymap.set("v", "mr", function() require("mewrw.core.engine").batch_rename(true) end, opts)
	vim.keymap.set("n", "d", function() require("mewrw.core.engine").create_directory() end, opts)
	vim.keymap.set("n", "Tc", function() require("mewrw.core.engine").bulk_action("copy") end, opts)
	vim.keymap.set("n", "Tm", function() require("mewrw.core.engine").bulk_action("move") end, opts)

	-- Help
	vim.keymap.set("n", "u", function() require("mewrw.core.engine").show_help() end, opts)
end

return M
