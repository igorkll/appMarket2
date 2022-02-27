local box = require("box")
local proxyFS = require("proxyFS")
local shell = require("shell")
local su = require("superUtiles")
local event = require("event")
local term = require("term")
local fs = require("filesystem")
local component = require("component")
local computer = require("computer")

----------------------------------------

local args = shell.parse(...)

----------------------------------------

if args[1] == "run" then
    local vmPath = shell.resolve(args[2])
    local path = fs.concat(vmPath, "filesystems")
    local vm = box.createContainer()

    for data in fs.list(path) do
        local full_path = fs.concat(path, data)
        local vfs = {address = fs.name(full_path), type = "filesystem", callback = proxyFS.createFS(full_path, fs.name(full_path), true)}
        vm:attachComponent(vfs)
    end
    for address in component.list() do
        local ctype = component.type(address)
        if ctype ~= "filesystem" and ctype ~= "disk_drive" and ctype ~= "eeprom" then
            vm:passComponent(address)
        end
    end
    vm:passComponent(computer.tmpAddress())
    vm.libcomputer.tmpAddress = computer.tmpAddress
    vm:attachComponent({address = box.uuid(), type = "eeprom", callback = {
        set = function(data)
            checkArg(1, data, "string")
            local path = fs.concat(vmPath, "eeprom.dat")
            su.saveFile(path, data)
        end,
        get = function()
            local path = fs.concat(vmPath, "eeprom.dat")
            if fs.exists(path) then
                return su.getFile(path)
            else
                return ""
            end
        end,
        setData = function(data)
            checkArg(1, data, "string")
            local path = fs.concat(vmPath, "eepromData.dat")
            su.saveFile(path, data)
        end,
        getData = function()
            local path = fs.concat(vmPath, "eepromData.dat")
            if fs.exists(path) then
                return su.getFile(path)
            else
                return ""
            end
        end,
        makeReadonly = function(checkSum)
            checkArg(1, checkSum, "string")
        end,
        getChecksum = function()
            return "00000000"
        end,
        setLabel = function(data)
            local path = fs.concat(vmPath, "eepromLabel.dat")
            if data then
                su.saveFile(path, data)
                return data
            else
                fs.remove(path)
                return "EEPROM"
            end
        end,
        getLabel = function()
            local path = fs.concat(vmPath, "eepromLabel.dat")
            if fs.exists(path) then
                return su.getFile(path)
            else
                return "EEPROM"
            end
        end,
        getSize = function()
            return math.huge
        end,
        getDataSize = function()
            return math.huge
        end
    }})
    assert(vm:bootstrap())

    local gpu = term.gpu()
    gpu.setBackground(0)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    local interrupt = event.superHook
    local interrupt2 = event.hook
    event.superHook = false
    event.hook = false
    local out = {vm:loop()}
    event.superHook = interrupt
    event.hook = interrupt2
    gpu.setBackground(0)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    print(table.unpack(out))
else
    print("usage:")
    print("vm run vmFolder")
end