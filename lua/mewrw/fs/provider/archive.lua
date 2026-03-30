local M = {
	name = "archive",
}

--- Archive URI Specification:
---
--- Format: [scheme]://[archive_path]::[internal_path]
---
--- Elements:
--- - scheme: "zip" or "tar"
--- - archive_path: Path to the archive file on the filesystem.
---   - Absolute (Linux): Starts with /// (e.g., zip:///home/user/test.zip)
---   - Absolute (Windows): Starts with // and drive (e.g., zip://C:/test.zip)
---   - Relative: Starts with // (e.g., zip://../test.zip)
--- - separator: "::" (separates the archive file from the content inside)
--- - internal_path: Relative path inside the archive (e.g., folder/file.txt)
---
--- Examples:
--- - zip:///mnt/c/data.zip::             (Root of absolute Linux path)
--- - zip://D:/work/backup.zip::src/main.c (File inside absolute Windows path)
--- - tar://./build.tar::README.md        (File inside relative path)

--- Parse Archive URI
---@param uri string scheme://archive_path::internal_path
---@return string scheme, string archive_path, string internal_path
local function parse_uri(uri)
	local scheme, rest = uri:match("^([^:]+)://(.*)$")
	if not scheme then return nil, nil, nil end

	-- Normalize absolute path: if it starts with ///, the 'rest' should start with /
	if uri:match("^%a+:///") and not rest:match("^/") then
		rest = "/" .. rest
	end

	-- Find the LAST occurrence of :: to separate archive from internal path
	local archive_path, internal_path = rest:match("^(.*)::(.-)$")
	
	if not archive_path then
		archive_path = rest
		internal_path = ""
	end
	return scheme, archive_path, internal_path
end

function M.can_handle(uri)
	return uri:match("^zip://") ~= nil or uri:match("^tar://") ~= nil
end

function M.list(uri, cb)
	local scheme, archive, internal = parse_uri(uri)
	-- Normalize archive path for internal usage
	local path_utils = require("mewrw.utils.path")
	local norm_archive = path_utils.normalize(archive)
	
	-- Build prefix for entries: ensure consistency between /// and //
	local prefix
	if norm_archive:match("^/") or norm_archive:match("^%a:/") then
		prefix = scheme .. ":///" .. norm_archive:gsub("^/+", "") .. "::"
	else
		prefix = scheme .. "://" .. norm_archive .. "::"
	end
	
	-- Native path for CLI tools
	local abs_archive = vim.fn.fnamemodify(norm_archive, ":p")
	if path_utils.is_windows then
		abs_archive = abs_archive:gsub("/", "\\")
	end

	local cmd
	if scheme == "zip" then
		if vim.fn.executable("unzip") == 1 then
			cmd = { "unzip", "-l", abs_archive }
		else
			cmd = { "tar", "-tf", abs_archive }
		end
	else
		-- Use -a (auto-detect) for compressed tar archives
		cmd = { "tar", "-atvf", abs_archive }
	end

	local stdout = {}
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, d) for _, l in ipairs(d) do if l ~= "" then table.insert(stdout, (l:gsub("\r", ""))) end end end,
		on_exit = function(_, c)
			if c ~= 0 then return cb(scheme .. " failed: " .. c) end
			local entries, found = {}, {}
			for i, line in ipairs(stdout) do
				local size, name, type_char
				if scheme == "zip" and cmd[1] == "unzip" then
					-- unzip -l format:  Length      Date    Time    Name
					if i >= 4 and i <= #stdout - 2 then
						if line:match("^%s*%d+%s+%d+%s+%d+%s+") then
							-- Windows extended format
							size = line:match("^%s*(%d+)")
							name = line:sub(43)
						else
							-- Standard Linux format
							size, name = line:match("%s*(%d+)%s+[%d%-]+%s+[%d:]+%s+(.+)")
						end
					end
				else
					-- Robust tar -tvf parsing
					-- Pattern: [type]perms [owner/group] [size] [date] [time] [name]
					-- Sample: "drwxrwxr-x anoop/anoop       0 2024-02-13 03:51 hmpol-0.1.5/"
					type_char = line:sub(1, 1)
					-- Extract name (everything after HH:MM)
					-- Extract size (the number right before YYYY-MM-DD)
					size, name = line:match("%s+(%d+)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d%s+(.+)$")
					
					if not name then
						-- Simple tar -tf fallback
						name = line:match("^%s*(.-)%s*$")
						size = 0
					end
				end

				if name then
					-- Robust Windows/Unix normalization for internal path
					name = name:gsub("\\", "/"):gsub("^%.[/\\]+", ""):gsub("^/+", "")
				end

				if name and (internal == "" or internal == "/" or name:sub(1, #internal) == internal) then
					local clean_internal = internal:gsub("/+$", "")
					local relative = (clean_internal == "") and name or name:sub(#clean_internal + 1):gsub("^/+", "")
					
					if relative ~= "" then
						local parts = vim.split(relative, "/")
						local entry_name = parts[1]
						local is_dir = #parts > 1 or name:match("/$") or type_char == "d"
						
						if not found[entry_name] then
							found[entry_name] = true
							local entry_internal = (internal ~= "" and (internal:gsub("/+$", "") .. "/") or "") .. entry_name
							table.insert(entries, {
								name = entry_name,
								path = prefix .. entry_internal,
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
	local abs_archive = vim.fn.fnamemodify(archive, ":p")
	if require("mewrw.utils.path").is_windows then
		abs_archive = abs_archive:gsub("/", "\\")
	end

	local cmd
	if scheme == "zip" then
		if vim.fn.executable("unzip") == 1 then
			cmd = { "unzip", "-p", abs_archive, internal }
		else
			cmd = { "tar", "-axf", abs_archive, "-O", internal }
		end
	else
		cmd = { "tar", "-axf", abs_archive, "-O", internal }
	end

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
	local tmp_dir = vim.fn.tempname():gsub("\\", "/")
	vim.fn.mkdir(tmp_dir, "p")
	local tmp_file = tmp_dir .. "/" .. internal
	vim.fn.mkdir(vim.fn.fnamemodify(tmp_file, ":h"), "p")

	local f = io.open(tmp_file, "w")
	if f then f:write(data) f:close() end

	local abs_archive = vim.fn.fnamemodify(archive, ":p"):gsub("\\", "/")
	local cmd = (scheme == "zip" and vim.fn.executable("zip") == 1) and { "zip", abs_archive, internal } or { "tar", "-rf", abs_archive, internal }

	vim.fn.jobstart(cmd, {
		cwd = tmp_dir,
		on_exit = function(_, c)
			vim.fn.delete(tmp_dir, "rf")
			if c == 0 then cb(nil) else cb("Update failed: " .. c) end
		end
	})
end

function M.delete(u, r, cb) cb("Delete not supported for archives") end
function M.rename(o, n, cb) cb("Rename not supported for archives") end
function M.mkdir(u, cb) cb("Mkdir not supported for archives") end

return M
