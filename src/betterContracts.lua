---${title}

---@author ${author}
---@version r_version_r
---@date 19/10/2020

InitRoyalUtility(Utils.getFilename("lib/utility/", g_currentModDirectory))
InitRoyalMod(Utils.getFilename("lib/rmod/", g_currentModDirectory))

---@class BetterContracts : RoyalMod
BetterContracts = RoyalMod.new(r_debug_r, false)
BetterContracts.fieldToMission = {}
BetterContracts.fieldToMissionUpdateTimeout = 5000
BetterContracts.fieldToMissionUpdateTimer = 5000

function BetterContracts:initialize()
    Utility.overwrittenFunction(MissionManager, "hasFarmActiveMission", BetterContracts.hasFarmActiveMission)
    Utility.appendedFunction(InGameMenuContractsFrame, "onFrameOpen", BetterContracts.onContractsFrameOpen)
    Utility.appendedFunction(InGameMenuContractsFrame, "onFrameClose", BetterContracts.onContractsFrameClose)

    Utility.appendedFunction(Vehicle, "load", BetterContracts.vLoad)

    addConsoleCommand("bcDebugMissions", "", "debugMissions", self)
end

function BetterContracts:vLoad(...)
    print("###############")
    print(self.configFileName)
    print("###############")
end

function BetterContracts:onMissionInitialize(baseDirectory, missionCollaborators)
    MissionManager.AI_PRICE_MULTIPLIER = 1.5
    MissionManager.MISSION_GENERATION_INTERVAL = 3600000 -- every 1 game hour
end

function BetterContracts:onSetMissionInfo(missionInfo, missionDynamicInfo)
    Utility.overwrittenFunction(g_currentMission.inGameMenu, "onClickMenuExtra1", BetterContracts.onClickMenuExtra1)
end

function BetterContracts:onLoad()
    print(Utils.getFilename("$data/vehicles/fendt/fendt700/fendt700.xml"))
end

function BetterContracts:onPreLoadMap(mapFile)
end

function BetterContracts:onCreateStartPoint(startPointNode)
end

function BetterContracts:onLoadMap(mapNode, mapFile)
end

function BetterContracts:onPostLoadMap(mapNode, mapFile)
    local fieldsAmount = TableUtility.count(g_fieldManager.fields)
    local adjustedFieldsAmount = math.max(fieldsAmount, 40)
    MissionManager.MAX_MISSIONS = math.min(100, math.ceil(adjustedFieldsAmount * 0.60)) -- max missions = 60% of fields amount (minimum 40 fields) max 100
    MissionManager.MAX_TRANSPORT_MISSIONS = math.max(math.ceil(MissionManager.MAX_MISSIONS / 20), 2) -- max transport missions is 1/20 of maximum missions but not less then 2
    MissionManager.MAX_MISSIONS = MissionManager.MAX_MISSIONS + MissionManager.MAX_TRANSPORT_MISSIONS -- add max transport missions to max missions
    MissionManager.MAX_MISSIONS_PER_GENERATION = math.min(MissionManager.MAX_MISSIONS, 50) -- max missions per generation = max mission but not more then 50
    MissionManager.MAX_TRIES_PER_GENERATION = math.ceil(MissionManager.MAX_MISSIONS_PER_GENERATION * 1.5) -- max tries per generation 50% more then max missions per generation
    g_logManager:devInfo("[%s] Fields amount %s (%s)", self.name, fieldsAmount, adjustedFieldsAmount)
    g_logManager:devInfo("[%s] MAX_MISSIONS set to %s", self.name, MissionManager.MAX_MISSIONS)
    g_logManager:devInfo("[%s] MAX_TRANSPORT_MISSIONS set to %s", self.name, MissionManager.MAX_TRANSPORT_MISSIONS)
    g_logManager:devInfo("[%s] MAX_MISSIONS_PER_GENERATION set to %s", self.name, MissionManager.MAX_MISSIONS_PER_GENERATION)
    g_logManager:devInfo("[%s] MAX_TRIES_PER_GENERATION set to %s", self.name, MissionManager.MAX_TRIES_PER_GENERATION)
end

function BetterContracts:onLoadSavegame(savegameDirectory, savegameIndex)
end

