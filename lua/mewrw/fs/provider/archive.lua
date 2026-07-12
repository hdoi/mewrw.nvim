local uri_parser = require("mewrw.utils.uri")
local path_utils = require("mewrw.utils.path")

local M = {
	name = "archive",
}

function M.can_handle(uri)
	local u = uri_parser.parse(uri)
	if not u then return false end
	local s = u.scheme
	return s == "zip" or s == "tar" or s == "7z" or s == "compress"
end

--- Normalize an archive-internal path to have NO leading slash and NO trailing slash.
--- e.g. "/foo/bar/" -> "foo/bar"
local function normalize_internal(p)
	return (p or ""):gsub("\\", "/"):gsub("^/+", ""):gsub("/+$", "")
end

--- Return {cmd, internal_path} for a given chain + action ("list" | "read").
--- internal_path is always slash-separated with no leading slash.
local function get_archive_cmd(chain, action)
	local layer = chain[#chain]
	local base  = chain[#chain - 1]
	local scheme   = layer.scheme
	-- layer.path may start with "/" per uri.lua normalisation; strip it
	local internal = normalize_internal(layer.path)

	local archive_path = base and base.path or ""
	local is_remote    = base and base.scheme == "sftp"

	local cmd = {}
	if is_remote then
		-- Build SSH wrapper command
		cmd = { "ssh" }
		if base.port then
			table.insert(cmd, "-p")
			table.insert(cmd, base.port)
		end
		table.insert(cmd, (base.user and base.user .. "@" or "") .. base.host)

		local inner_cmd
		if action == "list" then
			if scheme == "zip" then
				inner_cmd = "unzip -l " .. vim.fn.shellescape(archive_path)
			else
				inner_cmd = "tar -tvf " .. vim.fn.shellescape(archive_path)
			end
		else
			if scheme == "zip" then
				inner_cmd = "unzip -p " .. vim.fn.shellescape(archive_path)
				              .. " " .. vim.fn.shellescape(internal)
			else
				inner_cmd = "tar -axf " .. vim.fn.shellescape(archive_path)
				              .. " -O " .. vim.fn.shellescape(internal)
			end
		end
		table.insert(cmd, inner_cmd)
	else
		-- Local path: resolve to absolute and normalise separators.
		-- Always use forward slashes for zip/tar/7z tools on every platform.
		local abs_path = archive_path
		if not abs_path:match("^%a+://") then
			abs_path = vim.fn.fnamemodify(abs_path, ":p"):gsub("\\", "/")
		end
		-- On Windows a leading "/" before the drive letter may appear after
		-- fnamemodify (e.g. "/C:/foo"); strip it.
		if path_utils.is_windows and abs_path:match("^/%a:/") then
			abs_path = abs_path:sub(2)
		end

		if action == "list" then
			if scheme == "7z" then
				cmd = { "7z", "l", abs_path }
			elseif scheme == "zip" and vim.fn.executable("unzip") == 1 then
				cmd = { "unzip", "-l", abs_path }
			elseif scheme == "zip" then
				-- Fallback: use tar to list zip (requires GNU tar with zip support)
				cmd = { "tar", "-tf", abs_path }
			else
				cmd = { "tar", "-tvf", abs_path }
			end
		else -- read
			if scheme == "7z" then
				cmd = { "7z", "x", abs_path, "-so", internal }
			elseif scheme == "zip" and vim.fn.executable("unzip") == 1 then
				-- unzip -p always uses forward-slashes for the member name
				cmd = { "unzip", "-p", abs_path, internal }
			else
				cmd = { "tar", "-axf", abs_path, "-O", internal }
			end
		end
	end
	return cmd, internal
end

--- Parse a single line from "unzip -l" output.
--- Returns name (string) or nil.
-- unzip -l format:
--   Archive:  foo.zip
--   Length      Date    Time    Name
-- ---------  ---------- -----   ----
--    13  2024-02-13 12:00   content.txt
-- ---------                     -------
--  N files
local function parse_unzip_list_line(line)
	-- Skip header / separator / footer lines
	if line:match("^Archive:") then return nil end
	if line:match("^%s*Length") then return nil end
	if line:match("^%s*[-]+%s") then return nil end
	if line:match("%d+%s+files?$") then return nil end

	-- Standard unzip -l data line (flexible whitespace):
	-- <size>  <date>  <time>  <name>
	local name = line:match("^%s*%d+%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d%s+(.+)$")
	if name then return name:gsub("%s+$", "") end

	-- Legacy unzip -l (MS-DOS format): <size>  <date>  <time>  <name>
	name = line:match("^%s*%d+%s+%d+%-%d+%-%d+%s+%d+:%d+%s+(.+)$")
	if name then return name:gsub("%s+$", "") end

	return nil
end

--- Parse a single line from "tar -tvf" output.
--- Returns type_char (string) and name (string), or nils.
local function parse_tar_list_line(line)
	if not line:match("^[%-dbcl]") then return nil, nil end
	local type_char = line:sub(1, 1)
	local parts = vim.split(line, "%s+")
	local name = parts[#parts]
	if name == "" then name = parts[#parts - 1] end
	local size = parts[5]
	return type_char, name, size
end

--- Parse a single line from "7z l" output.
--- Returns type_char, name, size or nils.
local function parse_7z_list_line(line)
	if not line:match("^%d%d%d%d%-%d%d%-%d%d") then return nil, nil, nil end
	local size, name = line:match(
		"%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%s+[^%s]+%s+(%d+)%s+[^%s]+%s+(.+)$"
	)
	local type_char = line:match("%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%s+D") and "d" or "-"
	return type_char, name, size
end

function M.list(uri, cb)
	local chain = uri_parser.parse_chain(uri)
	if #chain < 1 then return cb("Invalid Archive URI") end

	local layer = chain[#chain]

	-- compress:// is a pseudo-scheme wrapping a single compressed file.
	if layer.scheme == "compress" then
		local internal = normalize_internal(layer.path)
		if internal == "" then
			local base = chain[#chain - 1]
			local archive_path = base and base.path or "archive"
			local name = vim.fn.fnamemodify(archive_path, ":t")
				:gsub("%.[gx]z$", ""):gsub("%.bz2$", "")
			local prefix = uri:gsub("/+$", "") .. "/"
			return cb(nil, {{
				name = name,
				path = prefix .. name,
				type = "file",
				size = 0,
			}})
		else
			return cb(nil, {})
		end
	end

	local cmd, internal = get_archive_cmd(chain, "list")
	-- internal has no leading slash; this is the directory we are listing
	local target_dir = internal

	-- Rebuild the URI prefix: everything up to the last layer's scheme://
	local parts = vim.split(uri, ":::", { plain = true })
	if #parts > 0 then
		parts[#parts] = layer.scheme .. "://"
	end
	local prefix = table.concat(parts, ":::")

	local stdout = {}
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, d)
			for _, l in ipairs(d) do
				if l ~= "" then
					-- Wrap gsub in () to discard the second return value (count)
					-- otherwise table.insert would receive 3 args (t, pos, val)
					table.insert(stdout, (l:gsub("\r", "")))
				end
			end
		end,
		on_exit = function(_, c)
			if c ~= 0 then return cb(layer.scheme .. " command failed (exit " .. c .. ")") end

			local entries, found = {}, {}

			for _, line in ipairs(stdout) do
				local name, size, type_char

				if layer.scheme == "zip" and (cmd[1] == "unzip" or cmd[1] == "ssh") then
					name = parse_unzip_list_line(line)
					-- unzip -l does not give type_char; detect dirs by trailing /
				elseif layer.scheme == "7z" then
					type_char, name, size = parse_7z_list_line(line)
				elseif layer.scheme == "tar" or layer.scheme == "compress" then
					type_char, name, size = parse_tar_list_line(line)
				else
					-- Fallback: tar-style for unknown schemes
					type_char, name, size = parse_tar_list_line(line)
				end

				if name then
					-- Normalise the entry name: no backslashes, no leading ./ or /
					name = name:gsub("\\", "/"):gsub("^%.[/\\]+", ""):gsub("^/+", ""):gsub("%s+$", "")
					local clean_name = name:gsub("/+$", "")

					if clean_name == "" then goto continue end

					local is_match  = false
					local relative  = ""

					if target_dir == "" then
						is_match = true
						relative = name
					elseif clean_name:sub(1, #target_dir) == target_dir then
						local next_char = name:sub(#target_dir + 1, #target_dir + 1)
						if next_char == "/" or next_char == "" then
							is_match = true
							relative = name:sub(#target_dir + 1):gsub("^/+", "")
						end
					end

					if is_match and relative ~= "" then
						local parts_rel  = vim.split(relative, "/")
						local entry_name = parts_rel[1]
						local is_dir     = #parts_rel > 1
						                   or name:match("/$")
						                   or type_char == "d"

						if not found[entry_name] then
							found[entry_name] = true
							local full_internal = (target_dir ~= "" and (target_dir .. "/") or "") .. entry_name
							table.insert(entries, {
								name = entry_name,
								path = prefix .. full_internal .. (is_dir and "/" or ""),
								type = is_dir and "directory" or "file",
								size = tonumber(size) or 0,
							})
						end
					end

					::continue::
				end
			end

			cb(nil, entries)
		end,
	})
end

function M.read(uri, cb)
	local chain = uri_parser.parse_chain(uri)
	local cmd, _ = get_archive_cmd(chain, "read")
	local stdout = {}
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, d) stdout = d end,
		on_exit = function(_, c)
			if c ~= 0 then
				cb("Read failed (exit " .. c .. ")")
			else
				cb(nil, table.concat(stdout, "\n"))
			end
		end,
	})
end

function M.write(uri, data, cb)
	cb("Write not supported for chained URIs yet")
end

function M.delete(u, r, cb) cb("Delete not supported for archives") end
function M.rename(o, n, cb) cb("Rename not supported for archives") end
function M.mkdir(u, cb)    cb("Mkdir not supported for archives") end

return M
