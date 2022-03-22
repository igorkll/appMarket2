local shell = require("shell")
local networks = require("networks")
local keyboard = require("keyboard")
local event = require("event")
local su = require("superUtiles")
local term = require("term")
local app = require("appDriver").create()

-----------------------------------------------

local args, options = shell.parse(...)

if #args == 0 then
    print("usage:")
    print("controller connect network device")
    print("controller get network device")
    app.exit()
    return
end

local gpu = term.gpu()
local appName = "controller"
local network = networks.getNetwork(args[2])
local deviceName = args[3]
if not network then
    print("no this network")
    app.exit()
    return
end

-----------------------------------------------

if args[1] == "connect" then
    pcall(gpu.setResolution, 8, 4)
    app.fullScreen = true
    term.clear()

    local function send(...)
        network.send(appName, "call", deviceName, ...)
    end

    while true do
        local eventName, uuid, lappName, code, dat = event.pull()
        if eventName == "key_down" and uuid == term.keyboard() then
            if code == keyboard.keys.w then
                send("forward")
            elseif code == keyboard.keys.s then
                send("back")
            elseif code == keyboard.keys.a then
                send("turnLeft")
            elseif code == keyboard.keys.d then
                send("turnRight")
            elseif code == keyboard.keys.space then
                send("up")
            elseif code == 42 then
                send("down")
            elseif code == keyboard.keys.z then
                local num = tonumber(io.read())
                if num then
                    send("select", num)
                end
            elseif code == keyboard.keys.r then
                send("swingUp")
            elseif code == keyboard.keys.f then
                send("swing")
            elseif code == keyboard.keys.v then
                send("swingDown")
            elseif code == keyboard.keys.t then
                send("placeUp")
            elseif code == keyboard.keys.g then
                send("place")
            elseif code == keyboard.keys.b then
                send("placeDown")
            elseif code == keyboard.keys.enter then
                local input = io.read()
                if input then
                    send(table.unpack(su.split(input, " ")))
                end
            end
        elseif eventName == "network_message" and uuid == network.name and lappName == appName and code == "return" then
            print(table.unpack(dat))
        end
    end
elseif args[1] == "get" then
    local robot = require("robot")
    while true do
        local eventData = {event.pull("network_message", network.name)}
        if eventData[3] == appName and eventData[4] == "call" and eventData[5] == deviceName then
            if not robot[eventData[6]] then
                --app commands
            else
                local dat = {pcall(robot[eventData[6]], table.unpack(eventData, 7))}
                network.send(appName, "return", dat)
            end
        end
    end
else
    print("mod is not found")
    app.exit()
    return
end