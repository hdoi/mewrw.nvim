local M = {}

--- Wrap a callback to ensure it runs on the Neovim UI thread (main loop)
---@param cb fun(...)
---@return fun(...)
function M.ui_cb(cb)
	return function(...)
		local args = { ... }
		vim.schedule(function()
			cb(unpack(args))
		end)
	end
end

return M
