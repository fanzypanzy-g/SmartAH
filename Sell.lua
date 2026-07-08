---------------------------------------------------------
-- SmartAH Sell Module (Sell.lua) - FULL DEBUG VERSION
---------------------------------------------------------

SmartAH_SellRunning        = false
SmartAH_SellPendingAuction = false
SmartAH_SellItemLink       = nil
SmartAH_SellStackSize      = 0
SmartAH_SellStackCount     = 0
SmartAH_SellUnitPrice      = 0
SmartAH_SellStacksPosted   = 0

SmartAH_AutoPricePending   = nil

if not SmartAH_DebugLog then
    SmartAH_DebugLog = {}
end

---------------------------------------------------------
-- DEBUG (PATCHED TO SAVE TO SAVEDVARIABLES)
---------------------------------------------------------

local function dbg(msg)
    local text = "[SmartAH SELL DEBUG] " .. tostring(msg)

    -- Print to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800" .. text .. "|r")

    -- Save to SavedVariables
    table.insert(SmartAH_DebugLog, text)
end

---------------------------------------------------------
-- INVENTORY HELPERS
---------------------------------------------------------

local function SmartAH_Sell_GetInventoryCount(itemLink)
    dbg("GetInventoryCount called for itemLink = " .. tostring(itemLink))

    if not itemLink then
        dbg("GetInventoryCount: itemLink is nil, returning 0")
        return 0
    end

    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        dbg("Scanning bag " .. bag .. " with " .. slots .. " slots")
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link == itemLink then
                local _, count = GetContainerItemInfo(bag, slot)
                dbg("Found matching item in bag " .. bag .. ", slot " .. slot .. ", count = " .. tostring(count))
                total = total + (count or 0)
            end
        end
    end

    dbg("GetInventoryCount: total = " .. total)
    return total
end

local function SmartAH_Sell_FindStack(itemLink, minCount)
    dbg("FindStack called for itemLink = " .. tostring(itemLink) .. ", minCount = " .. tostring(minCount))

    if not itemLink then
        dbg("FindStack: itemLink is nil, returning nil")
        return nil, nil, nil
    end

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        dbg("FindStack: scanning bag " .. bag .. " with " .. slots .. " slots")
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link == itemLink then
                local _, count = GetContainerItemInfo(bag, slot)
                dbg("FindStack: found item in bag " .. bag .. ", slot " .. slot .. ", count = " .. tostring(count))
                if (count or 0) >= minCount then
                    dbg("FindStack: stack meets requirement, returning bag=" .. bag .. ", slot=" .. slot .. ", count=" .. tostring(count))
                    return bag, slot, count
                else
                    dbg("FindStack: stack too small (" .. tostring(count) .. "), needed " .. tostring(minCount))
                end
            end
        end
    end

    dbg("FindStack: no suitable stack found")
    return nil, nil, nil
end

---------------------------------------------------------
-- SELL ON EVENT (PAGE-NIL FIX FÖR 1.12.1)
---------------------------------------------------------

function SmartAH_Sell_OnEvent(self, event)
    dbg("Sell_OnEvent: event=" .. tostring(event))

    -- AH öppnas → page får ALDRIG vara nil
    if event == "AUCTION_HOUSE_SHOW" then
        if AuctionFrameBrowse and AuctionFrameBrowse.page == nil then
            AuctionFrameBrowse.page = 0
            dbg("Sell_OnEvent: AuctionFrameBrowse.page was nil, set to 0")
        else
            dbg("Sell_OnEvent: AuctionFrameBrowse.page already set: " .. tostring(AuctionFrameBrowse.page))
        end
        return
    end

    -- AH stängs → stoppa säljet
    if event == "AUCTION_HOUSE_CLOSED" then
        dbg("Sell_OnEvent: AH closed, stopping sell")
        SmartAH_SellRunning = false
        return
    end
end

---------------------------------------------------------
-- GLOBAL PAGE GUARD (FÖR BLIZZARD BROWSE-FUNKTIONER)
---------------------------------------------------------

function SmartAH_AuctionPageGuard()
    if AuctionFrameBrowse and AuctionFrameBrowse.page == nil then
        AuctionFrameBrowse.page = 0
    end
