--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 19/10/2020

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
        -- If the event is coming from a client
        BetterContractsRefreshEvent.sendEvent(self.groupName, self.eventType)
    end
end

function BetterContractsRefreshEvent.sendEvent()
    if g_server ~= nil then
        -- Set generationTimer to 0 so missions will be refresh at next update
        g_missionManager.generationTimer = 0
    else
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(BetterContractsRefreshEvent:new())
    end
end
