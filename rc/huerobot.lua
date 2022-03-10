local colorPic = require("colorPic")
local component = require("component")
local thread = require("thread")

------------------------------------

local function rc()
    local count = 0
    while true do
        local color = colorPic.colorBlend(colorPic.hsvToRgb(count, 255, 255))
        if args.robot then
            require("robot").setLightColor(color)
        end
        if args.upgrade then
            component.colors.setColor(color)
        end

        count = math.floor((count + 8) % 256)
        os.sleep(0.2)
    end
end

------------------------------------

local th

function start()
    if not th then
        th = thread.create(rc)
        th:detach()
    end
end

function stop()
    if th then
        th:kill()
        th = nil
    end
end