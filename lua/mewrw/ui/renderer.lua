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

--- Internal formatters
local format = {
	size = function(size)
		if not size then return "      - " end
		local units = { " B", "KB", "MB", "GB", "TB" }
		local i = 1
		while size >= 1024 and i < #units do
			size = size / 1024
			i = i + 1
		end
		return string.format("%6.1f %s", size, units[i])
	end,
	time = function(time)
		if not time then return "                " end
		return os.date("%Y-%m-%d %H:%M", time)
	end
}

--- Get git status string and highlight group
local function get_git_status(path, is_dir, git_status)
	if not git_status then return nil, nil end
	
	local s = git_status[path]
	if not s and is_dir then
		local prefix = path:gsub("/$", "") .. "/"
		for p, st in pairs(git_status) do
			if p:sub(1, #prefix) == prefix then
				s = " M"
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
	local marks = engine.get_global_marks()
	local mark_count = 0
	for _ in pairs(marks) do mark_count = mark_count + 1 end

	-- 1. Build Header
	local lines = {
		string.format('" Directory: %s', state.uri),
		string.format('" Target   : %s%s', engine.get_global_target() or "(none)", state.git_branch and (" (Git: " .. state.git_branch .. ")") or ""),
		string.format('" Sort: %s (%s) | Hidden: %s | FullPath: %s', 
			state.sort_by, state.sort_reverse and "desc" or "asc",
			state.show_hidden and "on" or "off",
			state.show_full_path and "on" or "off"),
		string.format('" Marks: %d selected | Press u for help', mark_count),
		""
	}

	local hls = {}
	local virtual_texts = {}

	-- 2. Build Body
	for _, entry in ipairs(state.filtered_entries) do
		local name = state.show_full_path and entry.path or entry.name
		if entry.type == "directory" then name = name .. "/" end

		local line_text = ""
		local indent = string.rep("  ", entry.depth or 0)

		if state.view_mode == "detailed" then
			line_text = string.format("%s  %s  %s", format.size(entry.size), format.time(entry.mtime), name)
		elseif state.view_mode == "tree" then
			local prefix = entry.type == "directory" and (state.expanded_nodes[entry.path] and "▼ " or "▶ ") or "  "
			line_text = indent .. prefix .. name
		else
			line_text = name
		end

	-- 3. Prepare Decorations (Virtual Text)
	local current_line_idx = #lines
	
	-- Icons
	if state.icons and state.icons ~= "none" then
		local icon, icon_hl = require("mewrw.ui.icons").get(entry, state.icons)
		if icon ~= "" then
				table.insert(virtual_texts, {
					line = current_line_idx,
					text = icon .. " ",
					hl = icon_hl,
					col = state.view_mode == "tree" and (entry.depth or 0) * 2 or 0,
					pos = "inline"
				})
			end
		end

		-- Git Status
		local gs, ghl = get_git_status(entry.path, entry.type == "directory", state.git_status)
		if gs then
			table.insert(virtual_texts, { line = current_line_idx, text = " " .. gs, hl = ghl, pos = "eol" })
		end

		table.insert(lines, line_text)

		-- 4. Mark Highlight
		if marks[entry.path] then
			table.insert(hls, { current_line_idx, "Underlined", 0, -1 })
		end
	end

	-- 5. Apply to Buffer
	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.bufnr, "modifiable", false)

	local ns = vim.api.nvim_create_namespace("mewrw")
	vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

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
