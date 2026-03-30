local fs = require("mewrw.fs")
local State = require("mewrw.core.state")
local renderer = require("mewrw.ui.renderer")
local bookmarks = require("mewrw.core.bookmarks")
local help = require("mewrw.ui.help")

local M = {}

local HEADER_OFFSET = 5
local all_states = {}
local global_target_uri = nil
local global_marks = {} -- { [path] = true }

--- Get state for the current buffer
function M.get_state()
	local bufnr = vim.api.nvim_get_current_buf()
	local id = vim.b[bufnr] and vim.b[bufnr].mewrw_state_id
	return all_states[id]
end

function M.get_global_target()
	return global_target_uri
end
function M.get_global_marks()
	return global_marks
end

--- Helper to get entry under cursor or from specific line
local function get_entry(line)
	local state = M.get_state()
	if not state then
		return nil
	end
	line = line or vim.api.nvim_win_get_cursor(0)[1]
	return state.filtered_entries[line - HEADER_OFFSET]
end

function M.open_filter()
	local state = M.get_state()
	if not state then
		return
	end
	vim.ui.input({ prompt = "Filter: ", default = state.filter }, function(input)
		if input == nil then
			return
		end
		state.filter = input
		state:update()
		renderer.render(state)
	end)
end

function M.add_bookmark()
	local state = M.get_state()
	if state and state.uri ~= "" then
		bookmarks.add(state.uri)
	end
end
function M.list_bookmarks()
	bookmarks.list(M.open)
end
function M.remove_bookmark()
	bookmarks.remove()
end
function M.clear_bookmarks_for_test()
	bookmarks.clear_for_test()
end

function M.set_target()
	local state = M.get_state()
	if not state then
		return
	end
	global_target_uri = state.uri
	vim.notify("Target set: " .. global_target_uri)
	for _, s in pairs(all_states) do
		renderer.render(s)
	end
end

--- Core: Open a URI in a new buffer
---@param uri? string
---@param direction? "v"|"h"|"t"
function M.open(uri, direction)
	vim.schedule(function()
		if direction == "v" then
			vim.cmd("vsplit")
		elseif direction == "h" then
			vim.cmd("split")
		elseif direction == "t" then
			vim.cmd("tabnew")
		end

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
        -- print("Mewrw debugging: opening " .. tostring(uri))

		uri = uri or (M.get_state() and M.get_state().uri) or vim.fn.getcwd()
		if not uri:match("^%a+://") then
			-- Trim before and after resolution
			uri = uri:gsub("^%s*(.-)%s*$", "%1")
			uri = vim.fn.fnamemodify(uri, ":p"):gsub("\\", "/")
			-- Aggressively remove trailing / and /. and trailing spaces
			uri = uri:gsub("[\\/]%.?%s*$", "")
			if uri == "" then uri = "/" end
		else
			local scheme, rest = uri:match("^([^:]+://)(.*)$")
			if scheme and rest then
				rest = rest:gsub("\\", "/"):gsub("[\\/]%.?%s*$", "")
				if rest == "" then rest = "/" end
				uri = scheme .. rest
			end
		end

		local state = State.new(bufnr)
		all_states[bufnr] = state
		vim.b[bufnr].mewrw_state_id = bufnr
		require("mewrw.ui.renderer").setup_buffer(bufnr)

		vim.api.nvim_create_autocmd("BufWinEnter", {
			buffer = bufnr,
			callback = function()
				local bufs_wins = 0
				for _, w in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_get_buf(w) == bufnr then
						bufs_wins = bufs_wins + 1
					end
				end
				if bufs_wins > 1 then
					vim.schedule(function()
						M.open(state.uri)
					end)
				end
			end,
		})

		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = bufnr,
			callback = function()
				all_states[bufnr] = nil
			end,
		})

		fs.list(uri, function(err, entries)
			if err then
				return vim.schedule(function()
					vim.notify("Error: " .. tostring(err), vim.log.levels.ERROR)
				end)
			end
			vim.schedule(function()
				state:update(uri, entries)
				require("mewrw.ui.renderer").render(state)

				-- Git integration
				local config = require("mewrw").config
				if config.git_integration and not uri:match("^%a+://") then
					require("mewrw.core.git").get_info(uri, function(root, branch, statuses)
						if branch or statuses then
							state.git_branch = branch
							state.git_status = statuses
							require("mewrw.ui.renderer").render(state)
						end
					end)
				end

				if vim.api.nvim_buf_is_valid(bufnr) then
					local lc = vim.api.nvim_buf_line_count(bufnr)
					pcall(vim.api.nvim_win_set_cursor, 0, { math.min(6, lc), 0 })
				end
			end)
		end)
	end)
end

