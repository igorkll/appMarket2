local component = require("component")
local term = require("term")

--------------------------------------------

local invoke = component.invoke

local function filter(gpu, color)
    local depth = math.floor(invoke(gpu, "getDepth"))
    if depth == 4 then
        out = 0xFFFFFF - color
        if out == 0x00FFFF then out = 0x00AAFF end
        return out
    elseif depth == 1 then
        if color > 0 then
            return 0
        else
            return 0xFFFFFF
        end
    else
        return 0xFFFFFF - color
    end
end

local isStarted = false

--------------------------------------------

function start()
    if isStarted then return end
    isStarted = true
    local gpu = term.gpu().address
    function component.invoke(address, name, ...)
        if address == gpu then
            if name == "setForeground" or name == "setBackground" then
                local color = filter(gpu, ...)
                local color, isPal = invoke(address, name, color)
                if isPal then return color end
                return filter(gpu, color)
            elseif name == "getBackground" or name == "getForeground" then
                local color, isPal = invoke(address, name, ...)
                if isPal then return color end
                return filter(gpu, color)
            elseif name == "get" then
                local char, fore, back = invoke(address, name, ...)
                return char, filter(gpu, fore), filter(gpu, back)
            else
                return invoke(address, name, ...)
            end
        else
            return invoke(address, name, ...)
        end
    end
end

function stop()
    if not isStarted then return end
    isStarted = false
    component.invoke = invoke
end