local gui = require("gui_new").create()
local component = require("component")
local colorPic = require("colorPic")
local event = require("event")
local serialization = require("serialization")
local su = require("superUtiles")
local shell = require("shell")
local term = require("term")
local fs = require("filesystem")
local keyboard = require("keyboard")

local args, options = shell.parse(...)

-----------------------------------------

local camera

-----------------------------------------

local function map(value, low, high, low_2, high_2)
    local relative_value = (value - low) / (high - low)
    local scaled_value = low_2 + (high_2 - low_2) * relative_value
    return scaled_value
end

-----------------------------------------

local rx, ry = gui.gpu.maxResolution()
local depth = math.floor(gui.gpu.getDepth())

-----------------------------------------

local px, py
do
    local scale = 1
    local gpu = component.gpu
    local blockCountByWidth, blockCountByHeight = 1, 1
    local maxWidth, maxHeight = gpu.maxResolution()
    local proportion = (blockCountByWidth * 2 - 0.5) / (blockCountByHeight - 0.25)
    
    local height = scale * math.min(
    maxWidth / proportion,
    maxWidth,
    math.sqrt(maxWidth * maxHeight / proportion)
    )

    px, py = math.floor(height * proportion), math.floor(height)
end

local main = gui.createScene(nil, px, py)
local settings = gui.createScene(nil, 50, 5)

-----------------------------------------

local depthX, depthY, angleX, angleY = 40, 40, 90, 90
local image, metadata, imagePath

local function calculate(image)
    local metadata = {}
    metadata.sx = #image[1]
    metadata.sy = #image
    metadata.max = 0
    for y = 1, metadata.sy do
        for x = 1, metadata.sx do
            local value = image[y][x]
            if value > metadata.max then metadata.max = value end
        end
    end
    return metadata
end