function M.open_under_cursor()
	local state = M.get_state()
	local entry = get_entry()
	if not state or not entry then
		return
	end

	if state.view_mode == "tree" and entry.type == "directory" then
		if state.expanded_nodes[entry.path] then
			state.expanded_nodes[entry.path] = nil
			state:update()
			renderer.render(state)
		else
			fs.list(entry.path, function(err, entries)
				if err then
					return vim.notify(err, vim.log.levels.ERROR)
				end
				vim.schedule(function()
					state.expanded_nodes[entry.path] = entries
					state:update()
					renderer.render(state)
				end)
			end)
		end
		return
	end

	if entry.type == "directory" then
		return M.open(entry.path)
	end

	local ext = entry.name:match("%.([^.]+)$")
	if (ext == "zip" or ext == "tar") and not state.uri:match("^" .. ext) then
		return M.open(ext .. "://" .. entry.path)
	end

	if entry.path:match("^%a+://") then
		fs.read(entry.path, function(err, data)
			if err then
				return vim.notify(err, vim.log.levels.ERROR)
			end
			vim.schedule(function()
				local nb = vim.api.nvim_create_buf(true, false)
				vim.api.nvim_set_current_buf(nb)
				vim.api.nvim_buf_set_lines(nb, 0, -1, false, vim.split(data, "\n"))
				vim.api.nvim_buf_set_name(nb, entry.path)
				vim.api.nvim_create_autocmd("BufWriteCmd", {
					buffer = nb,
					callback = function()
						local content = table.concat(vim.api.nvim_buf_get_lines(nb, 0, -1, false), "\n")
						fs.write(entry.path, content, function(we)
							vim.schedule(function()
								if we then
									vim.notify("Save failed: " .. we, vim.log.levels.ERROR)
								else
									vim.notify("Saved")
									vim.api.nvim_buf_set_option(nb, "modified", false)
								end
							end)
						end)
					end,
				})
			end)
		end)
		return
	end
	vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
end

function M.open_external()
	local entry = get_entry()
	if not entry then
		return
	end
	local p = entry.path:gsub("^file://", "")
	if vim.ui.open then
		vim.ui.open(p)
	else
		local cmd = vim.fn.has("win32") == 1 and { "cmd.exe", "/c", "start", '""' }
			or (vim.fn.has("mac") == 1 and { "open" } or { "xdg-open" })
		table.insert(cmd, p)
		vim.fn.jobstart(cmd, { detach = true })
	end
end

function M.toggle_hidden()
	local s = M.get_state()
	if s then
		s.show_hidden = not s.show_hidden
		s:update()
		renderer.render(s)
	end
end

function M.toggle_full_path()
	local s = M.get_state()
	if s then
		s.show_full_path = not s.show_full_path
		renderer.render(s)
	end
end

function M.cycle_sort()
	local s = M.get_state()
	if not s then
		return
	end
	local m = { "name", "numerical", "extension", "size", "mtime" }
	local cur = 1
	for i, v in ipairs(m) do
		if v == s.sort_by then
			cur = i
		end
	end
	s.sort_by = m[(cur % #m) + 1]
	s:update()
	renderer.render(s)
end

function M.toggle_sort_reverse()
	local s = M.get_state()
	if s then
		s.sort_reverse = not s.sort_reverse
		s:update()
		renderer.render(s)
	end
end

function M.cycle_view_mode()
	local s = M.get_state()
	if not s then
		return
	end
	local m = { "list", "detailed", "tree" }
	local cur = 1
	for i, v in ipairs(m) do
		if v == s.view_mode then
			cur = i
		end
	end
	s.view_mode = m[(cur % #m) + 1]
	s:update()
	renderer.render(s)
end

function M.collapse_all()
	local s = M.get_state()
	if s then
		s.expanded_nodes = {}
		s:update()
		renderer.render(s)
	end
end

function M.expand_all()
	local state = M.get_state()
	if not state or state.view_mode ~= "tree" then
		return
	end

	local function expand_recursive(dir_uri)
		fs.list(dir_uri, function(err, entries)
			if err then
				return
			end
			vim.schedule(function()
				state.expanded_nodes[dir_uri] = entries
				state:update()
				renderer.render(state)
				for _, e in ipairs(entries) do
					if e.type == "directory" and not state.expanded_nodes[e.path] then
						expand_recursive(e.path)
					end
				end
			end)
		end)
	end
	expand_recursive(state.uri)
end

function M.toggle_mark(visual)
	local s = M.get_state()
	if not s then
		return
	end
	local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
	local stop = visual and vim.fn.line(".") or start
	if start > stop then
		start, stop = stop, start
	end

	for l = start, stop do
		local e = get_entry(l)
		if e then
			if global_marks[e.path] then
				global_marks[e.path] = nil
			else
				global_marks[e.path] = true
			end
		end
	end
	for _, state in pairs(all_states) do
		renderer.render(state)
	end
	if visual then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
	end
end

function M.clear_marks()
	global_marks = {}
	for _, state in pairs(all_states) do
		renderer.render(state)
	end
end

function M.show_marked_items()
	local targets = {}
	for p, _ in pairs(global_marks) do
		table.insert(targets, p)
	end
	if #targets == 0 then
		return vim.notify("No items marked")
	end

	table.sort(targets)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, targets)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "mewrw_marks")

	local width = math.min(80, vim.o.columns - 10)
	local height = math.min(#targets, vim.o.lines - 10)
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	})
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = bufnr, nowait = true })
end

