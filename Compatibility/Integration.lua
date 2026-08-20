local _, addon = ...

local BPMM = _G.BPMM or {}
_G.BPMM = BPMM

local function ShowBindPad()
    if not BindPadFrame then
        return
    end

    if not BindPadFrame:IsShown() then
        if ShowUIPanel then
            local ok = pcall(ShowUIPanel, BindPadFrame)
            if not ok then
                BindPadFrame:Show()
            end
        else
            BindPadFrame:Show()
        end
    end
end

local function ShowMegaMacro()
    if MegaMacro_Frame and MegaMacro_Frame:IsShown() then
        return
    end

    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    elseif MegaMacro_Frame then
        MegaMacro_Frame:Show()
    end
end

function BPMM:OpenBoth()
    ShowBindPad()
    ShowMegaMacro()
    if type(_G.BPMM_QueueMainWindowAlignment)=="function" then
        _G.BPMM_QueueMainWindowAlignment()
    end
end

-- /bbmm is the explicit "open both" command.
SLASH_BPMM_OPEN1 = "/bbmm"
SlashCmdList["BPMM_OPEN"] = function()
    BPMM:OpenBoth()
end

local event = CreateFrame("Frame")
event:RegisterEvent("PLAYER_LOGIN")

local initialized = false

event:SetScript("OnEvent", function()
    -- Run after both embedded systems have initialized their frames/slash commands.
    C_Timer.After(0.2, function()
        if not initialized and BPMM.InitializeStyle then
            initialized = true
            BPMM:InitializeStyle()
        elseif BPMM.RefreshStyle then
            BPMM:RefreshStyle()
        end
    end)
end)
