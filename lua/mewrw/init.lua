local M = {}

---@alias IconMode "none"|"devicons"|"emoji"

---@class MewrwConfig
---@field default_view_mode? "list"|"detailed"|"tree"
---@field show_hidden? boolean
---@field sort_by? "name"|"numerical"|"size"|"mtime"|"extension"
---@field sort_reverse? boolean
---@field icons? IconMode
---@field git_integration? boolean

---@type MewrwConfig
M.config = {
	default_view_mode = "list",
	show_hidden = false,
	sort_by = "name",
	sort_reverse = false,
	icons = "none",
	git_integration = false,
}

--- Initialize the plugin with user configuration
---@param opts? MewrwConfig
function M.setup(opts)
end

--- Open the file explorer
---@param uri? string
---@param direction? "v"|"h"|"t"
function M.open(uri, direction)
	require("mewrw.core.engine").open(uri, direction)
end

return M
