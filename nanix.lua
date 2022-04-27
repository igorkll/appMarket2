local nano = require("nano")
local gui = require("guix").create()
local serialization = require("serialization")
local su = require("superUtiles")
local fs = require("filesystem")

--------------------------------------------

local stateScene = gui.createScene(gui.selectColor(0x222222, nil, false), gui.maxX, gui.maxY)
local main = gui.createScene(gui.selectColor(0x222222, nil, false), gui.maxX, gui.maxY)
local noConnectScene = gui.createScene(gui.selectColor(0x222222, nil, false), gui.maxX, gui.maxY)

local connection
local label = noConnectScene.createLabel((noConnectScene.sizeX // 2) - (24 // 2), noConnectScene.sizeY // 3, 24, 1, "нету подключения к нанитам")
label.backColor = 0xAAAAAA
label.foreColor = 0

local refreshButton = noConnectScene.createButton((noConnectScene.sizeX // 2) - 8, (noConnectScene.sizeY // 3) * 2, 16, 1, "refresh", function()
    connection(true)
end)
refreshButton.backColor = gui.selectColor(0xAAAAAA, nil, true)
refreshButton.foreColor = gui.selectColor(0, nil, false)
refreshButton.invertBackColor = refreshButton.foreColor
refreshButton.invertForeColor = refreshButton.backColor

local stateLabel = stateScene.createLabel(1, stateScene.sizeY // 2, stateScene.sizeX, 1, "")
local oldStatusScene
local function status(text)
    stateLabel.text = text
    if gui.scene ~= stateScene then
        oldStatusScene = gui.scene
        gui.select(stateScene)
    else
        stateLabel.draw()
    end
end
local function statusOff()
    if oldStatusScene then
        gui.select(oldStatusScene)
        oldStatusScene = nil
    end
end

--------------------------------------------

local connectOldScene, inputsCount, isConnection
local function noConnection()
    isConnection = false
    if gui.scene ~= noConnectScene then
        connectOldScene = gui.scene
        gui.select(noConnectScene)

        while not isConnection do
            os.sleep(0.5)
        end
    end
end

local function nanoCall(...)
    ::start::
    local dat = {pcall(...)}
    if not dat[1] then
        if type(dat[2]) == "table" and dat[2].reason == "terminated" then
            gui.exit()
        end
        noConnection()
        goto start
    end
    return table.unpack(dat, 2)
end

function connection(back)
    status("подключения...")
    local ok, inputs2 = pcall(nano.getTotalInputCount)
    --statusOff()
    if ok then
        inputsCount = inputs2
        isConnection = true
        if back then gui.select(connectOldScene or main) end
    else
        noConnection()
    end
end

gui.start()
connection()

--------------------------------------------

local cfg = {pins = {}, notes = {}}
for i = 1, inputsCount do
    table.insert(cfg.pins, false)
    table.insert(cfg.notes, false)
end

local cfgPath = "/etc/nano4312.cfg"
local function saveCfg()
    su.saveFile(cfgPath, assert(serialization.serialize(cfg)))
end
if fs.exists(cfgPath) then
    cfg = assert(serialization.unserialize(assert(su.getFile(cfgPath))))
else
    saveCfg()
end

--------------------------------------------

local windowCount = 0
local function winAdd()
    windowCount = windowCount + 1
    gui.redrawAll = true
end
local function winRemove()
    windowCount = windowCount - 1
    if windowCount < 0 then windowCount = 0 end
    if windowCount == 0 then gui.redrawAll = false end
end

--------------------------------------------

local updateLabels

local buttons = {}
for i = 1, inputsCount do
    local b
    b = main.createButton(1, i + 2, 32, 1, "", function(state, oldState, button)
        if button == 1 then
            winAdd()

            b.state = oldState
            b.draw()

            local window = main.createWindow(math.floor(gui.lastTouch[3]), math.floor(gui.lastTouch[4]), 40, 10)
            window.userMove = true
            window.color = 0xAAAAAA

            local closeButton = main.createButton(1, 1, 8, 1, "close", function()
                winRemove()
                window.remove()
                gui.redraw()
            end)
            closeButton.backColor = 0xFF0000
            closeButton.foreColor = 0xFFFFFF

            window.attachObj(1, 1, closeButton)

            local noteLabel = main.createLabel(1, 1, window.sizeX, 1)
            noteLabel.foreColor = 0xFFFFFF
            noteLabel.backColor = 0x222222
            window.attachObj(1, 5, noteLabel)

            local mainNoteLabel = main.createLabel(1, 1, window.sizeX, 1, "управления заметкой к пину " .. tostring(i))
            mainNoteLabel.foreColor = 0xFFFFFF
            mainNoteLabel.backColor = 0x222222
            window.attachObj(1, 3, mainNoteLabel)

            local function updateText()
                noteLabel.text = cfg.notes[i] or "отсутствует"
                noteLabel.draw()
            end
            updateText()
            
            local input = main.createInputbox(1, 1, 18, 1, "новая заметка", function(read)
                cfg.notes[i] = read
                saveCfg()
                updateText()
                updateLabels()
                gui.redraw()
            end)
            input.backColor = 0xFFFFFF
            input.foreColor = 0x222222
            input.viewData = false
            window.attachObj(2, 9, input)

            local deleteNote = main.createButton(15, 1, 18, 1, "удалить заметку", function()
                cfg.notes[i] = false
                saveCfg()
                updateText()
                updateLabels()
                gui.redraw()
            end)
            deleteNote.backColor = 0xFFFFFF
            deleteNote.foreColor = 0x222222
            window.attachObj(window.sizeX - 19, 9, deleteNote)

            gui.redraw()
        else
            status("sending information...")
            nanoCall(nano.setInput, i, state)
            cfg.pins[i] = state
            saveCfg()
            gui.select(main)
        end
    end, 1, cfg.pins[i])
    table.insert(buttons, b)
    b.backColor = gui.selectColor(0xAAAAAA, nil, true)
    b.foreColor = gui.selectColor(0, nil, false)
    b.invertBackColor = b.foreColor
    b.invertForeColor = b.backColor
end
function updateLabels()
    for i = 1, #buttons do
        buttons[i].text = "pin: " .. tostring(i) .. ((cfg.notes[i] and (", note: " .. cfg.notes[i])) or "")
    end
end
updateLabels()

main.createButton(1, 1, 16, 1, "full upload", function()
    for i = 1, inputsCount do
        status("sending information (pin " .. tostring(i) .. ")")
        nanoCall(nano.setInput, i, cfg.pins[i])
    end
    gui.select(main)
end)

main.createButton(18, 1, 16, 1, "download data", function()
    for i = 1, inputsCount do
        status("getting information (pin " .. tostring(i) .. ")")
        cfg.pins[i] = nanoCall(nano.getInput, i)
        buttons[i].state = cfg.pins[i]
    end
    saveCfg()
    gui.select(main)
end)

local list = main.createList(34, 3, main.sizeX - 34 - 1, main.sizeY - 3 - 12)
list.autoScroll = false
list.autoRedraw = false
list.autoRemove = false
list.soundOn = false
list.addStr("ИНСТРУКЦИЯ(обязательна к прочтению)")
list.addStr("если вам кажиться что произошел рассинхрон - вам не кажеться")
list.addStr(string.rep("-", list.sizeX))
list.addStr("в случаи рассинхрона необходи нажать на кнопку download data")
list.addStr("чтобы скачать все данные, или нажать full upload чтобы")
list.addStr("отправить все")
list.addStr(string.rep("-", list.sizeX))
list.addStr("все пины сохраняються на диск")
list.addStr("для изменения состояния нажимайте на кнопки")
list.addStr(string.rep("-", list.sizeX))
list.addStr("если программа не будет открываться удалите конфигурационный файл")
list.addStr("(" .. cfgPath .. ") и нажмите download data")
list.addStr(string.rep("-", list.sizeX))
list.addStr("во время передачи данных нельзя ходить, иначе программа")
list.addStr("может зависнуть, если это произошло, закройте ее сочетаниям клавиш")
list.addStr("ctrl + alt + c и повторите действия")
list.addStr(string.rep("-", list.sizeX))
list.addStr("для упровления заметкой на пин нажмите на его кнопку правой")
list.addStr("кнопкой мыши")

local dataList = main.createList(34, list.posY + list.sizeY + 1, list.sizeX, 9)
dataList.autoRedraw = false
dataList.autoRemove = false
dataList.soundOn = false

local function refreshData()
    status("пожалуйста подождите...")

    dataList.clear()

    local name = tostring(nanoCall(nano.getName))
    if name then
        dataList.addStr("nikname: " .. name)
    end

    local power = tostring(nanoCall(nano.getPowerState))
    if power then
        dataList.addStr("power: " .. power)
    end

    local health = tostring(nanoCall(nano.getHealth))
    if health then
        dataList.addStr("health: " .. health)
    end

    local effects = nanoCall(nano.getActiveEffects)
    if effects then
        if type(effects) == "table" then effects = serialization.serialize(effects) end
        dataList.addStr("effects: " .. effects)
    end

    local selfInputs = tostring(nanoCall(nano.getSafeActiveInputs))
    if selfInputs then
        dataList.addStr("self inputs count: " .. selfInputs)
    end

    local maxInputs = tostring(nanoCall(nano.getMaxActiveInputs))
    if maxInputs then
        dataList.addStr("max inputs count: " .. maxInputs)
    end

    statusOff()

    dataList.draw()
end

main.createButton(34, main.sizeY - 1, list.sizeX, 1, "refresh", refreshData)

refreshData()

--------------------------------------------

gui.select(main)
gui.run()