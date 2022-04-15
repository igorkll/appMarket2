local component = require("component")
local term = require("term")
local thread = require("thread")
local unicode = require("unicode")

local gpu = term.gpu()

------------------------------

local args = args or {}

--local glasses = cpselect.get("glasses", "отображения информации с экрана", true)
local glasses = component.glasses

local function unBlendColor(color)
    local blue = color % 256
    local green = (color // 256) % 256
    local red = (color // (256 * 256)) % 256
    return red, green, blue
end

local count = 0
local function interrupt()
    count = count + 1
    if count % 16 == 0 then
        os.sleep(0.5)
    end
end

------------------------------

local objs = {}

local function func()
    while true do
        for k, v in pairs(objs) do
            --v.removeWidget()
        end
        local rx, ry = gpu.getResolution()
        --local r, g, b, char, fore, back, obj
        --local glasses_addText2D = glasses.addText2D
        --local gpu_get = gpu.get
        --local table_insert = table.insert

        local function emptyChar(char, fore, back)
            if char == " " and back == 0 then
                return true
            end
            if char == "█" and fore == 0 then
                return true
            end
            return false
        end

        local function backUsed(char)
            return char ~= "█"
        end

        local function foreUsed(char)
            return char ~= " "
        end

        local count = 1
        local image = {}
        for cy = 1, ry do
            local oldBack, oldFore
            for cx = 1, rx do
                local char, fore, back = gpu.get(cx, cy)

                ::tonew::
                if not oldBack then oldBack = back end
                if not oldFore then oldFore = fore end

                if back == oldBack and fore == oldFore then
                    if not image[count] then
                        image[count] = {x = cx, y = cy, text = char, fore = fore, back = back}
                    else
                        image[count].text = image[count].text .. char
                    end
                else
                    if image[count] then
                        count = count + 1
                        oldBack = nil
                        oldFore = nil
                        goto tonew
                    end
                end
            end
            if image[count] then count = count + 1 end
        end

        glasses.removeAll()

        for k, data in pairs(image) do
            if data.back ~= 0 then
                local r, g, b = unBlendColor(data.back)
                r = r / 255
                g = g / 255
                b = b / 255
                
                local obj = glasses.addText2D()
                obj.addTranslation(data.x * 4, data.y * 8, 0)
                obj.addColor(r, g, b, 1)

                local text = ""
                for i = 1, unicode.len(data.text) do
                    text = text .. "▌"
                end

                obj.setText(text)
            end


            local r, g, b = unBlendColor(data.fore)
            r = r / 255
            g = g / 255
            b = b / 255
            
            local obj = glasses.addText2D()
            obj.addTranslation(data.x * 4, data.y * 8, 0)
            obj.addColor(r, g, b, 1)
            obj.setText(data.text)

            interrupt()
        end
        os.sleep(args.drawTimeOut or 2)
    end
end

------------------------------

local t

function start()
    if not t then
        t = thread.create(func)
        t:detach()
    end
end

function stop()
    if t then
        t:kill()
        t = nil
    end
end