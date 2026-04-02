local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local uri_parser = require("mewrw.utils.uri")

print("========================================")
print("   Testing Chained URI Parser (::: Spec)")
print("========================================\n")

local function test(str)
	print("Parsing Chain: '" .. str .. "'")
	local chain = uri_parser.parse_chain(str)
	if #chain == 0 then
		print("  -> Result: EMPTY CHAIN\n")
		return
	end
	for i, res in ipairs(chain) do
		print(string.format("  Layer %d:", i))
		print("    scheme:   " .. tostring(res.scheme))
		print("    host:     " .. tostring(res.host))
		print("    path:     " .. tostring(res.path))
	end
	print("")
end

-- 1. Simple SFTP
test("sftp://localhost/")

-- 2. SFTP + Zip Chain (Option B format)
test("sftp://localhost/data.zip:::zip://")

-- 3. SFTP + Zip + Internal Path
test("sftp://user@host/work.zip:::zip://src/main.lua")

-- 4. Triple Nesting (SFTP + Zip + Tar)
test("sftp://host/backup.zip:::zip://nested.tar:::tar://")

-- 5. Windows Local Path as base
test("C:/Users/test.zip:::zip://")

-- 6. IPv4/Hostname with port
test("sftp://192.168.1.10:2222/path")

-- 7. Regular local path (Single layer chain)
test("/home/doi/mewrw")
