local M = {}

M.is_windows = vim.fn.has("win32") == 1
M.sep = M.is_windows and "\\" or "/"

--- Normalize path slashes and remove trailing dots/slashes
--- Always returns forward slashes internally for consistency.
---@param path string
---@return string
function M.normalize(path)
	if not path or path == "" then return "/" end

	-- 1. If it has a scheme, only clean up redundant slashes in the path part
	if path:match("^%a+://") then
		local scheme, rest = path:match("^([^:]+://)(.*)$")
		-- Collapse slashes in 'rest', but be careful about UNC or absolute start
		local is_abs = rest:match("^/")
		local cleaned = rest:gsub("/+", "/")
		if is_abs and not cleaned:match("^/") then cleaned = "/" .. cleaned end
		return scheme .. cleaned
	end

	-- 2. Trim leading/trailing whitespace and convert backslashes
	local p = path:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")

	-- 6. Collapse multiple slashes but preserve leading // for UNC paths
	local is_unc = p:match("^//") ~= nil
	p = p:gsub("/+", "/")
	if is_unc then p = "/" .. p end

	-- 7. On Windows, strip leading slash if followed by a drive letter (e.g., "/C:/")
	if M.is_windows then
		p = p:gsub("^/(%a:/)", "%1")
	end

	-- 8. Handle already absolute Windows paths to prevent double normalization
	local is_abs_win = M.is_windows and p:match("^%a:/") ~= nil

	if not is_abs_win then
		p = vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
		p = p:gsub("/+", "/")
	end

	-- 9. Aggressively remove trailing slashes, dots, and trailing spaces
	if M.is_windows then
		if p == "/" then return "/" end
		if p:match("^%a:/$") then return p end
		
		p = p:gsub("[\\/]%.?%s*$", "")
		
		if p == "" or p:match("^%a:$") then
			local drive = p:match("^%a:") or "C:"
			return drive .. "/"
		end
	else
		if p == "/" then return "/" end
		p = p:gsub("[\\/]%.?%s*$", "")
		if p == "" then return "/" end
	end

	return p
end

--- Join path components and normalize the result
---@param ... string
---@return string
function M.join(...)
	local parts = { ... }
	local result = table.concat(parts, "/")
	return M.normalize(result)
end

--- Check if a path is a filesystem root
---@param path string
---@return boolean
function M.is_root(path)
	if M.is_windows then
		return path == "/" or path:match("^%a:/$") ~= nil or path:match("^%a::?$") ~= nil
	else
		return path == "/"
	end
end

return M
