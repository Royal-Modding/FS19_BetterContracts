---${title}

---@author ${author}
---@version r_version_r
---@date 19/10/2020

InitRoyalUtility(Utils.getFilename("lib/utility/", g_currentModDirectory))
InitRoyalMod(Utils.getFilename("lib/rmod/", g_currentModDirectory))

---@class BetterContracts : RoyalMod
r_debug_r = true
SC= {                               
    FERTILIZER  = 1,    -- prices index
    LIQUIDFERT  = 2,
    HERBICIDE   = 3,
    SEEDS       = 4,
    CONTROLS    = {
        npcbox  = "npcbox",
        sortbox = "sortbox",
        layout  = "layout",
        filltype = "filltype",
        line3   = "line3",
        line4a  = "line4a",
        line4b  = "line4b",
        line5   = "line5",
        line6   = "line6",
        field   = "field",
        dimen   = "dimen",  
        etime   = "etime",   
        valu4a  = "valu4a",
        valu4b  = "valu4b",
        price   = "price",
        valu6   = "valu6",
        valu7   = "valu7",
        sortcat = "sortcat",
        sortprof = "sortprof",
        sortpmin = "sortpmin",
        helpsort = "helpsort",
    }
}
BetterContracts = RoyalMod.new(r_debug_r, false)
BetterContracts.fieldToMission = {}
BetterContracts.fieldToMissionUpdateTimeout = 5000
BetterContracts.fieldToMissionUpdateTimer = 5000

function BetterContracts:initialize()
    g_missionManager.missionMapNumChannels = 6
    self.turnTime   = 5.0               -- estimated seconds per turn at end of each lane
    self.events     = {}            
    self.initialized= false
                    --  Kuhn Axis402    Hardi Mega      Väderst Rapid   Väderst Tempo   mission
                    --  def spreader    def sprayer     def sower       def planter     vehicle
    self.SPEEDLIMS  = { 20,             12,             18,             15,             0} -- SPEEDLIMIT
    self.WORKWIDTH  = { 24,             24,              6,              6,             0} -- WORKWIDTH
    
    self.typeToCat  = {4,3,3,2,1,3,2,2,5}   -- mission.type to self category: harvest, spread, simple, mow, transport
    self.harvest    = {}                -- mow and harvest missions
    self.spread     = {}                -- sow, spray, fertilize 
    self.simple     = {}                -- plow, cultivate, weed
    self.transp     = {}                -- transport
    self.baling     = {}                -- mow/ bale
    self.IdToCont   = {}                -- to find a contract from its mission id 
    self.catHarvest = "BEETHARVESTING CORNHEADERS COTTONVEHICLES CUTTERS POTATOHARVESTING POTATOVEHICLES SUGARCANEHARVESTING"
    self.catSpread  = "fertilizerspreaders seeders planters sprayers sprayervehicles"
    self.catSimple  = "CULTIVATORS DISCHARROWS PLOWS POWERHARROWS SUBSOILERS WEEDERS"
    self.missionUpdTimeout  = 15000
    self.missionUpdTimer    = 0
    self.isOn       = false
    self.numCont    = 0                 -- # of contracts in our tables
    self.my         = {}                -- will hold my gui element adresses
    self.sort       = 0                 -- sorted status: 1 cat, 2 prof, 3 permin
    self.lastSort   = 0                 -- last sorted status
    self.buttons    = {
        {"sortcat",  g_i18n:getText("SC_sortCat")}, -- {button id, help text}
        {"sortprof", g_i18n:getText("SC_sortProf")}, 
        {"sortpmin", g_i18n:getText("SC_sortpMin")}, 
    }

    -- make my Gui texts global, needed for my Gui profilesd to work
    local gTexts = self.gameEnv.g_i18n.texts
    for k, v in pairs (g_i18n.texts) do
        local prefix, _ = k:find("SC_", 1, true)
        if prefix ~= nil then gTexts[k] = v; end
    end
    self.gameEnv["g_betterContracts"] = self

    if g_modIsLoaded["FS19_RefreshContracts"] then
        self.needsRefreshContractsConflictsPrevention = true
    end

    Utility.overwrittenFunction(MissionManager, "loadMissionVehicles", BetterContracts.loadMissionVehicles)

    -- Append functions for ingame menu contracts frame 
    InGameMenuContractsFrame.onFrameOpen  = 
    Utils.overwrittenFunction(InGameMenuContractsFrame.onFrameOpen, onFrameOpen)
    InGameMenuContractsFrame.onFrameClose = 
    Utils.appendedFunction(InGameMenuContractsFrame.onFrameClose, onFrameClose)
    InGameMenuContractsFrame.updateFarmersBox = 
    Utils.appendedFunction(InGameMenuContractsFrame.updateFarmersBox, updateFarmersBox)
    InGameMenuContractsFrame.assignContractToListItem = 
    Utils.appendedFunction(InGameMenuContractsFrame.assignContractToListItem, assignListItem)
    InGameMenuContractsFrame.updateList = 
    Utils.prependedFunction(InGameMenuContractsFrame.updateList, updateList)
    InGameMenuContractsFrame.sortList = 
    Utils.overwrittenFunction(InGameMenuContractsFrame.sortList, sortList)
    -- to allow multiple missions:
    MissionManager.hasFarmActiveMission =
    Utils.overwrittenFunction(nil, function() return false end)
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

