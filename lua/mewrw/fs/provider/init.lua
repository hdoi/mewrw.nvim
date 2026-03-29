---@alias EntryType "file"|"directory"|"link"|"other"

---@class Entry
---@field name string ファイル名
---@field path string フルパス
---@field type EntryType 種別
---@field size number? サイズ (bytes)
---@field mtime number? 最終更新日時 (timestamp)

---@class Provider
---@field name string
---@field can_handle fun(uri: string): boolean
---@field list fun(uri: string, cb: fun(err: string|nil, entries: Entry[]|nil))
---@field read fun(uri: string, cb: fun(err: string|nil, data: string|nil))
---@field write fun(uri: string, data: string, cb: fun(err: string|nil))
---@field delete fun(uri: string, recursive: boolean, cb: fun(err: string|nil))
---@field rename fun(old_uri: string, new_uri: string, cb: fun(err: string|nil))
---@field mkdir fun(uri: string, cb: fun(err: string|nil))

return {}
