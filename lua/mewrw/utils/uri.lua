local M = {}

--- Parse a single URI layer
local function parse_layer(str)
	local res = {
		scheme = nil,
		user = nil,
		password = nil,
		host = nil,
		port = nil,
		path = nil,
	}

	-- Flexible scheme extraction: support scheme://, scheme:/, or scheme:
	local scheme, rest = str:match("^([^:]+)://(.*)$")
	if not scheme then
		scheme, rest = str:match("^([^:]+):/(.*)$")
	end
	if not scheme then
		scheme, rest = str:match("^([^:]+):(.*)$")
	end
	
	if not scheme then return nil end
	res.scheme = scheme:lower()
	rest = rest or ""

	-- Separate authority and path
	-- Authority is everything before the first single slash
	local authority, path = rest:match("^([^/]*)(/.*)$")
	if not authority then
		authority = rest
		path = ""
	end
	res.path = path

	-- Parse authority: [user[:password]@]host[:port]
	local user_pass, host_port = authority:match("^([^@]+)@(.*)$")
	if not user_pass then
		host_port = authority
	else
		res.user, res.password = user_pass:match("^([^:]+):?(.*)$")
	end

	if host_port ~= "" then
		res.host, res.port = host_port:match("^([^:]+):?(.*)$")
	end
	
	if res.port == "" then res.port = nil end
	if res.host == "" then res.host = nil end

	return res
end

--- Parse a chained URI string (e.g., base:::zip://path)
function M.parse_chain(str)
	if not str or str == "" then return {} end
	local parts = vim.split(str, ":::", { plain = true })
	local chain = {}
	for _, p in ipairs(parts) do
		local parsed = parse_layer(p)
		if parsed then
			table.insert(chain, parsed)
		else
			-- Fallback for local paths or first layer
			table.insert(chain, { scheme = "file", path = p })
		end
	end
	return chain
end

--- Get the last layer's scheme
function M.get_scheme(str)
	local chain = M.parse_chain(str)
	return chain[#chain] and chain[#chain].scheme
end

--- Parse the last layer (backward compatible)
function M.parse(str)
	local chain = M.parse_chain(str)
	return chain[#chain]
end

return M