function M.delete_under_cursor(visual)
	local s = M.get_state()
	if not s then
		return
	end

	local targets = {}
	for p, _ in pairs(global_marks) do
		table.insert(targets, p)
	end

	if #targets == 0 then
		local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
		local stop = visual and vim.fn.line(".") or start
		if start > stop then
			start, stop = stop, start
		end
		for l = start, stop do
			local e = get_entry(l)
			if e then
				table.insert(targets, e.path)
			end
		end
	end

	if #targets == 0 then
		return
	end

	local msg = #targets == 1 and ("Delete " .. targets[1] .. "?") or ("Delete " .. #targets .. " items?")
	if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
		return
	end

	local count = 0
	for _, p in ipairs(targets) do
		fs.delete(p, false, function(err)
			vim.schedule(function()
				count = count + 1
				if global_marks[p] then
					global_marks[p] = nil
				end
				if count == #targets then
					vim.notify("Finished processing " .. #targets .. " items")
					M.open(s.uri)
				end
			end)
		end)
	end
	if visual then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
	end
end

function M.bulk_action(mode)
	local s = M.get_state()
	if not s then
		return
	end
	local targets = {}
	for p, _ in pairs(global_marks) do
		table.insert(targets, p)
	end
	if #targets == 0 then
		return vim.notify("No items marked")
	end

	local dest = global_target_uri or s.uri
	if vim.fn.confirm(string.format("%s %d items to %s?", mode:upper(), #targets, dest), "&Yes\n&No", 2) ~= 1 then
		return
	end

	local count = 0
	for _, src in ipairs(targets) do
		local name = vim.fn.fnamemodify(src, ":t")
		local d_path = dest:gsub("/$", "") .. "/" .. name
		local fn = (mode == "move") and fs.rename or fs.copy
		fn(src, d_path, function(err)
			vim.schedule(function()
				count = count + 1
				if count == #targets then
					vim.notify(string.format("Bulk %s finished", mode))
					global_marks = {}
					M.open(s.uri)
				end
			end)
		end)
	end
end

function M.show_help()
	help.show()
end

function M.rename_under_cursor()
	local s = M.get_state()
	local e = get_entry()
	if not s or not e then
		return
	end
	vim.ui.input({ prompt = "Rename: ", default = e.name }, function(n)
		if not n or n == "" or n == e.name then
			return
		end
		local dest = vim.fn.fnamemodify(e.path, ":h"):gsub("/$", "") .. "/" .. n
		fs.rename(e.path, dest, function(err)
			if err then
				vim.notify(err, vim.log.levels.ERROR)
			else
				M.open(s.uri)
			end
		end)
	end)
end

function M.batch_rename(visual)
	local s = M.get_state()
	if not s then
		return
	end

	local targets = {}
	for p, _ in pairs(global_marks) do
		table.insert(targets, p)
	end

	if #targets == 0 then
		local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
		local stop = visual and vim.fn.line(".") or start
		if start > stop then
			start, stop = stop, start
		end
		for l = start, stop do
			local e = get_entry(l)
			if e then
				table.insert(targets, e.path)
			end
		end
	end

	if #targets == 0 then
		return vim.notify("No items to rename")
	end
	require("mewrw.ui.batch_rename").open(targets, vim.api.nvim_get_current_buf())
end

function M.up_directory()
	local s = M.get_state()
	if not s or s.uri == "" then
		return
	end
	local p = vim.fn.fnamemodify(s.uri, ":h")
	if p ~= s.uri then
		M.open(p)
	end
end

function M.create_directory()
	local s = M.get_state()
	if not s or s.uri == "" then
		return
	end
	vim.ui.input({ prompt = "New Dir: " }, function(n)
		if not n or n == "" then
			return
		end
		fs.mkdir(s.uri:gsub("/$", "") .. "/" .. n, function(err)
			vim.schedule(function()
				if err then
					vim.notify(err, vim.log.levels.ERROR)
				else
					M.open(s.uri)
				end
			end)
		end)
	end)
end

return M