end

---------------------------------------------------------
-- CORE SELL FLOW
---------------------------------------------------------

local function SmartAH_Sell_Finish(reason)
    dbg("Sell_Finish called, reason = " .. tostring(reason))

    if reason then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SmartAH:|r Sell finished: " .. reason)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SmartAH:|r Sell complete.")
    end

    dbg("Sell_Finish: stacks posted = " .. tostring(SmartAH_SellStacksPosted))

    SmartAH_SellRunning        = false
    SmartAH_SellPendingAuction = false
    SmartAH_SellItemLink       = nil
    SmartAH_SellStackSize      = 0
    SmartAH_SellStackCount     = 0
    SmartAH_SellUnitPrice      = 0
    SmartAH_SellStacksPosted   = 0

    dbg("Sell_Finish: state reset")
end

function SmartAH_Sell_NextStack ()
    dbg("Sell_NextStack called")

    if not SmartAH_SellRunning then
        dbg("Sell_NextStack: SellRunning is false, aborting")
        return
    end

    if SmartAH_SellStacksPosted >= SmartAH_SellStackCount then
        dbg("Sell_NextStack: All stacks posted, stopping")
        SmartAH_SellRunning = false
        return
    end

    local itemLink   = SmartAH_SellItemLink
    local stackSize  = SmartAH_SellStackSize
    local unitPrice  = SmartAH_SellUnitPrice

    dbg("Sell_NextStack: itemLink=" .. tostring(itemLink)
        .. ", stackSize=" .. tostring(stackSize)
        .. ", unitPrice=" .. tostring(unitPrice))

    local bag, slot, count = SmartAH_Sell_FindStack(itemLink, stackSize)
    if not bag then
        dbg("Sell_NextStack: No stack found in bags")
        SmartAH_SellRunning = false
        return
    end

    dbg("Sell_NextStack: Found stack in bag=" .. tostring(bag)
        .. ", slot=" .. tostring(slot)
        .. ", count=" .. tostring(count))

    -- Beräkna stackpris från unit price
    local stackPrice = unitPrice * stackSize

    -- Undercut stackpriset med 1 copper
    local finalPrice = stackPrice - 1
    if finalPrice < 0 then
        finalPrice = 0
    end

    dbg("Sell_NextStack: stackPrice=" .. tostring(stackPrice)
        .. ", finalPrice=" .. tostring(finalPrice))

    PickupContainerItem(bag, slot)
    AuctionsItemButton:Click()

    AuctionsShortAuctionButton:Click()
    dbg("Sell_NextStack: Duration set to 2h")

    local gold   = math.floor(finalPrice / 10000)
    local silver = math.floor((finalPrice - (gold * 10000)) / 100)
    local copper = finalPrice - (gold * 10000) - (silver * 100)

    StartPriceGold:SetText(gold)
    StartPriceSilver:SetText(silver)
    StartPriceCopper:SetText(copper)

    BuyoutPriceGold:SetText(gold)
    BuyoutPriceSilver:SetText(silver)
    BuyoutPriceCopper:SetText(copper)

    dbg("Sell_NextStack: Prices set (stack undercut by 1 copper)")

    AuctionsCreateAuctionButton:Click()
    dbg("Sell_NextStack: Auction created")

    SmartAH_SellStacksPosted = SmartAH_SellStacksPosted + 1
    dbg("Sell_NextStack: SmartAH_SellStacksPosted=" .. tostring(SmartAH_SellStacksPosted))

    SmartAH_Sell_NextStack()
end

---------------------------------------------------------
-- START SELL SEQUENCE
---------------------------------------------------------

function SmartAH_Sell_Start(itemLink, stackSize, stackCount, unitPrice)

    dbg("Sell_Start: itemLink=" .. tostring(itemLink)
        .. ", stackSize=" .. tostring(stackSize)
        .. ", stackCount=" .. tostring(stackCount)
        .. ", unitPrice=" .. tostring(unitPrice))

    SmartAH_SellItemLink     = itemLink
    SmartAH_SellStackSize    = stackSize or 1
    SmartAH_SellStackCount   = stackCount or 1
    SmartAH_SellUnitPrice    = unitPrice or 0   -- per-enhet-pris från AutoPrice
    SmartAH_SellStacksPosted = 0
    SmartAH_SellRunning      = true

    SmartAH_Sell_NextStack()
