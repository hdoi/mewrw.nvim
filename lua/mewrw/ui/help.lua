local M = {}

local content = {
	{ "Navigation", "header" },
	{ "<CR>", "key", "Open (Enter Dir/Archive)" },
	{ "p", "key", "Quick Preview (Right)" },
	{ "x", "key", "Open with External App" },
	{ "-", "key", "Up Directory" },
	{ "R", "key", "Reload/Refresh View" },
	{ "?", "key", "Live Filter Entries" },
	{ "u", "key", "Show Help" },

	{ "View Options", "header" },
	{ "i", "key", "Cycle View Mode" },
	{ "a", "key", "Toggle Hidden Files" },
	{ "A", "key", "Toggle Full Path" },
	{ "s", "key", "Cycle Sort Type" },
	{ "S", "key", "Toggle Sort Reverse" },
	{ "C", "key", "Collapse All (Tree)" },
	{ "E", "key", "Expand All (Tree)" },

	{ "Marks & Operations", "header" },
	{ "mf", "key", "Toggle Mark (supports Visual)" },
	{ "mt", "key", "Clear All Marks" },
	{ "ma", "key", "Show Marked Items" },
	{ "TT", "key", "Set Global Target" },
	{ "Tc", "key", "Copy Marked to Target" },
	{ "Tm", "key", "Move Marked to Target" },
	{ "D", "key", "Delete (supports Visual)" },
	{ "r", "key", "Rename Under Cursor" },
	{ "mr", "key", "Batch Rename (supports Visual)" },
	{ "d", "key", "Create New Directory" },

	{ "Bookmarks", "header" },
	{ "m", "key", "Add Current to Bookmarks" },
	{ "b", "key", "List & Jump to Bookmark" },
	{ "B", "key", "Remove a Bookmark" },

	{ "Misc", "header" },
	{ "q", "key", "Close Help Window" },
}

function M.show()
	local lines, hls = {}, {}
	for i, item in ipairs(content) do
		local line
		if item[2] == "header" then
			line = "--- " .. item[1] .. " ---"
			table.insert(hls, { i - 1, "Title", 0, -1 })
		elseif item[2] == "key" then
			line = string.format(" %-12s : %s", item[1], item[3])
			table.insert(hls, { i - 1, "Special", 1, #item[1] + 1 })
			table.insert(hls, { i - 1, "Comment", #item[1] + 15, -1 })
		else
			line = item[1]
		end
		table.insert(lines, line)
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "mewrw_help")

	local width, height = 55, #lines
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor", width = width, height = height,
		col = (vim.o.columns - width) / 2, row = (vim.o.lines - height) / 2,
		style = "minimal", border = "rounded"
	})

	local ns = vim.api.nvim_create_namespace("mewrw_help")
	for _, hl in ipairs(hls) do
		vim.api.nvim_buf_add_highlight(bufnr, ns, hl[2], hl[1], hl[3], hl[4])
	end

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
	end, { buffer = bufnr, nowait = true })
end

return M
