local _, namespace = ...

local questId = 3982
local questName = "What Is Going On?"
local npcId = 9020
local frame = nil
local wave = 1
local enabled = false
local ready = false
local powerThreshold = 35
local gorshakHealthThreshold = 90
local totalWaves = 10
local party = {}
local eventHandlers = {}
local alwaysEventHandlers = {}
local frostNovaNames = {}
local isDuringWave = false
local broadcastNova = true
local firstTimePrompt = true

local function addFrostNovaRank(rank, spellId)
    local spellName = GetSpellInfo(spellId)
    if spellName then
        frostNovaNames[rank] = spellName
    end
end

addFrostNovaRank(1, 122)
addFrostNovaRank(2, 865)
addFrostNovaRank(3, 6131)
addFrostNovaRank(4, 10230)

local function unitPowerMatters(classId)
    return classId == 5 or classId == 7 or classId == 8 or classId == 11
end

local function setWave(newWave)
    wave = newWave
    frame.waveValue:SetText(tostring(newWave))
    frame.waveSlider:SetValue(newWave)
end

local function ui(unitId, frame)
    return party[unitId][frame]
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

local function getClassColor(classId)
    if classId == 5 then
        return 1, 1, 1
    end
    if classId == 8 then
        return 0.25, 0.78, 0.92
    end
    if classId == 9 then
        return 0.53, 0.53, 0.93
    end

    return 0.5, 0.5, 0.5 
end

local function updateUnitName(unitId)
    local nameFrame = ui(unitId, "name")
    if nameFrame == nil then
        return
    end

    local name = UnitName(unitId)
    if name ~= nil then
        nameFrame:SetText(name)

        local _, _, classId = UnitClass(unitId)
        party[unitId].classId = classId
        local r, g, b = getClassColor(classId)

        nameFrame:SetTextColor(r, g, b)
    else
        nameFrame:SetText("------")
        nameFrame:SetTextColor(1, 1, 1)
    end
end

local function updateUnitPower(unitId)
    local powerFrame = ui(unitId, "power")
    if powerFrame == nil then
        party[unitId].ready = true
        return
    end

    local power = unitPowerPercentage(unitId)
    if power ~= nil then
        powerFrame:SetText(tostring(power))

        if power >= powerThreshold then
            powerFrame:SetTextColor(0.2, 0.2, 1)
            party[unitId].ready = true
        elseif unitPowerMatters(party[unitId].classId) then
            powerFrame:SetTextColor(1, 0, 0)
            party[unitId].ready = false
        else
            powerFrame:SetTextColor(0.5, 0.5, 0.5)
            party[unitId].ready = true
        end
    else
        powerFrame:SetText("---")
    end
end

local function updateUnitLine(unitId)
    updateUnitName(unitId)
    updateUnitPower(unitId)
end

local function targetIsGorshak()
    local guid = UnitGUID("playertarget")
    if guid == nil then
        return
    end

    local id = guid:sub(-15, -12)
    return id == tostring(npcId)
end

local function getGorshakHealth()
    return percentage(UnitHealth("target"), UnitHealthMax("target"))
end

local function updateGorshakHealth()
    local gorshakHealthFrame = ui("gorshak", "health")
    if not gorshakHealthFrame then
        return
    end

    if targetIsGorshak() then
        local gorshakHealth = getGorshakHealth()
        if gorshakHealth ~= nil then
            gorshakHealthFrame:SetText(gorshakHealth)
            if gorshakHealth >= gorshakHealthThreshold then
                gorshakHealthFrame:SetTextColor(0.4, 0.8, 0.5)
            else
                gorshakHealthFrame:SetTextColor(1, 0, 0)
            end

            return
        end
    end

    gorshakHealthFrame:SetText("???")
    gorshakHealthFrame:SetTextColor(1, 1, 1)
end

local function updatePartyNames()
    updateUnitName("player")
    updateUnitName("party1")
    updateUnitName("party2")
    updateUnitName("party3")
    updateUnitName("party4")
end

local function updatePartyPower()
    updateUnitPower("player")
    updateUnitPower("party1")
    updateUnitPower("party2")
    updateUnitPower("party3")
    updateUnitPower("party4")
end

local function updatePartyLines()
    updatePartyNames()
    updatePartyPower()
end

-------------------
-- events
-------------------
eventHandlers.QUEST_DETAIL = function()
    if GetQuestID() == questId then
        if isDuringWave then
            CloseQuest()
            print("[BEF] It looks like a wave is already started, did you double click Gor'shak?  If a wave isn't currently active and you think this is broken, reload your UI.")
            return
        end

        if getGorshakHealth() < gorshakHealthThreshold then
            CloseQuest()
            print("[BEF] Not ready to start yet, check Gor'shak's health!")
            return
        end

        if not party.player.ready or not party.party1.ready or not party.party2.ready or not party.party3.ready or not party.party4.ready then
            CloseQuest()
            print("[BEF] Not ready to start yet, check party's mana!")
            return
        end

        AcceptQuest()
    end
