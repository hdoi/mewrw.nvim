local uv = vim.loop

local path_utils = require("mewrw.utils.path")

---@type Provider
local LocalProvider = {
	name = "local",
}

--- Join path components
local function join_path(base, name)
	return path_utils.join(base, name)
end

--- Get absolute filesystem path from URI
local function get_path(uri)
	local path = uri:gsub("^file://", "")
	return path_utils.normalize(path)
end

function LocalProvider.can_handle(uri)
	-- Only handle local paths (no scheme) or explicit file://
	return not uri:match("^%a+://") or uri:match("^file://")
end

function LocalProvider.list(uri, cb)
	local path = get_path(uri)

	-- Windows virtual root: list drives
	if path_utils.is_windows and path == "/" then
		local stdout = {}
		vim.fn.jobstart({ "powershell.exe", "-NoProfile", "-Command", "[System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady } | Select-Object -ExpandProperty Name" }, {
			stdout_buffered = true,
			on_stdout = function(_, d) stdout = d end,
			on_exit = function(_, c)
				if c ~= 0 then return cb("Failed to list drives") end
				local entries = {}
				for _, line in ipairs(stdout) do
					-- Just look for any sequence of [Letter]: in the line
					local drive = line:match("(%a:)")
					if drive then
						table.insert(entries, {
							name = drive .. "/",
							path = drive .. "/",
							type = "directory",
						})
					end
				end
				cb(nil, entries)
			end
		})
		return
	end

	uv.fs_scandir(path, function(err, iter)
		if err then return cb(err) end

		local entries = {}
		local function process_next()
			local name, type = uv.fs_scandir_next(iter)
			if not name then return cb(nil, entries) end

			local entry_path = join_path(path, name)
			uv.fs_stat(entry_path, function(stat_err, stat)
				table.insert(entries, {
					name = name,
					path = entry_path,
					type = type or "other",
					size = stat and stat.size,
					mtime = stat and stat.mtime.sec,
				})
				process_next()
			end)
		end
		process_next()
	end)
end

function LocalProvider.read(uri, cb)
	local path = get_path(uri)
	uv.fs_open(path, "r", 438, function(err, fd)
		if err then return cb(err) end
		uv.fs_fstat(fd, function(stat_err, stat)
			if stat_err then
				uv.fs_close(fd)
				return cb(stat_err)
			end
			uv.fs_read(fd, stat.size, 0, function(read_err, data)
				uv.fs_close(fd)
				cb(read_err, data)
			end)
		end)
	end)
end

function LocalProvider.write(uri, data, cb)
	local path = get_path(uri)
	uv.fs_open(path, "w", 438, function(err, fd)
		if err then return cb(err) end
		uv.fs_write(fd, data, 0, function(write_err)
			uv.fs_close(fd)
			cb(write_err)
		end)
	end)
end

function LocalProvider.delete(uri, recursive, cb)
	local path = get_path(uri)
	uv.fs_stat(path, function(err, stat)
		if err then return cb(err) end
		if stat.type == "directory" then
			if recursive then
				vim.schedule(function()
					local cmd = path_utils.is_windows 
						and { "cmd.exe", "/c", "rmdir", "/s", "/q", path:gsub("/", "\\") } 
						or { "rm", "-rf", path }
					vim.fn.jobstart(cmd, { on_exit = function(_, c) if c == 0 then cb(nil) else cb("Delete failed") end end })
				end)
			else
				uv.fs_rmdir(path, cb)
			end
		else
			uv.fs_unlink(path, cb)
		end
	end)
end

function LocalProvider.rename(old_uri, new_uri, cb)
	uv.fs_rename(get_path(old_uri), get_path(new_uri), cb)
end

function LocalProvider.copy(src_uri, dest_uri, cb)
	local src, dest = get_path(src_uri), get_path(dest_uri)
	uv.fs_stat(src, function(err, stat)
		if err then return cb(err) end
		if stat.type == "directory" then
			vim.schedule(function()
				local cmd = path_utils.is_windows 
					and { "cmd.exe", "/c", "xcopy", "/e", "/i", "/y", src:gsub("/", "\\"), dest:gsub("/", "\\") } 
					or { "cp", "-r", src, dest }
				vim.fn.jobstart(cmd, { on_exit = function(_, c) if c == 0 then cb(nil) else cb("Copy failed") end end })
			end)
		else
			uv.fs_copyfile(src, dest, nil, cb)
		end
	end)
end

function LocalProvider.mkdir(uri, cb)
	uv.fs_mkdir(get_path(uri), 493, cb)
end

return LocalProvider
