if vim.g.loaded_mewrw then
	return
end
vim.g.loaded_mewrw = 1

local function create_cmd(name, dir)
	vim.api.nvim_create_user_command(name, function(opts)
		local uri = opts.args ~= "" and opts.args or nil
		require("mewrw").open(uri, dir)
	end, {
		nargs = "?",
		complete = "dir",
		desc = string.format("Open mewrw file explorer (%s)", dir or "current"),
	})
end

create_cmd("Mewrw", nil)
create_cmd("MewrwV", "v")
create_cmd("MewrwH", "h")
create_cmd("MewrwT", "t")
