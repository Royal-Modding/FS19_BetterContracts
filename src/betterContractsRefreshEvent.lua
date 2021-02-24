---${title}

---@author ${author}
---@version r_version_r
---@date @date 19/10/2020

BetterContractsRefreshEvent = {}
BetterContractsRefreshEvent_mt = Class(BetterContractsRefreshEvent, Event)

InitEventClass(BetterContractsRefreshEvent, "BetterContractsRefreshEvent")

function BetterContractsRefreshEvent:emptyNew()
    local o = Event:new(BetterContractsRefreshEvent_mt)
    o.className = "BetterContractsRefreshEvent"
    return o
end

function BetterContractsRefreshEvent:new()
    local o = BetterContractsRefreshEvent:emptyNew()
    return o
end

function BetterContractsRefreshEvent:writeStream(streamId, connection)
end

function BetterContractsRefreshEvent:readStream(streamId, connection)
    self:run(connection)
end

function BetterContractsRefreshEvent:run(connection)
    if g_server ~= nil then
        g_missionManager.missions = {}
        g_missionManager.fieldToMission = {}
        g_missionManager.generationTimer = 0
    end
end

function BetterContractsRefreshEvent.sendEvent()
    g_client:getServerConnection():sendEvent(BetterContractsRefreshEvent:new())
end
