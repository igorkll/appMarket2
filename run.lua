local fs = require("filesystem")
local su = require("superUtiles")
local shell = require("shell")
local event = require("event")
local serialization = require("serialization")

-----------------------------------

local args = shell.parse(...)
local arg = {table.unpack(args, 2, #args)}

-----------------------------------

if args[1] then
    local data = assert(su.getFile(args[1]))
    data = su.modProgramm(data)
    local code = assert(load(data))

    os.setenv("_", args[1])
    local out = {xpcall(code, debug.traceback, table.unpack(arg))}
    for i = 1, #out do
        if type(out[i]) == "table" then
            local ok, value = pcall(serialization.serialize, out[i])
            if ok then
                out[i] = value
            else
                out[i] = tostring(out[i])
            end
        else
            out[i] = tostring(out[i])
        end
    end
    out = table.concat(out, "\n")

    local filename = os.tmpname()
    su.saveFile(filename, out)
    shell.execute("view", _ENV, filename)
    shell.execute("rm", _ENV, filename)
else
    print("path ...")
end