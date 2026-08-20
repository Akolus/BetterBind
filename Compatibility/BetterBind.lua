-- BetterBind public identity and lightweight interaction layer.
-- Legacy BindPad/MegaMacro globals and SavedVariables intentionally remain in
-- place so existing bindings, profiles, and extended macros keep working.

local SCALE_MIN,SCALE_MAX,SCALE_STEP=.70,1.40,.05

_G.BetterBind=_G.BindPadCore
_G.BetterMacro=_G.MegaMacro

local function Settings()
    BindPadVars=BindPadVars or {}
    BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
    local settings=BindPadVars.BPMMSettings
    settings.bindPadScale=tonumber(settings.bindPadScale) or 1
    settings.megaMacroScale=tonumber(settings.megaMacroScale) or 1
    -- All former settings-window behaviors except independent scale are
    -- deliberately retired.
    settings.linkedWindows=false
    -- /bb is the shared opener for BetterBind and BetterMacro.  Keep this
    -- enabled unconditionally now that the old settings UI has been retired.
    settings.openTogether=true
    settings.showProfileRow=true
    return settings
end

local function ClampScale(value)
    value=math.max(SCALE_MIN,math.min(SCALE_MAX,tonumber(value) or 1))
    return math.floor(value/SCALE_STEP+.5)*SCALE_STEP
end

local function CursorIsInHeader(frame)
    if not frame or not frame:IsMouseOver() then return false end
    local left,right,top=frame:GetLeft(),frame:GetRight(),frame:GetTop()
    if not left or not right or not top then return false end
    local cursorX,cursorY=GetCursorPosition()
    local scale=frame:GetEffectiveScale() or 1
    if scale==0 then scale=1 end
    cursorX,cursorY=cursorX/scale,cursorY/scale
    return cursorX>=left and cursorX<=right and cursorY<=top and cursorY>=top-40
end

local function InstallHeaderScale(frame,settingsKey)
    if not frame or frame.__BetterBindHeaderScale then return end
    frame.__BetterBindHeaderScale=true
    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel",function(self,delta)
        if not IsShiftKeyDown() or not CursorIsInHeader(self) then return end
        local settings=Settings()
        local current=ClampScale(settings[settingsKey] or self:GetScale() or 1)
        local nextScale=ClampScale(current+(delta>0 and SCALE_STEP or -SCALE_STEP))
        settings[settingsKey]=nextScale
        self:SetScale(nextScale)
    end)
end

local function HideMacroCreator(button)
    if not button or not button.addbutton then return end
    button.addbutton:Hide()
    button.addbutton:SetAlpha(0)
    button.addbutton:EnableMouse(false)
end

local function DisableMacroCreator()
    for i=1,250 do
        local button=_G["BindPadSlot"..i]
        if not button then break end
        HideMacroCreator(button)
    end
    if _G.BindPadMacroPopupFrame then BindPadMacroPopupFrame:Hide() end
    if _G.BindPadMacroFrame then BindPadMacroFrame:Hide() end
end

local function RemoveSettingsUI()
    SLASH_BPMMSETTINGS1=nil
    SLASH_BPMMSETTINGS2=nil
    if SlashCmdList then SlashCmdList["BPMMSETTINGS"]=nil end

    for _,name in ipairs({
        "BPMMSettingsPanel",
        "BPMMCompactSettingsPanel",
        "BPMMScrollableSettingsPanel",
    }) do
        local panel=_G[name]
        if panel then
            panel:Hide()
            if not panel.__BetterBindDisabled then
                panel.__BetterBindDisabled=true
                panel:HookScript("OnShow",function(self) self:Hide() end)
            end
        end
    end
end

-- Remove both creation entry points while leaving legacy macro execution code
-- available for profiles that already contain a BindPad virtual macro.
BindPadMacroAddButton_OnClick=function() end
BindPadMacroPopupFrame_Open=function() end
BindPadMacroFrame_Open=function() end

if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",HideMacroCreator)
end

local function Apply()
    Settings()
    RemoveSettingsUI()
    DisableMacroCreator()
    InstallHeaderScale(_G.BindPadFrame,"bindPadScale")
    InstallHeaderScale(_G.MegaMacro_Frame,"megaMacroScale")
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyTitles then
        BPMMGoalLayout.ApplyTitles()
    end
end

Apply()

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    Apply()
    C_Timer.After(.5,Apply)
    if ChatFrame_ImportAllListsToHash then
        ChatFrame_ImportAllListsToHash()
    end
end)

if _G.BindPadFrame then BindPadFrame:HookScript("OnShow",Apply) end
if _G.MegaMacro_Frame then MegaMacro_Frame:HookScript("OnShow",Apply) end
