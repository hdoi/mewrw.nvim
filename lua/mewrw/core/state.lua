---@alias SortBy "name"|"numerical"|"size"|"mtime"|"extension"
---@alias ViewMode "list"|"detailed"|"tree"
---@alias EntryType "file"|"directory"|"link"|"other"

---@class Entry
---@field name string The display name of the file or directory
---@field path string The full URI or path of the entry
---@field type EntryType The type of the entry
---@field size number? File size in bytes
---@field mtime number? Last modification time (unix timestamp)
---@field depth number? Nesting level for tree view

---@class State
---@field bufnr number The buffer number this state belongs to
---@field uri string The current directory URI
---@field entries Entry[] Raw entries fetched from the provider
---@field filtered_entries Entry[] Processed entries for rendering
---@field show_hidden boolean Toggle for hidden files
---@field show_full_path boolean Toggle for full path display
---@field filter string Current filtering pattern (case-insensitive)
---@field sort_by SortBy Current sort criteria
---@field sort_reverse boolean reverse sort flag
---@field view_mode ViewMode Current display mode
---@field expanded_nodes table<string, Entry[]> Cache for tree nodes
---@field git_branch string? Current git branch
---@field git_status table<string, string>? Git status for files
local State = {}
State.__index = State

local function get_extension(name)
	return name:match("^.+(%..+)$") or ""
end

local function natural_compare(a, b)
	local function tokenize(str)
		local tokens = {}
		for text, number in str:gmatch("(.-)(%d*)") do
			if text ~= "" then table.insert(tokens, text:lower()) end
			if number ~= "" then table.insert(tokens, tonumber(number)) end
		end
		return tokens
	end
	local ta, tb = tokenize(a), tokenize(b)
	for i = 1, math.max(#ta, #tb) do
		if not ta[i] then return true end
		if not tb[i] then return false end
		if type(ta[i]) ~= type(tb[i]) then return tostring(ta[i]) < tostring(tb[i]) end
		if ta[i] ~= tb[i] then return ta[i] < tb[i] end
	end
	return false
end

function State.new(bufnr)
	local self = setmetatable({}, State)
	self.bufnr = bufnr
	self.uri = ""
	self.entries = {}
	self.filtered_entries = {}
	self.show_hidden = false
	self.show_full_path = false
	self.filter = ""
	self.sort_by = "name"
	self.sort_reverse = false
	self.view_mode = "list"
	self.expanded_nodes = {}
	self.git_branch = nil
	self.git_status = nil
	return self
end

function State:sort_entries(entries)
	local res = { unpack(entries) }
	table.sort(res, function(a, b)
		if a.type == "directory" and b.type ~= "directory" then return true end
		if a.type ~= "directory" and b.type == "directory" then return false end

		local function compare_vals(v1, v2)
			if v1 == v2 then return nil end
			if self.sort_reverse then return v1 > v2 else return v1 < v2 end
		end

		local outcome
		if self.sort_by == "size" then
			outcome = compare_vals(a.size or 0, b.size or 0)
		elseif self.sort_by == "mtime" then
			outcome = compare_vals(a.mtime or 0, b.mtime or 0)
		elseif self.sort_by == "numerical" then
			if a.name ~= b.name then
				local is_less = natural_compare(a.name, b.name)
				if self.sort_reverse then outcome = not is_less else outcome = is_less end
			end
		elseif self.sort_by == "extension" then
			outcome = compare_vals(get_extension(a.name):lower(), get_extension(b.name):lower())
		end

		if outcome ~= nil then return outcome end

		local n1, n2 = a.name:lower(), b.name:lower()
		if n1 ~= n2 then
			if self.sort_reverse then return n1 > n2 else return n1 < n2 end
		end
		return false
	end)
	return res
end

function State:update(uri, entries)
	if uri then
		self.uri = uri
		self.expanded_nodes = {}
	end
	if entries then self.entries = entries end

	if self.view_mode ~= "tree" then
		local res = {}
		local pattern = self.filter:lower()
		for _, e in ipairs(self.entries) do
			local match_hidden = self.show_hidden or not e.name:match("^%.")
			local match_filter = pattern == "" or e.name:lower():find(pattern, 1, true)
			if match_hidden and match_filter then table.insert(res, e) end
		end
		self.filtered_entries = self:sort_entries(res)
	else
		local res = {}
		local function add_recursive(list, depth)
			local sorted = self:sort_entries(list)
			for _, e in ipairs(sorted) do
				if self.show_hidden or not e.name:match("^%.") then
					e.depth = depth
					table.insert(res, e)
					if self.expanded_nodes[e.path] then
						add_recursive(self.expanded_nodes[e.path], depth + 1)
					end
				end
			end
		end
		add_recursive(self.entries, 0)
		self.filtered_entries = res
	end
end

return State
