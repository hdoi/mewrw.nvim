local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

-- Load provider directly via dofile to bypass ANY cache
local archive_provider = dofile(root .. "/lua/mewrw/fs/provider/archive.lua")

print("--- Direct Test: archive_provider.can_handle('compress://test.gz::') ---")
print("Result: " .. tostring(archive_provider.can_handle("compress://test.gz::")))

-- Setup sandbox
local test_dir = root .. "/tests/sandbox_extended"
vim.fn.delete(test_dir, "rf")
vim.fn.mkdir(test_dir, "p")

local function create_file(path, content)
    local f = io.open(path, "w")
    if f then f:write(content) f:close() end
end

print("========================================")
print("   Testing Extended Archive Formats")
print("========================================")

local mewrw = require("mewrw")
local fs = require("mewrw.fs")
mewrw.setup()

-- IMPORTANT: Override the cached provider in fs with our fresh one
for i, p in ipairs(package.loaded["mewrw.fs"].providers or {}) do
    if p.name == "archive" then
        package.loaded["mewrw.fs"].providers[i] = archive_provider
    end
end

local function test_format(ext, create_cmd, internal_name)
    print(string.format("\n--- Testing .%s ---", ext))
    local archive_path = test_dir .. "/test." .. ext
    
    -- 1. Create archive
    vim.fn.system(create_cmd)
    if vim.fn.filereadable(archive_path) == 0 then
        print(string.format("  SKIP: .%s (Command failed)", ext))
        return
    end

    -- 2. Test Listing
    local scheme = (ext == "gz" or ext == "xz") and "compress" or (ext == "7z" and "7z" or "tar")
    local uri = scheme .. "://" .. archive_path .. "::"
    
    _G.test_done = false
    archive_provider.list(uri, function(err, entries)
        if err then
            print("  FAIL: List error: " .. err)
        else
            print(string.format("  PASS: List found %d entries", #entries))
            
            -- 3. Test Reading
            local file_uri = uri .. (internal_name or "data.txt")
            archive_provider.read(file_uri, function(r_err, data)
                if r_err then
                    print("  FAIL: Read error: " .. r_err)
                elseif data:match("hello") then
                    print("  PASS: Content read correctly")
                else
                    print("  FAIL: Content mismatch: " .. tostring(data))
                end
                _G.test_done = true
            end)
        end
    end)
    vim.wait(2000, function() return _G.test_done end)
end

-- Prepare source file
create_file(test_dir .. "/data.txt", "hello world")

-- Test Cases
test_format("gz", string.format("gzip -c %s/data.txt > %s/test.gz", test_dir, test_dir))
test_format("tar.xz", string.format("tar -cJf %s/test.tar.xz -C %s data.txt", test_dir, test_dir))

print("\n----------------------------------------")
print("Extended Archive Tests Finished")
print("----------------------------------------")
