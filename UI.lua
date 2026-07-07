---------------------------------------------------------
-- SmartAH UI Module (UI.lua)
---------------------------------------------------------

---------------------------------------------------------
-- PANEL SOM BLIZZARD-AUCTION-HOUSE-STIL
---------------------------------------------------------


if not SmartAH_DebugLog then
    SmartAH_DebugLog = {}
end

---------------------------------------------------------
-- DEBUG FOR UI (SAVES TO SAVEDVARIABLES)
---------------------------------------------------------

local function dbg_ui(msg)
    local text = "[SmartAH UI DEBUG] " .. tostring(msg)

    -- Print to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cffff00ff" .. text .. "|r")

    -- Save to SavedVariables
    table.insert(SmartAH_DebugLog, text)
end

local panel = CreateFrame("Frame", "SmartAHPanel", UIParent)
panel:SetWidth(250)
panel:SetHeight(260)
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 850, -200)

panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

panel:SetBackdropColor(0, 0, 0, 0.85)
panel:SetFrameStrata("MEDIUM")
panel:SetFrameLevel(10)
panel:Hide()

---------------------------------------------------------
-- TITLE
---------------------------------------------------------

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -20)
title:SetText("SmartAH")
title:SetTextColor(1, 0.82, 0)
title:SetShadowColor(0, 0, 0, 1)
title:SetShadowOffset(2, -2)

---------------------------------------------------------
-- BUTTON CREATOR
---------------------------------------------------------

local function CreateBlizzButton(name, text, x, y)
    local btn = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
    btn:SetWidth(80)
    btn:SetHeight(22)
    btn:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    btn:SetText(text)
    return btn
end

local btnScan  = CreateBlizzButton("SmartAH_ScanBtn",   "Scan",    20, -50)
local btnPrev  = CreateBlizzButton("SmartAH_PrevBtn",   "Preview", 20, -80)
local btnBuy   = CreateBlizzButton("SmartAH_BuyBtn",    "Buy",     20, -110)
local btnClear = CreateBlizzButton("SmartAH_ClearBtn",  "Clear",   20, -140)
local btnSell  = CreateBlizzButton("SmartAH_SellBtn",   "Sell",    20, -170)

---------------------------------------------------------
-- ORDER EDITBOX
---------------------------------------------------------

local editbox = CreateFrame("EditBox", "SmartAH_EditBox", panel, "InputBoxTemplate")
editbox:SetWidth(33)
editbox:SetHeight(20)
editbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, -50)
editbox:SetAutoFocus(false)
editbox:SetNumeric(true)

local orderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
orderLabel:SetPoint("LEFT", editbox, "RIGHT", 5, 0)
orderLabel:SetText("Order")

---------------------------------------------------------
-- ITEM SLOT
---------------------------------------------------------

local itemSlot = CreateFrame("Button", "SmartAH_ItemSlot", panel, "ItemButtonTemplate")
itemSlot:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, -90)
itemSlot:SetWidth(37)
itemSlot:SetHeight(37)

itemSlot.icon = getglobal(itemSlot:GetName().."IconTexture")
itemSlot.icon:SetTexture(nil)
itemSlot.itemLink = nil

---------------------------------------------------------
-- BAG CLICK HOOKS (FINAL PATCHED VERSION)
---------------------------------------------------------

-- Save original Blizzard handler once
if not SmartAH_Orig_ContainerFrameItemButton_OnClick then
    SmartAH_Orig_ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
end

function ContainerFrameItemButton_OnClick(button, ignoreModifiers)
    -- Our custom right-click handler for SmartAH
    if button == "RightButton"
       and AuctionFrame and AuctionFrame:IsShown()
       and SmartAHPanel and SmartAHPanel:IsShown() then

        local bag  = this:GetParent():GetID()
        local slot = this:GetID()
        local link = GetContainerItemLink(bag, slot)

        SmartAH_UI_OnItemSelected(link)
        return
    end

    -- Fallback to original Blizzard behavior
    SmartAH_Orig_ContainerFrameItemButton_OnClick(button, ignoreModifiers)
end

---------------------------------------------------------
-- STACK SIZE / COUNT / UNIT PRICE
---------------------------------------------------------

SmartAH_StackSizeBox = CreateFrame("EditBox", "SmartAH_StackSizeBox", panel, "InputBoxTemplate")
SmartAH_StackSizeBox:SetWidth(33)
SmartAH_StackSizeBox:SetHeight(20)
SmartAH_StackSizeBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, -140)
SmartAH_StackSizeBox:SetAutoFocus(false)
SmartAH_StackSizeBox:SetNumeric(false)

local stackSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stackSizeLabel:SetPoint("LEFT", SmartAH_StackSizeBox, "RIGHT", 5, 0)
stackSizeLabel:SetText("Stack Size")

SmartAH_StackCountBox = CreateFrame("EditBox", "SmartAH_StackCountBox", panel, "InputBoxTemplate")
SmartAH_StackCountBox:SetWidth(33)
SmartAH_StackCountBox:SetHeight(20)
SmartAH_StackCountBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, -170)
SmartAH_StackCountBox:SetAutoFocus(false)
SmartAH_StackCountBox:SetNumeric(false)

local stackCountLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stackCountLabel:SetPoint("LEFT", SmartAH_StackCountBox, "RIGHT", 5, 0)
stackCountLabel:SetText("Stacks")

SmartAH_UnitPriceBox = CreateFrame("EditBox", "SmartAH_UnitPriceBox", panel, "InputBoxTemplate")
SmartAH_UnitPriceBox:SetWidth(80)
SmartAH_UnitPriceBox:SetHeight(20)
SmartAH_UnitPriceBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 84, -200)
SmartAH_UnitPriceBox:SetAutoFocus(false)
SmartAH_UnitPriceBox:SetNumeric(true)

local unitPriceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitPriceLabel:SetPoint("LEFT", SmartAH_UnitPriceBox, "RIGHT", 5, 0)
unitPriceLabel:SetText("Unit Price")

---------------------------------------------------------
-- BUTTON SCRIPTS
---------------------------------------------------------

btnScan:SetScript("OnClick", function()
    SmartAH_ScanAllPages()
end)

btnPrev:SetScript("OnClick", function()
    SmartAH_Preview()
end)

btnBuy:SetScript("OnClick", function()
    SmartAH_Buy()
end)

btnSell:SetScript("OnClick", function()

    local itemLink = SmartAH_ItemSlot.itemLink
    if not itemLink then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SmartAH:|r Select an item first.")
        return
    end

    local stackSize  = tonumber(SmartAH_StackSizeBox:GetText()) or 1
    local stackCount = tonumber(SmartAH_StackCountBox:GetText()) or 1
    local unitPrice  = SmartAH_UnitPriceBox:GetNumber()

    SmartAH_Sell_Start(itemLink, stackSize, stackCount, unitPrice)
end)

btnClear:SetScript("OnClick", function()
    SmartAH_EditBox:SetText("")
    SmartAH_StackSizeBox:SetText("")
    SmartAH_StackCountBox:SetText("")
    SmartAH_UnitPriceBox:SetText("")
    SmartAH_ItemSlot.itemLink = nil
    SmartAH_ItemSlot.icon:SetTexture(nil)
end)

---------------------------------------------------------
-- ITEM SELECTION HANDLER (FINAL FIXED VERSION)
---------------------------------------------------------

function SmartAH_UI_OnItemSelected(itemLink)

    dbg_ui("raw itemLink = " .. tostring(itemLink))

    ---------------------------------------------------------
    -- Extract itemID (Vanilla-safe)
    ---------------------------------------------------------
    local itemID = nil
    local startPos = string.find(itemLink, "item:")
    if startPos then
        local idStart = startPos + 5
        local idEnd = string.find(itemLink, ":", idStart)
        if idEnd then
            itemID = tonumber(string.sub(itemLink, idStart, idEnd - 1))
        end
    end

    if not itemID then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SmartAH:|r Could not extract itemID.")
        return
    end

    ---------------------------------------------------------
    -- Get item name
    ---------------------------------------------------------
    local name = GetItemInfo(itemID)
    if not name then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SmartAH:|r Could not read item name.")
        return
    end

    ---------------------------------------------------------
    -- Fill UI slot (icon)
    ---------------------------------------------------------
    SmartAH_ItemSlot.itemLink = itemLink

    local texture = nil
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link == itemLink then
                texture = GetContainerItemInfo(bag, slot)
                break
            end
        end
        if texture then break end
    end

    SmartAH_ItemSlot.icon:SetTexture(texture)

    ---------------------------------------------------------
    -- CALCULATE BEST STACK SIZE AND FULL STACK COUNT
    ---------------------------------------------------------

    -- 1. Find the largest actual stack size in bags
    local largestStack = 1
    local totalItems = 0

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link == itemLink then
                local _, count = GetContainerItemInfo(bag, slot)
                count = count or 1

                -- Track total items
                totalItems = totalItems + count

                -- Track largest actual stack
                if count > largestStack then
                    largestStack = count
                end
            end
        end
    end

    -- 2. Calculate full stacks based on largest actual stack
    local fullStacks = math.floor(totalItems / largestStack)

    -- 3. Fill UI
    SmartAH_StackSizeBox:SetText(largestStack)
    SmartAH_StackCountBox:SetText(fullStacks)

    dbg_ui("UI.lua largestStack = " .. tostring(largestStack))
    dbg_ui("UI.lua totalItems = " .. tostring(totalItems))
    dbg_ui("UI.lua fullStacks = " .. tostring(fullStacks))

    ---------------------------------------------------------
    -- Set AH search
    ---------------------------------------------------------
    if BrowseName then
        BrowseName:SetText(name)
    end

    ---------------------------------------------------------
    -- Trigger scan
    ---------------------------------------------------------
    SmartAH_ScanAllPages()

    ---------------------------------------------------------
    -- Auto-price flag
    ---------------------------------------------------------
    SmartAH_AutoPricePending = name
    dbg_ui("UI.lua set AutoPricePending = " .. tostring(SmartAH_AutoPricePending))
end

---------------------------------------------------------
-- SHOW/HIDE
---------------------------------------------------------

function SmartAH_ShowPanel()
    if AuctionFrame and AuctionFrame:IsShown() then
        panel:Show()
    end
end

function SmartAH_HidePanel()
    panel:Hide()
end
