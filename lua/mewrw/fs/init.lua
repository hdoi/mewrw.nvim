local uri_parser = require("mewrw.utils.uri")

local M = {}

-- Load providers in priority order
-- SFTP and Archive should be checked BEFORE Local because Local is a catch-all
local providers = {
	require("mewrw.fs.provider.sftp"),
	require("mewrw.fs.provider.archive"),
	require("mewrw.fs.provider.local"),
}

--- Find the appropriate provider for a given URI
---@param uri string
---@return Provider|nil
local function get_provider(uri)
	-- uri_parser.parse(uri) now returns the last layer of a ::: chain
	for _, p in ipairs(providers) do
		if p.can_handle(uri) then return p end
	end
	return nil
end
--- Internal helper to call provider methods with error handling
local function call_provider(method, uri, ...)
	local args = { ... }
	local cb = args[#args]
	local p = get_provider(uri)
	if not p then
		return cb("No provider found for URI: " .. tostring(uri))
	end
	local ok, err = pcall(p[method], uri, unpack(args))
	if not ok then
		cb("Provider error (" .. p.name .. "): " .. tostring(err))
	end
end

function M.list(uri, cb) call_provider("list", uri, cb) end
function M.read(uri, cb) call_provider("read", uri, cb) end
function M.write(uri, data, cb) call_provider("write", uri, data, cb) end
function M.delete(uri, recursive, cb) call_provider("delete", uri, recursive, cb) end
function M.rename(old_uri, new_uri, cb) call_provider("rename", old_uri, new_uri, cb) end
function M.copy(src_uri, dest_uri, cb) call_provider("copy", src_uri, dest_uri, cb) end
function M.mkdir(uri, cb) call_provider("mkdir", uri, cb) end

return M
