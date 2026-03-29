local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local mewrw = require("mewrw")
local engine = require("mewrw.core.engine")

print("--- Testing Tree View Expansion ---")

mewrw.setup()

-- Helper to find the mewrw buffer
local function find_mewrw_buf()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'mewrw' then
            return bufnr
        end
    end
    return nil
end

-- 1. Setup
engine.open(root)
local bufnr
vim.wait(3000, function() 
    bufnr = find_mewrw_buf()
    return bufnr ~= nil
end)
assert(bufnr, "mewrw buffer was not created")

-- Wait for initial load
local state
vim.wait(3000, function()
    if vim.b[bufnr] and vim.b[bufnr].mewrw_state_id then
        vim.api.nvim_win_set_buf(0, bufnr)
        state = engine.get_state()
        if state and #state.filtered_entries > 0 then return true end
    end
    return false
end, 100, false)
assert(state, "mewrw state was not created")

-- 1. Switch to tree mode
print("\nStep 1: Switching to tree mode")
engine.cycle_view_mode() -- list -> detailed
engine.cycle_view_mode() -- detailed -> tree
assert(state.view_mode == "tree", "Failed to switch to tree mode")

-- 2. Find 'lua/' directory specifically
vim.wait(2000, function() return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) >= 6 end)
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local target_line = -1
for i, line in ipairs(lines) do
    -- Match name regardless of tree symbols/indents
    if line:match("lua/") then
        target_line = i
        break
    end
end

if target_line ~= -1 then
    print("Found 'lua/' at line " .. target_line .. ". Attempting to expand...")
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_win_set_cursor(0, {target_line, 0})
    engine.open_under_cursor()
    
    print("Waiting for expansion...")
    vim.wait(5000, function()
        for _, entry in ipairs(state.filtered_entries) do
            if entry.name == "mewrw" then return true end
        end
        return false
    end, 100, false)

    local found_child = false
    for _, entry in ipairs(state.filtered_entries) do
        if entry.name == "mewrw" then
            found_child = true
            break
        end
    end

    if found_child then
        print("SUCCESS: Tree expansion works!")
    else
        print("FAILURE: Tree expansion failed (child 'mewrw' not found).")
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for i, l in ipairs(lines) do if i <= 20 then print(i .. ": " .. l) end end
    end
else
    print("FAILURE: 'lua/' directory not found in buffer lines.")
    for i, l in ipairs(lines) do print(i .. ": " .. l) end
end

-- Cleanup
pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
print("Test finished.")