function BetterContracts:onMissionInitialize(baseDirectory, missionCollaborators)
    MissionManager.AI_PRICE_MULTIPLIER = 1.5
    MissionManager.MISSION_GENERATION_INTERVAL = 3600000 -- every 1 game hour
end

function BetterContracts:onSetMissionInfo(missionInfo, missionDynamicInfo)
    Utility.overwrittenFunction(g_currentMission.inGameMenu, "onClickMenuExtra1", onClickMenuExtra1)
    Utility.overwrittenFunction(g_currentMission.inGameMenu, "onClickMenuExtra2", onClickMenuExtra2)
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

    -- initialize constants depending on game manager instances
    self.ft     = g_fillTypeManager.fillTypes
    self.miss   = g_missionManager.missions
    self.prices = {-- storeprices per 1000 l 
        g_storeManager.xmlFilenameToItem["data/objects/bigbagcontainer/bigbagcontainerfertilizer.xml"].price,
        g_storeManager.xmlFilenameToItem["data/objects/pallets/liquidtank/fertilizertank.xml"].price / 2,
        g_storeManager.xmlFilenameToItem["data/objects/pallets/liquidtank/herbicidetank.xml"].price / 2,
        g_storeManager.xmlFilenameToItem["data/objects/bigbagcontainer/bigbagcontainerseeds.xml"].price 
    }
    self.sprUse = {
        g_sprayTypeManager.sprayTypes[SprayType.FERTILIZER].litersPerSecond,
        g_sprayTypeManager.sprayTypes[SprayType.LIQUIDFERTILIZER].litersPerSecond,
        g_sprayTypeManager.sprayTypes[SprayType.HERBICIDE].litersPerSecond,
    }
    self.mtype = { 
        FERTILIZE   = g_missionManager:getMissionType("fertilize").typeId,
        SOW         = g_missionManager:getMissionType("sow").typeId,
        SPRAY       = g_missionManager:getMissionType("spray").typeId,
    }
    self.gameMenu = g_currentMission.inGameMenu
    self.frCon = self.gameMenu.pageContracts

    -- load my gui xmls
    if not self:loadGUI(true, self.directory.."gui/") then
        print(string.format(
        "** Info: - '%s.Gui' failed to load! Supporting files are missing.", self.name))
    end

    -- setup my display elements ------------------------------------------------------
        -- add field "profit" to all listItems
    for _, item in ipairs(self.frCon.contractsList.elements) do
        local rewd   = item:getDescendantByName("reward")
        local profit = rewd:clone(item)
        profit.name  = "profit"
        profit:setPosition(-110/1920, 0)
        profit:setTextColor(1,1,1,1)
        profit:setVisible(false)
    end
        -- set controls for npcbox, sortbox and their elements:
    for _, name in pairs(SC.CONTROLS) do
        self.my[name] = self.frCon.farmerBox:getDescendantById(name)
    end 
        -- set callbacks for our 3 sort buttons
    for _, name in ipairs({"sortcat","sortprof","sortpmin"}) do
        self.my[name].onClickCallback           = onClickSortButton
        self.my[name].onHighlightCallback       = onHighSortButton
        self.my[name].onHighlightRemoveCallback = onRemoveSortButton
        self.my[name].onFocusCallback           = onHighSortButton
        self.my[name].onLeaveCallback           = onRemoveSortButton
    end
    self.my.npcbox:setVisible(false)
    self.my.sortbox:setVisible(false)
    self.initialized = true
end

