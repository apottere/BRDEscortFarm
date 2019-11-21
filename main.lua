local questId = 3982
local frame = nil
local ticker = nil
local counter = 1
local enabled = false
local currentRound = nil
local ready = false
local powerThreshold = 45
local totalRounds = 10

local function ui(subframe)
    return frame[subframe]
end

local function percentage(current, max)
    if current == nil or max == nil or max == 0 then
        return nil
    end

    return math.floor((current / max) * 100)
end

local function unitPowerPercentage(unit)
    local currentPower = UnitPower(unit)
    local maxPower = UnitPowerMax(unit)

    return percentage(currentPower, maxPower)
end

local function getClassColor(class)
    if class == 5 then
        return 1, 1, 1
    end
    if class == 8 then
        return 0.25, 0.78, 0.92
    end
    if class == 9 then
        return 0.53, 0.53, 0.93
    end

    return 0.5, 0.5, 0.5 
end

local function updateUnitLine(id)
    local name = UnitName(id)
    local power = unitPowerPercentage(id)

    local nameFrame = ui(id .. "Name")
    if nameFrame ~= nil then
        if name ~= nil then
            nameFrame:SetText(name)

            local _, _, class = UnitClass(id)
            local r, g, b = getClassColor(class)

            nameFrame:SetTextColor(r, g, b)
        else
            nameFrame:SetText("???")
            nameFrame:SetTextColor(1, 1, 1)
        end
    end

    local powerFrame = ui(id .. "Power")
    if powerFrame ~= nil then
        if power ~= nil then
            powerFrame:SetText(tostring(power))

            if power >= powerThreshold then
                powerFrame:SetTextColor(0.2, 0.2, 1)
            else
                powerFrame:SetTextColor(1, 0, 0)
                return false
            end
        else
            powerFrame:SetText("???")
        end
    end

    return true
end

local function targetIsGorshak()
    local guid = UnitGUID("playertarget")
    if guid == nil then
        return;
    end

    local id = guid:sub(-15, -12)
    return id == "9020"
end

local function getGorshakHealth()
    if targetIsGorshak() then
        return percentage(UnitHealth("target"), UnitHealthMax("target"))
    end

    return nil
end

local function runTick()
    local maybeReady = true
    local gorshakHealthFrame = ui("gorshakHealth")
    if gorshakHealthFrame then
        local gorshakHealth = getGorshakHealth()
        if gorshakHealth ~= nil then
            gorshakHealthFrame:SetText(gorshakHealth)

            if gorshakHealth ~= 100 then
                maybeReady = false
            end
        else
            gorshakHealthFrame:SetText("???")
        end
    end

    maybeReady = maybeReady and updateUnitLine("player")
    maybeReady = maybeReady and updateUnitLine("party1")
    maybeReady = maybeReady and updateUnitLine("party2")
    maybeReady = maybeReady and updateUnitLine("party3")
    maybeReady = maybeReady and updateUnitLine("party4")

    ready = maybeReady
end

-------------------
-- ui
-------------------
local function onShow()
    enabled = true
    ticker = C_Timer.NewTicker(0.5, runTick)
    runTick()
end

local function onHide()
    enabled = false
    if timer ~= nil then
        ticker:Cancel()
        ticker = nil
    end
end

