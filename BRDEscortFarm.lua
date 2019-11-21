SLASH_BEF1, SLASH_BEF2 = "/bef", "/brdescortfarm"
SlashCmdList.BEF = function(msg, editbox)
    if msg == "show" then
        BRDEscortFarm_Frame:Show()
    end

    if msg == "hide" then
        BRDEscortFarm_Frame:Hide()
    end
end

BRDEscortFarm = {}
local ticker = nil

function BRDEscortFarm:OnShow()
    ticker = C_Timer.NewTicker(0.5, BRDEscortFarm.RunTick)
    BRDEscortFarm:RunTick()
end

function BRDEscortFarm:OnHide()
    ticker:Cancel()
    ticker = nil
end

local function ui(frame)
    return _G['BRDEscortFarm_Frame_' .. frame]
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

local function updateUnitLine(id)
    local name = UnitName(id)
    local power = unitPowerPercentage(id)

    if name ~= nil then
        ui(id .. "Name"):SetText(name)
    else
        ui(id .. "Name"):SetText("???")
    end

    if power ~= nil then
        ui(id .. "Power"):SetText(tostring(power))
    else
        ui(id .. "Power"):SetText("???")
    end
end

local function targetIsGorshak()
    local guid = UnitGUID("playertarget")
    if guid == nil then
        return;
    end

    local id = guid:sub(-15, -12)
    return id == "9020"
end

function BRDEscortFarm:RunTick()
    local gorshakHealth = ui("gorshakHealth")
    if targetIsGorshak() then
        gorshakHealth:SetText(percentage(UnitHealth("target"), UnitHealthMax("target")))
    else
        gorshakHealth:SetText("???")
    end

    updateUnitLine("player")
    updateUnitLine("party1")
    updateUnitLine("party2")
    updateUnitLine("party3")
    updateUnitLine("party4")
end
