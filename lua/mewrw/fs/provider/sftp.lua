local M = {
	name = "sftp",
}

--- Parse SFTP URI
---@param uri string sftp://[user@]host[:port]/path
---@return string host_part, string path
local function parse_uri(uri)
	local rest = uri:gsub("^sftp://", "")
	local host_part, path = rest:match("^([^/]+)(/.*)$")
	return host_part or rest, path or "/"
end

function M.can_handle(uri)
	return uri:match("^sftp://") ~= nil
end

--- Execute sftp batch commands
---@param host string
---@param commands string[]
---@param cb fun(err: string|nil, output: string[]|nil)
local function run_batch(host, commands, cb)
	local stdout, stderr = {}, {}
	local job_id = vim.fn.jobstart({ "sftp", "-b", "-", host }, {
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
	local host, path = parse_uri(uri)
	-- base_dir ensures path ends with / for correct joining
	local base_dir = path:gsub("/$", "") .. "/"
	local uri_prefix = "sftp://" .. host
	
	run_batch(host, { 'ls -l "' .. path .. '"' }, function(err, output)
		if err then return cb(err) end
		local entries = {}
		for _, line in ipairs(output) do
			-- Regex to capture: type, size, and name (the last part of the line)
			local type_char, size, full_path_str = line:match("^([db%-l])[rwx%-]+%s+[^%s]+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+[^%s]+%s+[^%s]+%s+[^%s]+%s+(.*)$")
			if full_path_str then
				-- Remote 'ls' might return full path if given full path, extract only the tail name
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
	local host, remote = parse_uri(uri)
	local tmp = vim.fn.tempname()
	run_batch(host, { 'get "' .. remote .. '" "' .. tmp .. '"' }, function(err)
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
	local host, remote = parse_uri(uri)
	local tmp = vim.fn.tempname()
	local f = io.open(tmp, "w")
	if not f then return cb("Write temp failed") end
	f:write(data); f:close()
	run_batch(host, { 'put "' .. tmp .. '" "' .. remote .. '"' }, function(err)
		os.remove(tmp); cb(err)
	end)
end

function M.delete(uri, recursive, cb)
	local host, path = parse_uri(uri)
	run_batch(host, { (recursive and "rmdir " or "rm ") .. '"' .. path .. '"' }, cb)
end

function M.rename(old_uri, new_uri, cb)
	local host, old_p = parse_uri(old_uri)
	local _, new_p = parse_uri(new_uri)
	run_batch(host, { 'rename "' .. old_p .. '" "' .. new_p .. '"' }, cb)
end

function M.mkdir(uri, cb)
	local host, path = parse_uri(uri)
	run_batch(host, { 'mkdir "' .. path .. '"' }, cb)
end

return M
