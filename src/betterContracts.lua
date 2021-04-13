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
    g_missionManager.missionMapNumChannels = 6

    if g_modIsLoaded["FS19_RefreshContracts"] then
        self.needsRefreshContractsConflictsPrevention = true
    end

    if g_modIsLoaded["FS19_MoreMissionsAllowed"] then
        self.needsMoreMissionsAllowedConflictsPrevention = true
    end

    if not self.needsMoreMissionsAllowedConflictsPrevention then
        MissionManager.hasFarmActiveMission = BetterContracts.hasFarmActiveMission
    end
    Utility.overwrittenFunction(MissionManager, "loadMissionVehicles", BetterContracts.loadMissionVehicles)

    Utility.overwrittenFunction(InGameMenuContractsFrame, "sortList", BetterContracts.sortList)

    Utility.overwrittenFunction(InGameMenuContractsFrame, "onFrameOpen", BetterContracts.onContractsFrameOpen)
    Utility.appendedFunction(InGameMenuContractsFrame, "onFrameClose", BetterContracts.onContractsFrameClose)
end

---@param missionManager MissionManager
---@param superFunc function
---@return boolean
function BetterContracts.loadMissionVehicles(missionManager, superFunc, ...)
    local self = BetterContracts
    if superFunc(missionManager, ...) then
        if g_modIsLoaded["FS19_ThueringerHoehe_BG_Edition"] then
            g_logManager:devInfo("[%s] %s map detected, loading mission vehicles created by %s", self.name, "FS19_ThueringerHoehe", "Lahmi")
            missionManager.missionVehicles = {}
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/FS19_ThueringerHoehe/baseGame.xml")
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/FS19_ThueringerHoehe/claasPack.xml")
        else
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/baseGame.xml")
            self:loadExtraMissionVehicles(self.directory .. "missionVehicles/claasPack.xml")
        end
        return true
    end
    return false
end

function BetterContracts:loadExtraMissionVehicles(xmlFilename)
    local xmlFile = loadXMLFile("loadExtraMissionVehicles", xmlFilename)
    local modDirectory = nil
    local requiredMod = getXMLString(xmlFile, "missionVehicles#requiredMod")
    local hasRequiredMod = false
    if requiredMod ~= nil and g_modIsLoaded[requiredMod] then
        modDirectory = g_modNameToDirectory[requiredMod]
        hasRequiredMod = true
    end
    if hasRequiredMod or requiredMod == nil then
        local index = 0
        while true do
            local baseKey = string.format("missionVehicles.mission(%d)", index)
            if hasXMLProperty(xmlFile, baseKey) then
                local missionType = getXMLString(xmlFile, baseKey .. "#type") or ""
                if missionType ~= "" then
                    if g_missionManager.missionVehicles[missionType] == nil then
                        g_missionManager.missionVehicles[missionType] = {}
                        g_missionManager.missionVehicles[missionType].small = {}
                        g_missionManager.missionVehicles[missionType].medium = {}
                        g_missionManager.missionVehicles[missionType].large = {}
                    end
                    self:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
                end
            else
                break
            end
            index = index + 1
        end
    end
    delete(xmlFile)
end

function BetterContracts:loadExtraMissionVehicles_groups(xmlFile, baseKey, missionType, modDirectory)
    local index = 0
    while true do
        local groupKey = string.format("%s.group(%d)", baseKey, index)
        if hasXMLProperty(xmlFile, groupKey) then
            local group = {}
            local fieldSize = getXMLString(xmlFile, groupKey .. "#fieldSize") or "missingFieldSize"
            group.variant = getXMLString(xmlFile, groupKey .. "#variant")
            group.rewardScale = getXMLFloat(xmlFile, groupKey .. "#rewardScale") or 1
            group.identifier = #g_missionManager.missionVehicles[missionType][fieldSize] + 1
            group.vehicles = self:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
            table.insert(g_missionManager.missionVehicles[missionType][fieldSize], group)
        else
            break
        end
        index = index + 1
    end
end

