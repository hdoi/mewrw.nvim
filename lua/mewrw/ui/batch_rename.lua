local M = {}
local fs = require("mewrw.fs")

local ns_id = vim.api.nvim_create_namespace("mewrw_rename")

---@class RenameItem
---@field old_path string
---@field parent_dir string
---@field old_name string

local rename_items = {}
local original_bufnr = nil

--- Validate the current buffer content
local function validate(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local new_names = {}
	local seen = {}

	-- First pass: count duplicates in the buffer
	for _, name in ipairs(lines) do
		if name ~= "" then
			seen[name] = (seen[name] or 0) + 1
		end
	end

	for i, name in ipairs(lines) do
		if i > #rename_items then break end
		local item = rename_items[i]
		local virt_text = {}

		if name == "" then
			table.insert(virt_text, { " [EMPTY]", "ErrorMsg" })
		elseif name == item.old_name then
			table.insert(virt_text, { " [UNCHANGED]", "Comment" })
		elseif seen[name] > 1 then
			table.insert(virt_text, { " [DUPLICATE]", "WarningMsg" })
		else
			-- Check if file already exists on disk (if name changed)
			local new_path = item.parent_dir .. "/" .. name
			if vim.fn.getftype(new_path) ~= "" then
				table.insert(virt_text, { " [EXISTS ON DISK]", "ErrorMsg" })
			else
				table.insert(virt_text, { " [OK]", "DiagnosticOk" })
			end
		end

		vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
			virt_text = virt_text,
			virt_text_pos = "eol",
		})
	end
end

--- Apply the renames
function M.apply(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if #lines ~= #rename_items then
		return vim.notify("Line count mismatch!", vim.log.levels.ERROR)
	end

	validate(bufnr)
	-- Check if there are any errors by looking at extmarks or re-validating
	-- For simplicity, we'll confirm with the user
	if vim.fn.confirm("Apply these renames?", "&Yes\n&No", 2) ~= 1 then return end

	local count = 0
	local total = 0
	for i, new_name in ipairs(lines) do
		local item = rename_items[i]
		if new_name ~= "" and new_name ~= item.old_name then
			total = total + 1
			local new_path = item.parent_dir .. "/" .. new_name
			fs.rename(item.old_path, new_path, function(err)
				vim.schedule(function()
					count = count + 1
					if not err then
						local engine = require("mewrw.core.engine")
						local marks = engine.get_global_marks()
						if marks[item.old_path] then
							marks[item.old_path] = nil
							marks[new_path] = true
						end
					else
						vim.notify("Error renaming " .. item.old_name .. ": " .. err, vim.log.levels.ERROR)
					end

					if count == total then
						vim.notify("Batch rename completed: " .. total .. " items processed")
						vim.api.nvim_buf_delete(bufnr, { force = true })
						if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
							vim.api.nvim_set_current_buf(original_bufnr)
							require("mewrw.core.engine").open()
						end
					end
				end)
			end)
		end
	end

	if total == 0 then
		vim.notify("No changes to apply")
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
end

function M.open(items, source_buf)
	-- Sort items by full path to ensure consistent order
	table.sort(items)

	rename_items = {}
	original_bufnr = source_buf
	local display_names = {}

	for _, path in ipairs(items) do
		local name = vim.fn.fnamemodify(path, ":t")
		local parent = vim.fn.fnamemodify(path, ":h"):gsub("/$", "")
		table.insert(rename_items, { old_path = path, old_name = name, parent_dir = parent })
		table.insert(display_names, name)
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	-- Use a unique name by appending the buffer number
	local bufname = "mewrw://batch-rename/" .. bufnr
	vim.api.nvim_buf_set_name(bufnr, bufname)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "mewrw_rename")
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_names)

	-- Open in a split
	vim.cmd("split")
	vim.api.nvim_set_current_buf(bufnr)

	-- Auto-validate on changes
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function() validate(bufnr) end,
	})

	-- Apply on save
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		callback = function() M.apply(bufnr) end,
		noremap = true, silent = true, desc = "Apply Renames"
	})
	vim.keymap.set("n", "q", ":q!<CR>", { buffer = bufnr, silent = true })

	validate(bufnr)
	vim.notify("Edit names and press <CR> to apply. 'q' to cancel.")
end

return M