local function onEvent(self, event, arg1, arg2, arg3, arg4, arg5)
    if not enabled then
        return
    end

    if event == "QUEST_DETAIL" then
        if ready and GetQuestID() == questId and getGorshakHealth() == 100 then
            print("Accepting")
            AcceptQuest()
        else
            print("Not accepting")
        end
    end

    if event == "QUEST_ACCEPTED" then
        local _, _, _, _, _, _, _, id = GetQuestLogTitle(arg1)
        if id == questId then
            AbandonQuest(questId)
            currentRound = counter
            local msg = "[BEF] Wave " .. tostring(counter) .. " Incoming!"
            if counter == totalRounds then
                msg = msg .. "  Loot after this!"
                counter = 0
            end

            SendChatMessage(msg, "YELL")
            counter = counter + 1

            C_Timer.After(6, function()
                SendChatMessage("[BEF] Start casing Flame Strike now!", "YELL")
            end)
        end
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and currentRound ~= nil then
        local unitId = arg1
        local spell = arg3
        if spell == 122 or spell == 865 or spell == 6131 or spell == 10230 then
            SendChatMessage("[BEF] " .. UnitName(unitId) .. " casted Frost Nova!", "YELL")
        end
    end

    if event == "PLAYER_LEAVE_COMBAT" and currentRound ~= nil then
        local currentRoundBackup = currentRound
        currentRound = nil

        local msg = "[BEF] Round " .. currentRoundBackup .. " Cleared!"
        if currentRoundBackup == 10 then
            msg = msg .. "  Loot now!"
        end
        SendChatMessage(msg, "YELL")
    end
end