end

---------------------------------------------------------
-- EVENT HANDLER
---------------------------------------------------------

local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("CHAT_MSG_SYSTEM")
sellFrame:RegisterEvent("UI_ERROR_MESSAGE")

sellFrame:SetScript("OnEvent", function(self, event, arg1)
    dbg("SellFrame OnEvent: event=" .. tostring(event) .. ", arg1=" .. tostring(arg1))

    if not SmartAH_SellRunning then
        dbg("SellFrame: SellRunning is false, ignoring event")
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local msg = arg1 or ""
        dbg("SellFrame: CHAT_MSG_SYSTEM msg=" .. msg)

        if string.find(msg, "Auction created") then
            dbg("SellFrame: Auction created detected")
            SmartAH_SellPendingAuction = false
            SmartAH_SellStacksPosted   = SmartAH_SellStacksPosted + 1
            dbg("SellFrame: SmartAH_SellStacksPosted=" .. tostring(SmartAH_SellStacksPosted))
            SmartAH_Sell_NextStack()
        end

        return
    end

    if event == "UI_ERROR_MESSAGE" then
        local msg = arg1 or ""
        dbg("SellFrame: UI_ERROR_MESSAGE msg=" .. msg)

        SmartAH_SellPendingAuction = false
        SmartAH_SellStacksPosted   = SmartAH_SellStacksPosted + 1
        dbg("SellFrame: SmartAH_SellStacksPosted=" .. tostring(SmartAH_SellStacksPosted))

        SmartAH_Sell_NextStack()
        return
    end
end)

-- Correct event frame for AH show/close
local SmartAH_AHEventFrame = CreateFrame("Frame")
SmartAH_AHEventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
SmartAH_AHEventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

SmartAH_AHEventFrame:SetScript("OnEvent", function(self, event, ...)
    SmartAH_Sell_OnEvent(self, event)
end)

---------------------------------------------------------
-- AUTO PRICING (FULL DEBUG)
---------------------------------------------------------

local function SmartAH_Sell_AutoPrice(itemName)
    dbg("AutoPrice called for itemName = " .. tostring(itemName))

    local lowestUnit = nil

    if not SmartAH_Data then
        dbg("AutoPrice: SmartAH_Data is nil, cannot price")
        return
    end

    dbg("AutoPrice: iterating SmartAH_Data")

    for index, data in ipairs(SmartAH_Data) do
        dbg("AutoPrice: entry " .. index ..
            ", name=" .. tostring(data.name) ..
            ", buyout=" .. tostring(data.buyout) ..
            ", count=" .. tostring(data.count))

        if data.name == itemName and data.buyout > 0 and data.count > 0 then
            local unit = data.buyout / data.count
            dbg("AutoPrice: matching item, unit=" .. tostring(unit))

            if not lowestUnit or unit < lowestUnit then
                dbg("AutoPrice: new lowest unit price found: " .. tostring(unit))
                lowestUnit = unit
            end
        end
    end

    dbg("AutoPrice: final lowestUnit = " .. tostring(lowestUnit))
    dbg("AutoPrice: SmartAH_UnitPriceBox = " .. tostring(SmartAH_UnitPriceBox))

    if lowestUnit and SmartAH_UnitPriceBox then
        SmartAH_UnitPriceBox:SetNumber(lowestUnit)
        dbg("AutoPrice: UnitPriceBox updated to " .. tostring(lowestUnit))
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SmartAH:|r Lowest unit price: " .. SmartAH_FormatMoney(lowestUnit))
    else
        if not lowestUnit then
            dbg("AutoPrice: no lowestUnit found, not updating UI")
        end
        if not SmartAH_UnitPriceBox then
            dbg("AutoPrice: SmartAH_UnitPriceBox is nil, UI not available")
        end
    end
end

---------------------------------------------------------
-- SCAN COMPLETE → AUTO PRICE
---------------------------------------------------------

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("CHAT_MSG_SYSTEM")

