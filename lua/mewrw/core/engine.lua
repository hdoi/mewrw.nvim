local fs = require("mewrw.fs")
local State = require("mewrw.core.state")
local path_utils = require("mewrw.utils.path")
local async = require("mewrw.utils.async")

local M = {}

local HEADER_OFFSET = 5
local all_states = {}
local global_target_uri = nil
local global_marks = {}

function M.get_state()
	local bufnr = vim.api.nvim_get_current_buf()
	local id = vim.b[bufnr] and vim.b[bufnr].mewrw_state_id
	return all_states[id]
end

function M.get_global_target() return global_target_uri end
function M.set_global_target(uri) global_target_uri = uri end
function M.get_global_marks() return global_marks end
function M.clear_global_marks() global_marks = {} end

function M.get_entry(line)
	local state = M.get_state()
	if not state then return nil end
	line = line or vim.api.nvim_win_get_cursor(0)[1]
	return state.filtered_entries[line - HEADER_OFFSET]
end

function M.render_all()
	for _, s in pairs(all_states) do require("mewrw.ui.renderer").render(s) end
end

-- Aliases for navigation/operations
function M.open_filter(...) return require("mewrw.core.navigation").open_filter(...) end
function M.open_under_cursor(...) return require("mewrw.core.navigation").open_under_cursor(...) end
function M.open_external(...) return require("mewrw.core.navigation").open_external(...) end
function M.up_directory(...) return require("mewrw.core.navigation").up_directory(...) end
function M.toggle_hidden(...) return require("mewrw.core.navigation").toggle_hidden(...) end
function M.toggle_full_path(...) return require("mewrw.core.navigation").toggle_full_path(...) end
function M.cycle_sort(...) return require("mewrw.core.navigation").cycle_sort(...) end
function M.toggle_sort_reverse(...) return require("mewrw.core.navigation").toggle_sort_reverse(...) end
function M.cycle_view_mode(...) return require("mewrw.core.navigation").cycle_view_mode(...) end
function M.collapse_all(...) return require("mewrw.core.navigation").collapse_all(...) end
function M.expand_all(...) return require("mewrw.core.navigation").expand_all(...) end
function M.add_bookmark(...) return require("mewrw.core.operations").add_bookmark(...) end
function M.list_bookmarks(...) return require("mewrw.core.operations").list_bookmarks(...) end
function M.remove_bookmark(...) return require("mewrw.core.operations").remove_bookmark(...) end
function M.clear_bookmarks_for_test() return require("mewrw.core.bookmarks").clear_for_test() end
function M.set_target(...) return require("mewrw.core.operations").set_target(...) end
function M.toggle_mark(...) return require("mewrw.core.operations").toggle_mark(...) end
function M.clear_marks(...) return require("mewrw.core.operations").clear_marks(...) end
function M.show_marked_items(...) return require("mewrw.core.operations").show_marked_items(...) end
function M.delete_under_cursor(...) return require("mewrw.core.operations").delete_under_cursor(...) end
function M.bulk_action(...) return require("mewrw.core.operations").bulk_action(...) end
function M.rename_under_cursor(...) return require("mewrw.core.operations").rename_under_cursor(...) end
function M.batch_rename(...) return require("mewrw.core.operations").batch_rename(...) end
function M.create_directory(...) return require("mewrw.core.operations").create_directory(...) end
function M.show_help() return require("mewrw.ui.help").show() end

local function setup_autocmds(bufnr, state)
	vim.api.nvim_create_autocmd("BufWinEnter", {
		buffer = bufnr,
		callback = function()
			local wins = vim.fn.win_findbuf(bufnr)
			if #wins > 1 then vim.schedule(function() M.open(state.uri) end) end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", { buffer = bufnr, callback = function() all_states[bufnr] = nil end })
end

--- Core: Open a URI.
--- Performs check first, then creates buffer only on success.
function M.open(uri, direction, opts)
	opts = opts or {}

	local target_uri = uri
	if not target_uri then
		local bufname = vim.api.nvim_buf_get_name(0)
		if bufname ~= "" and vim.bo.buftype == "" then
			target_uri = vim.fn.fnamemodify(bufname, ":p:h")
		end
	end

	target_uri = target_uri or (M.get_state() and M.get_state().uri) or vim.fn.getcwd()

	-- Normalize everything via path_utils (it now handles schemes correctly)
	target_uri = path_utils.normalize(target_uri)

	-- Pre-check access
	fs.list(target_uri, async.ui_cb(function(err, entries)
		if err then
			vim.notify("Error: " .. tostring(err), vim.log.levels.ERROR)
			-- Do nothing else, keep current buffer
			return
		end

		-- Success: Create buffer and set state
		if direction == "v" then vim.cmd("rightbelow vsplit")
		elseif direction == "h" then vim.cmd("split")
		elseif direction == "t" then vim.cmd("tabnew") end

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)

		local state = State.new(bufnr, opts)
		all_states[bufnr] = state
		vim.b[bufnr].mewrw_state_id = bufnr
		require("mewrw.ui.renderer").setup_buffer(bufnr)
		setup_autocmds(bufnr, state)

		state:update(target_uri, entries, opts.expanded_nodes)
		require("mewrw.ui.renderer").render(state)

		if vim.api.nvim_buf_is_valid(bufnr) then
			local target_line = 6
			local focus_uri = opts.focus_uri or opts.prev_uri
			if focus_uri then
				local nf = path_utils.normalize(focus_uri)
				for i, e in ipairs(state.filtered_entries) do
					if path_utils.normalize(e.path) == nf then target_line = i + HEADER_OFFSET; break end
				end
			end
			pcall(vim.api.nvim_win_set_cursor, 0, { math.min(target_line, vim.api.nvim_buf_line_count(bufnr)), 0 })
		end

		if require("mewrw").config.git_integration and not target_uri:match("^%a+://") then
			require("mewrw.core.git").get_info(target_uri, async.ui_cb(function(_, branch, statuses)
				if branch or statuses then
					state.git_branch, state.git_status = branch, statuses
					require("mewrw.ui.renderer").render(state)
				end
			end))
		end
	end))
end

return M