frame = CreateFrame("Frame", "test", UIParent)
do
    frame:SetPoint("CENTER")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnShow", onShow)
    frame:SetScript("OnHide", onHide)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- events
    frame:SetScript("OnEvent", onEvent)
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("PLAYER_LEAVE_COMBAT")

    -- Create UI
    local width = 150
    frame:SetWidth(width)
    frame:SetHeight(200)
    frame:SetBackdrop({ 
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        tile = true,
        tileSize = 32,
        insets = { left = -5, right = -5, top = -5, bottom = -5 }
    });

    local fontHeight = 18
    local powerWidth = 30

    -- title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetText("BRD Escort Farm")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.title:SetTextColor(1, 0.6, 0)
    frame.title:SetWidth(width)
    frame.title:SetHeight(fontHeight)

    -- gor'shak
    frame.gorshakName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gorshakName:SetText("Gor'Shak")
    frame.gorshakName:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
    frame.gorshakName:SetTextColor(0.3, 1, 0.4)
    frame.gorshakName:SetWidth(width - powerWidth)
    frame.gorshakName:SetHeight(fontHeight)
    frame.gorshakName:SetJustifyH("LEFT")

    frame.gorshakHealth = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gorshakHealth:SetText("???")
    frame.gorshakHealth:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -5)
    frame.gorshakHealth:SetTextColor(0.4, 0.8, 0.5)
    frame.gorshakHealth:SetWidth(powerWidth)
    frame.gorshakHealth:SetHeight(fontHeight)
    frame.gorshakHealth:SetJustifyH("RIGHT")

    -- player
    frame.playerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.playerName:SetText(UnitName("player"))
    frame.playerName:SetPoint("TOPLEFT", frame.gorshakName, "BOTTOMLEFT")
    frame.playerName:SetWidth(width - powerWidth)
    frame.playerName:SetHeight(fontHeight)
    frame.playerName:SetJustifyH("LEFT")

    frame.playerPower = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.playerPower:SetText("???")
    frame.playerPower:SetPoint("TOPRIGHT", frame.gorshakHealth, "BOTTOMRIGHT")
    frame.playerPower:SetTextColor(0.2, 0.2, 1)
    frame.playerPower:SetWidth(powerWidth)
    frame.playerPower:SetHeight(fontHeight)
    frame.playerPower:SetJustifyH("RIGHT")

    -- party 1
    frame.party1Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party1Name:SetText("???")
    frame.party1Name:SetPoint("TOPLEFT", frame.playerName, "BOTTOMLEFT")
    frame.party1Name:SetTextColor(1, 1, 1)
    frame.party1Name:SetWidth(width - powerWidth)
    frame.party1Name:SetHeight(fontHeight)
    frame.party1Name:SetJustifyH("LEFT")

    frame.party1Power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party1Power:SetText("???")
    frame.party1Power:SetPoint("TOPRIGHT", frame.playerPower, "BOTTOMRIGHT")
    frame.party1Power:SetTextColor(0.2, 0.2, 1)
    frame.party1Power:SetWidth(powerWidth)
    frame.party1Power:SetHeight(fontHeight)
    frame.party1Power:SetJustifyH("RIGHT")

    -- party 2
    frame.party2Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party2Name:SetText("???")
    frame.party2Name:SetPoint("TOPLEFT", frame.party1Name, "BOTTOMLEFT")
    frame.party2Name:SetTextColor(1, 1, 1)
    frame.party2Name:SetWidth(width - powerWidth)
    frame.party2Name:SetHeight(fontHeight)
    frame.party2Name:SetJustifyH("LEFT")

    frame.party2Power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party2Power:SetText("???")
    frame.party2Power:SetPoint("TOPRIGHT", frame.party1Power, "BOTTOMRIGHT")
    frame.party2Power:SetTextColor(0.2, 0.2, 1)
    frame.party2Power:SetWidth(powerWidth)
    frame.party2Power:SetHeight(fontHeight)
    frame.party2Power:SetJustifyH("RIGHT")

    -- party 3
    frame.party3Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party3Name:SetText("???")
    frame.party3Name:SetPoint("TOPLEFT", frame.party2Name, "BOTTOMLEFT")
    frame.party3Name:SetTextColor(1, 1, 1)
    frame.party3Name:SetWidth(width - powerWidth)
    frame.party3Name:SetHeight(fontHeight)
    frame.party3Name:SetJustifyH("LEFT")

    frame.party3Power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party3Power:SetText("???")
    frame.party3Power:SetPoint("TOPRIGHT", frame.party2Power, "BOTTOMRIGHT")
    frame.party3Power:SetTextColor(0.2, 0.2, 1)
    frame.party3Power:SetWidth(powerWidth)
    frame.party3Power:SetHeight(fontHeight)
    frame.party3Power:SetJustifyH("RIGHT")

    -- party 4
    frame.party4Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party4Name:SetText("???")
    frame.party4Name:SetPoint("TOPLEFT", frame.party3Name, "BOTTOMLEFT")
    frame.party4Name:SetTextColor(1, 1, 1)
    frame.party4Name:SetWidth(width - powerWidth)
    frame.party4Name:SetHeight(fontHeight)
    frame.party4Name:SetJustifyH("LEFT")

    frame.party4Power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.party4Power:SetText("???")
    frame.party4Power:SetPoint("TOPRIGHT", frame.party3Power, "BOTTOMRIGHT")
    frame.party4Power:SetTextColor(0.2, 0.2, 1)
    frame.party4Power:SetWidth(powerWidth)
    frame.party4Power:SetHeight(fontHeight)
    frame.party4Power:SetJustifyH("RIGHT")

    -- buttons
    frame.incrementCounter = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.incrementCounter:SetPoint("TOPLEFT", frame.party4Name, "BOTTOMLEFT", 0, -10)
    frame.incrementCounter:SetText("Increment Counter")
	frame.incrementCounter:SetWidth(width)
    frame.incrementCounter:SetHeight(21)
    frame.incrementCounter:SetScript("OnClick", function() 
        if counter < totalRounds then
            counter = counter + 1
        end
        print(tostring(counter))
    end)

    frame.decrementCounter = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.decrementCounter:SetPoint("TOPLEFT", frame.incrementCounter, "BOTTOMLEFT", 0, 0)
    frame.decrementCounter:SetText("Decrement Counter")
	frame.decrementCounter:SetWidth(width)
    frame.decrementCounter:SetHeight(21)
    frame.decrementCounter:SetScript("OnClick", function() 
        if counter > 1 then
            counter = counter - 1
        end
        print(tostring(counter))
    end)

    frame:Hide()
    -- frame:Show()
end

-------------------
-- slash commands
-------------------
SLASH_BEF1, SLASH_BEF2 = "/bef", "/brdescortfarm"
SlashCmdList.BEF = function(msg, editbox)
    if msg == "show" then
        frame:Show()
        return
    end

    if msg == "hide" then
        frame:Hide()
        return
    end

    print("/bef show")
    print("/bef hide")
end