end

eventHandlers.QUEST_ACCEPTED = function(questIndex)
    local _, _, _, _, _, _, _, id = GetQuestLogTitle(questIndex)
    if id == questId then
        SelectQuestLogEntry(questIndex)
        SetAbandonQuest()
        AbandonQuest()
        isDuringWave = true

        local msg = "[BEF] Wave " .. tostring(wave) .. " Incoming!"
        if wave == totalWaves then
            msg = msg .. "  Loot after this!"
        end

        SendChatMessage(msg, "YELL")
        C_Timer.After(5.5, function()
            SendChatMessage("[BEF] Start casting Flamestrike now!", "YELL")
        end)
    end
end

eventHandlers.PLAYER_REGEN_ENABLED = function()
    if not isDuringWave then
        return
    end
    isDuringWave = false

    local msg = "[BEF] Wave " .. wave .. " Cleared!"
    if wave == 10 then
        msg = msg .. "  Loot now!"
        setWave(1)
    else
        setWave(wave + 1)
    end
    SendChatMessage(msg, "YELL")
end

eventHandlers.UNIT_POWER_FREQUENT = function(unitId)
    if party[unitId] then
        updateUnitLine(unitId)
    end
end

eventHandlers.COMBAT_LOG_EVENT_UNFILTERED = function(unitId, _, spellId)
    if not broadcastNova then
        return
    end

    if not isDuringWave then
        return
    end

    local _, eventType, _, source, _, _, _, _, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()
    if eventType ~= "SPELL_CAST_SUCCESS" then
        return
    end

    local _, _, _, _, _, name = GetPlayerInfoByGUID(source)

    if spellName == frostNovaNames[1] or spellName == frostNovaNames[2] or spellName == frostNovaNames[3] or spellName == frostNovaNames[4]  then
        SendChatMessage("[BEF] " .. name .. " casts Frost Nova!", "YELL")
    end
end

alwaysEventHandlers.UNIT_TARGET = function(unitId)
    if unitId ~= "player" then
        return
    end

    if firstTimePrompt then
        firstTimePrompt = false

        if not enabled and targetIsGorshak() then
            print("[BEF] It looks like you're doing an escort farm, but you haven't opened the UI yet!  Type /bef show to get started.")
        end
    end

    if not enabled then
        return
    end

    updateGorshakHealth()
end

eventHandlers.UNIT_HEALTH_FREQUENT = function(unitId)
    if unitId ~= "target" then
        return
    end

    updateGorshakHealth()
end

eventHandlers.GROUP_ROSTER_UPDATE = function()
    updatePartyLines()
end

eventHandlers.GROUP_JOINED = function()
    updatePartyLines()
end

alwaysEventHandlers.QUEST_ACCEPT_CONFIRM = function(player, name)
    if name == questName then
        StaticPopup_Hide("QUEST_ACCEPT")
    end
end

-------------------
-- ui
-------------------
local function onShow()
    enabled = true
    firstTimePrompt = false
    updatePartyLines()
    updateGorshakHealth()
end

local function onHide()
    enabled = false
end

