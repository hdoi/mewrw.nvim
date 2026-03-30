local M = {}

--- Set key mappings for the mewrw buffer
---@param bufnr number
function M.setup(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }
	local nav = require("mewrw.core.navigation")
	local ops = require("mewrw.core.operations")
	local engine = require("mewrw.core.engine")

	-- Navigation
	vim.keymap.set("n", "<CR>", nav.open_under_cursor, opts)
	vim.keymap.set("n", "x", nav.open_external, opts)
	vim.keymap.set("n", "-", nav.up_directory, opts)
	vim.keymap.set("n", "<BS>", nav.up_directory, opts)
	vim.keymap.set("n", "R", function()
		local s = engine.get_state()
		if s then
			engine.open(s.uri, nil, {
				view_mode = s.view_mode,
				show_hidden = s.show_hidden,
				show_full_path = s.show_full_path,
				sort_by = s.sort_by,
				sort_reverse = s.sort_reverse,
				filter = s.filter,
				expanded_nodes = s.expanded_nodes
			})
		else
			engine.open()
		end
	end, opts)

	-- View Options
	vim.keymap.set("n", "i", nav.cycle_view_mode, opts)
	vim.keymap.set("n", "a", nav.toggle_hidden, opts)
	vim.keymap.set("n", "A", nav.toggle_full_path, opts)
	vim.keymap.set("n", "s", nav.cycle_sort, opts)
	vim.keymap.set("n", "S", nav.toggle_sort_reverse, opts)
	vim.keymap.set("n", "C", nav.collapse_all, opts)
	vim.keymap.set("n", "E", nav.expand_all, opts)
	vim.keymap.set("n", "?", nav.open_filter, opts)

	-- Marks & Bookmarks
	vim.keymap.set("n", "mf", function() ops.toggle_mark() end, opts)
	vim.keymap.set("v", "mf", function() ops.toggle_mark(true) end, opts)
	vim.keymap.set("n", "mt", ops.clear_marks, opts)
	vim.keymap.set("n", "ma", ops.show_marked_items, opts)
	vim.keymap.set("n", "TT", ops.set_target, opts)
	vim.keymap.set("n", "m", ops.add_bookmark, opts)
	vim.keymap.set("n", "b", ops.list_bookmarks, opts)
	vim.keymap.set("n", "B", ops.remove_bookmark, opts)

	-- Operations
	vim.keymap.set("n", "D", function() ops.delete_under_cursor() end, opts)
	vim.keymap.set("v", "D", function() ops.delete_under_cursor(true) end, opts)
	vim.keymap.set("n", "r", ops.rename_under_cursor, opts)
	vim.keymap.set("n", "mr", function() ops.batch_rename() end, opts)
	vim.keymap.set("v", "mr", function() ops.batch_rename(true) end, opts)
	vim.keymap.set("n", "d", ops.create_directory, opts)
	vim.keymap.set("n", "Tc", function() ops.bulk_action("copy") end, opts)
	vim.keymap.set("n", "Tm", function() ops.bulk_action("move") end, opts)

	-- Help
	vim.keymap.set("n", "u", function() require("mewrw.ui.help").show() end, opts)
end

return M
