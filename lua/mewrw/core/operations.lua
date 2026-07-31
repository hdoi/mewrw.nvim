local M = {}
local fs = require("mewrw.fs")
local renderer = require("mewrw.ui.renderer")
local bookmarks = require("mewrw.core.bookmarks")

--- Helper to get the engine module
local function engine() return require("mewrw.core.engine") end

local function refresh_state(s)
	if not s then return end
	engine().open(s.uri, nil, {
		view_mode = s.view_mode,
		show_hidden = s.show_hidden,
		show_full_path = s.show_full_path,
		sort_by = s.sort_by,
		sort_reverse = s.sort_reverse,
		filter = s.filter,
		expanded_nodes = s.expanded_nodes,
	})
end

local function remove_path_from_expanded_nodes(state, p)
	if not state or not state.expanded_nodes then return end
	state.expanded_nodes[p] = nil
	state.expanded_nodes[p .. "/"] = nil

	for _, entries in pairs(state.expanded_nodes) do
		for i = #entries, 1, -1 do
			local entry = entries[i]
			if entry.path == p or entry.path == p .. "/" then
				table.remove(entries, i)
			end
		end
	end
end

local function rename_path_in_expanded_nodes(state, old_p, new_p)
	if not state or not state.expanded_nodes then return end
	if state.expanded_nodes[old_p] then
		state.expanded_nodes[new_p] = state.expanded_nodes[old_p]
		state.expanded_nodes[old_p] = nil
	end
	if state.expanded_nodes[old_p .. "/"] then
		state.expanded_nodes[new_p .. "/"] = state.expanded_nodes[old_p .. "/"]
		state.expanded_nodes[old_p .. "/"] = nil
	end

	local old_name = vim.fn.fnamemodify(old_p, ":t")
	local new_name = vim.fn.fnamemodify(new_p, ":t")
	for _, entries in pairs(state.expanded_nodes) do
		for _, entry in ipairs(entries) do
			if entry.path == old_p or entry.path == old_p .. "/" then
				entry.path = new_p
				entry.name = new_name
				break
			end
		end
	end
end

function M.add_bookmark()
	local state = engine().get_state()
	if state and state.uri ~= "" then bookmarks.add(state.uri) end
end
function M.list_bookmarks() bookmarks.list(engine().open) end
function M.remove_bookmark() bookmarks.remove() end

function M.set_target()
	local state = engine().get_state()
	if not state then return end
	engine().set_global_target(state.uri)
	vim.notify("Target set: " .. state.uri)
	engine().render_all()
end

function M.toggle_mark(visual)
	local s = engine().get_state()
	if not s then return end
	local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
	local stop = visual and vim.fn.line(".") or start
	if start > stop then start, stop = stop, start end

	local marks = engine().get_global_marks()
	for l = start, stop do
		local e = engine().get_entry(l)
		if e then
			if marks[e.path] then marks[e.path] = nil
			else marks[e.path] = true end
		end
	end
	engine().render_all()
	if visual then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true) end
end

function M.clear_marks()
	engine().clear_global_marks()
	engine().render_all()
end

function M.show_marked_items()
	local marks = engine().get_global_marks()
	local targets = {}
	for p, _ in pairs(marks) do table.insert(targets, p) end
	if #targets == 0 then return vim.notify("No items marked") end
	table.sort(targets)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, targets)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "mewrw_marks")

	local width = math.min(80, vim.o.columns - 10)
	local height = math.min(#targets, vim.o.lines - 10)
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor", width = width, height = height,
		col = (vim.o.columns - width) / 2, row = (vim.o.lines - height) / 2,
		style = "minimal", border = "rounded",
	})
	vim.keymap.set("n", "q", function() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end, { buffer = bufnr, nowait = true })
end

