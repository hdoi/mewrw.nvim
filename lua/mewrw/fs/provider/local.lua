local path_utils = require("mewrw.utils.path")

local LocalProvider = {
	name = "local",
}

local function get_path(uri)
	local path = uri:gsub("^file://", "")
	return path_utils.normalize(path)
end

function LocalProvider.can_handle(uri)
	if uri:find(":::", 1, true) then return false end
	local scheme = uri:match("^([%a%d%+%.%-]+)://")
	local is_windows_drive = path_utils.is_windows and scheme and #scheme == 1
	if scheme and not is_windows_drive and scheme ~= "file" then return false end
	return true
end

function LocalProvider.list(uri, cb)
	local path = get_path(uri)
	
	-- Windows: If path is "/", list all VALID drives
	if path_utils.is_windows and path == "/" then
		local drives = {}
		local handle = io.popen("fsutil fsinfo drives")
		if handle then
			local res = handle:read("*a")
			handle:close()
			for d in res:gmatch("(%a):") do 
				local drive_path = d:upper() .. ":/"
				-- Strict check: must be a directory AND stat-able
				if vim.fn.isdirectory(drive_path) == 1 then
					local stat = vim.loop.fs_stat(drive_path)
					if stat then
						table.insert(drives, drive_path)
					end
				end
			end
		end
		-- Fallback to A-Z only if fsutil failed completely
		if #drives == 0 then
			for i = 65, 90 do
				local d = string.char(i) .. ":/"
				if vim.fn.isdirectory(d) == 1 then
					if vim.loop.fs_stat(d) then table.insert(drives, d) end
				end
			end
		end
		
		local entries = {}
		for _, d in ipairs(drives) do
			table.insert(entries, { name = d, path = d, type = "directory", size = 0 })
		end
		return cb(nil, entries)
	end

	local entries = {}
	local handle = vim.loop.fs_scandir(path)
	if not handle then return cb("ENOENT: no such file or directory: " .. path) end

	while true do
		local name, type = vim.loop.fs_scandir_next(handle)
		if not name then break end
		local full_path = path_utils.join(path, name)
		local stat = vim.loop.fs_stat(full_path)
		table.insert(entries, {
			name = name,
			path = full_path,
			type = type or "file",
			size = stat and stat.size or 0,
			mtime = stat and stat.mtime.sec or 0,
		})
	end
	cb(nil, entries)
end

function LocalProvider.read(uri, cb)
	local path = get_path(uri)
	local f = io.open(path, "rb")
	if not f then return cb("Read failed") end
	local data = f:read("*a")
	f:close()
	cb(nil, data)
end

function LocalProvider.write(uri, data, cb)
	local path = get_path(uri)
	local f = io.open(path, "wb")
	if not f then return cb("Write failed") end
	f:write(data); f:close()
	cb(nil)
end

function LocalProvider.delete(uri, recursive, cb)
	local path = get_path(uri)
	vim.fn.delete(path, recursive and "rf" or "")
	cb(nil)
end

function LocalProvider.rename(old_uri, new_uri, cb)
	local old_p, new_p = get_path(old_uri), get_path(new_uri)
	local ok, err = os.rename(old_p, new_p)
	cb(ok and nil or err)
end

function LocalProvider.copy(src_uri, dest_uri, cb)
	LocalProvider.read(src_uri, function(err, d)
		if err then return cb(err) end
		LocalProvider.write(dest_uri, d, cb)
	end)
end

function LocalProvider.mkdir(uri, cb)
	local path = get_path(uri)
	vim.fn.mkdir(path, "p")
	cb(nil)
end

return LocalProvider