local function onEvent(self, event, ...)
    local handler
    handler = alwaysEventHandlers[event]
    if handler then
        handler(...)
        return
    end

    if not enabled then
        return
    end

    handler = eventHandlers[event]
    if handler then
        handler(...)
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

    -- Create UI
    local width = 150
    frame:SetWidth(width)
    frame:SetHeight(295)
    frame:SetBackdrop({ 
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        tile = true,
        tileSize = 32,
        insets = { left = -5, right = -5, top = -5, bottom = -5 }
    })

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
    party.gorshak = {}
    party.gorshak.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.gorshak.name:SetText("Gor'shak")
    party.gorshak.name:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -10)
    party.gorshak.name:SetTextColor(0.3, 1, 0.4)
    party.gorshak.name:SetWidth(width - powerWidth)
    party.gorshak.name:SetHeight(fontHeight)
    party.gorshak.name:SetJustifyH("LEFT")

    party.gorshak.health = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.gorshak.health:SetText("???")
    party.gorshak.health:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -5)
    party.gorshak.health:SetTextColor(0.4, 0.8, 0.5)
    party.gorshak.health:SetWidth(powerWidth)
    party.gorshak.health:SetHeight(fontHeight)
    party.gorshak.health:SetJustifyH("RIGHT")

    -- player
    party.player = {}
    party.player.ready = true
    party.player.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.player.name:SetText(UnitName("player"))
    party.player.name:SetPoint("TOPLEFT", party.gorshak.name, "BOTTOMLEFT")
    party.player.name:SetWidth(width - powerWidth)
    party.player.name:SetHeight(fontHeight)
    party.player.name:SetJustifyH("LEFT")

    party.player.power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.player.power:SetText("???")
    party.player.power:SetPoint("TOPRIGHT", party.gorshak.health, "BOTTOMRIGHT")
    party.player.power:SetTextColor(0.2, 0.2, 1)
    party.player.power:SetWidth(powerWidth)
    party.player.power:SetHeight(fontHeight)
    party.player.power:SetJustifyH("RIGHT")

    -- party 1
    party.party1 = {}
    party.party1.ready = true
    party.party1.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party1.name:SetText("???")
    party.party1.name:SetPoint("TOPLEFT", party.player.name, "BOTTOMLEFT")
    party.party1.name:SetTextColor(1, 1, 1)
    party.party1.name:SetWidth(width - powerWidth)
    party.party1.name:SetHeight(fontHeight)
    party.party1.name:SetJustifyH("LEFT")

    party.party1.power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party1.power:SetText("???")
    party.party1.power:SetPoint("TOPRIGHT", party.player.power, "BOTTOMRIGHT")
    party.party1.power:SetTextColor(0.2, 0.2, 1)
    party.party1.power:SetWidth(powerWidth)
    party.party1.power:SetHeight(fontHeight)
    party.party1.power:SetJustifyH("RIGHT")

    -- party 2
    party.party2 = {}
    party.party2.ready = true
    party.party2.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party2.name:SetText("???")
    party.party2.name:SetPoint("TOPLEFT", party.party1.name, "BOTTOMLEFT")
    party.party2.name:SetTextColor(1, 1, 1)
    party.party2.name:SetWidth(width - powerWidth)
    party.party2.name:SetHeight(fontHeight)
    party.party2.name:SetJustifyH("LEFT")

    party.party2.power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party2.power:SetText("???")
    party.party2.power:SetPoint("TOPRIGHT", party.party1.power, "BOTTOMRIGHT")
    party.party2.power:SetTextColor(0.2, 0.2, 1)
    party.party2.power:SetWidth(powerWidth)
    party.party2.power:SetHeight(fontHeight)
    party.party2.power:SetJustifyH("RIGHT")

    -- party 3
    party.party3 = {}
    party.party3.ready = true
    party.party3.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party3.name:SetText("???")
    party.party3.name:SetPoint("TOPLEFT", party.party2.name, "BOTTOMLEFT")
    party.party3.name:SetTextColor(1, 1, 1)
    party.party3.name:SetWidth(width - powerWidth)
    party.party3.name:SetHeight(fontHeight)
    party.party3.name:SetJustifyH("LEFT")

    party.party3.power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party3.power:SetText("???")
    party.party3.power:SetPoint("TOPRIGHT", party.party2.power, "BOTTOMRIGHT")
    party.party3.power:SetTextColor(0.2, 0.2, 1)
    party.party3.power:SetWidth(powerWidth)
    party.party3.power:SetHeight(fontHeight)
    party.party3.power:SetJustifyH("RIGHT")

    -- party 4
    party.party4 = {}
    party.party4.ready = true
    party.party4.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party4.name:SetText("???")
    party.party4.name:SetPoint("TOPLEFT", party.party3.name, "BOTTOMLEFT")
    party.party4.name:SetTextColor(1, 1, 1)
    party.party4.name:SetWidth(width - powerWidth)
    party.party4.name:SetHeight(fontHeight)
    party.party4.name:SetJustifyH("LEFT")

    party.party4.power = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    party.party4.power:SetText("???")
    party.party4.power:SetPoint("TOPRIGHT", party.party3.power, "BOTTOMRIGHT")
    party.party4.power:SetTextColor(0.2, 0.2, 1)
    party.party4.power:SetWidth(powerWidth)
    party.party4.power:SetHeight(fontHeight)
    party.party4.power:SetJustifyH("RIGHT")

    -- wave slider
    frame.waveLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.waveLabel:SetText("Current Wave")
    frame.waveLabel:SetPoint("TOPLEFT", party.party4.name, "BOTTOMLEFT", 0, -10)
    frame.waveLabel:SetWidth(width - powerWidth)
    frame.waveLabel:SetHeight(fontHeight)
    frame.waveLabel:SetJustifyH("LEFT")

    frame.waveValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.waveValue:SetText(tostring(wave))
    frame.waveValue:SetPoint("TOPRIGHT", party.party4.power, "BOTTOMRIGHT", 0, -10)
    frame.waveValue:SetTextColor(1, 0.6, 0)
    frame.waveValue:SetWidth(powerWidth)
    frame.waveValue:SetHeight(fontHeight)
    frame.waveValue:SetJustifyH("RIGHT")

    frame.waveSlider = CreateFrame("Slider", "BEF_WaveSlider", frame, "OptionsSliderTemplate")
    frame.waveSlider:SetMinMaxValues(1, 10)
    frame.waveSlider:SetObeyStepOnDrag(true)
    frame.waveSlider:SetValueStep(1)
    frame.waveSlider:SetStepsPerPage(1)
    frame.waveSlider:SetValue(wave)
    frame.waveSlider:SetPoint("TOPLEFT", frame.waveLabel, "BOTTOMLEFT", 5, 0)
    frame.waveSlider:SetWidth(width - 10)
    BEF_WaveSliderLow:SetText("1")
    BEF_WaveSliderHigh:SetText("10")
    frame.waveSlider:HookScript("OnValueChanged", function(self, value)
        if value ~= wave then
            setWave(value)
        end
    end)

    -- minimum mana slider
    frame.manaLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.manaLabel:SetText("Minimum Mana")
    frame.manaLabel:SetPoint("TOPLEFT", frame.waveSlider, "BOTTOMLEFT", -5, -15)
    frame.manaLabel:SetWidth(width - powerWidth)
    frame.manaLabel:SetHeight(fontHeight)
    frame.manaLabel:SetJustifyH("LEFT")

    frame.manaValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.manaValue:SetText(tostring(powerThreshold))
    frame.manaValue:SetPoint("TOPRIGHT", frame.waveSlider, "BOTTOMRIGHT", 5, -15)
    frame.manaValue:SetTextColor(1, 0.6, 0)
    frame.manaValue:SetWidth(powerWidth)
    frame.manaValue:SetHeight(fontHeight)
    frame.manaValue:SetJustifyH("RIGHT")

    frame.manaSlider = CreateFrame("Slider", "BEF_ManaSlider", frame, "OptionsSliderTemplate")
    frame.manaSlider:SetMinMaxValues(5, 100)
    frame.manaSlider:SetObeyStepOnDrag(true)
    frame.manaSlider:SetValueStep(5)
    frame.manaSlider:SetStepsPerPage(1)
    frame.manaSlider:SetValue(powerThreshold)
    frame.manaSlider:SetPoint("TOPLEFT", frame.manaLabel, "BOTTOMLEFT", 5, 0)
    frame.manaSlider:SetWidth(width - 10)
    BEF_ManaSliderLow:SetText("5")
    BEF_ManaSliderHigh:SetText("100")
    frame.manaSlider:HookScript("OnValueChanged", function(self, value)
        if value ~= powerThreshold then
            powerThreshold = value
            frame.manaValue:SetText(tostring(value))
            updatePartyPower()
        end
    end)

    -- broadcast nova button
    frame.broadcastNovaLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.broadcastNovaLabel:SetText("Broadcast Nova")
    frame.broadcastNovaLabel:SetPoint("TOPLEFT", frame.manaSlider, "BOTTOMLEFT", -5, -15)
    frame.broadcastNovaLabel:SetWidth(width - powerWidth)
    frame.broadcastNovaLabel:SetHeight(fontHeight)
    frame.broadcastNovaLabel:SetJustifyH("LEFT")

    frame.broadcastNovaButton = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.broadcastNovaButton:SetPoint("TOPRIGHT", frame.manaSlider, "BOTTOMRIGHT", 5, -15)
    frame.broadcastNovaButton:SetChecked(broadcastNova)
    frame.broadcastNovaButton:SetButtonState("NORMAL")
    frame.broadcastNovaButton:SetWidth(22)
    frame.broadcastNovaButton:SetHeight(22)
    frame.broadcastNovaButton:SetScript("OnClick", function()
        broadcastNova = not broadcastNova
    end)

    -- end set button
    frame.surpriseLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.surpriseLoot:SetPoint("TOPLEFT", frame.broadcastNovaLabel, "BOTTOMLEFT", 0, -10)
    frame.surpriseLoot:SetText("End Set Early")
	frame.surpriseLoot:SetWidth(width)
    frame.surpriseLoot:SetHeight(21)
    frame.surpriseLoot:SetScript("OnClick", function() 
        if wave == 1 then
            return
        end
        setWave(1)
        SendChatMessage("[BEF] Surprise LOOT SESSION!", "YELL")
    end)

    -- events
    frame:SetScript("OnEvent", onEvent)
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("UNIT_POWER_FREQUENT")
    frame:RegisterEvent("UNIT_TARGET")
    frame:RegisterEvent("UNIT_HEALTH_FREQUENT")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("GROUP_JOINED")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")

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