scanFrame:SetScript("OnEvent", function()

    ---------------------------------------------------------
    -- TEST: ser vi ens eventet?
    ---------------------------------------------------------
    dbg("SCANFRAME FIRED: event=" .. tostring(event) .. ", arg1=" .. tostring(arg1))

    if event == "CHAT_MSG_SYSTEM" then
        local msg = arg1 or ""
        dbg("ScanFrame: CHAT_MSG_SYSTEM msg=" .. msg)

        if string.find(msg, "Scan complete") then
            dbg("ScanFrame: Scan complete detected")
            dbg("ScanFrame: SmartAH_AutoPricePending = " .. tostring(SmartAH_AutoPricePending))

            if SmartAH_AutoPricePending then
                dbg("ScanFrame: calling AutoPrice for " .. tostring(SmartAH_AutoPricePending))
                SmartAH_Sell_AutoPrice(SmartAH_AutoPricePending)
                SmartAH_AutoPricePending = nil
                dbg("ScanFrame: SmartAH_AutoPricePending reset to nil")
            else
                dbg("ScanFrame: no AutoPricePending set, nothing to do")
            end
        end
    end
end)

function SmartAH_Sell_OnScanComplete()
    dbg("SmartAH_Sell_OnScanComplete called")
    dbg("AutoPricePending = " .. tostring(SmartAH_AutoPricePending))

    if SmartAH_AutoPricePending then
        SmartAH_Sell_AutoPrice(SmartAH_AutoPricePending)
        SmartAH_AutoPricePending = nil
        dbg("AutoPricePending cleared")
    else
        dbg("No AutoPricePending set")
    end
end

---------------------------------------------------------
-- PAGE NIL FIX WRAPPER FOR BLIZZARD FUNCTION (Lua 5.0 SAFE)
---------------------------------------------------------
-- SmartAH: safe hook for Blizzard's AuctionFrameBrowse_Update to prevent nil 'page' errors
local SmartAH_Orig_AuctionFrameBrowse_Update = AuctionFrameBrowse_Update

function AuctionFrameBrowse_Update()
    -- Ensure AuctionFrameBrowse.page is never nil before Blizzard code uses it
    if AuctionFrameBrowse and AuctionFrameBrowse.page == nil then
        AuctionFrameBrowse.page = 0
        dbg("SmartAH: AuctionFrameBrowse.page was nil, set to 0 before Browse_Update")
    end

    -- Call the original Blizzard implementation
    if SmartAH_Orig_AuctionFrameBrowse_Update then
        SmartAH_Orig_AuctionFrameBrowse_Update()
    end
end

---------------------------------------------------------
-- GLOBAL PAGE GUARD (PERMANENT FIX FÖR BLIZZARD PAGE-NIL)
---------------------------------------------------------

function SmartAH_InitPageGuard()
    if SmartAH_PageGuardFrame then
        return
    end

    SmartAH_PageGuardFrame = CreateFrame("Frame")
    SmartAH_PageGuardFrame:SetScript("OnUpdate", function()
        if AuctionFrameBrowse and AuctionFrameBrowse.page == nil then
            AuctionFrameBrowse.page = 0
        end
    end)
end

-- Kör guarden direkt när addon laddas
SmartAH_InitPageGuard()

---------------------------------------------------------
-- REGISTER EVENTS FOR SELL MODULE
---------------------------------------------------------

local SmartAH_EventFrame = CreateFrame("Frame")
SmartAH_EventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
SmartAH_EventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
SmartAH_EventFrame:SetScript("OnEvent", function(_, event)
    SmartAH_Sell_OnEvent(event)
end)

---------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------

SLASH_SMARTAHCLEAR1 = "/sab"
SlashCmdList["SMARTAHCLEAR"] = function()
    SmartAH_Data       = {}
    SmartAH_BuyQueue   = {}
    SmartAH_BuyTarget  = nil
    SmartAH_BuyRunning = false
    SmartAH_DebugLog   = {}   -- ← DENNA ÄR KRITISK
    SmartAH_AutoPricePending = nil

    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SmartAH:|r Saved data cleared. Reload UI to write changes.")
end
