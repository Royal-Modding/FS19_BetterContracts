---@diagnostic disable: lowercase-global
--=======================================================================================================
-- BetterContracts SCRIPT 
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Royal-Modding / Mmtrx		
-- Changelog:
--  v1.0.0.0	19.10.2020	initial by Royal-Modding
--	v1.2.0.0	12.04.2021	release candidate RC-2
--  v1.2.1.0	24.04.2021  (Mmtrx) gui enhancements: addtl details, sort buttons
--=======================================================================================================

-------------------- Gui enhance functions ---------------------------------------------------
function onFrameOpen(self, superFunc, ...)
    if g_betterContracts.needsRefreshContractsConflictsPrevention then
        -- this will prevent execution of FS19_RefreshContracts code (because they check for that field to be nil)
        g_betterContracts.gameMenu.refreshContractsElement_Button = 1
    end
    superFunc(self, ...)
    g_betterContracts.gameMenu.refreshContractsElement_Button = nil

	local self = g_betterContracts
	local inGameMenu = self.gameMenu
	local parent = inGameMenu.menuButton[1].parent
    -- add new buttons
    if inGameMenu.newContractsButton == nil then
        inGameMenu.newContractsButton = inGameMenu.menuButton[1]:clone(parent)
        inGameMenu.newContractsButton.onClickCallback = onClickNewContractsCallback
        inGameMenu.newContractsButton:setText(g_i18n:getText("bc_new_contracts"))
        inGameMenu.newContractsButton:setInputAction("MENU_EXTRA_1")
    end
    if inGameMenu.clearContractsButton == nil then
        inGameMenu.clearContractsButton = inGameMenu.menuButton[1]:clone(parent)
        inGameMenu.clearContractsButton.onClickCallback = onClickClearContractsCallback
        inGameMenu.clearContractsButton:setText(g_i18n:getText("bc_clear_contracts"))
        inGameMenu.clearContractsButton:setInputAction("MENU_EXTRA_2")
    end
	if inGameMenu.detailsButton == nil then
	    local button = inGameMenu.menuButton[1]:clone(parent)
	    button.onClickCallback = detailsButtonCallback
	    inGameMenu.detailsButton = button
	    local text = g_i18n:getText("bc_detailsOn")
	    if self.isOn then text = g_i18n:getText("bc_detailsOff") end
	    button:setText(text)
	    button:setInputAction("MENU_EXTRA_3")
	end
	-- register action, so that our button is also activated by keystroke
	local _, eventId = g_currentMission.inputManager:registerActionEvent("MENU_EXTRA_3", 
		inGameMenu, onClickMenuExtra3, false, true, false, true)
	self.eventExtra3 = eventId

	-- if we were sorted on last frame close, focus the corresponding sort button
	if self.isOn and self.sort > 0 then
		self:radioButton(self.sort)  
	end
end;
function onFrameClose()
    local inGameMenu = g_currentMission.inGameMenu
    for _, button in ipairs({inGameMenu.newContractsButton,inGameMenu.clearContractsButton,
    	inGameMenu.detailsButton}) do
    	if button ~= nil then
    	    button:unlinkElement()
    	    button:delete()
    	end
    end
    if g_betterContracts.eventExtra3 ~= nil then
    	g_inputBinding:removeActionEvent(g_betterContracts.eventExtra3)
    end
    inGameMenu.newContractsButton = nil
    inGameMenu.clearContractsButton = nil
    inGameMenu.detailsButton = nil
end;

function onClickMenuExtra1(inGameMenu, superFunc, ...)
    if superFunc ~= nil then
        superFunc(inGameMenu, ...)
    end
    if inGameMenu.newContractsButton ~= nil then
        inGameMenu.newContractsButton.onClickCallback(inGameMenu)
    end
end
function onClickMenuExtra2(inGameMenu, superFunc, ...)
    if superFunc ~= nil then
        superFunc(inGameMenu, ...)
    end
    if inGameMenu.clearContractsButton ~= nil then
        inGameMenu.clearContractsButton.onClickCallback(inGameMenu)
    end
end
function onClickMenuExtra3(inGameMenu)
	---Due to how the input system works in fs19, the input is not only handled 
	-- with a click callback but also via these events
    if inGameMenu.detailsButton ~= nil then
    	inGameMenu.detailsButton.onClickCallback(inGameMenu)
		inGameMenu:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
    end
end;

function onClickNewContractsCallback(inGameMenu)
    BetterContractsNewEvent.sendEvent()
end
function onClickClearContractsCallback(inGameMenu)
    BetterContractsClearEvent.sendEvent()
