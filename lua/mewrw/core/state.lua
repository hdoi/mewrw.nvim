local path_utils = require("mewrw.utils.path")
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

function State.new(bufnr, opts)
	local global_config = require("mewrw").config
	opts = opts or {}
	local self = setmetatable({}, State)
	self.bufnr = bufnr
	self.uri = ""
	self.entries = {}
	self.filtered_entries = {}
	
	self.show_hidden = (opts.show_hidden ~= nil) and opts.show_hidden or global_config.show_hidden
	self.show_full_path = (opts.show_full_path ~= nil) and opts.show_full_path or false
	self.filter = opts.filter or ""
	self.sort_by = opts.sort_by or global_config.sort_by
	self.sort_reverse = (opts.sort_reverse ~= nil) and opts.sort_reverse or global_config.sort_reverse
	self.view_mode = opts.view_mode or global_config.default_view_mode
	self.expanded_nodes = opts.expanded_nodes or {}
	
	self.git_branch = nil
	self.git_status = nil
	return self
end

local comparators = {
	size = function(a, b) return (a.size or 0) < (b.size or 0) end,
	mtime = function(a, b) return (a.mtime or 0) < (b.mtime or 0) end,
	extension = function(a, b) return get_extension(a.name):lower() < get_extension(b.name):lower() end,
	numerical = function(a, b) return natural_compare(a.name, b.name) end,
	name = function(a, b) return a.name:lower() < b.name:lower() end,
}

function State:sort_entries(entries)
	local res = { unpack(entries) }
	local cmp = comparators[self.sort_by] or comparators.name

	table.sort(res, function(a, b)
		-- 1. Directories always first
		if a.type == "directory" and b.type ~= "directory" then return true end
		if a.type ~= "directory" and b.type == "directory" then return false end

		-- 2. Primary comparison
		local is_less = cmp(a, b)
		local is_more = cmp(b, a)

		if not is_less and not is_more then
			-- Items are equal by primary criteria, fallback to name for stability
			if a.name:lower() == b.name:lower() then return false end
			return a.name:lower() < b.name:lower()
		end

		if self.sort_reverse then
			return is_more
		end
		return is_less
	end)
	return res
end

function State:update(uri, entries, expanded_nodes)
	if uri then
		self.uri = uri
		if expanded_nodes then self.expanded_nodes = expanded_nodes end
	end
	if entries then self.entries = entries end

	local pattern = self.filter:lower()
	local function filter_entry(e)
		local match_hidden = self.show_hidden or not e.name:match("^%.")
		local match_filter = pattern == "" or e.name:lower():find(pattern, 1, true)
		return match_hidden and match_filter
	end

	if self.view_mode ~= "tree" then
		local res = {}
		for _, e in ipairs(self.entries) do
			if filter_entry(e) then table.insert(res, e) end
		end
		self.filtered_entries = self:sort_entries(res)
	else
		local res = {}
		local function add_recursive(list, depth)
			local sorted = self:sort_entries(list)
			for _, e in ipairs(sorted) do
				if filter_entry(e) then
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
