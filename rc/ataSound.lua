local computer = require("computer")
local component = require("component")
local thread = require("thread")
local event = require("event")

-----------------------------------

local function beep(n, d)
    if not n then n = 440 end
    if not d then d = 0.1 end
    if component.isAvailable("beep") then
        component.beep.beep({[n] = d})
        os.sleep(d * 1.5)
    else
        computer.beep(n, d)
    end
end

-----------------------------------

local t

function start()
    if not t then
        t = thread.create(function()
            while true do
                local eventName, uuid, ctype = event.pull()
                if eventName == "component_added" then
                    beep(2000)
                    beep(1000)
                elseif eventName == "component_removed" then
                    beep(1000)
                    beep(2000)
                end
            end
        end)
        t:detach()
    end
end

function stop()
    if t then
        t:kill()
        t = nil
    end
end