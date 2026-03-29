local M = {}

local content = {
	{ "Navigation", "header" }, { "<CR>", "key", "Open" }, { "-", "key", "Up" }, { "R", "key", "Reload" }, { "x", "key", "OS Open" },
	{ "View", "header" }, { "i", "key", "Mode" }, { "a", "key", "Hidden" }, { "A", "key", "Full Path" }, { "?", "key", "Filter" },
	{ "Sort", "header" }, { "s", "key", "Criteria" }, { "S", "key", "Reverse" },
	{ "Marks", "header" }, { "mf", "key", "Toggle Mark" }, { "mt", "key", "Clear Marks" }, { "ma", "key", "Show Marked List" }, { "TT", "key", "Set Target" }, { "Tc", "key", "Copy to Target" }, { "Tm", "key", "Move to Target" },
	{ "Ops", "header" }, { "D", "key", "Delete (supports visual range)" }, { "r", "key", "Rename" }, { "mr", "key", "Batch Rename" }, { "d", "key", "Mkdir" },
	{ "Tree", "header" }, { "C", "key", "Collapse All" }, { "E", "key", "Expand All" },
	{ "Misc", "header" }, { "u", "key", "Help" }, { "q", "key", "Close" }
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
