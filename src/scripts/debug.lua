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

-------------------- development helper functions ---------------------------------------------------
function BetterContracts:consoleCommandPrint()
	actionprint()
end
function loadSettings()
	--load settings from modsSettings folder
	local key = "SeeCont"
	local self = g_betterContracts
	local f = g_betterContracts.modsSettings .. "SeeCont.xml"
	if fileExists(f) then
		local xmlFile = loadXMLFile("SeeCont", f, key)
		self.dispSize = Utils.getNoNil(getXMLInt(xmlFile, key .. "#size"), 1)
		self.debug = Utils.getNoNil(getXMLBool(xmlFile, key .. "#debug"), false)
		delete(xmlFile)
	end
	if self.debug then
		print(string.format("read settings from %s: size = %d, debug = %s", f, self.dispSize, self.debug))
	end
end
function saveSettings()
	local key = "SeeCont"
	local f = g_betterContracts.modsSettings .. "SeeCont.xml"
	local xmlFile = createXMLFile("SeeCont", f, key)
	setXMLFloat(xmlFile, key .. "#turnTime", g_betterContracts.turnTime)
	setXMLBool(xmlFile, key .. "#debug", g_betterContracts.debug)
	saveXMLFile(xmlFile)
	delete(xmlFile)
	if g_betterContracts.debug then
		print("** BetterContracts:saved settings to " .. f)
	end
end
function actionprint()
	-- print table of current missions
	local sep = string.rep("-", 45)
	local self = g_betterContracts
	-- initialize contracts tables :
	self:refresh()

	-- harvest missions:
	print(sep .. "Harvest Mis" .. sep)
	print(string.format("%2s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s", "Nr", "Type", "Field", "ha", "reward", "duration", "Filltype", "deliver", "keep", "price", "Total", "perMinute"))
	for i, c in ipairs(self.harvest) do
		local m = c.miss
		print(
			string.format(
				"%2s %10s %10s %10.2f %10s %10s %10s %10d %10d %10d %10s %10s",
				i,
				m.type.name,
				m.field.fieldId,
				m.field.fieldArea,
				g_i18n:formatNumber(m.reward, 0),
				MathUtil.round(c.worktime / 60),
				c.ftype,
				c.deliver,
				c.keep,
				c.price,
				g_i18n:formatNumber(c.profit),
				g_i18n:formatNumber(c.permin)
			)
		)
	end
	-- spread missions:
	print(sep .. "Spread Miss" .. sep)
	print(string.format("%2s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s", "Nr", "Type", "Field", "ha", "reward", "duration", "Filltype", "usage", "price", "cost", "Total", "perMinute"))

	for i, c in ipairs(self.spread) do
		local m = c.miss
		local j = c.bestj
		print(
			string.format(
				"%2s %10s %10s %10.2f %10s %10s %10.10s %10d %10s %10d %10s %10s",
				i,
				m.type.name,
				m.field.fieldId,
				m.field.fieldArea,
				g_i18n:formatNumber(m.reward),
				MathUtil.round(c.worktime[j] / 60),
				c.ftype,
				c.usage[j],
				c.price[j],
				c.cost[j],
				g_i18n:formatNumber(c.profit),
				g_i18n:formatNumber(c.profit / c.worktime[j] * 60)
			)
		)
		if c.maxj > 1 then
			print(string.format("%57s %10s %10d %10s %10d %10s", MathUtil.round(c.worktime[2] / 60), "liquidFert", c.usage[2], c.price[2], c.cost[2], g_i18n:formatNumber(m.reward + c.cost[2])))
		end
		if c.maxj == 3 then
			print(string.format("%57s %10s %10d %10s %10d %10s", MathUtil.round(c.worktime[2] / 60), "vehicle", c.usage[3], c.price[3], c.cost[3], g_i18n:formatNumber(m.reward + c.cost[3])))
		end
	end
	-- simple missions:
	if #self.simple > 0 then
		print(sep .. "Simple Miss" .. sep)
		for i, c in ipairs(self.simple) do
			print(string.format("%2s %10s %10s %10.2f %10d %10s %54s", i, c.miss.type.name, c.miss.field.fieldId, c.miss.field.fieldArea, c.miss.reward, g_i18n:formatMinutes(c.worktime), g_i18n:formatNumber(c.miss.reward, 0)))
		end
	end
