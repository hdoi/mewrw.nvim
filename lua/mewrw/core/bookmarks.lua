local M = {}

local bookmarks = {}
local bookmarks_path = vim.fn.stdpath("data") .. "/mewrw_bookmarks"

local function save_bookmarks()
	local f = io.open(bookmarks_path, "w")
	if f then
		for _, b in ipairs(bookmarks) do f:write(b .. "\n") end
		f:close()
	end
end

local function load_bookmarks()
	local f = io.open(bookmarks_path, "r")
	if f then
		bookmarks = {}
		for line in f:lines() do
			if line ~= "" then table.insert(bookmarks, line) end
		end
		f:close()
	end
end

load_bookmarks()

function M.add(uri)
	if not uri or uri == "" then return end
	for _, b in ipairs(bookmarks) do
		if b == uri then return end
	end
	table.insert(bookmarks, uri)
	save_bookmarks()
	vim.notify("Bookmarked: " .. uri)
end

function M.list(callback)
	if #bookmarks == 0 then
		vim.notify("No bookmarks saved")
		return
	end
	vim.ui.select(bookmarks, { prompt = "Open Bookmark:" }, function(choice)
		if choice then callback(choice) end
	end)
end

function M.remove()
	if #bookmarks == 0 then return end
	vim.ui.select(bookmarks, { prompt = "Delete Bookmark:" }, function(choice)
		if not choice then return end
		for i, b in ipairs(bookmarks) do
			if b == choice then
				table.remove(bookmarks, i)
				save_bookmarks()
				return
			end
		end
	end)
end

function M.clear_for_test()
	bookmarks = {}
end

return M
