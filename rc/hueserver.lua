local colorPic = require("colorPic")
local component = require("component")
local thread = require("thread")

------------------------------------

local function rc()
    local count = 0
    while true do
        for address in component.list("light_board") do
            local light_board = component.proxy(address)
            for i = 1, light_board.light_count do
                light_board.setActive(i, true)
                --local color = (count + ((256 // 4) * (i - 1))) % 256
                local color = (count + ((256 // 16) * (i - 1))) % 256
                light_board.setColor(i, colorPic.colorBlend(colorPic.hsvToRgb(color, 255, 255)))
            end
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