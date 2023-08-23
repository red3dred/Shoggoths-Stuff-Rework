require "/scripts/util.lua"
require "/scripts/rect.lua"

function init()
	if (not player.getProperty("magWeaponAffinity", nil)) then
		local cfg = root.assetJson("/interface/scripted/srm_weaponaffinity/srm_weaponaffinity.config")
		player.interact("ScriptPane", cfg)
	end
	feedingCooldownMax = 45
	feedingCooldown = feedingCooldownMax
	feedingMax = 3
	player.setProperty("magFeedingUses", 0)
	defaultMag = {name="srm_mag",count=1,parameters={
		magForm = "mag",
			
		magLevel = 0,
		synchro = 0,
		iq = 0,
		def = 0,
		pow = 0,
		dex = 0,
		mind = 0,
			
		defMeter = 0,
		powMeter = 0,
		dexMeter = 0,
		mindMeter = 0,
			
		pbAttack1 = "",
		pbAttack2 = "",
		pbAttack3 = ""
	}}
	if (not player.getProperty("freeMagEquipped", false)) then
		player.setProperty("freeMagEquipped", true)
		player.setProperty("magEquipped", defaultMag)
	end
	stockConfig = root.assetJson("/config/srm_stocks.config")
	organsConfig = root.assetJson("/config/srm_organs.config")
	ruinLootConfig = root.assetJson("/config/srm_ruinloot.config")
	message.setHandler("srm_warp", function(_, isItMine, location) 
		player.warp(location)
	end)
	message.setHandler("srm_hasKey", function(_, isItMine, objectId) 
		if player.hasItemWithParameter("inventoryIcon", "srm_ruinkey.png") then
			world.sendEntityMessage(objectId, "srm_hasKeyAnswer", true)
		else
			world.sendEntityMessage(objectId, "srm_hasKeyAnswer", false)
		end
	end)
	message.setHandler("srm_consumeKey", function(_, isItMine) 
		player.consumeItemWithParameter("inventoryIcon", "srm_ruinkey.png", 1)
	end)
	organsWithTechConfig = {}
	for i=1,#organsConfig do
		if (organsConfig[i].hasTech == true) then
			--sb.logInfo(sb.printJson(organsConfig[i]))
			organsWithTechConfig[#organsWithTechConfig+1] = organsConfig[i] 
		end
	end
	
	stockReadyToUpdate = false
	stockHistoryMax = 30
	stockUpdateRate = 2
	stockUpdateTimer = stockUpdateRate
	
	trendMinLength = 20
	trendMaxLength = 60
	
	script.setUpdateDelta(1)
end

function update(dt)
	if (not player.getProperty("magSectionId", nil)) then
		setSectionId(world.entityName(player.id()))
	end
	if (player.getProperty("magEquipped", nil)) then
		if (player.getProperty("magEquipped", nil).name ~= "srm_mag") then player.setProperty("magEquipped", defaultMag) end
		status.setPersistentEffects("persistentMag", {"srm_mag"})
	else
		status.clearPersistentEffects("persistentMag")
	end
	if player.getProperty("magFeedingUses", feedingMax) < feedingMax then
		if feedingCooldown <= 0 then
			player.setProperty("magFeedingUses", feedingMax)
			feedingCooldown = feedingCooldownMax
		else
			feedingCooldown = feedingCooldown - dt
		end
		--sb.logInfo(feedingCooldown)
	end
	localAnimator = math.srm_localAnimator
	if (not hasStatus("srm_curseoftrials")) then player.consumeItem("srm_trialhook") end
	
	eldritchColoring()
	
	deadCells()
	
	organEffects()
	organTech()
	uniqueBlueprint()
	
	stockPhone()
	stockMarket()
	stockUpdateTimer = stockUpdateTimer + dt
end



--ORGAN FUNCTIONS UNDER HERE
--ORGAN FUNCTIONS UNDER HERE
--ORGAN FUNCTIONS UNDER HERE



-- This gives the effects of the organs
function organEffects()
	if (player.getProperty("organEquipped_Head", "") ~= nil) and (player.getProperty("organEquipped_Head", "") ~= "") then 
		status.addEphemeralEffect(player.getProperty("organEquipped_Head", ""), 0.2)
	end
	if (player.getProperty("organEquipped_Back", "") ~= nil) and (player.getProperty("organEquipped_Back", "") ~= "") then 
		status.addEphemeralEffect(player.getProperty("organEquipped_Back", ""), 0.2)
	end
	if (player.getProperty("organEquipped_Chest", "") ~= nil) and (player.getProperty("organEquipped_Chest", "") ~= "") then 
		status.addEphemeralEffect(player.getProperty("organEquipped_Chest", ""), 0.2)
	end
	if (player.getProperty("organEquipped_Gut", "") ~= nil) and (player.getProperty("organEquipped_Gut", "") ~= "") then 
		status.addEphemeralEffect(player.getProperty("organEquipped_Gut", ""), 0.2)
	end
end

-- If any of the specified statuses exist then equip the tech
function organTech()
	hasRelatedStatus = false
	for i=1,#organsWithTechConfig do
		if hasStatus(organsWithTechConfig[i].name) then hasRelatedStatus = true end
	end
	if hasRelatedStatus then 
		switchEquippedTech("srm_organtech")
	else
		removeTech("srm_organtech")
	end
end

-- This handles organ blueprints and ruin loot from the corrupted vault
function uniqueBlueprint()
	if (player.currency("srm_organblueprint") > 0) then
		player.consumeCurrency("srm_organblueprint", 1)
		localAnimator.playAudio("/sfx/objects/absorbblueprint.ogg")
		notOwnedOrgans = {}
		for i=1,#organsConfig do
			if (not player.blueprintKnown(organsConfig[i].name)) then
				notOwnedOrgans[#notOwnedOrgans+1] = organsConfig[i].name
			end
		end
		if (#notOwnedOrgans>0) then
			player.giveBlueprint(notOwnedOrgans[math.random(#notOwnedOrgans)])
		else
			world.spawnTreasure(world.entityPosition(player.id()), "blueprintRunestoneTreasure", 1)
		end
	end
	if (player.currency("srm_ruinblueprint") > 0) then
		local hasBP = false
		local message = ""
		player.consumeCurrency("srm_ruinblueprint", 1)
		localAnimator.playAudio("/sfx/objects/absorbblueprintrare.ogg")
		if (player.blueprintKnown("srm_helminth")) then
			notOwnedLoot = {}
			for i=1,#ruinLootConfig do
				if (not player.blueprintKnown(ruinLootConfig[i].name)) then
					notOwnedLoot[#notOwnedLoot+1] = ruinLootConfig[i]
				end
			end
			if (#notOwnedLoot>0) then
				local selected = notOwnedLoot[math.random(#notOwnedLoot)]
				hasBP = true
				message = selected.message
				player.giveBlueprint(selected.name)
			else
				world.spawnTreasure(world.entityPosition(player.id()), "ruinRunestoneTreasure", 1)
			end
		else
			hasBP = true
			message = "You have obtained the blueprint for the Helminth, craftable at the Deathstate Portal inside the Organ category. This apparatus allows the user to transplant organs inside their body."
			player.giveBlueprint("srm_helminth")
		end
		if hasBP then
			local srm_message = { 
				important = false,
				unique = false,
				type = "generic",
				textSpeed = 30,
				portraitFrames = 2,
				persistTime = 1,
				messageId = sb.makeUuid(),	  
				chatterSound = "/sfx/interface/aichatter3_loop.ogg",
				portraitImage = "/ai/portraits/gibberingbladder.png:talk.<frame>",
				senderName = "Crypt Helper",
				text = message
			}
			srm_message.messageId = sb.makeUuid()
			world.sendEntityMessage(
				player.id(),
				"queueRadioMessage",
				srm_message
			)
		end
	end
end

-- Gives the player a tech disk containing their old tech and equip the new one
function switchEquippedTech(tech)
	oldTech = player.equippedTech("body") or "nothing"
	if ((tech ~= oldTech) and (oldTech ~= "nothing")) then
		techdisk = {
			parameters= {
				description = "Using this disk will give back the '" .. oldTech .. "' tech.",
				tech_to_unlock = oldTech
			},
			name = "srm_generictech",
			count = 1
		}
		player.giveItem(techdisk)
	end
	player.makeTechAvailable(tech)
	player.enableTech(tech)
	player.equipTech(tech) 
end

-- Removes the specified tech
function removeTech(tech)
	player.unequipTech(tech) 
	player.makeTechUnavailable(tech)
end

-- This gives the stock market phone blueprint if enough capital was accumulated
function stockPhone()
	if (not player.blueprintKnown("srm_stockphone")) then
		if (player.currency("money") >= 10000) then
			player.giveBlueprint("srm_stockphone")
		end
	end
end

-- This handles stock market data generation.
function stockMarket()
	if (stockUpdateTimer >= stockUpdateRate) then
		stockReadyToUpdate = true
		stockUpdateTimer = 0
	end
	if (stockReadyToUpdate) then
		stockReadyToUpdate = false
		oldData = player.getProperty("stocksMarketData", {noonecares="puregarbage"})
		newData = {}
		-- This loops through categories.
		for categoryKey,v in pairs(stockConfig) do
			newData[categoryKey] = {}
			-- This loops through stocks from categories.
			local stockArray = stockConfig[categoryKey].offers
			for stockKey,v2 in pairs(stockArray) do
				-- This gets the price of the stock, speculative or physical.
				local itemPrice = 100
				if (stockConfig[categoryKey].type == "speculative") then 
					itemPrice = stockArray[stockKey].price
				else
					local currentItem = {name="",parameters={},count=1}
					currentItem.name = stockArray[stockKey].sourceItem
					local itemParameters = root.itemConfig(currentItem).config
					itemPrice = itemParameters.price
				end
				
				-- This is dummy data that only exists if the stock is brand new.
				-- For graph rendering reasons, you must store a total of 31 values inside an array ranging from 0 to 30
				newData[categoryKey][stockKey] = {
					stockValue = itemPrice,
					stockHistory = {},
					trendInfluence = 0, -- Ranges from -0.5 to 0.5. Since the number generated ranges from -0.5 to 0.5, this simulates trends.
					trendTimer = 60
				}
				for i=0,stockHistoryMax do
					newData[categoryKey][stockKey].stockHistory[i] = itemPrice
				end
				
				-- If old data exists, use it to continue running the stocks.
				if (not (oldData.noonecares == "puregarbage")) then 
					if (oldData[categoryKey][stockKey] == nil) then
						newData[categoryKey][stockKey].stockValue = itemPrice
					else
						newData[categoryKey][stockKey].stockValue = oldData[categoryKey][stockKey].stockValue
					end
					for i=0,stockHistoryMax do
						if (oldData[categoryKey][stockKey] == nil) then
							newData[categoryKey][stockKey].stockHistory[i] = itemPrice
						else
							newData[categoryKey][stockKey].stockHistory[i] = oldData[categoryKey][stockKey].stockHistory["" .. i .. ""]
							if (newData[categoryKey][stockKey].stockHistory[i] == nil) then newData[categoryKey][stockKey].stockHistory[i] = itemPrice end
						end
					end
					if (oldData[categoryKey][stockKey] == nil) then
						local trend = generateNewTrend()
						newData[categoryKey][stockKey].trendInfluence = trend.influence
						newData[categoryKey][stockKey].trendTimer = trend.timer
					else
						newData[categoryKey][stockKey].trendInfluence = oldData[categoryKey][stockKey].trendInfluence
						newData[categoryKey][stockKey].trendTimer = oldData[categoryKey][stockKey].trendTimer
					end
				end
					
				-- Updates the trend.
				newData[categoryKey][stockKey].trendTimer = newData[categoryKey][stockKey].trendTimer - (stockUpdateRate)
				if (newData[categoryKey][stockKey].trendTimer <= 0) then
					parameters = generateNewTrend()
					newData[categoryKey][stockKey].trendInfluence = parameters.influence
					newData[categoryKey][stockKey].trendTimer = parameters.timer
				end
				
				-- Updates the history.
				for i=1,stockHistoryMax do
					newData[categoryKey][stockKey].stockHistory[i-1] = newData[categoryKey][stockKey].stockHistory[i]
				end
				
				-- Updates the price.
				newData[categoryKey][stockKey].stockValue = newData[categoryKey][stockKey].stockValue + generateStockVariation(
					newData[categoryKey][stockKey].trendInfluence
				)
				if (newData[categoryKey][stockKey].stockValue <= 1) then
					newData[categoryKey][stockKey].stockValue = 1
				end
				
				-- Updates the history part 2.
				newData[categoryKey][stockKey].stockHistory[stockHistoryMax] = newData[categoryKey][stockKey].stockValue
				--sb.logInfo(sb.printJson(newData[categoryKey][stockKey].stockHistory))
			end
		end
		player.setProperty("stocksMarketData", newData)
	end
end

-- This generates a new trend for the current stock.
function generateNewTrend()
	local trend = {}
	trend.influence = math.random() - 0.5
	trend.timer = math.random(trendMinLength, trendMaxLength)
	return trend
end

-- This generates a new stock variation.
function generateStockVariation(stockInfluence)
	local stockVariation = math.random() - 0.5
	stockVariation = stockVariation + stockInfluence
	stockVariation = stockVariation * (stockUpdateRate)
	return stockVariation
end

--This entire function handles coloring objects and/or items when being a valid eldritch entity.
function eldritchColoring()
	if (hasStatus("srm_eldritchracial")) then		
		--This section of the function fetches the directives from the player's portrait.
		----------------------------------------------------------------------------------------------------------------------------------------
		bodyDirectives = ""
		local portrait = world.entityPortrait(player.id(), "fullneutral")
		--sb.logInfo(sb.printJson(portrait))
		for key, value in pairs(portrait) do
					if (string.find(portrait[key].image, "body.png")) then
							local body_image =	portrait[key].image
							local directive_location = string.find(body_image, "replace")
							bodyDirectives = string.sub(body_image,directive_location)
			end
		end
		bodyDirectives = "?" .. bodyDirectives
		
		--This section handles checking if the object is a valid colorable object.
		----------------------------------------------------------------------------------------------------------------------------------------
		--sb.logInfo(sb.printJson(root.itemConfig(player.swapSlotItem()).config.shoggothColorable, 1))
		local isValid = false
		if (not (player.swapSlotItem() == nil)) then
			if (sb.printJson(root.itemConfig(player.swapSlotItem()).config.shoggothColorable, 1) == "true") then
				isValid = true
				if (player.swapSlotItem().parameters.shoggothColorable == "false") then
					isValid = false
				end
			end
		--This section handles coloring the object, and checks for various parameters to color them as well.
		----------------------------------------------------------------------------------------------------------------------------------------
			if (isValid and not mcontroller.crouching()) then
				local newItem = player.swapSlotItem()
				-- Preventing Recoloring
				newItem.parameters.shoggothColorable = "false"			
				-- Color
				newItem.parameters.color = root.itemConfig(player.swapSlotItem()).config.color .. bodyDirectives				
				-- Inventory Icon
				if (type(root.itemConfig(player.swapSlotItem()).config.inventoryIcon) == "string") then
					newItem.parameters.inventoryIcon = root.itemConfig(player.swapSlotItem()).config.inventoryIcon .. bodyDirectives	
				else
					local iconArray = root.itemConfig(player.swapSlotItem()).config.inventoryIcon
					for i=1,#iconArray do
						iconArray[i].image = iconArray[i].image .. bodyDirectives
					end
					newItem.parameters.inventoryIcon = iconArray
				end
				-- Placement Image
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.placementImage) == "null")) then
					newItem.parameters.placementImage = root.itemConfig(player.swapSlotItem()).config.placementImage .. bodyDirectives				
				end			
				-- Sit Cover Image (When Applicable)
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.sitCoverImage) == "null")) then
					newItem.parameters.sitCoverImage = root.itemConfig(player.swapSlotItem()).config.sitCoverImage .. bodyDirectives			
				end			
				-- Large Image (When Applicable)
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.largeImage) == "null")) then
					newItem.parameters.largeImage = root.itemConfig(player.swapSlotItem()).config.largeImage .. bodyDirectives			
				end			
				player.setSwapSlotItem(newItem)
			elseif (isValid and mcontroller.crouching()) then
				local newItem = player.swapSlotItem()
				-- Preventing Recoloring
				newItem.parameters.shoggothColorable = "false"			
				-- Inventory Icon
				newItem.parameters.inventoryIcon = root.itemConfig(player.swapSlotItem()).config.inventoryIcon			
				-- Color
				newItem.parameters.color = root.itemConfig(player.swapSlotItem()).config.color			
				-- Placement Image
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.placementImage) == "null")) then
					newItem.parameters.placementImage = root.itemConfig(player.swapSlotItem()).config.placementImage					
				end
				-- Sit Cover Image (When Applicable)
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.sitCoverImage) == "null")) then
					newItem.parameters.sitCoverImage = root.itemConfig(player.swapSlotItem()).config.sitCoverImage			
				end			
				-- Large Image (When Applicable)
				if (not (sb.printJson(root.itemConfig(player.swapSlotItem()).config.largeImage) == "null")) then
					newItem.parameters.largeImage = root.itemConfig(player.swapSlotItem()).config.largeImage			
				end
				player.setSwapSlotItem(newItem)
			end	
		end
	end
