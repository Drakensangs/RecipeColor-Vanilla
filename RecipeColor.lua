RecipeColor = {}

-- Returns the numeric item ID from a hyperlink string, or -1 if not found.
local function GetFromLink(link)
	if link ~= nil then
		local _, _, id = string.find(link, "|c%x+|Hitem:(%d+):%d+:%d+:%d+|h%[.-%]|h|r")
		if id ~= nil then return id end
	end
	return -1
end

-- Returns the ContainerFrame name for a given bag ID, or nil if not visible.
local function GetContainerFrameName(id)
	for i = 1, NUM_CONTAINER_FRAMES, 1 do
		local containerFrame = getglobal("ContainerFrame" .. i)
		if containerFrame:IsShown() and containerFrame:GetID() == id then
			return "ContainerFrame" .. i
		end
	end
	return nil
end

-- Returns the BankFrameItem index (offset by 39) for a given slot ID.
local function GetBankFrameInventorySlot(slot)
	for i = 1, NUM_BANKGENERIC_SLOTS, 1 do
		local bankSlot = getglobal("BankFrameItem" .. i)
		if bankSlot:GetID() == slot then
			return i + 39
		end
	end
	return nil
end

-- Resolved once at initialization to avoid getglobal calls on every scan.
local ScanTooltipLines

-- Checks if an item is an already-known recipe via a hidden tooltip scan.
-- SetOwner is called before every scan because other addons (e.g. guda) can
-- silently invalidate our tooltip by calling SetOwner on their own scan tooltip.
local function IsKnownRecipe(bag, slot)
	RecipeColor_ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	RecipeColor_ScanTooltip:ClearLines()
	if bag == -1 then
		RecipeColor_ScanTooltip:SetInventoryItem("player", GetBankFrameInventorySlot(slot))
	elseif bag == "MailBox" then
		RecipeColor_ScanTooltip:SetInboxItem(slot)
	elseif bag == "Merchant" then
		RecipeColor_ScanTooltip:SetMerchantItem(slot)
	else
		RecipeColor_ScanTooltip:SetBagItem(bag, slot)
	end
	for i = 1, table.getn(ScanTooltipLines) do
		local text = ScanTooltipLines[i]:GetText()
		if text and string.find(text, "Already known") then
			return true
		end
	end
	return false
end

-- Colors a single item frame green if it is a known recipe.
local function ColorSlot(bag, slot, itemFrame)
	if itemFrame == nil or not itemFrame:IsVisible() then return end
	local itemid = GetFromLink(GetContainerItemLink(bag, slot))
	if itemid == -1 then return end
	local _, _, _, _, itemclass = GetItemInfo(itemid)
	if itemclass == "Recipe" then
		if IsKnownRecipe(bag, slot) then
			SetItemButtonTextureVertexColor(itemFrame, 0, 1, 0)
		end
	end
end

-- Hook helpers.
local globalHooks = {}

local function HookGlobal(funcName, newFunc)
	globalHooks[funcName] = getglobal(funcName)
	setglobal(funcName, newFunc)
end

local function IsHookedGlobal(funcName)
	return globalHooks[funcName] ~= nil
end

local methodHooks = {}

local function HookMethod(obj, methodName, newFunc)
	if not methodHooks[obj] then methodHooks[obj] = {} end
	methodHooks[obj][methodName] = obj[methodName]
	obj[methodName] = newFunc
end

local function IsHookedMethod(obj, methodName)
	return methodHooks[obj] ~= nil and methodHooks[obj][methodName] ~= nil
end

-- Colors known recipes green in all open bags.
function RecipeColor:ColorKnownRecipesInBags()
	for bag = 0, 11, 1 do
		local numSlots = GetContainerNumSlots(bag)
		local bagName = GetContainerFrameName(bag)
		if bagName and numSlots > 0 then
			for slot = 1, numSlots do
				local itemFrame = getglobal(bagName .. "Item" .. (numSlots - (slot - 1)))
				ColorSlot(bag, slot, itemFrame)
			end
		end
	end
end

-- Colors known recipes green in the main bank frame.
function RecipeColor:ColorKnownRecipesInBank()
	local bag = BANK_CONTAINER
	for slot = 1, GetContainerNumSlots(bag) do
		local itemFrame = getglobal("BankFrameItem" .. slot)
		ColorSlot(bag, slot, itemFrame)
	end
end

-- Colors known recipes green in the mailbox.
function RecipeColor:ColorKnownRecipesInMail()
	if not MailFrame:IsVisible() then return end
	local numItems = GetInboxNumItems()
	local pageNum = InboxFrame.pageNum or 1
	local startIndex = (pageNum - 1) * 7 + 1
	for frameSlot = 1, 7 do
		local icon = getglobal("MailItem" .. frameSlot .. "ButtonIcon")
		if icon then icon:SetVertexColor(1, 1, 1) end
	end
	for frameSlot = 1, 7 do
		local i = startIndex + (frameSlot - 1)
		if i > numItems then break end
		local _, _, _, _, canUse = GetInboxItem(i)
		local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(i)
		if canUse and hasItem and IsKnownRecipe("MailBox", i) then
			local icon = getglobal("MailItem" .. frameSlot .. "ButtonIcon")
			if icon then
				SetDesaturation(icon, nil)
				icon:SetVertexColor(0, 1, 0)
			end
		end
	end
end