function BetterContracts:loadGUI(canLoad, guiPath)
    if canLoad then
        local fname
        -- load my gui profiles 
        fname = guiPath .. "guiProfiles.xml"
        if fileExists(fname) then
            g_gui:loadProfiles(fname)
        else
            canLoad = false
        end
        -- load "SCGui.xml"
        fname = guiPath .. "SCGui.xml"
        if canLoad and fileExists(fname) then
            local xmlFile = loadXMLFile("Temp", fname)
            local fbox = self.gameMenu.pageContracts.farmerBox
            g_gui:loadGuiRec(xmlFile, "GUI", fbox, self.gameMenu.pageContracts)
            local layout = fbox:getDescendantById("layout")
            layout:invalidateLayout(true)       -- adjust sort buttons
            fbox:applyScreenAlignment()
            fbox:updateAbsolutePosition()
            fbox:onGuiSetupFinished()           -- connect the tooltip elements
            delete(xmlFile)
        else
            canLoad = false
            print(string.format("**Error: [GuiLoader %s]  Required file '%s' could not be found!", 
                self.modName, fname))
        end
    end
    return canLoad
end;
function BetterContracts:refresh()
    -- refresh our contract tables
    self.harvest, self.spread, self.simple, self.baling, self.transp = {}, {}, {}, {}, {}
    self.IdToCont = {}
    local m
    for i, m in ipairs(self.miss) do 
        self.IdToCont[m.id] = self:addMission(m) 
    end
    self.numCont = #self.miss
end;
function BetterContracts:update(dt)
    local self = g_betterContracts
    self.missionUpdTimer = self.missionUpdTimer + dt
    if self.missionUpdTimer >= self.missionUpdTimeout then
        self:refresh()
        self.fieldToMission = {}
        for _, mission in pairs(g_missionManager.missions) do
            if mission.field ~= nil then
                self.fieldToMission[mission.field.fieldId] = mission
            end
        end
        self.missionUpdTimer = 0
    end
end;
function BetterContracts:addMission(m)
    -- add mission m to the corresponding BetterContracts list 
    local cont = {}
    local dim, wid, hei, dura, wwidth, speed, vtype, vname
    local cat = self.typeToCat[m.type.typeId]
    if cat < 5 then
        dim = self:getDimensions(m.field, false)
        wid, hei = dim.width, dim.height
        if wid > hei then wid, hei = hei, wid end;

        wwidth, speed, vtype, vname = self:getFromVehicle(cat ,m)
        -- estimate mission duration:
        if wwidth ~= nil and wwidth >0 then
            _, dura = self:estWorktime(wid, hei, wwidth, speed)
        elseif cat ~= 2 then
            print("**Error BetterContracts:addMission() - getFromVehicle() returned 0")
            dura = 1
        end
    end
    if cat == 1 then
        local keep = math.floor(m.expectedLiters * 0.265)
        local price= m.sellPoint:getEffectiveFillTypePrice(m.fillType)
        local profit = m.reward + keep * price
        cont = {
            miss    = m,
            width   = wid, height = hei,
            worktime= dura,
            ftype   = self.ft[m.fillType].title,
            deliver = math.floor(m.expectedLiters * 0.735),     --must be delivered
            keep    = keep,                                     --can be sold on your own
            price   = price *1000, 
            profit  = profit,
            permin  = profit /dura *60,
        }
        table.insert(self.harvest,cont)
    elseif cat == 2 then 
        cont = self:spreadMission(m, wid, hei, wwidth, speed)
        table.insert(self.spread, cont)
    elseif cat == 3 then
        cont = {
            miss    = m,
            width   = wid, height = hei,
            worktime= dura,
            profit  = m.reward,
            permin  = m.reward/dura *60
        }
        table.insert(self.simple, cont)
    elseif cat == 4 then
        local keep = math.floor(m.expectedLiters * 0.2105)
        local price= m.sellPoint:getEffectiveFillTypePrice(m.fillType)
        local profit = m.reward + keep * price
        cont = {
            miss    = m,
            width   = wid, height = hei,
            worktime= dura *3,      -- dura is just the mow time, adjust for windrowing/ baling
            ftype   = self.ft[m.fillType].title,
            deliver = math.ceil(m.expectedLiters - keep),--#bales to be delivered
            keep    = keep,                                     --can be sold on your own
            price   = price *1000, 
            profit  = profit,
            permin  = profit /dura /3 *60,
        }
        table.insert(self.baling, cont)
    else
        cont = {miss = m,
                profit = m.reward,
                permin = 0}
        table.insert(self.transp, cont)
    end
    return {cat, cont}
end;
