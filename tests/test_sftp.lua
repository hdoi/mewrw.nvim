local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing SFTP Provider (localhost) ---")

mewrw.setup()

-- Helper to find a mewrw buffer
local function find_mewrw_buf(path_pattern)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then
            local state_id = vim.b[bufnr].mewrw_state_id
            if state_id then
                local original_buf = vim.api.nvim_get_current_buf()
                vim.api.nvim_set_current_buf(bufnr)
                local state = engine.get_state()
                vim.api.nvim_set_current_buf(original_buf)
                if not path_pattern or (state and state.uri:match(path_pattern)) then
                    return bufnr
                end
            end
        end
    end
    return nil
end

-- 1. Listing root test
local user = os.getenv("USER") or "root"
local sftp_uri = "sftp://" .. user .. "@localhost/"
print("Step 1: Attempting to list root: " .. sftp_uri)

engine.open(sftp_uri)

local bufnr
local success = vim.wait(10000, function()
    bufnr = find_mewrw_buf("sftp://")
    if not bufnr then return false end
    local original_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(bufnr)
    local state = engine.get_state()
    vim.api.nvim_set_current_buf(original_buf)
    return state and #state.filtered_entries > 0
end, 200)

if success then
    print("SUCCESS: Found " .. #engine.get_state().filtered_entries .. " entries via SFTP root.")
else
    print("FAILURE: SFTP root listing failed.")
end

-- 2. Listing home test
local home_path = "/home/" .. user
local home_uri = "sftp://" .. user .. "@localhost" .. home_path
print("\nStep 2: Attempting to list home: " .. home_uri)

engine.open(home_uri)

local home_buf
local home_success = vim.wait(10000, function()
    home_buf = find_mewrw_buf(user .. "@localhost/home/" .. user)
    if not home_buf then return false end
    vim.api.nvim_win_set_buf(0, home_buf)
    local state = engine.get_state()
    return state and state.uri:match("/home/" .. user) and #state.filtered_entries > 0
end, 200)

if home_success then
    local state = engine.get_state()
    print("SUCCESS: Found " .. #state.filtered_entries .. " entries in " .. state.uri)
    assert(not state.uri:match("/home/home"), "ERROR: Detected duplicated path component!")
else
    print("FAILURE: SFTP home listing failed or path is still incorrect.")
end

-- Cleanup
if bufnr then pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) end
if home_buf then pcall(vim.api.nvim_buf_delete, home_buf, { force = true }) end
print("Test finished.")