-- Colors known recipes green at the merchant.
function RecipeColor:ColorKnownRecipesAtMerchant()
	if not MerchantFrame:IsVisible() then return end
	local numMerchantItems = GetMerchantNumItems()
	for i = 1, MERCHANT_ITEMS_PER_PAGE, 1 do
		local index = (((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i)
		if index <= numMerchantItems then
			if IsKnownRecipe("Merchant", index) then
				local itemButton = getglobal("MerchantItem" .. i .. "ItemButton")
				local merchantButton = getglobal("MerchantItem" .. i)
				SetItemButtonNameFrameVertexColor(merchantButton, 0, 1, 0)
				SetItemButtonSlotVertexColor(merchantButton, 0, 1, 0)
				SetItemButtonTextureVertexColor(itemButton, 0, 1, 0)
				SetItemButtonNormalTextureVertexColor(itemButton, 0, 1, 0)
			end
		end
	end
end

-- Builds an OnShow closure for a ContainerFrame bag.
local function MakeBagOnShow(frame)
	local orig = frame:GetScript("OnShow")
	if not orig then orig = function() end end
	return function()
		local bag = frame:GetID()
		local numSlots = GetContainerNumSlots(bag)
		local bagName = GetContainerFrameName(bag)
		if bagName then
			for slot = 1, numSlots do
				local itemFrame = getglobal(bagName .. "Item" .. (numSlots - (slot - 1)))
				ColorSlot(bag, slot, itemFrame)
			end
		end
		orig()
	end
end

-- Builds an OnShow closure for a BankFrameItem slot button.
local function MakeBankOnShow(frame)
	local orig = frame:GetScript("OnShow")
	if not orig then orig = function() end end
	return function()
		local slot = frame:GetID()
		ColorSlot(BANK_CONTAINER, slot, frame)
		orig()
	end
end

-- Initializes all hooks. Called exactly once when ADDON_LOADED fires.
local function RecipeColor_Initialize()
	-- Resolve scan tooltip text lines once.
	ScanTooltipLines = {}
	for i = 1, 30 do
		local line = getglobal("RecipeColor_ScanTooltipTextLeft" .. i)
		if line then
			ScanTooltipLines[i] = line
		else
			break
		end
	end

	-- Hook Blizzard bag/bank frame OnShow scripts.
	local bagFrames = {
		ContainerFrame1,  ContainerFrame2,  ContainerFrame3,
		ContainerFrame4,  ContainerFrame5,  ContainerFrame6,
		ContainerFrame7,  ContainerFrame8,  ContainerFrame9,
		ContainerFrame10, ContainerFrame11, ContainerFrame12,
	}
	for _, f in ipairs(bagFrames) do
		f:SetScript("OnShow", MakeBagOnShow(f))
	end
	for i = 1, 24 do
		local f = getglobal("BankFrameItem" .. i)
		f:SetScript("OnShow", MakeBankOnShow(f))
	end
	RecipeColor.BagFrames = bagFrames

	-- Hook MerchantFrame_Update.
	local orig = MerchantFrame_Update
	HookGlobal("MerchantFrame_Update", function()
		orig()
		RecipeColor:ColorKnownRecipesAtMerchant()
	end)

	local origInbox = InboxFrame_Update
	HookGlobal("InboxFrame_Update", function()
		origInbox()
		for i = 1, 7 do
			local mailItem = getglobal("MailItem" .. i)
			if mailItem then
				mailItem:Hide()
				mailItem:Show()
			end
		end
		RecipeColor:ColorKnownRecipesInMail()
	end)

	-- Initialize compatibility hooks if the compatibility module is loaded.
	if RecipeColor.InitCompat then
		RecipeColor.InitCompat(IsKnownRecipe, GetFromLink, HookGlobal)
	end
end

-- Event handler.
function RecipeColor_OnEvent(this, event, arg1)
	-- Initialize all hooks exactly once.
	if event == "ADDON_LOADED" and not RecipeColor._initialized then
		RecipeColor._initialized = true
		RecipeColor_Initialize()
	end

	-- Dispatch compat addon events (e.g. SUCC-bag loads after RecipeColor).
	if RecipeColor.OnCompatEvent then
		RecipeColor.OnCompatEvent(event, arg1)
	end

	-- Standard bag/bank/mail events.
	if event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN"
			or event == "UPDATE_INVENTORY_ALERTS" then
		if RecipeColor.BagFrames and RecipeColor.BagFrames[1]
				and RecipeColor.BagFrames[1].bagsShown > 0 then
			RecipeColor:ColorKnownRecipesInBags()
		end
		if BankFrame:IsVisible() then
			RecipeColor:ColorKnownRecipesInBank()
		end
		if RecipeColor.OneBagTicker then
			RecipeColor.OneBagTicker:Show()
		end
	elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
		if RecipeColor.BagFrames and RecipeColor.BagFrames[1]
				and RecipeColor.BagFrames[1].bagsShown > 0 then
			RecipeColor:ColorKnownRecipesInBags()
		end
		if BankFrame:IsVisible() then
			RecipeColor:ColorKnownRecipesInBank()
		end
		if RecipeColor.OneBagTicker then
			RecipeColor.OneBagTicker:Show()
		end
		if RecipeColor.PfUIBankTicker then
			RecipeColor.PfUIBankTicker:Show()
		end
	end
end

function RecipeColor_OnLoad()
	this:RegisterEvent("ADDON_LOADED")
	this:RegisterEvent("BAG_UPDATE")
	this:RegisterEvent("ITEM_LOCK_CHANGED")
	this:RegisterEvent("BAG_UPDATE_COOLDOWN")
	this:RegisterEvent("UPDATE_INVENTORY_ALERTS")
	this:RegisterEvent("BANKFRAME_OPENED")
	this:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
end