function BetterContracts:loadExtraMissionVehicles_vehicles(xmlFile, groupKey, modDirectory)
    local index = 0
    local vehicles = {}
    while true do
        local vehicleKey = string.format("%s.vehicle(%d)", groupKey, index)
        if hasXMLProperty(xmlFile, vehicleKey) then
            local vehicle = {}
            local baseDirectory = nil
            if getXMLBool(xmlFile, vehicleKey .. "#isMod") then
                baseDirectory = modDirectory
            end
            vehicle.filename = Utils.getFilename(getXMLString(xmlFile, vehicleKey .. "#filename") or "missingFilename", baseDirectory)
            vehicle.configurations = self:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
            table.insert(vehicles, vehicle)
        else
            break
        end
        index = index + 1
    end
    return vehicles
end

function BetterContracts:loadExtraMissionVehicles_configurations(xmlFile, vehicleKey)
    local index = 0
    local configurations = {}
    while true do
        local configurationKey = string.format("%s.configuration(%d)", vehicleKey, index)
        if hasXMLProperty(xmlFile, configurationKey) then
            local name = getXMLString(xmlFile, configurationKey .. "#name") or "missingName"
            local id = getXMLInt(xmlFile, configurationKey .. "#id") or 1
            configurations[name] = id
        else
            break
        end
        index = index + 1
    end
    return configurations
end

function BetterContracts:onMissionInitialize(baseDirectory, missionCollaborators)
    MissionManager.AI_PRICE_MULTIPLIER = 1.5
    MissionManager.MISSION_GENERATION_INTERVAL = 3600000 -- every 1 game hour
end

function BetterContracts:onSetMissionInfo(missionInfo, missionDynamicInfo)
    Utility.overwrittenFunction(g_currentMission.inGameMenu, "onClickMenuExtra1", BetterContracts.onClickMenuExtra1)
    Utility.overwrittenFunction(g_currentMission.inGameMenu, "onClickMenuExtra2", BetterContracts.onClickMenuExtra2)
end

function BetterContracts:onPostLoadMap(mapNode, mapFile)
    local fieldsAmount = TableUtility.count(g_fieldManager.fields)
    local adjustedFieldsAmount = math.max(fieldsAmount, 45)
    MissionManager.MAX_MISSIONS = math.min(120, math.ceil(adjustedFieldsAmount * 0.60)) -- max missions = 60% of fields amount (minimum 45 fields) max 120
    MissionManager.MAX_TRANSPORT_MISSIONS = math.max(math.ceil(MissionManager.MAX_MISSIONS / 15), 2) -- max transport missions is 1/15 of maximum missions but not less then 2
    MissionManager.MAX_MISSIONS = MissionManager.MAX_MISSIONS + MissionManager.MAX_TRANSPORT_MISSIONS -- add max transport missions to max missions
    MissionManager.MAX_MISSIONS_PER_GENERATION = math.min(MissionManager.MAX_MISSIONS / 5, 30) -- max missions per generation = max mission / 5 but not more then 30
    MissionManager.MAX_TRIES_PER_GENERATION = math.ceil(MissionManager.MAX_MISSIONS_PER_GENERATION * 1.5) -- max tries per generation 50% more then max missions per generation
    g_logManager:devInfo("[%s] Fields amount %s (%s)", self.name, fieldsAmount, adjustedFieldsAmount)
    g_logManager:devInfo("[%s] MAX_MISSIONS set to %s", self.name, MissionManager.MAX_MISSIONS)
    g_logManager:devInfo("[%s] MAX_TRANSPORT_MISSIONS set to %s", self.name, MissionManager.MAX_TRANSPORT_MISSIONS)
    g_logManager:devInfo("[%s] MAX_MISSIONS_PER_GENERATION set to %s", self.name, MissionManager.MAX_MISSIONS_PER_GENERATION)
    g_logManager:devInfo("[%s] MAX_TRIES_PER_GENERATION set to %s", self.name, MissionManager.MAX_TRIES_PER_GENERATION)
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

function BetterContracts.sortList(pageContracts, superFunc, ...)
    -- sort by mission type and field number (multiply mission type by a big number to make it the first sorting parameter)
    table.sort(
        pageContracts.contracts,
        function(c1, c2)
            local c1V = c1.mission.type.typeId * -1000
            if c1.mission.field ~= nil then
                c1V = c1V + c1.mission.field.fieldId
            end
            if c1.active then
                c1V = c1V - 100000
            end
            if c1.finished then
                if c1.mission.success then
                    c1V = c1V - 1000000
                else
                    c1V = c1V - 50000
                end
            end

            local c2V = c2.mission.type.typeId * -1000
            if c2.mission.field ~= nil then
                c2V = c2V + c2.mission.field.fieldId
            end
            if c2.active then
                c2V = c2V - 100000
            end
            if c2.finished then
                if c2.mission.success then
                    c2V = c2V - 1000000
                else
                    c2V = c2V - 50000
                end
            end

            return c1V < c2V
        end
    )
