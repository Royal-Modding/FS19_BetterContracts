--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 19/10/2020

BetterContracts = {}
BetterContracts.name = "BetterContracts"
BetterContracts.fieldToMission = {}
BetterContracts.fieldToMissionUpdateTimeout = 5000
BetterContracts.fieldToMissionUpdateTimer = 5000

function BetterContracts:loadMap()
    MissionManager.MAX_MISSIONS_PER_GENERATION = 25
    MissionManager.MAX_TRIES_PER_GENERATION = 50

    MissionManager.MAX_MISSIONS = 200
    MissionManager.MISSION_GENERATION_INTERVAL = 1200000

    MissionManager.MAX_TRANSPORT_MISSIONS = 10

    MissionManager.AI_PRICE_MULTIPLIER = 2

    MissionManager.hasFarmActiveMission = Utils.overwrittenFunction(MissionManager.hasFarmActiveMission, BetterContracts.hasFarmActiveMission)

    InGameMenuContractsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuContractsFrame.onFrameOpen, BetterContracts.onContractsFrameOpen)
    InGameMenuContractsFrame.onFrameClose = Utils.appendedFunction(InGameMenuContractsFrame.onFrameClose, BetterContracts.onContractsFrameClose)

    g_currentMission.inGameMenu.onClickMenuExtra1 = Utils.overwrittenFunction(g_currentMission.inGameMenu.onClickMenuExtra1, BetterContracts.onClickMenuExtra1)

    --addConsoleCommand("dcDebugMissions", "", "debugMissions", self)
end

--function BetterContracts:debugMissions()
--    DebugUtil.printTableRecursively(g_missionManager.missions, nil, nil, 1)
--end

function BetterContracts:update(dt)
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

function BetterContracts:onClickMenuExtra1(superFunc, ...)
    if superFunc ~= nil then
        superFunc(self, ...)
    end
    if self.refreshContractsButton ~= nil then
        self.refreshContractsButton.onClickCallback(self)
    end
end

function BetterContracts:onClickRefreshCallback()
    BetterContractsRefreshEvent.sendEvent()
end

-- this should grant to accept multiple contracts
function BetterContracts:hasFarmActiveMission()
    return false
end

function BetterContracts.colorForFarm(farmId)
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

                local r, g, b, _ = BetterContracts.colorForFarm(mission.farmId)
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

addModEventListener(BetterContracts)
