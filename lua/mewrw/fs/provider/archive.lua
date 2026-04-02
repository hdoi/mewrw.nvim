local uri_parser = require("mewrw.utils.uri")

local M = {
	name = "archive",
}

local function debug_print(msg)
	if vim.fn.has("win32") == 1 and _G.mewrw_debug then
		print("[DEBUG] archive: " .. msg)
	end
end

function M.can_handle(uri)
	local u = uri_parser.parse(uri)
	if not u then return false end
	local s = u.scheme
	return s == "zip" or s == "tar" or s == "7z" or s == "compress"
end

local function get_archive_cmd(chain, action)
	local path_utils = require("mewrw.utils.path")
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
			else inner_cmd = "tar -tvf " .. vim.fn.shellescape(archive_path) end
		else -- read
			if scheme == "zip" then inner_cmd = "unzip -p " .. vim.fn.shellescape(archive_path) .. " " .. vim.fn.shellescape(internal)
			else inner_cmd = "tar -axf " .. vim.fn.shellescape(archive_path) .. " -O " .. vim.fn.shellescape(internal) end
		end
		table.insert(cmd, inner_cmd)
	else
		local abs_path = archive_path
		if not abs_path:match("^%a+://") then
			abs_path = vim.fn.fnamemodify(abs_path, ":p"):gsub("\\", "/")
		end
		
		if path_utils.is_windows then
			abs_path = abs_path:gsub("^/+", "")
			if scheme == "zip" and vim.fn.executable("unzip") == 1 then
				abs_path = abs_path:gsub("/", "\\")
			end
		end

		if action == "list" then
			if scheme == "7z" then cmd = { "7z", "l", abs_path }
			elseif scheme == "zip" and vim.fn.executable("unzip") == 1 then cmd = { "unzip", "-l", abs_path }
			elseif scheme == "zip" then cmd = { "tar", "-tf", abs_path }
			else cmd = { "tar", "-tvf", abs_path } end
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
	if layer.scheme == "compress" then
		if layer.path == "" or layer.path == "/" then
			local base = chain[#chain - 1]
			local archive_path = base and base.path or "archive"
			local name = vim.fn.fnamemodify(archive_path, ":t"):gsub("%.[gx]z$", ""):gsub("%.bz2$", "")
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
	local target_dir = internal:gsub("^/+", ""):gsub("/+$", "")
	
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
					local clean = l:gsub("\r", "")
					table.insert(stdout, clean) 
				end 
			end 
		end,
		on_exit = function(_, c)
			if c ~= 0 then return cb(layer.scheme .. " failed: " .. c) end
			local entries, found = {}, {}
			
			local filtered_stdout = {}
			if layer.scheme == "zip" and cmd[1] == "unzip" then
				local start_parsing = false
				for _, line in ipairs(stdout) do
					if line:match("^%s*[-]+%s+[-]+%s+") then
						start_parsing = not start_parsing
					elseif start_parsing then
						if not line:match("%d+%s+files?$") then
							table.insert(filtered_stdout, line)
						end
					end
				end
			else
				filtered_stdout = stdout
			end

			for _, line in ipairs(filtered_stdout) do
				local size, name, type_char
				if line:match("^Archive:") or line:match("^%s*Length") or line:match("^%s*[-]+%s+") then
					-- skip
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
					-- Robust Tar parsing: 
					-- 1. Extract type from first char
					type_char = line:sub(1, 1)
					-- 2. Extract name by splitting by multiple spaces and taking the last part
					-- Based on tar.log: drwxrwxr-x  0 anoop  anoop       0 2 13  2024 hmpol-0.1.5/
					-- The name starts after the date/time part. 
					-- Strategy: Find the first occurrence of a path-like string (with /) or just the 9th+ column.
					local parts_list = vim.split(line, "%s+")
					-- Standard tar format name is usually the last column
					name = parts_list[#parts_list]
					if name == "" then name = parts_list[#parts_list - 1] end -- Handle trailing space
					-- Size is usually the 5th column
					size = parts_list[5]
				end

				if name then
					name = name:gsub("\\", "/"):gsub("^%.[/\\]+", ""):gsub("^/+", ""):gsub("%s+$", "")
					local clean_name = name:gsub("/+$", "")
					
					local is_match = false
					local relative = ""
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
						local parts_rel = vim.split(relative, "/")
						local entry_name = parts_rel[1]
						local is_dir = #parts_rel > 1 or name:match("/$") or type_char == "d"
						
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