end

function BetterContracts:onContractsFrameOpen(superFunc, ...)
    if BetterContracts.needsRefreshContractsConflictsPrevention then
        -- this will prevent execution of FS19_RefreshContracts code (because they check for that field to be nil)
        g_currentMission.inGameMenu.refreshContractsElement_Button = 1
    end
    superFunc(self, ...)
    g_currentMission.inGameMenu.refreshContractsElement_Button = nil

    -- add new buttons
    if g_currentMission.inGameMenu.newContractsButton == nil then
        g_currentMission.inGameMenu.newContractsButton = g_currentMission.inGameMenu.menuButton[1]:clone(self)
        g_currentMission.inGameMenu.newContractsButton.onClickCallback = BetterContracts.onClickNewContractsCallback
        g_currentMission.inGameMenu.newContractsButton:setText(g_i18n:getText("bc_new_contracts"))
        g_currentMission.inGameMenu.newContractsButton:setInputAction("MENU_EXTRA_1")
        g_currentMission.inGameMenu.menuButton[1].parent:addElement(g_currentMission.inGameMenu.newContractsButton)
    end

    if g_currentMission.inGameMenu.clearContractsButton == nil then
        g_currentMission.inGameMenu.clearContractsButton = g_currentMission.inGameMenu.menuButton[1]:clone(self)
        g_currentMission.inGameMenu.clearContractsButton.onClickCallback = BetterContracts.onClickClearContractsCallback
        g_currentMission.inGameMenu.clearContractsButton:setText(g_i18n:getText("bc_clear_contracts"))
        g_currentMission.inGameMenu.clearContractsButton:setInputAction("MENU_EXTRA_2")
        g_currentMission.inGameMenu.menuButton[1].parent:addElement(g_currentMission.inGameMenu.clearContractsButton)
    end
end

function BetterContracts:onContractsFrameClose()
    -- remove new buttons
    if g_currentMission.inGameMenu.newContractsButton ~= nil then
        g_currentMission.inGameMenu.newContractsButton:unlinkElement()
        g_currentMission.inGameMenu.newContractsButton:delete()
        g_currentMission.inGameMenu.newContractsButton = nil
    end

    if g_currentMission.inGameMenu.clearContractsButton ~= nil then
        g_currentMission.inGameMenu.clearContractsButton:unlinkElement()
        g_currentMission.inGameMenu.clearContractsButton:delete()
        g_currentMission.inGameMenu.clearContractsButton = nil
    end
end

function BetterContracts.onClickMenuExtra1(inGameMenu, superFunc, ...)
    if superFunc ~= nil then
        superFunc(inGameMenu, ...)
    end
    if inGameMenu.newContractsButton ~= nil then
        inGameMenu.newContractsButton.onClickCallback(inGameMenu)
    end
end

function BetterContracts.onClickMenuExtra2(inGameMenu, superFunc, ...)
    if superFunc ~= nil then
        superFunc(inGameMenu, ...)
    end
    if inGameMenu.clearContractsButton ~= nil then
        inGameMenu.clearContractsButton.onClickCallback(inGameMenu)
    end
end

function BetterContracts.onClickNewContractsCallback(inGameMenu)
    BetterContractsNewEvent.sendEvent()
end

function BetterContracts.onClickClearContractsCallback(inGameMenu)
    BetterContractsClearEvent.sendEvent()
end

---@param missionManager MissionManager
---@param farmId integer
---@return boolean
function BetterContracts.hasFarmActiveMission(missionManager, farmId)
    local activeMissionsCount = 0
    for _, mission in ipairs(missionManager.missions) do
        if mission.farmId == farmId and (mission.status == AbstractMission.STATUS_RUNNING or mission.status == AbstractMission.STATUS_FINISHED) then
            activeMissionsCount = activeMissionsCount + 1
        end
    end
    return activeMissionsCount >= 2 ^ missionManager.missionMapNumChannels - 1
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

                local r, g, b, _ = unpack(GameplayUtility.getFarmColor(mission.farmId))
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