local function photo(depthX, depthY, angle)
    local image = {}
    for y = -(angleY / 2), angleY / 2, angleY / depthY do
        table.insert(image, {})
        local tbl = image[#image]
        for x = -(angleX / 2), angleX / 2, angleX / depthX do
            local value = camera.distance(math.rad(x), -math.rad(y))
            table.insert(tbl, value)
        end
    end
    return image
end

local function loadPhoto(path)
    local file = assert(su.getFile(path))
    local tbl = assert(serialization.unserialize(file))
    return tbl
end

local function savePhoto(path)
    local data = assert(serialization.serialize(image))
    return assert(su.saveFile(path, data))
end

local function funcExecute(func, ...)
    local out = {pcall(func, ...)}
    if out[1] then
        return table.unpack(out, 2)
    else
        gui.splash(out[2] or "unkown error")
        return nil, out[2]
    end
end

local function getPath(exists)
    local oldscene = gui.getScene()
    gui.select(0)

    term.write("path: ")
    local path = shell.resolve(io.read())

    gui.select(oldscene)

    if not path then return nil end
    if exists then
        if fs.exists(path) then
            if fs.isDirectory(path) then
                gui.splash("это директория")
            else
                return path
            end
        else
            gui.splash("файла не сушествует")
        end
    else
        if not fs.exists(path) then
            return path
        else
            if gui.yesno("файл уже сушествует, заменить?") then
                return path
            end
        end
    end
    return nil
end

local drawzone = main.createDrawZone(1, 3, 1, 1, function(gpu, posX, posY, sizeX, sizeY)
    if image then
        for x = 1, metadata.sx do
            for y = 1, metadata.sy do
                local color = image[y][x]
                if depth == 1 then
                    if math.floor(color) == -1 then
                        color = 0
                    else
                        color = 0xFFFFFF
                    end
                else
                    if math.floor(color) == -1 then
                        color = 0
                    else
                        color = map(color, 0, metadata.max, 0, 255)
                        color = -math.floor(color)
                        color = colorPic.colorBlend(color, color, color)
                    end
                end
                if y % 2 == 1 then
                    gpu.setBackground(color)
                else
                    gpu.setForeground(color)
                    gpu.set(posX + (x - 1), ((y - 1) // 2) + posY, "▄")
                end
            end
        end
    else
        if depth == 1 then
            gpu.setBackground(0xFFFFFF)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(0xAAAAAA)
            gpu.setForeground(0xFFFFFF)
        end
        gpu.fill(posX, posY, sizeX, sizeY, " ")
        gpu.set(posX, posY, "нет снимка в буфере")
    end
end, drawzoneindex)

local function ioMenager(num)
    if num == 1 then
        local path = getPath()
        if path then
            local ok = funcExecute(savePhoto, path)
            if ok then
                imagePath = path
            end
        end
        gui.redraw()
    elseif num == 2 then
        if not imagePath then
            ioMenager(1)
            return
        end
        funcExecute(savePhoto, imagePath)
    elseif num == 3 then
        local path = getPath(true)
        if path then
            local img = funcExecute(loadPhoto, path)
            if img then
                imagePath = path
                image = img
                metadata = calculate(image)
            end
        end
        gui.redraw()
    elseif num == 4 then
        image = nil
        imagePath = nil
    end
end

main.createButton(1, 1, 6, 1, "file", nil, nil, false, nil, nil, nil, function()
    local _, num = gui.context(true, 2, 2, {{"save as", image}, {"save", image and imagePath}, {"load", true}, {"clear", true}}, true)
    ioMenager(num)
end)
main.createButton(8, 1, 6, 1, "photo", 0x00FF00, 0xFFFFFF, false, nil, nil, nil, function()
    if camera then
        gui.status("делаеться фото, подождите")
        local img = photo(depthX, depthY, angle)
        if img then
            image = img
            metadata = calculate(image)
        end
        gui.redraw()
    else
        gui.splash("камера не выбрана")
    end
end)
main.createButton(15, 1, 8, 1, "settings", 0xFFAA00, 0xFFFFFF, false, nil, nil, nil, function()
    gui.select(settings)
end)

main.createButton(15 + 8 + 1, 1, 8, 1, "select", 0xFF00FF, 0xFFFFFF, false, nil, nil, nil, function()
    local strs = {}
    local addresses = {}
    for address in component.list("camera") do
        table.insert(addresses, address)
        table.insert(strs, address:sub(1, 4))
    end
    table.insert(strs, "clear")

    local _, num = gui.context(true, 15 + 8 + 3, 2, strs, true)
    if num then
        if num > #addresses then
            camera = nil
        else
            local address = addresses[num]
            camera = component.proxy(address)
        end
    end
end)

-----------------------------------------

settings.createSeekBar(1, 1, 50, 0x660000, 0, 8, 300, depthX, true, 0, function(new)
    depthX = math.floor(new)
end, true, "depthX", 14)
settings.createSeekBar(1, 2, 50, 0x660000, 0, 8, 300, depthY, true, 0, function(new)
    depthY = math.floor(new)
end, true, "depthY", 14)
settings.createSeekBar(1, 3, 50, 0x660000, 0, 8, 300, angleX, true, 0, function(new)
    angleX = math.floor(new)
end, true, "angleX", 14)
settings.createSeekBar(1, 4, 50, 0x660000, 0, 8, 300, angleY, true, 0, function(new)
    angleY = math.floor(new)
end, true, "angleY", 14)
settings.createButton(1, 5, 16, 1, "back", 0xFFAA00, 0xFFFFFF, false, nil, nil, nil, function()
    gui.select(main)
end)
local pathLabel = main.createLabel(1, 2, 24, 1, "path", 0x00AA00, 0xFFFFFF)
local cameraLabel = main.createLabel(26, 2, 10, 1, "camera", 0x00AA00, 0xFFFFFF)

if args[1] then
    local path = shell.resolve(args[1])
    local img = funcExecute(loadPhoto, path)
    if img then
        imagePath = path
        image = img
        metadata = calculate(image)
    end
end

gui.select(main)

-----------------------------------------

while true do
    local eventData = {event.pull()}
    if eventData[1] == "key_down" and eventData[2] == term.keyboard() then
        if eventData[4] == keyboard.keys.w then
            gui.exit()
        elseif eventData[4] == keyboard.keys.s then
            ioMenager(2)
        end
    end
    gui.uploadEvent(table.unpack(eventData))
    if camera and not component.proxy(camera.address) then
        camera = nil
    end
    if pathLabel.text ~= imagePath then
        if imagePath then
            pathLabel.text = imagePath
        else
            pathLabel.text = "path"
        end
        pathLabel.draw()
    end
    if not camera or cameraLabel.text ~= camera.address:sub(1, 8) then
        if camera then
            cameraLabel.text = camera.address:sub(1, 8)
        else
            cameraLabel.text = "camera"
        end
        cameraLabel.draw()
    end
end