end

function deadCells()
	local cellLevel = 0
	if (player.primaryHandItem()) then
		if (player.primaryHandItem().parameters.cellsConsumed ~= nil) then
		cellLevel = cellLevel + player.primaryHandItem().parameters.cellsConsumed
	end
	end
	if (player.primaryHandItem() ~= player.altHandItem()) then
		if (player.altHandItem()) then
			if (player.altHandItem().parameters.cellsConsumed ~= nil) then
				cellLevel = cellLevel + player.altHandItem().parameters.cellsConsumed
			end
		end
	end
	local powerLevel = 1+((math.sqrt(cellLevel+100)-10)/100)
	status.setStatusProperty("deadCellsPowerLevel", powerLevel)
	status.addEphemeralEffect("srm_deadCellsPower")
end

function setSectionId(playerName)
	local sectionData = root.assetJson("/config/srm_mag.config").sectionIds
	local sectionId = 0
	for i = 1, #playerName do
		local c = playerName:sub(i,i)
		local valueFound = nil
		for _, a in pairs(sectionData.characterTables) do
			local charArray = a.chars
			for _, v in pairs(charArray) do
				if (c == v) then
					valueFound = a.value
					break
				end
			end
			if valueFound then break end
		end
		if valueFound then sectionId = sectionId + valueFound end
	end
	sectionId = math.floor((sectionId % 10))
	local sectionName = "viridia"
	for k, v in pairs(sectionData.sectionTables) do
		if (sectionId == v) then
			sectionName = k
			break
		end
	end
	player.setProperty("magSectionId", sectionName)
end



--UTILITY FUNCTIONS UNDER HERE
--UTILITY FUNCTIONS UNDER HERE
--UTILITY FUNCTIONS UNDER HERE



--finds status, returns true if it is found
function hasStatus(theStatusInQuestion)
	effects = status.activeUniqueStatusEffectSummary()
	if (#effects > 0) then
		for i=1, #effects do
			if (effects[i][1] == theStatusInQuestion) then
				return true
			end
		end		 
	end
	return false
end