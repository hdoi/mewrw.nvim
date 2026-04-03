local M = {}

--- Path Normalization Utility
M.is_windows = vim.fn.has("win32") == 1
M.sep = M.is_windows and "\\" or "/"

local function normalize_part(p, is_first_layer)
	if not p or p == "" then return "/" end
	if p == "/" then return "/" end
	
	p = p:gsub("\\", "/")

	local scheme = p:match("^([%a%d%+%.%-]+)://")
	local is_windows_drive = M.is_windows and scheme and #scheme == 1
	
	if scheme and not is_windows_drive then
		local s, rest = p:match("^([^:]+://)(.*)$")
		return s .. rest:gsub("/+", "/")
	end

	if is_first_layer then
		if M.is_windows then
			local drive, rest = p:match("^/?(%a):(.*)$")
			if drive then
				p = drive:upper() .. ":" .. rest:gsub("^/+", "/")
			else
				p = vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
			end
		else
			p = vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
		end
	end

	p = p:gsub("/+", "/")
	if p ~= "/" and not (M.is_windows and p:match("^%a:/$")) then
		p = p:gsub("[\\/]%.?%s*$", "")
	end
	
	if M.is_windows and p:match("^/%a:/") then
		p = p:sub(2)
	end

	-- 4. Collapse redundant slashes and cleanup trailing junk
	p = p:gsub("/+", "/")
	if p ~= "/" and not (M.is_windows and p:match("^%a:/$")) then
		p = p:gsub("[\\/]%.?%s*$", "")
	end
	
	return p
end

function M.normalize(path)
	if not path or path == "" or path == "/" then return "/" end
	
	local parts = vim.split(path, ":::", { plain = true })
	local normalized_parts = {}
	for i, part in ipairs(parts) do
		local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
		table.insert(normalized_parts, normalize_part(trimmed, i == 1))
	end
	local result = table.concat(normalized_parts, ":::")
	
	if M.is_windows and _G.mewrw_debug then
		print(string.format("[DEBUG] path.normalize: '%s' -> '%s'", path, result))
	end
	
	return result
end

function M.join(...)
	local parts = { ... }
	local result = table.concat(parts, "/")
	return M.normalize(result)
end

function M.is_root(path)
	if M.is_windows then
		if path:find(":::") then return false end
		return path == "/" or path:match("^%a:/$") ~= nil
	else
		return path == "/"
	end
end

return M