function BetterContracts:onPreLoadVehicles(xmlFile, resetVehicles)
end

function BetterContracts:onPreLoadItems(xmlFile)
end

function BetterContracts:onPreLoadOnCreateLoadedObjects(xmlFile)
end

function BetterContracts:onLoadFinished()
end

function BetterContracts:onStartMission()
end

function BetterContracts:onMissionStarted()
end

function BetterContracts:onWriteStream(streamId)
end

function BetterContracts:onReadStream(streamId)
end

function BetterContracts:onUpdate(dt)
    self.fieldToMissionUpdateTimer = self.fieldToMissionUpdateTimer + dt
    if self.fieldToMissionUpdateTimer >= self.fieldToMissionUpdateTimeout then
        self.fieldToMission = {}
        for _, mission in pairs(g_missionManager.missions) do
            if mission.field ~= nil then
                self.fieldToMission[mission.field.fieldId] = mission
            end
        end
        self.fieldToMissionUpdateTimer = 0
    end
end

function BetterContracts:onUpdateTick(dt)
end

function BetterContracts:onWriteUpdateStream(streamId, connection, dirtyMask)
end

function BetterContracts:onReadUpdateStream(streamId, timestamp, connection)
end

function BetterContracts:onMouseEvent(posX, posY, isDown, isUp, button)
end

function BetterContracts:onKeyEvent(unicode, sym, modifier, isDown)
end

function BetterContracts:onDraw()
end

function BetterContracts:onPreSaveSavegame(savegameDirectory, savegameIndex)
end

function BetterContracts:onPostSaveSavegame(savegameDirectory, savegameIndex)
end

function BetterContracts:onPreDeleteMap()
end

function BetterContracts:onDeleteMap()
end

function BetterContracts:onLoadHelpLine()
    --return self.directory .. "gui/helpLine.xml"
end

function BetterContracts:debugMissions()
    DebugUtil.printTableRecursively(MissionManager, nil, nil, 1)
    print("")
    print("#########################")
    print("#########################")
    print("#########################")
    print("#########################")
    print("")
    DebugUtil.printTableRecursively(g_missionManager.missionVehicles, nil, nil, 6)
end

function BetterContracts:onContractsFrameOpen()
    -- add button for contracts refreshing
    if g_currentMission.inGameMenu.refreshContractsButton == nil then
        g_currentMission.inGameMenu.refreshContractsButton = g_currentMission.inGameMenu.menuButton[1]:clone(self)
        g_currentMission.inGameMenu.refreshContractsButton.onClickCallback = BetterContracts.onClickRefreshCallback
        g_currentMission.inGameMenu.refreshContractsButton:setText(g_i18n:getText("refresh_contracts"))
        g_currentMission.inGameMenu.refreshContractsButton:setInputAction("MENU_EXTRA_1")
        g_currentMission.inGameMenu.menuButton[1].parent:addElement(g_currentMission.inGameMenu.refreshContractsButton)
    end
end

function BetterContracts:onContractsFrameClose()
    -- remove button for contracts refreshing
    if g_currentMission.inGameMenu.refreshContractsButton ~= nil then
        g_currentMission.inGameMenu.refreshContractsButton:unlinkElement()
        g_currentMission.inGameMenu.refreshContractsButton:delete()
        g_currentMission.inGameMenu.refreshContractsButton = nil
    end
end

function BetterContracts.onClickMenuExtra1(inGameMenu, superFunc, ...)
    if superFunc ~= nil then
        superFunc(inGameMenu, ...)
    end
    if inGameMenu.refreshContractsButton ~= nil then
        inGameMenu.refreshContractsButton.onClickCallback(inGameMenu)
    end
end

function BetterContracts:onClickRefreshCallback()
    BetterContractsRefreshEvent.sendEvent()
end

-- this should grant to accept multiple contracts
function BetterContracts:hasFarmActiveMission()
    return false
end

function BetterContracts.colorByFarmId(farmId)
    local farm = g_farmManager:getFarmById(farmId)
    if farm ~= nil then
        local color = Farm.COLORS[farm.color]
        if color ~= nil then
            return color[1], color[2], color[3], color[4]
        end
    end
    return 1, 1, 1, 1
end

