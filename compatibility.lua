local IsKnownRecipe
local GetFromLink
local HookGlobal

local isBagnon   = false
local isOneBag   = false
local isEngBags  = false
local isAllInOne = false
local isSUCCbag  = false
local isPfUI     = false

function RecipeColor.InitCompat(isKnownRecipeFn, getFromLinkFn, hookGlobalFn)
	IsKnownRecipe = isKnownRecipeFn
	GetFromLink   = getFromLinkFn
	HookGlobal    = hookGlobalFn

	isBagnon   = IsAddOnLoaded("Bagnon") or IsAddOnLoaded("Bagnon_Core")
	isOneBag   = (OneCore ~= nil)
	isEngBags  = IsAddOnLoaded("EngInventory") or IsAddOnLoaded("EngBags")
	isAllInOne = IsAddOnLoaded("AllInOneInventory")
	isPfUI     = IsAddOnLoaded("pfUI")

	-- Bagnon
	if isBagnon then
		local bagnonTicker = CreateFrame("Frame")
		bagnonTicker:Hide()
		bagnonTicker:SetScript("OnUpdate", function()
			if (not Bagnon or not Bagnon:IsShown()) and
			   (not Banknon or not Banknon:IsShown()) then
				this:Hide()
				return
			end
			if not CursorHasItem() then
				this:Hide()
			end
			local function ColorBagnonFrame(frame)
				if not frame or not frame:IsShown() then return end
				local size = frame.size
				if not size or size == 0 then return end
				local frameName = frame:GetName()
				for s = 1, size do
					local button = getglobal(frameName .. "Item" .. s)
					if button and button.hasItem and not button.isLink then
						local bagID = button:GetParent():GetID()
						local slotID = button:GetID()
						if IsKnownRecipe(bagID, slotID) then
							SetItemButtonTextureVertexColor(button, 0, 1, 0)
						end
					end
				end
			end
			ColorBagnonFrame(Bagnon)
			if Banknon then ColorBagnonFrame(Banknon) end
		end)
		RecipeColor.BagnonTicker = bagnonTicker

		local origFrame = BagnonFrame_Update
		HookGlobal("BagnonFrame_Update", function(frame, bagID)
			origFrame(frame, bagID)
			bagnonTicker:Show()
		end)

		local origGen = BagnonFrame_Generate
		HookGlobal("BagnonFrame_Generate", function(frame)
			origGen(frame)
			bagnonTicker:Show()
		end)
	end

	-- OneBag
	if isOneBag then
		local oneBagTicker = CreateFrame("Frame")
		oneBagTicker:Hide()
		oneBagTicker:SetScript("OnUpdate", function()
			this:Hide()
			local function ColorOneBagFrame(frame)
				if not frame or not frame:IsShown() then return end
				local handler = frame.handler
				if not handler or not handler.frame or not handler.frame.bags then return end
				for bag, bagFrame in pairs(handler.frame.bags) do
					if bagFrame and bagFrame.size and bagFrame.size > 0 then
						for slot = 1, bagFrame.size do
							local button = bagFrame[slot]
							if button and button:IsShown() then
								local bagID = bagFrame:GetID()
								local slotID = button:GetID()
								local link = GetContainerItemLink(bagID, slotID)
								if link then
									local itemid = GetFromLink(link)
									if itemid ~= -1 then
										local _, _, _, _, itemclass = GetItemInfo(itemid)
										if itemclass == "Recipe" and IsKnownRecipe(bagID, slotID) then
											SetItemButtonTextureVertexColor(button, 0, 1, 0)
										end
									end
								end
							end
						end
					end
				end
			end
			ColorOneBagFrame(OneBagFrame)
			if OneBankFrame then ColorOneBagFrame(OneBankFrame) end
		end)
		RecipeColor.OneBagTicker = oneBagTicker

		local origOneBagOnShow = OneBagFrame:GetScript("OnShow")
		OneBagFrame:SetScript("OnShow", function()
			if origOneBagOnShow then origOneBagOnShow() end
			oneBagTicker:Show()
		end)
	end

	-- OneView
	if isOneBag and OneView and OneView.FillBags then
		local origFillBags = OneView.FillBags
		OneView.FillBags = function(self)
			origFillBags(self)
			if not self.frame or not self.frame.bags then return end
			for bagID, bagFrame in pairs(self.frame.bags) do
				if bagFrame and bagFrame.size and bagFrame.size > 0 then
					for slot = 1, bagFrame.size do
						local button = bagFrame[slot]
						if button and button:IsShown() then
							SetItemButtonTextureVertexColor(button, 1, 1, 1)
						end
					end
				end
			end
			for bagID, bagFrame in pairs(self.frame.bags) do
				if bagFrame and bagFrame.size and bagFrame.size > 0 then
					for slot = 1, bagFrame.size do
						local button = bagFrame[slot]
						if button and button:IsShown() and button.itemId then
							local _, _, _, _, itemclass = GetItemInfo(button.itemId)
							if itemclass == "Recipe" then
								RecipeColor_ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
								RecipeColor_ScanTooltip:ClearLines()
								RecipeColor_ScanTooltip:SetHyperlink(button.itemId)
								local known = false
								for i = 1, 30 do
									local line = getglobal("RecipeColor_ScanTooltipTextLeft" .. i)
									if not line then break end
									local text = line:GetText()
									if text and string.find(text, "Already known") then
										known = true
										break
									end
								end
								if known then
									SetItemButtonTextureVertexColor(button, 0, 1, 0)
								end
							end
						end
					end
				end
			end
		end
	end

	-- EngInventory/EngInventory
	if isEngBags then
		local engTicker = CreateFrame("Frame")
		engTicker:Hide()
		engTicker:SetScript("OnUpdate", function()
			if not EngInventory_frame or not EngInventory_frame:IsShown() then
				this:Hide()
				return
			end
			if not EngInventory_buttons or not EngInventory_item_cache then
				this:Hide()
				return
			end
			if not CursorHasItem() then
				this:Hide()
			end
			for frameName, btnData in pairs(EngInventory_buttons) do
				local bagnum = btnData["bagnum"]
				local slotnum = btnData["slotnum"]
				local itm = EngInventory_item_cache[bagnum] and EngInventory_item_cache[bagnum][slotnum]
				if itm and itm["itemlink"] and itm["itemtype"] == "Recipe" then
					if IsKnownRecipe(bagnum, slotnum) then
						local iconTexture = getglobal(frameName .. "IconTexture")
						if iconTexture then
							iconTexture:SetVertexColor(0, 1, 0, 1)
						end
					end
				end
			end
		end)
		RecipeColor.EngTicker = engTicker

		local origInv = EngInventory_UpdateButton
		HookGlobal("EngInventory_UpdateButton", function(itemframe, itm)
			origInv(itemframe, itm)
			engTicker:Show()
		end)

		-- EngBank
		if EngBank_UpdateButton then
			local origBank = EngBank_UpdateButton
			HookGlobal("EngBank_UpdateButton", function(itemframe, itm)
				origBank(itemframe, itm)
				if not itm or not itm["itemlink"] then return end
				if itm["itemtype"] ~= "Recipe" then return end
				if IsKnownRecipe(itm["bagnum"], itm["slotnum"]) then
					local iconTexture = getglobal(itemframe:GetName() .. "IconTexture")
					if iconTexture then
						iconTexture:SetVertexColor(0, 1, 0, 1)
					end
				end
			end)
		end
	end

	-- AllInOneInventory
	if isAllInOne then
		local origUpdate = AllInOneInventoryFrame_UpdateButton
		HookGlobal("AllInOneInventoryFrame_UpdateButton", function(slot, object)
			origUpdate(slot, object)
			RecipeColor:AddOnCore_SetAddon(slot, object)
		end)
		local origCooldown = AIOBFrame_UpdateCooldown
		HookGlobal("AIOBFrame_UpdateCooldown", function(slot, object)
			origCooldown(slot, object)
			RecipeColor:AddOnCore_SetAddon(slot, object)
		end)
	end

	-- pfUI loot frame
	if isPfUI and pfUI and pfUI.loot then
		local function PfUIColorLootSlots()
			if not pfUI.loot or not pfUI.loot.slots then return end
			for _, slot in pairs(pfUI.loot.slots) do
				if slot and slot:IsShown() and slot.icon then
					slot.icon:SetVertexColor(1, 1, 1)
				end
			end
			for _, slot in pairs(pfUI.loot.slots) do
				if slot and slot:IsShown() and slot.icon then
					local lootSlot = slot:GetID()
					if lootSlot and lootSlot > 0 and LootSlotIsItem(lootSlot) then
						local link = GetLootSlotLink(lootSlot)
						if link then
							local itemid = GetFromLink(link)
							if itemid ~= -1 then
								local _, _, _, _, itemclass = GetItemInfo(itemid)
								if itemclass == "Recipe" then
									RecipeColor_ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
									RecipeColor_ScanTooltip:ClearLines()
									RecipeColor_ScanTooltip:SetLootItem(lootSlot)
									for i = 1, 30 do
										local line = getglobal("RecipeColor_ScanTooltipTextLeft" .. i)
										if not line then break end
										local text = line:GetText()
										if text and string.find(text, "Already known") then
											slot.icon:SetVertexColor(0, 1, 0)
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end

		local origUpdateLootFrame = pfUI.loot.UpdateLootFrame
		pfUI.loot.UpdateLootFrame = function(self)
			origUpdateLootFrame(self)
			PfUIColorLootSlots()
		end
	end

	-- pfUI bag frame
	if isPfUI and pfUI and pfUI.bag then
		local function PfUIColorSlot(bag, slot)
			if not pfUI.bags[bag] then return end
			if not pfUI.bags[bag].slots[slot] then return end
			local frame = pfUI.bags[bag].slots[slot].frame
			if not frame or not frame.hasItem then return end
			local link = GetContainerItemLink(bag, slot)
			if not link then return end
			local itemid = GetFromLink(link)
			if itemid == -1 then return end
			local _, _, _, _, itemclass = GetItemInfo(itemid)
			if itemclass ~= "Recipe" then return end
			if IsKnownRecipe(bag, slot) then
				SetItemButtonTextureVertexColor(frame, 0, 1, 0)
			end
		end

		if pfUI.unusable then
			-- "Highlight Unusable Items" ON: hook the unusable update to run last.
			local origPfUIUnusableUpdateSlot = pfUI.unusable.UpdateSlot
			pfUI.unusable.UpdateSlot = function(self, bag, slot)
				origPfUIUnusableUpdateSlot(self, bag, slot)
				PfUIColorSlot(bag, slot)
			end
		else
			-- "Highlight Unusable Items" OFF: hook UpdateSlot and UpdateItemLock.
			-- Bank slots are skipped here and handled by the deferred ticker,
			-- because SetInventoryItem races the server inside synchronous hooks.
			local origPfUIUpdateSlot = pfUI.bag.UpdateSlot
			pfUI.bag.UpdateSlot = function(self, bag, slot)
				origPfUIUpdateSlot(self, bag, slot)
				if bag ~= -1 then
					PfUIColorSlot(bag, slot)
				end
			end

			local origPfUIUpdateItemLock = pfUI.bag.UpdateItemLock
			pfUI.bag.UpdateItemLock = function(self)
				origPfUIUpdateItemLock(self)
				for bag = -2, 11 do
					if bag ~= -1 then
						local bagsize = GetContainerNumSlots(bag)
						if bag == -2 and pfUI.bag.showKeyring == true then bagsize = GetKeyRingSize() end
						for slot = 1, bagsize do
							PfUIColorSlot(bag, slot)
						end
					end
				end
				-- Show the bank ticker after UpdateItemLock has reset bank slot colors.
				if RecipeColor.PfUIBankTicker and pfUI.bag.left
						and pfUI.bag.left:IsShown() then
					RecipeColor.PfUIBankTicker:Show()
				end
			end

			-- Hook UpdateBag: when bag == -1 this runs inside pfUI's 0.1s deferred
			-- tick, so server data has settled and PfUIColorSlot is safe to call directly.
			local origPfUIUpdateBag = pfUI.bag.UpdateBag
			pfUI.bag.UpdateBag = function(self, bag)
				origPfUIUpdateBag(self, bag)
				if bag == -1 then
					if not pfUI.bags[-1] then return end
					local bagsize = GetContainerNumSlots(BANK_CONTAINER)
					for slot = 1, bagsize do
						PfUIColorSlot(-1, slot)
					end
				end
			end

			-- Deferred ticker for bank slot coloring (BANKFRAME_OPENED, ITEM_LOCK_CHANGED).
			local pfUIBankTicker = CreateFrame("Frame")
			pfUIBankTicker:Hide()
			pfUIBankTicker:SetScript("OnUpdate", function()
				if not pfUI.bag.left or not pfUI.bag.left:IsShown() then
					this:Hide()
					return
				end
				this:Hide()
				if not pfUI.bags[-1] then return end
				local bagsize = GetContainerNumSlots(BANK_CONTAINER)
				for slot = 1, bagsize do
					PfUIColorSlot(-1, slot)
				end
				for bag = 5, 11 do
					local bsize = GetContainerNumSlots(bag)
					for slot = 1, bsize do
						PfUIColorSlot(bag, slot)
					end
				end
			end)
			RecipeColor.PfUIBankTicker = pfUIBankTicker
		end
	end

	-- guda
	if Guda_ItemButton_SetItem then
		local origGuda = Guda_ItemButton_SetItem
		HookGlobal("Guda_ItemButton_SetItem", function(button, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
			local itemclass = itemData and itemData.class
			if not itemclass and itemData and itemData.link then
				local itemid = GetFromLink(itemData.link)
				if itemid ~= -1 then
					local _, _, _, _, cls = GetItemInfo(itemid)
					itemclass = cls
				end
			end
			origGuda(button, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
			if itemclass == "Recipe" and button.hasItem
					and not button.isReadOnly and not button.otherChar then
				if button.unusableOverlay and button.unusableOverlay:IsShown() then
					-- Only recolor if actually known — a genuinely unusable recipe stays red.
					if IsKnownRecipe(button.bagID, button.slotID) then
						button.unusableOverlay:SetVertexColor(0, 1, 0, button.unusableOverlay:GetAlpha())
					end
				elseif IsKnownRecipe(button.bagID, button.slotID) then
					if not button.unusableOverlay then
						local icon = getglobal(button:GetName().."IconTexture")
							or getglobal(button:GetName().."Icon")
						local overlay = (icon and icon:GetParent() or button):CreateTexture(nil, "OVERLAY")
						overlay:SetAllPoints(icon or button)
						overlay:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
						overlay:Hide()
						button.unusableOverlay = overlay
					end
					button.unusableOverlay:SetVertexColor(0, 1, 0, 0.45)
					button.unusableOverlay:Show()
				end
			end
		end)
	end
end

-- AllInOneInventory per-slot dispatch (called from the AllInOneInventory hooks above).
function RecipeColor:AddOnCore_SetAddon(slot, object)
	if isAllInOne then
		local name = slot:GetName()
		if name == "AllInOneInventoryFrame" then
			local item = getglobal(name .. "Item" .. object)
			if (not item) or (not item:IsVisible()) then return end
			local bagn, slotn = AllInOneInventory_GetIdAsBagSlot(item:GetID())
			if (bagn == -1) and (slotn == -1) then return end
			-- ColorSlot is local in RecipeColor.lua; replicate inline here.
			if item:IsVisible() then
				local itemid = GetFromLink(GetContainerItemLink(bagn, slotn))
				if itemid ~= -1 then
					local _, _, _, _, itemclass = GetItemInfo(itemid)
					if itemclass == "Recipe" and IsKnownRecipe(bagn, slotn) then
						SetItemButtonTextureVertexColor(getglobal(item:GetName()), 0, 1, 0)
					end
				end
			end
		else
			local bagn  = slot.bagIndex
			local slotn = slot.itemIndex
			if slot:IsVisible() then
				local itemid = GetFromLink(GetContainerItemLink(bagn, slotn))
				if itemid ~= -1 then
					local _, _, _, _, itemclass = GetItemInfo(itemid)
					if itemclass == "Recipe" and IsKnownRecipe(bagn, slotn) then
						SetItemButtonTextureVertexColor(getglobal(slot:GetName()), 0, 1, 0)
					end
				end
			end
		end
	end
	if isOneBag then
		local bag = slot:GetParent()
		local bagn = bag:GetID()
		local slotn = slot:GetID()
		if GetContainerItemLink(bagn, slotn) then
			if IsKnownRecipe(bagn, slotn) then
				SetItemButtonTextureVertexColor(getglobal(slot:GetName()), 0, 1, 0)
			end
		end
	end
end

-- Deferred event handler for compat addons. Called from RecipeColor_OnEvent.
function RecipeColor.OnCompatEvent(event, arg1)
	-- SUCC-bag loads after RecipeColor (S > R), so its hook is installed here
	-- when its own ADDON_LOADED fires. A deferred OnUpdate ticker is used because
	-- BAG_UPDATE fires before SUCC-bag finishes its own ItemUpdate calls.
	if event == "ADDON_LOADED" and arg1 == "SUCC-bag" then
		isSUCCbag = true

		local succTicker = CreateFrame("Frame")
		succTicker:Hide()
		succTicker:SetScript("OnUpdate", function()
			this:Hide()
			local frames = {SUCC_bag, SUCC_bag.bank, SUCC_bag.keyring}
			for _, frame in ipairs(frames) do
				if frame and frame:IsShown() and frame.size and frame.size > 0 then
					local frameName = frame:GetName()
					for s = 1, frame.size do
						local button = getglobal(frameName .. "Item" .. s)
						if button and button.hasItem then
							local bagID = button:GetParent():GetID()
							local slotID = button:GetID()
							local link = GetContainerItemLink(bagID, slotID)
							if link then
								local itemid = GetFromLink(link)
								if itemid ~= -1 then
									local _, _, _, _, itemclass = GetItemInfo(itemid)
									if itemclass == "Recipe" and IsKnownRecipe(bagID, slotID) then
										SetItemButtonTextureVertexColor(button, 0, 1, 0)
									end
								end
							end
						end
					end
				end
			end
		end)

		local origOpen = SBFrameOpen
		HookGlobal("SBFrameOpen", function(frame, automatic)
			origOpen(frame, automatic)
			succTicker:Show()
		end)

		RecipeColor.SUCCTicker = succTicker
	end

	if isSUCCbag and RecipeColor.SUCCTicker then
		if event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED"
				or event == "BAG_UPDATE_COOLDOWN" or event == "UPDATE_INVENTORY_ALERTS"
				or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
			RecipeColor.SUCCTicker:Show()
		end
	end

	if isBagnon and RecipeColor.BagnonTicker then
		if event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED"
				or event == "BAG_UPDATE_COOLDOWN" or event == "UPDATE_INVENTORY_ALERTS"
				or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
			RecipeColor.BagnonTicker:Show()
		end
	end
end