end
function detailsButtonCallback(inGameMenu)
	local self = g_betterContracts
	local frCon = self.frCon
	local selected = frCon.contractsList.selectedIndex 

	-- it's a toggle button - change my "on" state 
	self.isOn = not self.isOn
	self.my.npcbox:setVisible(self.isOn)
	self.my.sortbox:setVisible(self.isOn)
	frCon.npcFieldBox:setVisible(not self.isOn)

	if self.isOn then
		inGameMenu.detailsButton:setText(g_i18n:getText("bc_detailsOff"))
		-- if we were sorted on last "off" click, then one of our sort buttons might still have focus 
		if self.lastSort > 0 then
			FocusManager:setFocus(frCon.contractsList, "top") -- remove focus from our sort buttton
		end
	else
		inGameMenu.detailsButton:setText(g_i18n:getText("bc_detailsOn"))
		-- "off" always resets sorting to default
		if self.sort > 0 then
			self:radioButton(0) 	-- reset all sort buttons
		end
		self.my.helpsort:setText("")	
		frCon:updateList() 			-- restore standard sort order
	end
	-- refresh farmerBox
	updateFarmersBox(frCon, frCon.contracts[selected].mission.field, nil)
	frCon.contractsList:updateItemPositions()
end;

function updateList(frCon)
	-- if a mission was created or deleted, update our tables
	local self = g_betterContracts
	if #self.miss ~= self.numCont then
		self:refresh()
	end
end;
function assignListItem(frCon, item, contract)
	local profit = item:getDescendantByName("profit")
	local self = g_betterContracts
	if not self.isOn then 
		profit:setVisible(false)
		return 
	end
	local id = contract.mission.id 
	local prof = self.IdToCont[id][2].profit or 0
	local showProf = ListUtil.hasListElement({1,2,4}, self.IdToCont[id][1])  	
	if showProf then 			-- only for harvest, spread, mow contracts
		local reward = item:getDescendantByName("reward")
		local rewtext = reward:getText()
		reward:setText(g_i18n:formatMoney(prof, 0, true, true))
		profit:setText(rewtext)
	end
	profit:setVisible(showProf)
end;
function sortList(frCon, superfunc )
	-- sort frCon.contracts according to sort button clicked
	local self = g_betterContracts
	if not self.isOn or self.sort == 0 then
		superfunc(frCon)
		return
	end
	local sorts = function (a,b)
		local av, bv = 1000000.0 * (a.active and 1 or 0) + 500000.0 * (a.finished and 1 or 0),
					1000000.0 * (b.active and 1 or 0) + 500000.0 * (b.finished and 1 or 0)
		local am, bm = a.mission, b.mission

		if self.sort == 3 then 			-- sort profit per Minute
			av = av + self.IdToCont[am.id][2].permin
			bv = bv + self.IdToCont[bm.id][2].permin

		elseif self.sort == 2 then 		-- sort profit
			av = av + self.IdToCont[am.id][2].profit
			bv = bv + self.IdToCont[bm.id][2].profit

		elseif self.sort == 1 then 		-- sort mission category / field #
			av = av - 5000* self.IdToCont[am.id][1] 
			if am.field ~= nil then av = av - am.field.fieldId end

			bv = bv - 5000* self.IdToCont[bm.id][1] 
			if bm.field ~= nil then bv = bv - bm.field.fieldId end

		else  							-- should not happen
			av, bv = a.hash, b.hash
		end
		return av > bv
	end
	table.sort(frCon.contracts, sorts)
