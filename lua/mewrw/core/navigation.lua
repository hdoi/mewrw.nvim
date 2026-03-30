local M = {}
local fs = require("mewrw.fs")
local renderer = require("mewrw.ui.renderer")
local path_utils = require("mewrw.utils.path")

--- Helper to get the engine module (to avoid circular dependency during load)
local function engine()
	return require("mewrw.core.engine")
end

function M.open_filter()
	local state = engine().get_state()
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

function M.open_under_cursor()
	local state = engine().get_state()
	local entry = engine().get_entry()
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
		return engine().open(entry.path, nil, {
			view_mode = state.view_mode,
			show_hidden = state.show_hidden,
			show_full_path = state.show_full_path,
			sort_by = state.sort_by,
			sort_reverse = state.sort_reverse,
			filter = state.filter,
			expanded_nodes = state.expanded_nodes,
		})
	end

	local name_lower = entry.name:lower()
	local is_archive = name_lower:match("%.zip$") or name_lower:match("%.tar$") or name_lower:match("%.tar%.gz$") or name_lower:match("%.tgz$")
	
	if is_archive and not state.uri:match("^zip") and not state.uri:match("^tar") then
		local scheme = name_lower:match("%.zip$") and "zip" or "tar"
		return engine().open(scheme .. "://" .. entry.path .. "::")
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
	local entry = engine().get_entry()
	if not entry then
		return
	end
	local p = entry.path:gsub("^file://", "")

	if path_utils.is_windows then
		p = p:gsub("/", "\\")
		vim.fn.jobstart({ "cmd.exe", "/c", "start", '""', p }, { detach = true })
	elseif vim.ui.open then
		vim.ui.open(p)
	else
		local cmd = vim.fn.has("mac") == 1 and { "open" } or { "xdg-open" }
		table.insert(cmd, p)
		vim.fn.jobstart(cmd, { detach = true })
	end
end

function M.up_directory()
	local s = engine().get_state()
	if not s or s.uri == "" then return end

	local entry = engine().get_entry()
	local focus = entry and entry.path or s.uri

	local opts = {
		view_mode = s.view_mode,
		show_hidden = s.show_hidden,
		show_full_path = s.show_full_path,
		sort_by = s.sort_by,
		sort_reverse = s.sort_reverse,
		filter = s.filter,
		expanded_nodes = s.view_mode == "tree" and vim.deepcopy(s.expanded_nodes) or nil,
		focus_uri = focus,
		prev_uri = s.uri,
	}

	if s.view_mode == "tree" and opts.expanded_nodes then
		opts.expanded_nodes[s.uri] = vim.deepcopy(s.entries)
	end

	-- 1. Handle Windows PC Root
	if path_utils.is_windows and s.uri == "/" then return end
	if path_utils.is_windows and s.uri:match("^%a:/$") then
		return engine().open("/", nil, opts)
	end

	-- 2. Handle Archive navigation (zip://, tar://)
	local scheme = s.uri:match("^(%a+)://")
	if scheme == "zip" or scheme == "tar" then
		local rest = s.uri:match("^%a+://+(.*)$")
		local archive_part, internal_part = rest:match("^(.*)::(.*)$")
		
		if not archive_part then
			archive_part = rest
			internal_part = ""
		end

		local is_abs = s.uri:match("^%a+:///")
		local slash_prefix = is_abs and "/" or ""

		if internal_part == "" or internal_part == "/" then
			-- Already at archive root: Go to local parent directory
			local raw_path = slash_prefix .. archive_part:gsub("^/+", "")
			local parent = vim.fn.fnamemodify(raw_path, ":h")
			opts.focus_uri = raw_path
			return engine().open(parent, nil, opts)
		else
			-- Move up within archive
			local parent_internal = vim.fn.fnamemodify(internal_part, ":h")
			if parent_internal == "." then parent_internal = "" end
			local target = scheme .. "://" .. slash_prefix .. archive_part:gsub("^/+", "") .. "::" .. parent_internal
			return engine().open(target, nil, opts)
		end
	end

	-- 3. Standard directory navigation
	local p = vim.fn.fnamemodify(s.uri, ":h")
	if p ~= s.uri then
		engine().open(p, nil, opts)
	end
end

function M.toggle_hidden()
	local s = engine().get_state()
	if s then
		s.show_hidden = not s.show_hidden
		s:update()
		renderer.render(s)
	end
end

function M.toggle_full_path()
	local s = engine().get_state()
	if s then
		s.show_full_path = not s.show_full_path
		renderer.render(s)
	end
end

function M.cycle_sort()
	local s = engine().get_state()
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
	local s = engine().get_state()
	if s then
		s.sort_reverse = not s.sort_reverse
		s:update()
		renderer.render(s)
	end
end

function M.cycle_view_mode()
	local s = engine().get_state()
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
	local s = engine().get_state()
	if s then
		s.expanded_nodes = {}
		s:update()
		renderer.render(s)
	end
end

function M.expand_all()
	local state = engine().get_state()
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

return M
