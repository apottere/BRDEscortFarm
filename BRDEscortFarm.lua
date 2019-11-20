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

local function unitPowerPercentage(unit)
    local currentPower = UnitPower(unit)
    local maxPower = UnitPowerMax(unit)
    if maxPower == 0 then
        return nil
    end

    return math.floor((currentPower / maxPower) * 100)
end

local function displayUnitLine()
end

function BRDEscortFarm:RunTick()
    local memberCount = GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE);
    print(tostring(UnitHealthMax(9020)))
end

function BRDEscortFarm:OnEvent(event, target)
    local guid = UnitGUID(target .. "target")
    if guid == nil then
        return;
    end

    print(guid)

    local id = guid:sub(-15, -12)
    print(tostring(id))
    if id == "9020" then
        print(UnitHealthMax(target .. "target"))
    end
end