local M = {
	name = "archive",
}

--- Parse Archive URI
---@param uri string scheme://archive_path::internal_path
---@return string scheme, string archive_path, string internal_path
local function parse_uri(uri)
	local scheme, rest = uri:match("^(%a+)://(.*)$")
	local archive_path, internal_path = rest:match("^(.*)::(.*)$")
	return scheme, archive_path or rest, internal_path or ""
end

function M.can_handle(uri)
	return uri:match("^zip://") ~= nil or uri:match("^tar://") ~= nil
end

function M.list(uri, cb)
	local scheme, archive, internal = parse_uri(uri)
	local prefix = scheme .. "://" .. archive .. "::"
	local cmd = scheme == "zip" and { "unzip", "-l", archive } or { "tar", "-tvf", archive }

	local stdout = {}
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, d) for _, l in ipairs(d) do if l ~= "" then table.insert(stdout, l) end end end,
		on_exit = function(_, c)
			if c ~= 0 then return cb(scheme .. " failed: " .. c) end
			local entries, found = {}, {}
			for i, line in ipairs(stdout) do
				local size, name, type_char
				if scheme == "zip" then
					if i >= 4 and i <= #stdout - 2 then
						size, _, _, name = line:match("%s*(%d+)%s+[%d%-]+%s+[%d:]+%s+(.*)")
					end
				else
					type_char, size, name = line:match("^([db%-l])[rwx%-]+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+[%d%-]+%s+[%d:]+%s+(.*)")
					name = name and name:gsub("^%./", "")
				end

				if name and (internal == "" or name:sub(1, #internal) == internal) then
					local relative = name:sub(#internal + 1):gsub("^/", "")
					if relative ~= "" then
						local parts = vim.split(relative, "/")
						local entry_name = parts[1]
						local is_dir = #parts > 1 or (scheme == "zip" and name:match("/$")) or type_char == "d"
						if not found[entry_name] then
							found[entry_name] = true
							table.insert(entries, {
								name = entry_name,
								path = prefix .. (internal ~= "" and (internal:gsub("/$", "") .. "/") or "") .. entry_name,
								type = is_dir and "directory" or "file",
								size = tonumber(size) or 0,
							})
						end
					end
				end
			end
			cb(nil, entries)
		end
	})
end

function M.read(uri, cb)
	local scheme, archive, internal = parse_uri(uri)
	local cmd = scheme == "zip" and { "unzip", "-p", archive, internal } or { "tar", "-xf", archive, "-O", internal }
	local stdout = {}
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, d) stdout = d end,
		on_exit = function(_, c)
			if c ~= 0 then cb("Extract failed: " .. c) else cb(nil, table.concat(stdout, "\n")) end
		end
	})
end

function M.write(uri, data, cb)
	local scheme, archive, internal = parse_uri(uri)
	internal = internal:gsub("^/", "")
	
	-- Use a more reliable temporary directory
	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, "p")
	local tmp_file = tmp_dir .. "/" .. internal
	vim.fn.mkdir(vim.fn.fnamemodify(tmp_file, ":h"), "p")

	local f = io.open(tmp_file, "w")
	if not f then return cb("Temp file creation failed") end
	f:write(data); f:close()

	local abs_archive = vim.fn.fnamemodify(archive, ":p")
	local cmd = scheme == "zip" and { "zip", abs_archive, internal } or { "tar", "-rf", abs_archive, internal }

	vim.fn.jobstart(cmd, {
		cwd = tmp_dir,
		on_exit = function(_, c)
			vim.fn.delete(tmp_dir, "rf")
			if c == 0 then
				cb(nil)
			else
				cb("Update failed with exit code " .. c)
			end
		end
	})
end

function M.delete(u, r, cb) cb("Delete not supported for archives") end
function M.rename(o, n, cb) cb("Rename not supported for archives") end
function M.mkdir(u, cb) cb("Mkdir not supported for archives") end

return M
