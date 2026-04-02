local M = {}

--- Path Normalization Utility
M.is_windows = vim.fn.has("win32") == 1
M.sep = M.is_windows and "\\" or "/"

--- Normalize a single path part (internal helper)
local function normalize_part(p, is_first_layer)
	if not p or p == "" then return "" end
	
	-- 1. Unify separators (backslashes to forward slashes)
	p = p:gsub("\\", "/")

	-- 2. Extract scheme if present (e.g., zip://)
	local scheme, rest = p:match("^([^:]+://)(.*)$")
	if not scheme then
		-- Fallback for scheme:/ or scheme:
		scheme, rest = p:match("^([^:]+:/?)(.*)$")
	end

	if scheme then
		-- Only normalize the 'rest' part to avoid collapsing scheme slashes
		return scheme .. rest:gsub("/+", "/")
	end

	-- 3. If no scheme, it's a local path or raw fragment
	if is_first_layer then
		-- Absolute resolution for local filesystem paths
		if M.is_windows then
			local drive = p:match("^(%a):")
			if drive then
				local r = p:sub(3):gsub("^/+", "")
				p = drive:upper() .. ":/" .. r
			else
				p = vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
			end
		else
			p = vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
		end
	end

	-- 4. Collapse redundant slashes and cleanup trailing junk
	p = p:gsub("/+", "/")
	if p ~= "/" and not (M.is_windows and p:match("^%a:/$")) then
		p = p:gsub("[\\/]%.?%s*$", "")
	end
	
	return p
end

function M.normalize(path)
	if not path or path == "" then return "/" end
	
	-- Split by chain separator (plain text search)
	local parts = vim.split(path, ":::", { plain = true })
	local normalized_parts = {}
	
	for i, part in ipairs(parts) do
		table.insert(normalized_parts, normalize_part(part, i == 1))
	end
	
	local result = table.concat(normalized_parts, ":::")
	if result == "" then return "/" end
	return result
end

function M.join(...)
	local parts = { ... }
	local result = table.concat(parts, "/")
	return M.normalize(result)
end

function M.is_root(path)
	if M.is_windows then
		return path == "/" or path:match("^%a:/$") ~= nil or path:match("^%a::?$") ~= nil
	else
		return path == "/"
	end
end

return M
