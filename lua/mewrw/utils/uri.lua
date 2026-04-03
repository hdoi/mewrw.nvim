local M = {}

local is_windows = vim.fn.has("win32") == 1

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

	local s = str:gsub("^%s+", ""):gsub("%s+$", "")

	-- 1. Flexible scheme extraction
	local scheme, rest = s:match("^([^:]+)://(.*)$")
	if not scheme then
		scheme, rest = s:match("^([^:]+):/(.*)$")
	end
	if not scheme then
		scheme, rest = s:match("^([^:]+):(.*)$")
	end
	
	-- Windows Guard: Single letter scheme is likely a drive letter, NOT a scheme.
	-- But if it's followed by :// (like c://), we might still treat it as a scheme
	-- depending on the spec. Here we follow URI_spec.md: 1-char is NOT a scheme.
	if scheme and is_windows and #scheme == 1 then
		return nil
	end

	if not scheme then return nil end
	res.scheme = scheme:lower()
	rest = rest or ""

	-- 2. Action-only schemes (zip, tar, etc.)
	if res.scheme == "zip" or res.scheme == "tar" or res.scheme == "7z" or res.scheme == "compress" then
		res.path = rest:match("^/*(.*)$")
		if not res.path:match("^/") then res.path = "/" .. res.path end
		return res
	end

	-- 3. Authority schemes (sftp, file)
	local authority, path = rest:match("^([^/]*)(/.*)$")
	if not authority then
		authority = rest
		path = "/"
	end
	res.path = path

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

--- Parse a chained URI string
function M.parse_chain(str)
	if not str or str == "" then return {} end
	
	local parts = vim.split(str, ":::", { plain = true })
	local chain = {}
	for _, p in ipairs(parts) do
		local trimmed = p:gsub("^%s+", ""):gsub("%s+$", "")
		local parsed = parse_layer(trimmed)
		if parsed then
			table.insert(chain, parsed)
		else
			-- Fallback: treat as raw file path (especially for Windows drives)
			table.insert(chain, { scheme = "file", path = trimmed })
		end
	end
	return chain
end

function M.parse(str)
	local chain = M.parse_chain(str)
	return chain[#chain]
end

return M