end
--[[
Nr       Type      Field         ha     reward   Filltype    usage      price       cost       Total
 5  fertilize         16       1.10       1996     Dünger      330     	 1260       -421        1576
												Flüssigdü	   412		 1600	    -640        1312
										mission    Dünger      330     	 1260       -421        1576
												
(-111, 212) (-111, 277) (-235, 213)			width: 64.51, height: 123.44, area: 7962.54
(-262, 249) (-262, 212) (-233, 250)			width: 37.31, height: 28.69, area: 1069.87
(-234, 277) (-262, 249) (-216, 258)			width: 39.14, height: 26.43, area: 1033.83
(-258, 260) (-262, 249) (-251, 257)			width: 11.74, height: 6.90, area: 80.82
(-253, 264) (-258, 260) (-249, 261)			width:  6.02, height: 5.52, area: 32.33
(-234, 277) (-253, 264) (-231, 272)			width: 22.74, height: 6.03, area: 136.98
---------------------------------------------Harvest Mis---------------------------------------------
Nr       Type      Field         ha     reward   duration   Filltype    deliver       keep      price      Total  perMinute
 1    harvest          1       5.91      9,747         29      Wheat      71488      25774        761     29,375      1,028
 2    harvest         39       5.81      9,582         28      Wheat      56984      20545        761     25,228        893
 3    harvest         40       5.49      9,051         32     Barley      75089      27072        662     26,996        848
 4    harvest         13       1.99      3,279         16     Barley      28050      10113        718     10,547        667
 5    harvest         38       1.41      7,428         21 Sugar Beet      89658      32325        179     13,220        617
 6    harvest         17       4.39      7,249         41   Soybeans      28191      10164       1527     22,776        561
 7    harvest         31       1.79      2,958         16     Barley      22137       7981        662      8,248        528
 8    harvest          5       2.85      4,696         32 Sunflowers      21755       7843       1153     13,741        428
 9    harvest         33       1.51      2,498         15     Canola       8714       3141       1106      5,974        393
10    harvest         23       4.57      7,540         55        Oat      37718      13599        775     18,082        326
11    harvest         37       2.06     10,867         72   Potatoes     109339      39421        292     22,400        310
---------------------------------------------Spread Miss---------------------------------------------
Nr       Type      Field         ha     reward   duration   Filltype      usage      price       cost      Total  perMinute
 1  fertilize         22       8.33     15,164         12    Duenger       1990       1920      -3821     11,342        912
                                                       20 liquidFert       2686       1600      -4298     10,865
                                                       20    vehicle       2697       1600      -4315     10,848
 2  fertilize         18       5.23      9,511          8    Duenger       1286       1920      -2469      7,041        877
                                                       13 liquidFert       1736       1600      -2778      6,732
                                                       13    vehicle       1823       1600      -2917      6,593
 3  fertilize          4       3.51      6,395          6    Duenger        880       1920      -1690      4,704        828
                                                        9 liquidFert       1188       1600      -1901      4,493
                                                        9    vehicle       1320       1600      -2112      4,282
 4  fertilize         19       3.76      6,838          6    Duenger       1013       1920      -1945      4,892        778
                                                       10 liquidFert       1368       1600      -2189      4,649
 5  fertilize         34       3.66      6,662          6    Duenger        977       1920      -1876      4,785        767
                                                       10 liquidFert       1319       1600      -2110      4,551
                                                       10    vehicle       1248       1600      -1997      4,664
 6  fertilize          8       1.92      3,494          3    Duenger        522       1920      -1002      2,491        742
                                                        5 liquidFert        704       1600      -1127      2,366
                                                        5    vehicle        768       1600      -1230      2,263
 7  fertilize         41       1.13      2,058          2    Duenger        334       1920       -642      1,415        600
                                                        4 liquidFert        452       1600       -723      1,334
                                                        4    vehicle        452       1600       -723      1,334
 8  fertilize         30       1.41      2,569          3    Duenger        498       1920       -957      1,611        475
                                                        5 liquidFert        673       1600      -1077      1,491
                                                        5    vehicle        673       1600      -1077      1,491
 9  fertilize         28       1.06      1,924          4 Fluessigduenger        388       1600       -621      1,302        371
                                                        4 liquidFert        443       1600       -709      1,214
                                                        4    vehicle        388       1600       -621      1,302

Sprayer hardi/mega2200/mega2200.xml - scale 1.0, speed 12.0, width 24.0
nlanes 4, workL 467.9, workT 84.2
nlanes 4, workL 467.9, workT 140.4
nlanes 4, workL 467.9, workT 140.4
 1  fertilize         18       0.81       1472    Dünger        242       1920       -465       1006
                                            -- Flüssigd?       327       1600       -523        948
                                       vehicle Flüssigd?       327       1600       -523        948

---------------------------------------------Spread Miss---------------------------------------------
Nr       Type      Field         ha     reward   Filltype      usage      price       cost      Total    #possib
 1  fertilize         12       0.97      1.773    Duenger        334       1920       -641      1.131          3
                                            -- Fluessigdu        451       1600       -721      1.051
                                            --    vehicle        334       1920       -641      1.131
 2  fertilize          3       1.71      3.115    Duenger        471       1920       -906      2.208          3
                                            -- Fluessigdu        637       1600      -1019      2.095
                                            --    vehicle        495       1920       -951      2.163
 3  fertilize         10       1.97      3.594    Duenger        641       1920      -1231      2.362          2
                                            -- Fluessigdu        865       1600      -1385      2.208
 4  fertilize         15       0.31        565    Duenger        113       1920       -218        346          2
                                            -- Fluessigdu        153       1600       -245        319
 5  fertilize         20       0.87      1.580    Duenger        284       1920       -546      1.033          2
                                            -- Fluessigdu        384       1600       -614        965
 6  fertilize          1       0.86      1.566    Duenger        197       1920       -378      1.187          3
                                            -- Fluessigdu        266       1600       -426      1.139
                                            --    vehicle        310       1600       -497      1.068
 7  fertilize          9       1.61      2.938    Duenger        464       1920       -891      2.046          3
                                            -- Fluessigdu        626       1600      -1002      1.935
                                            --    vehicle        464       1920       -891      2.046
 8  fertilize         19       1.67      3.039    Duenger        447       1920       -858      2.180          2
                                            -- Fluessigdu        603       1600       -965      2.073
 9  fertilize         11       0.91      1.651    Duenger        212       1920       -408      1.242          2
                                            -- Fluessigdu        287       1600       -459      1.191
10        sow         17       0.97      1.898       Saat        483        900       -434      1.463          1
11  fertilize         16       1.10      1.996    Duenger        293       1920       -563      1.432          2
                                            -- Fluessigdu        396       1600       -633      1.362
---------------------------------------------Simple Miss---------------------------------------------
 1  cultivate          6       1.00        658                                                    658
]]
