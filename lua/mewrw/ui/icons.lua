local M = {}

local emoji_map = {
	directory = "📁",
	file = "📄",
	image = "🖼️",
	archive = "📦",
	config = "⚙️",
	unknown = "❓",
}

local ext_emoji = {
	-- Programming & Code
	lua = "🌙", py = "🐍", js = "📜", ts = "📘", go = "🐹", rs = "🦀",
	c = "🇨", h = "📑", cpp = "➕", java = "☕", f = "ⓕ", sh = "🐚",
	sql = "🗄️", vim = "💚",
	
	-- Data & Config
	json = "📋", yaml = "📋", xml = "📰", toml = "⚙️", ini = "⚙️",
	conf = "🔧", env = "🔑", csv = "📊", tsv = "📊", dat = "💾",
	
	-- Documents
	md = "📝", txt = "📄", pdf = "📕", log = "🪵",
	docx = "📝", xlsx = "📈", pptx = "📊",
	
	-- Media & Images
	png = "🖼️", jpg = "🖼️", gif = "🖼️", wav = "🔊", mp3 = "🎵", mp4 = "🎥",
	
	-- Archives & System
	zip = "📦", tar = "📦", dmg = "💿", bin = "🔢", out = "📤", pdb = "🧬",
}

--- Get icon and highlight for an entry
---@param entry Entry
---@param mode "devicons"|"emoji"
---@return string icon, string? hl_group
function M.get(entry, mode)
	if mode == "emoji" then
		if entry.type == "directory" then
			return emoji_map.directory, nil
		end
		local ext = entry.name:match("%.([^.]+)$")
		if ext then
			ext = ext:lower()
		end
		return ext_emoji[ext] or emoji_map.file, nil
	end

	if mode == "devicons" then
		local has_devicons, devicons = pcall(require, "nvim-web-devicons")
		if has_devicons then
			local icon, hl = devicons.get_icon(entry.name, entry.name:match("%.([^.]+)$"), {
				default = true,
			})
			return icon, hl
		end
		-- Fallback to emoji if devicons is not installed
		return M.get(entry, "emoji")
	end

	return "", nil
end

return M
