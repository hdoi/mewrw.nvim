local uv = vim.loop

---@type Provider
local LocalProvider = {
	name = "local",
}

local is_windows = vim.fn.has("win32") == 1
local sep = is_windows and "\\" or "/"

--- Join path components
local function join_path(base, name)
	if base == "/" or (is_windows and base:match("^%a:[\\/]?$")) then
		return base:gsub("[\\/]$", "") .. sep .. name
	end
	return base:gsub("[\\/]$", "") .. sep .. name
end

--- Get absolute filesystem path from URI
local function get_path(uri)
	local path = uri:gsub("^file://", "")
	if is_windows and path:match("^/[%a]:") then
		path = path:sub(2)
	end
	path = vim.fn.fnamemodify(path, ":p")
	if path ~= "/" and not (is_windows and path:match("^%a:[\\/]?$")) then
		path = path:gsub("[\\/]$", "")
	end
    -- print("LocalProvider get_path: '" .. uri .. "' -> '" .. path .. "'")
	return path
end

function LocalProvider.can_handle(uri)
	return not uri:match("^%a+://") or uri:match("^file://")
end

function LocalProvider.list(uri, cb)
	local path = get_path(uri)
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
					local cmd = is_windows and { "cmd.exe", "/c", "rmdir", "/s", "/q", path } or { "rm", "-rf", path }
					vim.fn.jobstart(cmd, { on_exit = function(_, c) cb(c == 0 and nil or "Delete failed") end })
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
				local cmd = is_windows and { "xcopy", "/e", "/i", "/y", src, dest } or { "cp", "-r", src, dest }
				vim.fn.jobstart(cmd, { on_exit = function(_, c) cb(c == 0 and nil or "Copy failed") end })
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
