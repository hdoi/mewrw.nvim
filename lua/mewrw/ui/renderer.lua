local M = {}

--- Setup buffer options for mewrw
---@param bufnr number
function M.setup_buffer(bufnr)
	vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "mewrw")
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
	require("mewrw.ui.maps").setup(bufnr)
end

--- Format size in bytes to human readable string
---@param size number?
---@return string
local function format_size(size)
	if not size then return "      - " end
	local units = { " B", "KB", "MB", "GB", "TB" }
	local i = 1
	while size >= 1024 and i < #units do
		size = size / 1024
		i = i + 1
	end
	return string.format("%6.1f %s", size, units[i])
end

--- Format unix timestamp to YYYY-MM-DD HH:MM
---@param time number?
---@return string
local function format_time(time)
	if not time then return "                " end
	return os.date("%Y-%m-%d %H:%M", time)
end

--- Get git status string for a given entry path
--- If it's a directory, checks recursively.
---@param path string
---@param is_dir boolean
---@param git_status table<string, string>|nil
---@return string? status, string? hl
local function get_git_status(path, is_dir, git_status)
	if not git_status then return nil, nil end
	
	local s = git_status[path]
	if not s and is_dir then
		-- Directory propagation: Check if any file under this path has a status
		local prefix = path:gsub("/$", "") .. "/"
		for p, st in pairs(git_status) do
			if p:sub(1, #prefix) == prefix then
				s = " M" -- Indicate modified if anything inside changed
				break
			end
		end
	end

	if not s then return nil, nil end

	local color = "Comment"
	if s:match("M") then color = "DiffChange"
	elseif s:match("A") or s:match("?") then color = "DiffAdd"
	elseif s:match("U") or s:match("D") then color = "DiffDelete"
	end
	return "[" .. s:gsub(" ", "") .. "]", color
end

--- Render the state into the buffer
---@param state State
function M.render(state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end

	local engine = require("mewrw.core.engine")
	local config = require("mewrw").config
	local icons = require("mewrw.ui.icons")
	local marks = engine.get_global_marks()
	local mark_count = 0
	for _ in pairs(marks) do mark_count = mark_count + 1 end

	local lines = {}
	-- 5-line standard header
	table.insert(lines, string.format('" Directory: %s', state.uri))
	local branch_info = state.git_branch and (" (Git: " .. state.git_branch .. ")") or ""
	table.insert(lines, string.format('" Target   : %s%s', engine.get_global_target() or "(none)", branch_info))
	table.insert(lines, string.format('" Sort: %s (%s) | Hidden: %s | FullPath: %s', 
		state.sort_by, state.sort_reverse and "desc" or "asc",
		state.show_hidden and "on" or "off",
		state.show_full_path and "on" or "off"))
	table.insert(lines, string.format('" Marks: %d selected | Press u for help', mark_count))
	table.insert(lines, "") -- Blank line (index 5)

	local hls = {}
	local virtual_texts = {}

	for i, entry in ipairs(state.filtered_entries) do
		local line = ""
		local name = state.show_full_path and entry.path or entry.name
		if entry.type == "directory" then name = name .. "/" end

		local icon_text = ""
		local icon_hl = nil
		if config.icons ~= "none" then
			icon_text, icon_hl = icons.get(entry, config.icons)
		end

		if state.view_mode == "detailed" then
			line = string.format("%s  %s  %s", format_size(entry.size), format_time(entry.mtime), name)
		elseif state.view_mode == "tree" then
			local prefix = ""
			if entry.type == "directory" then
				prefix = state.expanded_nodes[entry.path] and "▼ " or "▶ "
			else
				prefix = "  "
			end
			line = string.rep("  ", entry.depth or 0) .. prefix .. name
		else
			line = name
		end

		-- Icons (Virtual Text)
		if config.icons ~= "none" and icon_text ~= "" then
			table.insert(virtual_texts, {
				line = #lines,
				text = icon_text .. " ",
				hl = icon_hl,
				col = state.view_mode == "tree" and (entry.depth or 0) * 2 or 0,
				pos = "inline"
			})
		end

		-- Git status (Virtual Text on the right)
		local gs, ghl = get_git_status(entry.path, entry.type == "directory", state.git_status)
		if gs then
			table.insert(virtual_texts, {
				line = #lines,
				text = " " .. gs,
				hl = ghl,
				pos = "eol"
			})
		end

		table.insert(lines, line)

		-- Highlight marked items
		if marks[entry.path] then
			table.insert(hls, { #lines - 1, "Underlined", 0, -1 })
		end
	end

	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", false)

	local ns = vim.api.nvim_create_namespace("mewrw")
	vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

	-- Apply virtual texts
	for _, vt in ipairs(virtual_texts) do
		vim.api.nvim_buf_set_extmark(state.bufnr, ns, vt.line, vt.col or 0, {
			virt_text = { { vt.text, vt.hl or "Normal" } },
			virt_text_pos = vt.pos,
		})
	end

	for _, hl in ipairs(hls) do
		vim.api.nvim_buf_add_highlight(state.bufnr, ns, hl[2], hl[1], hl[3], hl[4])
	end
end

return M
