local uri_parser = require("mewrw.utils.uri")

local M = {
	name = "sftp",
}

function M.can_handle(uri)
	local u = uri_parser.parse(uri)
	return u ~= nil and u.scheme == "sftp"
end

--- Execute sftp batch commands
---@param u table Parsed URI components
---@param commands string[]
---@param cb fun(err: string|nil, output: string[]|nil)
local function run_batch(u, commands, cb)
	if not u or not u.host then return cb("Invalid SFTP host") end
	local stdout, stderr = {}, {}
	
	-- Construct host argument correctly: [user@]host
	local host_arg = u.host
	if u.user then host_arg = u.user .. "@" .. u.host end
	
	-- Construct sftp command: handle port if present
	local cmd = { "sftp", "-b", "-" }
	if u.port then
		table.insert(cmd, "-P")
		table.insert(cmd, u.port)
	end
	table.insert(cmd, host_arg)
	
	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, d) for _, l in ipairs(d) do if l ~= "" then table.insert(stdout, l) end end end,
		on_stderr = function(_, d) for _, l in ipairs(d) do if l ~= "" then table.insert(stderr, l) end end end,
		on_exit = function(_, c)
			if c ~= 0 then
				cb(table.concat(stderr, "\n") or "sftp exit " .. c)
			else
				cb(nil, stdout)
			end
		end
	})
	if job_id <= 0 then return cb("Failed to start sftp") end
	vim.fn.chansend(job_id, table.concat(commands, "\n") .. "\nquit\n")
	vim.fn.chanclose(job_id, "stdin")
end

function M.list(uri, cb)
	local u = uri_parser.parse(uri)
	if not u or not u.host then return cb("Invalid SFTP URI: " .. tostring(uri)) end

	-- Ensure path ends with / for correct joining
	local base_dir = u.path:gsub("/$", "") .. "/"
	local uri_prefix = "sftp://" .. (u.user and (u.user .. "@") or "") .. u.host .. (u.port and (":" .. u.port) or "")
	
	run_batch(u, { 'ls -l "' .. u.path .. '"' }, function(err, output)
		if err then return cb(err) end
		local entries = {}
		for _, line in ipairs(output or {}) do
			local type_char, size, full_path_str = line:match("^([db%-l])[rwx%-]+%s+[^%s]+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+[^%s]+%s+[^%s]+%s+[^%s]+%s+(.*)$")
			if full_path_str then
				local name = full_path_str:match("([^/]+)/?$")
				if name and name ~= "." and name ~= ".." then
					table.insert(entries, {
						name = name,
						path = uri_prefix .. base_dir .. name,
						type = (type_char == "d" and "directory" or (type_char == "l" and "link" or "file")),
						size = tonumber(size),
					})
				end
			end
		end
		cb(nil, entries)
	end)
end

function M.read(uri, cb)
	local u = uri_parser.parse(uri)
	if not u or not u.host then return cb("Invalid SFTP URI") end
	local tmp = vim.fn.tempname()
	run_batch(u, { 'get "' .. u.path .. '" "' .. tmp .. '"' }, function(err)
		if err then return cb(err) end
		local f = io.open(tmp, "r")
		if not f then return cb("Read temp failed") end
		local data = f:read("*a")
		f:close()
		os.remove(tmp)
		cb(nil, data)
	end)
end

function M.write(uri, data, cb)
	local u = uri_parser.parse(uri)
	if not u or not u.host then return cb("Invalid SFTP URI") end
	local tmp = vim.fn.tempname()
	local f = io.open(tmp, "w")
	if not f then return cb("Write temp failed") end
	f:write(data); f:close()
	run_batch(u, { 'put "' .. tmp .. '" "' .. u.path .. '"' }, function(err)
		os.remove(tmp); cb(err)
	end)
end

function M.delete(uri, recursive, cb)
	local u = uri_parser.parse(uri)
	if not u or not u.host then return cb("Invalid SFTP URI") end
	run_batch(u, { (recursive and "rmdir " or "rm ") .. '"' .. u.path .. '"' }, cb)
end

function M.rename(old_uri, new_uri, cb)
	local u_old = uri_parser.parse(old_uri)
	local u_new = uri_parser.parse(new_uri)
	if not u_old or not u_new or not u_old.host then return cb("Invalid SFTP URI") end
	run_batch(u_old, { 'rename "' .. u_old.path .. '" "' .. u_new.path .. '"' }, cb)
end

function M.copy(src_uri, dest_uri, cb)
	cb("Copy not supported directly on SFTP")
end

function M.mkdir(uri, cb)
	local u = uri_parser.parse(uri)
	if not u or not u.host then return cb("Invalid SFTP URI") end
	run_batch(u, { 'mkdir "' .. u.path .. '"' }, cb)
end

return M
