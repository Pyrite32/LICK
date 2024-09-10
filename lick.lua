-- lick.lua
--
-- simple LIVECODING environment for Löve
-- overwrites love.run, pressing all errors to the terminal/console or overlays it
local lick = {}
lick.main = "main.lua"
lick.conf = "conf.lua"
lick.debug = false
lick.reset = false
lick.clearFlag = false
lick.sleepTime = love.graphics.newCanvas and 0.001 or 1
lick.showReloadMessage = true
lick.sourceDirectory = 'src'

local drawok_old, updateok_old, loadok_old
local last_modified = 0
local debugoutput = nil
local last_modified_file_list = 0

local fileList = {}

-- Error handler wrapping for pcall
local function handle(err)
    return "ERROR: " .. err
end

-- Initialization
local function load()
    last_modified = 0
end

---comment
---@param ... unknown
---@return unknown
local function combinePath(a, b)
    return a .. '/' .. b
end

---comment
---@param directoryStr string
---@param fileInfoTable table
---@return nil
local function populateFileList(directoryStr, fileInfoTable)
    -- does path exist?
    local info = love.filesystem.getInfo(lick.sourceDirectory);
    if not info or info.type ~= 'directory' then
        print("sourceDirectory: " .. lick.sourceDirectory .. " is not a directory!")
        return
    end

    local childFilesAndDirectories = love.filesystem.getDirectoryItems(directoryStr)

    for _, value in ipairs(childFilesAndDirectories) do
        local info = love.filesystem.getInfo(combinePath(directoryStr, value))
        if info then
            if info.type == 'directory' then
                local path = combinePath(directoryStr, value)
                populateFileList(path, fileInfoTable)
            else
                local path = combinePath(directoryStr, value)
                table.insert(fileInfoTable, { path = path, info = info })
            end
        end
    end
end


local function checkFileUpdate()

    local mainFileInfo = love.filesystem.getInfo(lick.main)
    if not mainFileInfo then
        print("could not find the file " .. lick.main)
        return
    end

    local confFileInfo = love.filesystem.getInfo(lick.conf)
    if not confFileInfo then
        print("could not find the file " .. lick.conf)
        return
    end

    local file_recently_changed = last_modified < mainFileInfo.modtime or
        last_modified < confFileInfo.modtime

    if not file_recently_changed then
        for _, file in ipairs(fileList) do
            if file then
                if last_modified < file.info.modtime then
                    file_recently_changed = true
                    last_modified = file.info.modtime
                    break
                end
            end
        end
        if not file_recently_changed then return end -- no files changed.
    else
        -- either main or conf recently changed.
        last_modified = math.max(mainFileInfo.modtime, confFileInfo.modtime)
    end

    local success, chunk = pcall(love.filesystem.load, lick.main)
    if not success then
        print(tostring(chunk))
        debugoutput = chunk .. "\n"
    end
    local ok, err = xpcall(chunk, handle)

    if not ok then
        print(tostring(err))
        if debugoutput then
            debugoutput = (debugoutput .. "ERROR: " .. err .. "\n")
        else
            debugoutput = err .. "\n"
        end
    else
        if lick.showReloadMessage then print("CHUNK LOADED\n") end
        debugoutput = nil
    end
    if lick.reset then
        local loadok, err = xpcall(love.load, handle)
        if not loadok and not loadok_old then
            print("ERROR: " .. tostring(err))
            if debugoutput then
                debugoutput = (debugoutput .. "ERROR: " .. err .. "\n")
            else
                debugoutput = err .. "\n"
            end
            loadok_old = not loadok
        end
    end
end

local function update(dt)
    checkFileUpdate()

    last_modified_file_list = last_modified_file_list + dt
    if last_modified_file_list >= 1.0 then
        last_modified_file_list = 0
        for k, _ in pairs(fileList) do
            fileList[k] = nil
        end
        populateFileList(lick.sourceDirectory, fileList)
    end

    local updateok, err = pcall(love.update, dt)
    if not updateok and not updateok_old then
        print("ERROR: " .. tostring(err))
        if debugoutput then
            debugoutput = (debugoutput .. "ERROR: " .. err .. "\n")
        else
            debugoutput = err .. "\n"
        end
    end
    updateok_old = not updateok
end

local function draw()
    local drawok, err = xpcall(love.draw, handle)
    if not drawok and not drawok_old then
        print(tostring(err))
        if debugoutput then
            debugoutput = (debugoutput .. err .. "\n")
        else
            debugoutput = err .. "\n"
        end
    end

    if lick.debug and debugoutput then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf(debugoutput, (love.graphics.getWidth() / 2) + 50, 0, 400, "right")
    end
    drawok_old = not drawok
end


function love.run()
    math.randomseed(os.time())
    math.random()
    math.random()
    load()

    local dt = 0

    -- Main loop time.
    while true do
        -- Process events.
        if love.event then
            love.event.pump()
            for e, a, b, c, d in love.event.poll() do
                if e == "quit" then
                    if not love.quit or not love.quit() then
                        if love.audio then
                            love.audio.stop()
                        end
                        return
                    end
                end

                love.handlers[e](a, b, c, d)
            end
        end

        -- Update dt, as we'll be passing it to update
        if love.timer then
            love.timer.step()
            dt = love.timer.getDelta()
        end

        -- Call update and draw
        if update then update(dt) end -- will pass 0 if love.timer is disabled
        if love.graphics then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if draw then draw() end
        end

        if love.timer then love.timer.sleep(lick.sleepTime) end
        if love.graphics then love.graphics.present() end
    end
end

return lick
