local gui = require("gui_new").create()
local event = require("event")
local thread = require("thread")
local su = require("superUtiles")
local keyboard = require("keyboard")
local computer = require("computer")
local shell = require("shell")
local networks = require("networks")

-------------------------------------------

local args = shell.parse(...)

local gpu = gui.gpu
local rx, ry = gpu.getResolution()

local userCode = args[2] or su.generateRandomID()
local appName = "lchat"

if not args[1] then
    print("usage:")
    print("lchat network [nikname]")
    return
end

local network = networks.getNetwork(args[1])
if not network then io.stderr:write("this network in not open\n") return end

-------------------------------------------

local main = gui.createScene()
local logZone = main.createLogZone(1, 1, rx, ry - 3)
local input = main.createInputBox(1, ry - 2, rx, 3, "input", nil, nil, function(str)
    if str then
        network.send(appName, userCode..": "..str)
        logZone.add(userCode.."(you): "..str)
    end
end)

thread.create(function()
    while true do
        local _, _, _, message = event.pull("network_message", network.name)
        logZone.add(message)
    end
end)

gui.select(main)

-------------------------------------------

while true do
    local eventData = {event.pull()}
    gui.uploadEvent(table.unpack(eventData))
    if eventData[1] == "key_down" and eventData[2] == gui.keyboard and eventData[4] == 28 then
        input.input()
    end
end