end;
function updateFarmersBox(frCon, field, npc)
	-- set the text values in our npcbox 
	local self = g_betterContracts
	if not self.isOn then return end
	if field == nil then 		-- it's a transport mission
		self.my.npcbox:setVisible(false) 
		return
	end	
	frCon.npcFieldBox:setVisible(false)
	self.my.npcbox:setVisible(true) 

	local text4a, text4b
	local text = string.format(g_i18n:getText("SC_field"),field.fieldId, 
		g_i18n:formatArea(field.fieldArea, 2))
	self.my.field:setText(text)

	local ix = frCon.contractsList.selectedIndex
	local m =  frCon.contracts[ix].mission
	local con = self.IdToCont[m.id]
	if con == nil then
		print("**Error BetterContracts:updateFarmersBox() - no contract found for mission id "..tostring(m.id))
		return
	end
	local cat= con[1]
	local c =  con[2]
	local etime = c.worktime
	if cat == 2 then etime = c.worktime[c.bestj] end
	if cat > 4 then return end 		-- should not happen, since field==nil was already checked

	self.my.dimen:setText(string.format("%s / %s m",
	 g_i18n:formatNumber(c.width), g_i18n:formatNumber(c.height)))
	self.my.line3:setText(g_i18n:getText("SC_worktim"))
	self.my.etime:setText(g_i18n:formatMinutes(etime/60)) 
	self.my.valu7:setText(g_i18n:formatMoney(c.permin))
	self.my.line5:setText(g_i18n:getText("SC_price")) 	-- will be overwritten if active/ cat 4
	self.my.line5:setVisible(cat~=3) 	-- price field only for harvest/ spread/ mow contracts

	if cat == 1 or cat == 4 then 		-- harvest / mow contract
		local active = frCon.contracts[ix].active
		--get current price
		local price= m.sellPoint:getEffectiveFillTypePrice(m.fillType)
		self.my.filltype:setText(c.ftype)

		if active then
			self.my.line3:setText(g_i18n:getText("SC_worked"))
			self.my.etime:setText(string.format("%.1f%%", m:getFieldCompletion()*100))

			local delivered = m.depositedLiters
			text4a, text4b = g_i18n:getText("SC_delivered"), g_i18n:getText("SC_togo")
			local val4a, val4b = g_i18n:formatVolume(MathUtil.round(delivered/100)*100),
				g_i18n:formatVolume(MathUtil.round((c.deliver-delivered)/100)*100)
			if cat == 4 then
				local bUnit = g_i18n:getText("unit_bale")
				bUnit = string.sub(bUnit,1,1):upper()..string.sub(bUnit,2)
				text4a = bUnit.." " .. text4a
				text4b = bUnit.." " .. text4b
				val4a = string.format("%.0f",delivered/4000)
				val4b = string.format("%.0f",c.deliver/4000 - tonumber(val4a))
			end
			self.my.line4a:setText(text4a)
			self.my.valu4a:setText(val4a)
			self.my.line4b:setText(text4b)
			self.my.valu4b:setText(val4b)
		else
			text4a = g_i18n:formatVolume(MathUtil.round(c.deliver/100)*100)
			text4b = g_i18n:formatVolume(MathUtil.round(c.keep/100)*100)
			self.my.line4a:setText(g_i18n:getText("SC_deliver"))
			self.my.line4b:setText(g_i18n:getText("SC_keep"))
			self.my.valu4a:setText(text4a)
			self.my.valu4b:setText(text4b)
		end
		self.my.price:setText(g_i18n:formatMoney(price*1000))
		self.my.line6:setText(g_i18n:getText("SC_profit"))
		self.my.valu6:setText(g_i18n:formatMoney(price*c.keep))

	elseif cat == 2 then 	-- spread contract
		local j = c.bestj
		self.my.filltype:setText(c.ftype)
		self.my.line4a:setText("")
		self.my.valu4a:setText("")
		self.my.line4b:setText(g_i18n:getText("SC_usage"))
		self.my.valu4b:setText(g_i18n:formatVolume(c.usage[j], 0))
		self.my.price:setText(g_i18n:formatMoney(c.price[j], 0))
		self.my.line6:setText(g_i18n:getText("SC_cost"))
		self.my.valu6:setText(g_i18n:formatMoney(c.cost[j],0))

	else 					-- simple contract
		self.my.filltype:setText("")
		self.my.line4a:setText("")
		self.my.valu4a:setText("")
		self.my.line4b:setText("")
		self.my.valu4b:setText("")
		self.my.price:setText("")
		self.my.line6:setText("")
		self.my.valu6:setText("")
	end
end;
function BetterContracts:radioButton(st)
	-- implement radiobutton behaviour: max. one sort button can be active
	self.lastSort = self.sort
	self.sort = st
	local prof = {
		active = {"SeeContactiveCat","SeeContactiveProf","SeeContactivepMin" },
		std    = {"SeeContsortCat","SeeContsortProf","SeeContsortpMin"}
	}
	local bname
	if st == 0 then 		-- called from buttonCallback() when switching to off
		if self.lastSort > 0 then 				-- reset the active sort icon
			local a = self.lastSort
			bname = self.buttons[a][1]
			self.my[bname]:applyProfile(prof.std[a])
			FocusManager:unsetFocus(self.my[bname]) 	-- remove focus if we are sorted
			FocusManager:unsetHighlight(self.my[bname]) -- remove highlight 
		end
		return
	end
	local a, b = math.fmod(st+1,3), math.fmod(st+2,3)
	if a == 0 then a = 3 end
	if b == 0 then b = 3 end
	self.my[self.buttons[st][1]]:applyProfile(prof.active[st]) 	-- set this Button Active
	self.my[self.buttons[ a][1]]:applyProfile(prof.std[a]) 		-- reset the other 2 
	self.my[self.buttons[ b][1]]:applyProfile(prof.std[b])
end;
function onClickSortButton(frCon, button)
	local self, n = g_betterContracts, 0
	for i, bu in ipairs(self.buttons) do
		if bu[1] == button.id then
			n = i
			break
		end
	end
	self:radioButton(n) 
	frCon:updateList()
end;
function onHighSortButton(frCon, button)
	-- show help text
	local self = g_betterContracts
	--print(button.id.." -onHighlight / onFocusEnter, sort "..tostring(self.sort))
	local tx = ""
	for _, bu in ipairs(self.buttons) do
		if bu[1] == button.id then
			tx = bu[2]
			break
		end
	end
	self.my.helpsort:setText(tx)
end;
function onRemoveSortButton(frCon, button)
	-- reset help text
	local self = g_betterContracts
	--print(button.id.." -onHighlightRemove / onFocusLeave, sort "..tostring(self.sort))
	if self.sort == 0 then 
		self.my.helpsort:setText("")	
	else
		self.my.helpsort:setText(self.buttons[self.sort][2])
	end
end;