function MapHotspot:render(minX, maxX, minY, maxY, scale, drawText)
    if self:getIsVisible() and self.enabled then
        scale = scale or 1

        -- draw bg
        self.overlayBg:setDimension(self.width * self.zoom * scale, self.height * self.zoom * scale)
        self.overlayBg:setPosition(self.x, self.y)

        if not self:getIsActive() then
            self.overlayBg:setColor(unpack(MapHotspot.COLOR.INACTIVE))
        else
            self.overlayBg:setColor(unpack(self.bgImageColor))
        end

        local overlay = self:getOverlay(self.height * self.zoom * g_screenHeight)
        local overlayPosY = self.overlayBg.y + self.overlayBg.height - overlay.height
        if self.verticalAlignment == Overlay.ALIGN_VERTICAL_MIDDLE then
            overlayPosY = self.overlayBg.y + (self.overlayBg.height - overlay.height) * 0.5
        elseif self.verticalAlignment == Overlay.ALIGN_VERTICAL_BOTTOM then
            overlayPosY = self.overlayBg.y
        end

        overlay:setDimension(self.overlayBg.width * self.iconScale, self.overlayBg.height * self.iconScale)
        overlay:setPosition(self.x + self.overlayBg.width * 0.5 - overlay.width * 0.5, overlayPosY)

        if self.blinking then
            self.overlayBg:setColor(nil, nil, nil, IngameMap.alpha)
            overlay:setColor(nil, nil, nil, IngameMap.alpha)
        end

        self.overlayBg:render()
        overlay:render()

        local doRenderText = self.showNameDefault and self.fullViewName ~= "" and (drawText or self.renderLast)
        doRenderText = doRenderText or self.category == MapHotspot.CATEGORY_AI or self.category == MapHotspot.CATEGORY_FIELD_DEFINITION

        if doRenderText then
            if self.category == MapHotspot.CATEGORY_FIELD_DEFINITION and BetterContracts.fieldToMission[tonumber(self.fullViewName)] and BetterContracts.fieldToMission[tonumber(self.fullViewName)].status ~= 0 then
                -- render custom field number
                local mission = BetterContracts.fieldToMission[tonumber(self.fullViewName)]

                setTextBold(true)
                setTextAlignment(self.textAlignment)
                local alpha = 1
                if not mission.success then
                    alpha = IngameMap.alpha
                end
                setTextColor(0, 0, 0, alpha)

                local posX = self.x + (0.5 * self.width + self.textOffsetX) * self.zoom * scale
                local posY = self.y - (self.textSize - self.textOffsetY) * self.zoom * scale

                renderText(posX, posY - 1 / g_screenHeight, self.textSize * self.zoom * scale, self.fullViewName)

                local r, g, b, _ = BetterContracts.colorByFarmId(mission.farmId)
                setTextColor(r, g, b, alpha)

                renderText(posX + 1 / g_screenWidth, posY, self.textSize * self.zoom * scale, self.fullViewName)
                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextColor(1, 1, 1, 1)
            else
                setTextBold(self.textBold)
                setTextAlignment(self.textAlignment)
                local alpha = 1
                if self.blinking then
                    alpha = IngameMap.alpha
                end
                setTextColor(0, 0, 0, 1)

                local posX = self.x + (0.5 * self.width + self.textOffsetX) * self.zoom * scale
                local posY = self.y - (self.textSize - self.textOffsetY) * self.zoom * scale
                local textWidth = getTextWidth(self.textSize * self.zoom * scale, self.fullViewName) + 1 / g_screenWidth

                if self.category ~= MapHotspot.CATEGORY_FIELD_DEFINITION then
                    posX = math.min(math.max(posX, minX + textWidth * 0.5), maxX - textWidth * 0.5)
                    posY = math.min(math.max(posY, minY), maxY - self.textSize * self.zoom * scale)
                end

                renderText(posX, posY - 1 / g_screenHeight, self.textSize * self.zoom * scale, self.fullViewName)

                setTextColor(self.textColor[1], self.textColor[2], self.textColor[3], alpha)

                renderText(posX + 1 / g_screenWidth, posY, self.textSize * self.zoom * scale, self.fullViewName)
                setTextAlignment(RenderText.ALIGN_LEFT)
                setTextColor(1, 1, 1, 1)
            end
        end
    end
end
