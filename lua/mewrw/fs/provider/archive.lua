local uri_parser = require("mewrw.utils.uri")

local M = {
	name = "archive",
}

function M.can_handle(uri)
	local u = uri_parser.parse(uri)
	if not u then return false end
	local s = u.scheme
	return s == "zip" or s == "tar" or s == "7z" or s == "compress"
end

--- Get command to run on archive
local function get_archive_cmd(chain, action)
	local layer = chain[#chain]
	local base = chain[#chain - 1]
	local scheme = layer.scheme
	local internal = layer.path:gsub("^/+", "")
	
	local archive_path = base and base.path or ""
	local is_remote = base and base.scheme == "sftp"
	
	local cmd = {}
	if is_remote then
		cmd = { "ssh" }
		if base.port then table.insert(cmd, "-p") table.insert(cmd, base.port) end
		table.insert(cmd, (base.user and base.user .. "@" or "") .. base.host)
		
		local inner_cmd = ""
		if action == "list" then
			if scheme == "zip" then inner_cmd = "unzip -l " .. vim.fn.shellescape(archive_path)
			else inner_cmd = "tar -atvf " .. vim.fn.shellescape(archive_path) end
		else -- read
			if scheme == "zip" then inner_cmd = "unzip -p " .. vim.fn.shellescape(archive_path) .. " " .. vim.fn.shellescape(internal)
			else inner_cmd = "tar -axf " .. vim.fn.shellescape(archive_path) .. " -O " .. vim.fn.shellescape(internal) end
		end
		table.insert(cmd, inner_cmd)
	else
		local abs_path = vim.fn.fnamemodify(archive_path, ":p")
		if require("mewrw.utils.path").is_windows then abs_path = abs_path:gsub("/", "\\") end
		if action == "list" then
			if scheme == "7z" then cmd = { "7z", "l", abs_path }
			elseif scheme == "zip" and vim.fn.executable("unzip") == 1 then cmd = { "unzip", "-l", abs_path }
			elseif scheme == "zip" then cmd = { "tar", "-tf", abs_path }
			else cmd = { "tar", "-atvf", abs_path } end
		else -- read
			if scheme == "7z" then cmd = { "7z", "x", abs_path, "-so", internal }
			elseif scheme == "zip" and vim.fn.executable("unzip") == 1 then cmd = { "unzip", "-p", abs_path, internal }
			else cmd = { "tar", "-axf", abs_path, "-O", internal } end
		end
	end
	return cmd, internal
end

function M.list(uri, cb)
	local chain = uri_parser.parse_chain(uri)
	if #chain < 1 then return cb("Invalid Archive URI") end
	
	local layer = chain[#chain]
	local cmd, internal = get_archive_cmd(chain, "list")
	-- Standardize internal: remove leading/trailing slashes for easier comparison
	local target_dir = internal:gsub("^/+", ""):gsub("/+$", "")
	local prefix = uri:gsub("/+$", ""):gsub("::.*$", "::")

	local stdout = {}
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, d) for _, l in ipairs(d) do if l ~= "" then table.insert(stdout, (l:gsub("\r", ""))) end end end,
		on_exit = function(_, c)
			if c ~= 0 then return cb(layer.scheme .. " failed: " .. c) end
			local entries, found = {}, {}
			for _, line in ipairs(stdout) do
				local size, name, type_char
				
				if line:match("^Archive:") or line:match("^%s*Length") or line:match("^%s*[-]+%s+") or line:match("^%s*%d+%s+files?$") then
					-- Skip header
				elseif layer.scheme == "7z" then
					if line:match("^%d%d%d%d%-%d%d%-%d%d") then
						size, name = line:match("%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%s+[^%s]+%s+(%d+)%s+[^%s]+%s+(.+)$")
						type_char = line:match("%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d%s+D") and "d" or "-"
					end
				elseif layer.scheme == "zip" then
					if line:match("^%s*%d+%s+") then
						if line:match("^%s*%d+%s+%d+%s+%d+%s+") then
							size = line:match("^%s*(%d+)")
							name = line:sub(43)
						else
							size, name = line:match("%s*(%d+)%s+[%d%-]+%s+[%d:]+%s+(.+)")
						end
					end
				elseif line:match("^[%-dbcl]") then
					type_char = line:sub(1, 1)
					size, name = line:match("%s+(%d+)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d%s+(.+)$")
					if not name then name = line:match("^%s*(.-)%s*$") size = 0 end
				end

				if name then
					name = name:gsub("\\", "/"):gsub("^%.[/\\]+", ""):gsub("^/+", ""):gsub("%s+$", "")
					local clean_name = name:gsub("/+$", "")
					
					-- Hierarchical check:
					-- 1. If target_dir is empty, we are at root.
					-- 2. If target_dir matches start of clean_name, we are potentially inside.
					local is_match = false
					local relative = ""
					if target_dir == "" then
						is_match = true
						relative = name
					elseif clean_name:sub(1, #target_dir) == target_dir then
						-- Ensure it's not a partial match (e.g., target 'abc' should not match 'abcde/')
						local next_char = name:sub(#target_dir + 1, #target_dir + 1)
						if next_char == "/" or next_char == "" then
							is_match = true
							relative = name:sub(#target_dir + 1):gsub("^/+", "")
						end
					end

					if is_match and relative ~= "" then
						local parts = vim.split(relative, "/")
						local entry_name = parts[1]
						local is_dir = #parts > 1 or name:match("/$") or type_char == "d"
						
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
				end
			end
			cb(nil, entries)
		end
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
			if c ~= 0 then cb("Read failed: " .. c) else cb(nil, table.concat(stdout, "\n")) end
		end
	})
end

function M.write(uri, data, cb)
	cb("Write not supported for chained URIs yet")
end

function M.delete(u, r, cb) cb("Delete not supported for archives") end
function M.rename(o, n, cb) cb("Rename not supported for archives") end
function M.mkdir(u, cb) cb("Mkdir not supported for archives") end

return M