function M.delete_under_cursor(visual)
	local s = engine().get_state()
	if not s then return end
	local marks = engine().get_global_marks()
	local targets = {}
	for p, _ in pairs(marks) do table.insert(targets, p) end

	if #targets == 0 then
		local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
		local stop = visual and vim.fn.line(".") or start
		if start > stop then start, stop = stop, start end
		for l = start, stop do
			local e = engine().get_entry(l)
			if e then table.insert(targets, e.path) end
		end
	end
	if #targets == 0 then return end

	local msg = #targets == 1 and ("Delete " .. targets[1] .. "?") or ("Delete " .. #targets .. " items?")
	if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then return end

	local count = 0
	for _, p in ipairs(targets) do
		fs.delete(p, true, function(err)
			vim.schedule(function()
				count = count + 1
				if marks[p] then marks[p] = nil end
				remove_path_from_expanded_nodes(s, p)
				if count == #targets then
					vim.notify("Finished processing " .. #targets .. " items")
					refresh_state(s)
				end
			end)
		end)
	end
	if visual then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true) end
end

function M.bulk_action(mode)
	local s = engine().get_state()
	if not s then return end
	local marks = engine().get_global_marks()
	local targets = {}
	for p, _ in pairs(marks) do table.insert(targets, p) end
	if #targets == 0 then return vim.notify("No items marked") end

	local dest = engine().get_global_target() or s.uri
	if vim.fn.confirm(string.format("%s %d items to %s?", mode:upper(), #targets, dest), "&Yes\n&No", 2) ~= 1 then return end

	local count = 0
	for _, src in ipairs(targets) do
		local name = vim.fn.fnamemodify(src, ":t")
		local d_path = dest:gsub("/$", "") .. "/" .. name
		local fn = (mode == "move") and fs.rename or fs.copy
		fn(src, d_path, function(err)
			vim.schedule(function()
				count = count + 1
				if not err then
					if mode == "move" then
						remove_path_from_expanded_nodes(s, src)
					end
					local dest_parent = vim.fn.fnamemodify(d_path, ":h")
					if s.expanded_nodes[dest_parent] then
						s.expanded_nodes[dest_parent] = nil
					end
				end
				if count == #targets then
					vim.notify(string.format("Bulk %s finished", mode))
					engine().clear_global_marks()
					refresh_state(s)
				end
			end)
		end)
	end
end

function M.rename_under_cursor()
	local s = engine().get_state()
	local e = engine().get_entry()
	if not s or not e then return end
	vim.ui.input({ prompt = "Rename: ", default = e.name }, function(n)
		if not n or n == "" or n == e.name then return end
		local dest = vim.fn.fnamemodify(e.path, ":h"):gsub("/$", "") .. "/" .. n
		fs.rename(e.path, dest, function(err)
			if err then
				vim.notify(err, vim.log.levels.ERROR)
			else
				rename_path_in_expanded_nodes(s, e.path, dest)
				refresh_state(s)
			end
		end)
	end)
end

function M.batch_rename(visual)
	local s = engine().get_state()
	if not s then return end
	local marks = engine().get_global_marks()
	local targets = {}
	for p, _ in pairs(marks) do table.insert(targets, p) end

	if #targets == 0 then
		local start = visual and vim.fn.line("v") or vim.api.nvim_win_get_cursor(0)[1]
		local stop = visual and vim.fn.line(".") or start
		if start > stop then start, stop = stop, start end
		for l = start, stop do
			local e = engine().get_entry(l)
			if e then table.insert(targets, e.path) end
		end
	end
	if #targets == 0 then return vim.notify("No items to rename") end
	require("mewrw.ui.batch_rename").open(targets, vim.api.nvim_get_current_buf())
end

function M.create_directory()
	local s = engine().get_state()
	if not s or s.uri == "" then return end
	vim.ui.input({ prompt = "New Dir: " }, function(n)
		if not n or n == "" then return end
		local new_path = s.uri:gsub("/$", "") .. "/" .. n
		fs.mkdir(new_path, function(err)
			vim.schedule(function()
				if err then
					vim.notify(err, vim.log.levels.ERROR)
				else
					-- Since the new dir was created, if s.uri is an expanded node, we might want to invalidate it.
					-- However, s.uri is usually the root of the buffer which gets re-listed anyway by engine().open.
					refresh_state(s)
				end
			end)
		end)
	end)
end

return M
