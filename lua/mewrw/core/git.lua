local M = {}

--- Run a shell command asynchronously and return its output
---@param cmd string[]
---@param cwd string
---@param cb fun(output: string|nil)
local function run_cmd(cmd, cwd, cb)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)
	local data = ""
	local handle

	handle = vim.loop.spawn(cmd[1], {
		args = { unpack(cmd, 2) },
		cwd = cwd,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		if handle then handle:close() end
		if stdout then stdout:close() end
		if stderr then stderr:close() end
		vim.schedule(function()
			cb(code == 0 and data or nil)
		end)
	end)

	if not handle then
		return cb(nil)
	end

	vim.loop.read_start(stdout, function(err, chunk)
		if chunk then data = data .. chunk end
	end)
end

--- Get git status for a directory
---@param dir string
---@param cb fun(repo_root: string|nil, branch: string|nil, statuses: table<string, string>|nil)
function M.get_info(dir, cb)
	-- 1. Check if inside a git repo and get repo root
	run_cmd({ "git", "rev-parse", "--show-toplevel" }, dir, function(root)
		if not root then return cb(nil, nil, nil) end
		root = root:gsub("\n", "")

		-- 2. Get current branch
		run_cmd({ "git", "branch", "--show-current" }, dir, function(branch)
			branch = branch and branch:gsub("\n", "") or "HEAD"

			-- 3. Get status porcelain
			run_cmd({ "git", "status", "--porcelain", "-u" }, dir, function(status_output)
				local statuses = {}
				if status_output then
					for line in status_output:gmatch("[^\n]+") do
						local s = line:sub(1, 2)
						local p = line:sub(4)
						-- Remove quotes if git config core.quotepath is on
						p = p:gsub('^"', ''):gsub('"$', '')
						-- If rename, take the new path
						if s:match("R") then
							p = p:match("->%s+(.+)$") or p
						end
						-- Convert to full path and normalize slashes
						local full_path = (root .. "/" .. p):gsub("//+", "/")
						statuses[full_path] = s
					end
				end
				cb(root, branch, statuses)
			end)
		end)
	end)
end

return M
