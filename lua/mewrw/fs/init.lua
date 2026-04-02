local M = {}

---@class Provider
---@field name string Provider name
---@field can_handle fun(uri: string): boolean Returns true if provider supports URI
---@field list fun(uri: string, cb: fun(err: string|nil, entries: Entry[]|nil)) List directory
---@field read fun(uri: string, cb: fun(err: string|nil, data: string|nil)) Read file
---@field write fun(uri: string, data: string, cb: fun(err: string|nil)) Write file
---@field delete fun(uri: string, recursive: boolean, cb: fun(err: string|nil)) Delete item
---@field rename fun(old_uri: string, new_uri: string, cb: fun(err: string|nil)) Rename item
---@field copy fun(src_uri: string, dest_uri: string, cb: fun(err: string|nil)) Copy item
---@field mkdir fun(uri: string, cb: fun(err: string|nil)) Create directory

local providers = {
	require("mewrw.fs.provider.local"),
	require("mewrw.fs.provider.sftp"),
	require("mewrw.fs.provider.archive"),
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
	if p and p[method] then
		p[method](uri, unpack(args))
	else
		cb("No provider found for URI: " .. uri)
	end
end

function M.list(uri, cb) call_provider("list", uri, cb) end
function M.read(uri, cb) call_provider("read", uri, cb) end
function M.write(uri, data, cb) call_provider("write", uri, data, cb) end
function M.delete(uri, recursive, cb) call_provider("delete", uri, recursive, cb) end
function M.rename(old_uri, new_uri, cb)
	local p = get_provider(old_uri)
	if p then p.rename(old_uri, new_uri, cb) else cb("No provider found for URI: " .. old_uri) end
end
function M.copy(src_uri, dest_uri, cb)
	local p = get_provider(src_uri)
	if p then p.copy(src_uri, dest_uri, cb) else cb("No provider found for URI: " .. src_uri) end
end
function M.mkdir(uri, cb) call_provider("mkdir", uri, cb) end

return M
