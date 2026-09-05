-- BetterBind consolidated interface and integration layer.
-- Visual construction is centralized here so each control owns one deliberate
-- icon stack instead of inherited Blizzard art plus duplicate custom passes.
-- Core and BetterMacro engines remain separate to preserve dependency order.

local eventHandlers={}
local eventHub=CreateFrame("Frame")
local CLOSE_ART="Interface\\AddOns\\BetterBind\\UI\\media\\close-modern.tga"

-- HUI-inspired icon stack requested for every BetterBind icon surface.
-- Backdrop, border and selected art are Blizzard atlases; only the rounded
-- mask is the credited HUI media file shipped in UI/media.
local ICON_STYLE={
    backdrop="plunderstorm-actionbar-slot-background",
    border="UI-HUD-CoolDownManager-IconOverlay",
    mask="Interface\\AddOns\\BetterBind\\UI\\media\\HUI_Mask_CooldownTracker.png",
    selected="GearEnchant_IconBorder",
    backdropScale=60/45,
    borderScale=60/45,
    stateScale=48/45,
    maskScale=.96,
    iconScale=1.13,
    purple={.533,.227,1,1},
    blue={.05,.565,.905,1},
}

local function SetIconAtlas(texture,atlas)
    if not texture or not atlas then return false end
    local atlasExists=not (_G.C_Texture and C_Texture.GetAtlasInfo)
        or C_Texture.GetAtlasInfo(atlas)
    if atlasExists and texture.SetAtlas then
        local ok=pcall(texture.SetAtlas,texture,atlas,false)
        if ok then return true end
    end
    texture:SetTexture(nil)
    return false
end

local function SizeIconStyleTexture(texture,button,scale)
    if not texture or not button then return end
    local width,height=button:GetSize()
    if not width or width<=0 then width=button:GetWidth() or 1 end
    if not height or height<=0 then height=button:GetHeight() or width end
    texture:ClearAllPoints()
    texture:SetPoint("CENTER",button,"CENTER",0,0)
    texture:SetSize(width*(scale or 1),height*(scale or 1))
end

local function EnsureIconStateTexture(button,key,atlas,color,scale,subLevel,blendMode)
    if not button then return end
    local texture=button[key]
    if not texture then
        texture=button:CreateTexture(nil,"OVERLAY",nil,subLevel or 6)
        texture.__BetterBindOwned=true
        button[key]=texture
    end
    SetIconAtlas(texture,atlas)
    SizeIconStyleTexture(texture,button,scale)
    texture:SetDesaturated(true)
    texture:SetVertexColor(unpack(color))
    texture:SetBlendMode(blendMode or "ADD")
    return texture
end

local function RegisterEventHandler(eventName,handler)
    local handlers=eventHandlers[eventName]
    if not handlers then
        handlers={}
        eventHandlers[eventName]=handlers
        eventHub:RegisterEvent(eventName)
    end
    handlers[#handlers+1]=handler
end

eventHub:SetScript("OnEvent",function(_,eventName,...)
    local handlers=eventHandlers[eventName]
    if not handlers then return end
    for _,handler in ipairs(handlers) do
        local arguments={...}
        local ok,message=xpcall(function()
            handler(eventName,unpack(arguments))
        end,function(errorMessage)
            local trace=debugstack and debugstack(2,20,20) or ""
            return tostring(errorMessage).."\n"..trace
        end)
        if not ok then
            local errorHandler=geterrorhandler and geterrorhandler()
            if errorHandler then errorHandler(message) end
        end
    end
end)

-- Commands and paired-window integration
do
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
end

-- Close-button styling
do
-- Shared close-button skin for BetterBind dialogs and main windows.

local function GetCloseButton(frame)
    if not frame then return end
    local name=frame.GetName and frame:GetName()
    return (name and _G[name.."CloseButton"])
        or frame.CloseButton
        or frame.closeButton
        or (frame.BorderBox and frame.BorderBox.CloseButton)
        or (frame.TitleContainer and frame.TitleContainer.CloseButton)
end

local function MakeCleanClose(frame,explicitButton)
    local button=explicitButton or GetCloseButton(frame)
    if not button then return end

    for _,region in ipairs({button:GetRegions()}) do
        if region and not region.__BetterBindOwned then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    -- Hiding the existing regions is API-safe across templates and clients.
    -- Calling SetNormal/Highlight/PushedTexture(nil) is not accepted by every
    -- WoW button mixin and previously allowed a cosmetic pass to abort startup.
    if button.__BetterAppearanceBG then button.__BetterAppearanceBG:Hide() end

    button:SetSize(20,20)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-5,-5)

    local clean=button.__BPMMCleanClose
    if clean and not clean.label then
        if clean.line1 then clean.line1:Hide() end
        if clean.line2 then clean.line2:Hide() end
        if clean.icon then clean.icon:Hide() end
        if clean.art then clean.art:Hide() end
        clean=nil
        button.__BPMMCleanClose=nil
    end
    if not clean then
        -- ASCII X is supported by every WoW font. The previous external icon
        -- texture remained clickable but was visually missing on some frames.
        local label=button:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
        label:SetPoint("CENTER",button,"CENTER",0,1)
        label:SetText("X")
        label:SetTextColor(.78,.82,.88,1)
        label:SetShadowColor(0,0,0,.75)
        label:SetShadowOffset(0,0)
        label.__BetterBindOwned=true

        clean={label=label}
        button.__BPMMCleanClose=clean
        button:HookScript("OnEnter",function(self)
            local state=self.__BPMMCleanClose
            if not state then return end
            if self.__BetterAppearanceBG then self.__BetterAppearanceBG:Hide() end
            if self.__BetterAppearanceUnderline then
                self.__BetterAppearanceUnderline:Hide()
            end
            state.label:SetTextColor(.40,.92,.90,1)
        end)
        button:HookScript("OnLeave",function(self)
            local state=self.__BPMMCleanClose
            if not state then return end
            if self.__BetterAppearanceBG then self.__BetterAppearanceBG:Hide() end
            if self.__BetterAppearanceUnderline then
                self.__BetterAppearanceUnderline:Hide()
            end
            state.label:SetTextColor(.78,.82,.88,1)
        end)
    end

    clean.label:SetText("X")
    clean.label:SetTextColor(.78,.82,.88,1)
    clean.label:SetAlpha(1)
    clean.label:Show()
    if button.__BetterAppearanceUnderline then
        button.__BetterAppearanceUnderline:Hide()
    end
    button:SetAlpha(1)
    button:EnableMouse(true)

    -- ButtonFrameTemplate may reassign its native red X during a later
    -- refresh. Reassert the custom state after the button itself is shown.
    if not button.__BetterBindCloseShowHook then
        button.__BetterBindCloseShowHook=true
        button:HookScript("OnShow",function(self)
            C_Timer.After(0,function()
                if self:IsShown() then MakeCleanClose(frame,self) end
            end)
        end)
    end
end

_G.BetterBindAppearance_StyleClose=MakeCleanClose

local function StyleFrameCloseButtons(frame,explicitButton)
    if not frame then return end
    local seen={}
    local function Apply(button)
        if button and not seen[button] then
            seen[button]=true
            local ok,message=xpcall(function()
                MakeCleanClose(frame,button)
            end,function(errorMessage)
                local trace=debugstack and debugstack(2,20,20) or ""
                return ("BetterBind close-marker styling failed: %s\n%s"):format(
                    tostring(errorMessage),trace
                )
            end)
            if not ok then
                local errorHandler=geterrorhandler and geterrorhandler()
                if errorHandler then errorHandler(message) end
            end
        end
    end
    Apply(explicitButton)
    Apply(GetCloseButton(frame))
    if frame.GetChildren then
        for _,child in ipairs({frame:GetChildren()}) do
            local name=child.GetName and child:GetName()
            if child.GetObjectType and child:GetObjectType()=="Button"
                and name and name:lower():find("close",1,true)
            then
                Apply(child)
            end
        end
    end
end

local function Refresh()
    StyleFrameCloseButtons(_G.BindPadFrame,_G.BindPadFrameCloseButton)
    StyleFrameCloseButtons(_G.MegaMacro_Frame,_G.MegaMacro_FrameCloseButton)
    StyleFrameCloseButtons(_G.BindPadBindFrame,_G.BindPadBindFrameCloseButton)
    StyleFrameCloseButtons(_G.BindPadMacroFrame,_G.BindPadMacroFrameCloseButton)
end

_G.BetterBindAppearance_RefreshCloseButtons=Refresh

RegisterEventHandler("PLAYER_LOGIN",function()
    C_Timer.After(0,Refresh)
end)

for _,frame in ipairs({
    _G.BindPadFrame,_G.MegaMacro_Frame,_G.BindPadBindFrame,_G.BindPadMacroFrame,
}) do
    if frame then frame:HookScript("OnShow",Refresh) end
end
end

-- Window behavior
do
-- BetterBind window behavior.
-- Keeps scale, position persistence and paired opening in one
-- event-driven layer. Retired settings panels and polling frames are omitted.

local DEFAULTS={
    bindPadScale=1,
    megaMacroScale=1,
    openTogether=true,
    rememberWindowPositions=true,
}

local function Settings()
    BindPadVars=BindPadVars or {}
    BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
    local settings=BindPadVars.BPMMSettings
    for key,value in pairs(DEFAULTS) do
        if settings[key]==nil then settings[key]=value end
    end
    settings.windowPositions=settings.windowPositions or {}
    return settings
end

local function ClampScale(value)
    value=tonumber(value) or 1
    return math.max(.7,math.min(1.4,math.floor(value*100+.5)/100))
end

local function ApplyScale()
    local settings=Settings()
    if _G.BindPadFrame then
        BindPadFrame:SetScale(ClampScale(settings.bindPadScale))
    end
    if _G.MegaMacro_Frame then
        MegaMacro_Frame:SetScale(ClampScale(settings.megaMacroScale))
    end
end

local function SavePoint(frame,key)
    if not frame or not Settings().rememberWindowPositions then return end
    local point,relativeTo,relativePoint,x,y=frame:GetPoint(1)
    if not point then return end
    local relativeName="UIParent"
    if relativeTo and relativeTo.GetName and relativeTo:GetName() then
        relativeName=relativeTo:GetName()
    end
    Settings().windowPositions[key]={
        point=point,
        relativeTo=relativeName,
        relativePoint=relativePoint or point,
        x=tonumber(x) or 0,
        y=tonumber(y) or 0,
    }
end

local function RestorePoint(frame,key)
    if not frame or not Settings().rememberWindowPositions then return end
    local saved=Settings().windowPositions[key]
    if not saved then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        saved.point or "CENTER",
        _G[saved.relativeTo or "UIParent"] or UIParent,
        saved.relativePoint or saved.point or "CENTER",
        tonumber(saved.x) or 0,
        tonumber(saved.y) or 0
    )
end

local function ResetPositions()
    Settings().windowPositions={}
    if _G.BindPadFrame then
        BindPadFrame:ClearAllPoints()
        BindPadFrame:SetPoint("CENTER",UIParent,"CENTER",-310,0)
    end
    if _G.MegaMacro_Frame then
        MegaMacro_Frame:ClearAllPoints()
        if _G.BindPadFrame then
            MegaMacro_Frame:SetPoint("TOPLEFT",BindPadFrame,"TOPRIGHT",4,0)
        else
            MegaMacro_Frame:SetPoint("CENTER",UIParent,"CENTER",310,0)
        end
    end
end

_G.BPMM_SaveWindowPoint=SavePoint
_G.BPMM_RestoreWindowPoint=RestorePoint
_G.BPMM_ResetWindowPositions=ResetPositions

local function InstallWindowHooks(frame,key)
    if not frame or frame.__BetterBindWindowHooks then return end
    frame.__BetterBindWindowHooks=true

    frame:HookScript("OnDragStop",function(self)
        SavePoint(self,key)
    end)

    frame:HookScript("OnShow",function(self)
        if self.__BetterBindPositionRestored then return end
        self.__BetterBindPositionRestored=true
        RestorePoint(self,key)
    end)
end

local function AlignMainWindows()
    if not _G.BindPadFrame or not _G.MegaMacro_Frame
        or not BindPadFrame:IsShown() or not MegaMacro_Frame:IsShown()
    then
        return
    end
    MegaMacro_Frame:ClearAllPoints()
    MegaMacro_Frame:SetPoint("TOPLEFT",BindPadFrame,"TOPRIGHT",4,0)
    SavePoint(BindPadFrame,"BindPad")
    SavePoint(MegaMacro_Frame,"MegaMacro")
end

local function QueueMainWindowAlignment()
    C_Timer.After(0,AlignMainWindows)
    C_Timer.After(.05,AlignMainWindows)
end

_G.BPMM_AlignMainWindows=AlignMainWindows
_G.BPMM_QueueMainWindowAlignment=QueueMainWindowAlignment

local anchorHooksInstalled=false
local function InstallAnchorHooks()
    if anchorHooksInstalled then return end
    anchorHooksInstalled=true
    local function ReanchorIfPaired()
        if _G.BindPadFrame and BindPadFrame:IsShown()
            and _G.MegaMacro_Frame and MegaMacro_Frame:IsShown()
        then
            QueueMainWindowAlignment()
        end
    end
    if _G.BindPadFrame then BindPadFrame:HookScript("OnShow",ReanchorIfPaired) end
    if _G.MegaMacro_Frame then MegaMacro_Frame:HookScript("OnShow",ReanchorIfPaired) end
end

local slashInstalled=false
local function InstallBindPadSlash()
    if slashInstalled then return end
    local original=SlashCmdList and SlashCmdList.BINDPAD
    if type(original)~="function" then return end

    SlashCmdList.BINDPAD=function(message)
        local trimmed=(message or ""):match("^%s*(.-)%s*$") or ""
        if trimmed~="" then return original(message) end

        if _G.BindPadFrame and not BindPadFrame:IsShown() then
            if ShowUIPanel then
                local shown=pcall(ShowUIPanel,BindPadFrame)
                if not shown then BindPadFrame:Show() end
            else
                BindPadFrame:Show()
            end
        end

        if Settings().openTogether and _G.BindPadFrame and BindPadFrame:IsShown() then
            if _G.MegaMacroWindow and type(MegaMacroWindow.Show)=="function" then
                if not _G.MegaMacro_Frame or not MegaMacro_Frame:IsShown() then
                    MegaMacroWindow.Show()
                end
            elseif _G.MegaMacro_Frame then
                MegaMacro_Frame:Show()
            end
            QueueMainWindowAlignment()
        end
    end
    slashInstalled=true
end

local function Initialize()
    Settings()
    ApplyScale()
    InstallWindowHooks(_G.BindPadFrame,"BindPad")
    InstallWindowHooks(_G.MegaMacro_Frame,"MegaMacro")
    InstallAnchorHooks()
    RestorePoint(_G.BindPadFrame,"BindPad")
    RestorePoint(_G.MegaMacro_Frame,"MegaMacro")
    C_Timer.After(.35,InstallBindPadSlash)
end

RegisterEventHandler("PLAYER_LOGIN",Initialize)
C_Timer.After(0,InstallBindPadSlash)
end

-- Search, selection and locate integration
do
-- Direct BetterBind/BetterMacro integration.  These bridges never migrate or
-- rewrite macro, binding, profile or SavedVariables data.
do
-- 1) MegaMacro -> BindPad drag/drop uses MegaMacro's native PickupMacro cursor payload.
-- 2) Right-click a BindPad slot backed by a MegaMacro opens/selects it in MegaMacro.
-- 3) Selecting a MegaMacro highlights matching visible BindPad slots.
--
-- This file does not modify MegaMacroGlobalData, BindPad slot data, or bindings.

local BPMM71 = {}
_G.BPMM71 = BPMM71

local TYPE_MACRO_LOCAL = "MACRO"
local TYPE_BINDPAD_MACRO_LOCAL = "CLICK"
local selectedMegaMacroId = nil
local originalBindPadSlotOnClick = nil

local function GetNativeMacroIndexByName(name)
    if not name or name == "" then return nil end

    -- Prefer the API when available.
    if GetMacroIndexByName then
        local index = GetMacroIndexByName(name)
        if index and index > 0 then return index end
    end

    local globalCount, charCount = GetNumMacros()
    local maxIndex = (globalCount or 0) + (charCount or 0)
    -- Character macros use the fixed offset on modern clients, so scan the
    -- engine's known range as well.
    maxIndex = math.max(maxIndex, 138)

    for i = 1, maxIndex do
        local macroName = GetMacroInfo(i)
        if macroName == name then
            return i
        end
    end
end

local function GetMegaMacroIdFromPadSlot(padSlot)
    if not padSlot or padSlot.type ~= TYPE_MACRO_LOCAL then return nil end
    if not MegaMacroEngine or not MegaMacroEngine.GetMacroIdFromIndex then return nil end

    local index = GetNativeMacroIndexByName(padSlot.name)
    if not index then
        -- BindPad's action is normally "MACRO <name>". Use that as fallback.
        local actionName = padSlot.action and padSlot.action:match("^MACRO%s+(.+)$")
        index = GetNativeMacroIndexByName(actionName)
    end
    if not index then return nil end

    local id = MegaMacroEngine.GetMacroIdFromIndex(index)
    if id and MegaMacro and MegaMacro.GetById and MegaMacro.GetById(id) then
        return id
    end
end

local function GetScopeTab(scope)
    if not MegaMacroScopes then return nil end
    if scope == MegaMacroScopes.Global then return 1 end
    if scope == MegaMacroScopes.Class then return 2 end
    if scope == MegaMacroScopes.Specialization then return 3 end
    if scope == MegaMacroScopes.Character then return 4 end
    if scope == MegaMacroScopes.Inactive then return 5 end
end

local function EnsureHighlight(button)
    if button.__BPMM71Highlight then return button.__BPMM71Highlight end

    local h=EnsureIconStateTexture(
        button,"__BPMM71Highlight",ICON_STYLE.selected,
        ICON_STYLE.purple,ICON_STYLE.stateScale,6,"ADD"
    )
    h:Hide()
    return h
end

local function RefreshBindPadHighlights()
    if not BindPadCore then return end

    local i = 1
    while true do
        local button = _G["BindPadSlot" .. i]
        if not button then break end

        local padSlot = BindPadCore.GetSlotInfo and BindPadCore.GetSlotInfo(button:GetID())
        local id = GetMegaMacroIdFromPadSlot(padSlot)
        local selected=selectedMegaMacroId~=nil and id==selectedMegaMacroId
        if selected then
            EnsureHighlight(button):Show()
        elseif button.__BPMM71Highlight then
            button.__BPMM71Highlight:Hide()
        end
        i = i + 1
    end
end

local function SelectMegaMacroById(id)
    if not id or not MegaMacro or not MegaMacro.GetById then return false end
    local macro = MegaMacro.GetById(id)
    if not macro then return false end

    -- Re-running ShowUIPanel on an already-open BetterMacro window lets the
    -- panel manager normalize its anchor, which visibly nudges the window.
    if not (MegaMacro_Frame and MegaMacro_Frame:IsShown()) then
        if MegaMacroWindow and MegaMacroWindow.Show then
            MegaMacroWindow.Show()
        elseif MegaMacro_Frame then
            MegaMacro_Frame:Show()
        end
    end

    local tabIndex = GetScopeTab(macro.Scope)
    if tabIndex then
        local tab = _G["MegaMacro_FrameTab" .. tabIndex]
        if tab and MegaMacro_FrameTab_OnClick then
            MegaMacro_FrameTab_OnClick(tab)
        end
    end

    -- SetMacroItems() assigns .Macro to the visible buttons. Find the exact id
    -- and use MegaMacro's own click handler so selection/edit state stays native.
    for i = 1, (HighestMaxMacroCount or 60) do
        local button = _G["MegaMacro_MacroButton" .. i]
        if button and button.Macro and button.Macro.Id == id then
            if MegaMacro_MacroButton_OnClick then
                MegaMacro_MacroButton_OnClick(button)
            end
            selectedMegaMacroId = id
            RefreshBindPadHighlights()
            return true
        end
    end

    return false
end

BPMM71.SelectMegaMacroById = SelectMegaMacroById
BPMM71.RefreshBindPadHighlights = RefreshBindPadHighlights

-- ---------------------------------------------------------------------------
-- Right-click bridge
-- ---------------------------------------------------------------------------

local function InstallBindPadRightClickBridge()
    if BPMM71.rightClickInstalled then return end
    if type(_G.BindPadSlot_OnClick) ~= "function" then return end

    originalBindPadSlotOnClick = _G.BindPadSlot_OnClick

    _G.BindPadSlot_OnClick = function(self, button, down)
        if button == "RightButton"
            and BindPadCore
            and not BindPadCore.CursorHasIcon()
        then
            local padSlot = BindPadCore.GetSlotInfo(self:GetID())
            local id = GetMegaMacroIdFromPadSlot(padSlot)

            if id then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                if SelectMegaMacroById(id) then
                    C_Timer.After(0,function()
                        if type(_G.MegaMacro_EditButton_OnClick)=="function" then
                            MegaMacro_EditButton_OnClick()
                        end
                    end)
                end
                return
            end

            -- Native BetterBind macros have their own name/icon editor.
            -- Reuse it directly; spells and items remain untouched.
            if padSlot and padSlot.type==TYPE_BINDPAD_MACRO_LOCAL
                and type(_G.BindPadMacroPopupFrame_Open)=="function"
            then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                BindPadMacroPopupFrame_Open(self)
                return
            end
        end

        local result=originalBindPadSlotOnClick(self, button, down)
        if button=="LeftButton"
            and BindPadCore.selectedSlotButton==self
            and _G.BindPadBindFrame and BindPadBindFrame:IsShown()
            and type(_G.BetterBindAppearance_SelectBindPadCell)=="function"
        then
            BetterBindAppearance_SelectBindPadCell(self)
        end
        return result
    end

    BPMM71.rightClickInstalled = true
end

-- ---------------------------------------------------------------------------
-- Selection -> BindPad highlight bridge
-- ---------------------------------------------------------------------------

local function InstallMegaMacroSelectionBridge()
    if BPMM71.selectionInstalled then return end
    if type(_G.MegaMacro_MacroButton_OnClick) ~= "function" then return end

    hooksecurefunc("MegaMacro_MacroButton_OnClick", function(button)
        if button and button.Macro then
            selectedMegaMacroId = button.Macro.Id
            RefreshBindPadHighlights()
        end
    end)

    BPMM71.selectionInstalled = true
end

-- Refresh when BindPad redraws slots/tabs/profile contents.
local function InstallBindPadRefreshBridge()
    if BPMM71.refreshInstalled then return end

    if type(_G.BindPadSlot_UpdateState) == "function" then
        hooksecurefunc("BindPadSlot_UpdateState", function()
            if selectedMegaMacroId then
                C_Timer.After(0, RefreshBindPadHighlights)
            end
        end)
    end

    if BindPadFrame then
        BindPadFrame:HookScript("OnShow", function()
            C_Timer.After(0, RefreshBindPadHighlights)
        end)
    end

    BPMM71.refreshInstalled = true
end

-- ---------------------------------------------------------------------------
-- Drag feedback
--
-- MegaMacro already calls PickupMacro(nativeIndex) from its macro buttons.
-- BindPad already consumes cursor type "macro" in BindPadSlot_OnReceiveDrag.
-- We deliberately do NOT replace either implementation. This preserves the
-- proven native drag/drop path and avoids a second macro storage mechanism.
-- ---------------------------------------------------------------------------

local lastCursorMegaId = nil
local function RefreshDragFeedback()
    if not GetCursorInfo or not MegaMacroEngine then return end
    local cursorType, index = GetCursorInfo()
    local id = nil

    if cursorType == "macro" and index then
        id = MegaMacroEngine.GetMacroIdFromIndex(index)
        if id and (not MegaMacro or not MegaMacro.GetById or not MegaMacro.GetById(id)) then
            id = nil
        end
    end

    if id ~= lastCursorMegaId then
        lastCursorMegaId = id

        -- Subtle feedback: gold edge around BindPad while carrying a MegaMacro.
        if BindPadFrame then
            if id then
                if not BindPadFrame.__BPMM71DropGlow then
                    local g = CreateFrame("Frame", nil, BindPadFrame, "BackdropTemplate")
                    g:SetPoint("TOPLEFT", 1, -1)
                    g:SetPoint("BOTTOMRIGHT", -1, 1)
                    g:SetFrameLevel((BindPadFrame:GetFrameLevel() or 1) + 20)
                    g:SetBackdrop({
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    g:SetBackdropBorderColor(1, .78, .08, .8)
                    g:EnableMouse(false)
                    BindPadFrame.__BPMM71DropGlow = g
                end
                BindPadFrame.__BPMM71DropGlow:Show()
            elseif BindPadFrame.__BPMM71DropGlow then
                BindPadFrame.__BPMM71DropGlow:Hide()
            end
        end
    end
end

RegisterEventHandler("CURSOR_CHANGED",RefreshDragFeedback)

local function ClearDragFeedback()
    lastCursorMegaId=nil
    if BindPadFrame and BindPadFrame.__BPMM71DropGlow then
        BindPadFrame.__BPMM71DropGlow:Hide()
    end
end

if BindPadFrame then
    BindPadFrame:HookScript("OnHide",ClearDragFeedback)
end
if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnHide",ClearDragFeedback)
end

local function InstallBridges(event)
    local delay = event == "PLAYER_LOGIN" and .5 or 0
    C_Timer.After(delay, function()
        InstallBindPadRightClickBridge()
        InstallMegaMacroSelectionBridge()
        InstallBindPadRefreshBridge()
        RefreshBindPadHighlights()
    end)
end
RegisterEventHandler("PLAYER_LOGIN",InstallBridges)
RegisterEventHandler("PLAYER_REGEN_ENABLED",InstallBridges)

end

-- Unified live search across BetterMacro and the visible BetterBind profile.
do
-- Presentation only: search never changes macro/binding/profile data.

local Search72 = {}
_G.BPMM72 = Search72

local query = ""
local searchFrame
local editBox
local placeholder
local resultText
local refreshPending = false

local function lower(v)
    return type(v) == "string" and string.lower(v) or ""
end

local function contains(text, needle)
    if needle == "" then return true end
    return string.find(lower(text), needle, 1, true) ~= nil
end

local function GetMacroIndexByPadSlot(padSlot)
    if not padSlot or padSlot.type ~= "MACRO" then return nil end

    local name = padSlot.name
    if (not name or name == "") and padSlot.action then
        name = padSlot.action:match("^MACRO%s+(.+)$")
    end
    if not name or name == "" then return nil end

    if GetMacroIndexByName then
        local index = GetMacroIndexByName(name)
        if index and index > 0 then return index end
    end

    -- Fallback scan, including modern character macro range.
    for i=1,138 do
        local macroName = GetMacroInfo(i)
        if macroName == name then return i end
    end
end

local function GetMegaMacroForPadSlot(padSlot)
    if not MegaMacroEngine or not MegaMacro or not MegaMacro.GetById then return nil end
    local index = GetMacroIndexByPadSlot(padSlot)
    if not index then return nil end

    local id = MegaMacroEngine.GetMacroIdFromIndex(index)
    if not id then return nil end
    return MegaMacro.GetById(id)
end

local function PadSlotMatches(padSlot, q)
    if not padSlot then return false end
    if contains(padSlot.name, q) then return true end
    if contains(padSlot.macrotext, q) then return true end
    if contains(padSlot.action, q) then return true end

    local mega = GetMegaMacroForPadSlot(padSlot)
    if mega then
        if contains(mega.DisplayName, q) then return true end
        if contains(mega.Code, q) then return true end
    end

    return false
end

local function MegaMacroMatches(macro, q)
    if not macro then return false end
    return contains(macro.DisplayName, q)
        or contains(macro.Code, q)
        or contains(tostring(macro.Id or ""), q)
end

local function RestoreAll()
    -- MegaMacro visible buttons.
    for i=1,(HighestMaxMacroCount or 60) do
        local b=_G["MegaMacro_MacroButton"..i]
        if b then b:SetAlpha(1) end
    end

    -- BindPad slots.
    local i=1
    while true do
        local b=_G["BindPadSlot"..i]
        if not b then break end
        b:SetAlpha(1)
        if b.__BPMM72SearchMatch then
            b.__BPMM72SearchMatch:Hide()
        end
        i=i+1
    end

    if resultText then resultText:SetText("") end
end

local function EnsureMatchMarker(button)
    if button.__BPMM72SearchMatch then return button.__BPMM72SearchMatch end

    local m=EnsureIconStateTexture(
        button,"__BPMM72SearchMatch",ICON_STYLE.border,
        {.10,.60,1,.95},ICON_STYLE.borderScale,5,"ADD"
    )
    m:Hide()
    return m
end

local function CountAllMegaMatches(q)
    if q=="" or not MegaMacro or not MegaMacro.GetMacrosInScope or not MegaMacroScopes then
        return 0
    end

    local count=0
    local seen={}
    local scopes={
        MegaMacroScopes.Global,
        MegaMacroScopes.Class,
        MegaMacroScopes.Specialization,
        MegaMacroScopes.Character,
        MegaMacroScopes.Inactive,
    }

    for _,scope in ipairs(scopes) do
        if scope and not seen[scope] then
            seen[scope]=true
            local ok,items=pcall(MegaMacro.GetMacrosInScope,scope)
            if ok and type(items)=="table" then
                for _,macro in ipairs(items) do
                    if MegaMacroMatches(macro,q) then count=count+1 end
                end
            end
        end
    end

    return count
end

local function ApplySearch()
    refreshPending=false
    local q=lower((query or ""):match("^%s*(.-)%s*$") or "")

    if placeholder then
        placeholder:SetShown(q=="")
    end

    if q=="" then
        RestoreAll()
        return
    end

    for i=1,(HighestMaxMacroCount or 60) do
        local b=_G["MegaMacro_MacroButton"..i]
        if b and b:IsShown() then
            -- Ignore MegaMacro's one "new macro" plus button as a result.
            if b.Macro then
                if MegaMacroMatches(b.Macro,q) then
                    b:SetAlpha(1)
                else
                    b:SetAlpha(.18)
                end
            elseif b.IsNewButton then
                b:SetAlpha(.12)
            else
                b:SetAlpha(1)
            end
        end
    end

    local bindMatches=0
    local i=1

    while true do
        local b=_G["BindPadSlot"..i]
        if not b then break end

        local padSlot=BindPadCore and BindPadCore.GetSlotInfo and BindPadCore.GetSlotInfo(b:GetID())

        if b:IsShown() and padSlot and padSlot.type then
            if PadSlotMatches(padSlot,q) then
                b:SetAlpha(1)
                EnsureMatchMarker(b):Show()
                bindMatches=bindMatches+1
            else
                b:SetAlpha(.18)
                if b.__BPMM72SearchMatch then b.__BPMM72SearchMatch:Hide() end
            end
        elseif b:IsShown() then
            b:SetAlpha(.10)
            if b.__BPMM72SearchMatch then b.__BPMM72SearchMatch:Hide() end
        else
            if b.__BPMM72SearchMatch then b.__BPMM72SearchMatch:Hide() end
        end

        i=i+1
    end

    local allMegaMatches=CountAllMegaMatches(q)

    if resultText then
        resultText:SetFormattedText(
            "%d BetterMacro%s  |  %d BetterBind",
            allMegaMatches,
            allMegaMatches==1 and "" or "s",
            bindMatches
        )
    end
end

local function QueueSearch()
    if refreshPending then return end
    refreshPending=true
    C_Timer.After(.03,ApplySearch)
end

local function SetQuery(text,focus)
    query=text or ""
    if editBox and editBox:GetText()~=query then
        editBox:SetText(query)
    end
    QueueSearch()
    if focus and editBox then
        editBox:SetFocus()
        editBox:HighlightText()
    end
end

Search72.SetQuery=SetQuery
Search72.ApplySearch=ApplySearch
Search72.GetQuery=function() return query end

local function BuildSearchUI()
    if searchFrame or not MegaMacro_Frame then return end

    -- Title-bar search: compact enough to avoid tabs/content and the close button.
    searchFrame=CreateFrame("Frame","BPMMUnifiedSearch",MegaMacro_Frame,"BackdropTemplate")
    searchFrame:SetSize(250,24)
    searchFrame:SetPoint("TOP",MegaMacro_Frame,"TOP",0,-8)
    searchFrame:SetFrameLevel((MegaMacro_Frame:GetFrameLevel() or 1)+25)
    searchFrame:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    searchFrame:SetBackdropColor(.025,.025,.03,.96)
    searchFrame:SetBackdropBorderColor(.22,.22,.25,1)

    editBox=CreateFrame("EditBox","BPMMUnifiedSearchEditBox",searchFrame)
    editBox:SetPoint("LEFT",8,0)
    editBox:SetPoint("RIGHT",-26,0)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetTextInsets(0,0,0,0)

    placeholder=searchFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    placeholder:SetPoint("LEFT",editBox,"LEFT",0,0)
    placeholder:SetText("Search macros + BetterBind...")
    placeholder:SetTextColor(.46,.46,.50,1)

    local clear=CreateFrame("Button",nil,searchFrame)
    clear:SetSize(20,20)
    clear:SetPoint("RIGHT",-2,0)
    searchFrame.ClearButton=clear

    local clearIcon=clear:CreateTexture(nil,"ARTWORK")
    clearIcon:SetTexture(CLOSE_ART,"CLAMP","CLAMP")
    clearIcon:SetSize(12,12)
    clearIcon:SetPoint("CENTER")
    clearIcon:SetVertexColor(.58,.58,.62,1)

    clear:SetScript("OnEnter",function()
        clearIcon:SetVertexColor(1,.78,.90,1)
    end)
    clear:SetScript("OnLeave",function()
        clearIcon:SetVertexColor(.58,.58,.62,1)
    end)
    clear:SetScript("OnClick",function()
        editBox:SetText("")
        editBox:ClearFocus()
    end)

    resultText=MegaMacro_Frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    resultText:SetPoint("LEFT",searchFrame,"RIGHT",8,0)
    resultText:SetWidth(160)
    resultText:SetJustifyH("LEFT")
    resultText:SetTextColor(.58,.58,.62,1)

    editBox:SetScript("OnTextChanged",function(self)
        query=self:GetText() or ""
        QueueSearch()
    end)
    editBox:SetScript("OnEscapePressed",function(self)
        if self:GetText()~="" then
            self:SetText("")
        else
            self:ClearFocus()
        end
    end)
    editBox:SetScript("OnEnterPressed",function(self)
        self:ClearFocus()
    end)

    searchFrame:HookScript("OnEnter",function()
        searchFrame:SetBackdropBorderColor(.92,.72,.08,1)
    end)
    searchFrame:HookScript("OnLeave",function()
        if not editBox:HasFocus() then
            searchFrame:SetBackdropBorderColor(.22,.22,.25,1)
        end
    end)
    editBox:SetScript("OnEditFocusGained",function()
        searchFrame:SetBackdropBorderColor(.92,.72,.08,1)
    end)
    editBox:SetScript("OnEditFocusLost",function()
        searchFrame:SetBackdropBorderColor(.22,.22,.25,1)
    end)
end

-- Refresh search when either addon redraws its buttons.
local function InstallRefreshHooks()
    if Search72.hooksInstalled then return end

    if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
        hooksecurefunc("MegaMacro_MacroButton_OnClick",QueueSearch)
    end
    if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
        hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
            C_Timer.After(0,QueueSearch)
        end)
    end
    if type(_G.BindPadSlot_UpdateState)=="function" then
        hooksecurefunc("BindPadSlot_UpdateState",QueueSearch)
    end

    if BindPadFrame then
        BindPadFrame:HookScript("OnShow",QueueSearch)
    end
    if MegaMacro_Frame then
        MegaMacro_Frame:HookScript("OnShow",function()
            BuildSearchUI()
            QueueSearch()
        end)
        MegaMacro_Frame:HookScript("OnHide",function()
            if editBox then editBox:ClearFocus() end
        end)
    end

    Search72.hooksInstalled=true
end

-- Slash command: /bbfind recuperate
-- Blank /bbfind just opens/focuses the field.
SLASH_BPMMFIND1="/bbfind"
SlashCmdList["BPMMFIND"]=function(msg)
    if MegaMacroWindow and MegaMacroWindow.Show then
        MegaMacroWindow.Show()
    elseif MegaMacro_Frame then
        MegaMacro_Frame:Show()
    end

    BuildSearchUI()
    SetQuery(msg or "",true)
end

RegisterEventHandler("PLAYER_LOGIN",function()
    C_Timer.After(.5,function()
        BuildSearchUI()
        InstallRefreshHooks()
        QueueSearch()
    end)
end)
end

-- Read-only "where is this macro used?" locator.
do
-- Adds a compact Locate control on the right side of MegaMacro's footer.
-- Read-only: never changes macro, binding, profile, or SavedVariables data.

local M = {}
_G.BPMM74 = M

local selectedId = nil
local selectedMacro = nil
local pulseToken = 0

local C = {
    bg = {.035,.035,.042,1},
    hover = {.055,.060,.070,1},
    border = {.16,.16,.18,1},
    blue = {.08,.58,.88,1},
    text = {.88,.88,.91,1},
    muted = {.52,.52,.56,1},
}

local function GetMacroIndexByName(name)
    if not name or name == "" then return nil end

    if GetMacroIndexByName then
        local index = _G.GetMacroIndexByName(name)
        if index and index > 0 then return index end
    end

    for i=1,138 do
        local macroName = GetMacroInfo(i)
        if macroName == name then return i end
    end
end

local function MegaIdFromPadSlot(padSlot)
    if not padSlot or padSlot.type ~= "MACRO" then return nil end
    if not MegaMacroEngine or not MegaMacroEngine.GetMacroIdFromIndex then return nil end

    -- New BetterBind slots persist BetterMacro's stable ID at drop time.
    -- Prefer it over the native macro name, which can be truncated or renamed.
    if padSlot.megaMacroId and MegaMacro and MegaMacro.GetById
        and MegaMacro.GetById(padSlot.megaMacroId)
    then
        return padSlot.megaMacroId
    end

    local name = padSlot.name
    if (not name or name=="") and padSlot.action then
        name = padSlot.action:match("^MACRO%s+(.+)$")
    end

    local index = GetMacroIndexByName(name)
    if not index then return nil end
    return MegaMacroEngine.GetMacroIdFromIndex(index)
end

local function VisibleBindPadMatches(id)
    local matches = {}
    if not id or not BindPadCore then return matches end

    local i = 1
    while true do
        local button = _G["BindPadSlot"..i]
        if not button then break end

        if button:IsShown() then
            local slot = BindPadCore.GetSlotInfo and BindPadCore.GetSlotInfo(button:GetID())
            if slot and MegaIdFromPadSlot(slot) == id then
                matches[#matches+1] = {
                    button = button,
                    slot = slot,
                    slotIndex = button:GetID(),
                }
            end
        end

        i = i + 1
    end

    return matches
end

local function NativeMacroIndex(id)
    if not id or not MegaMacroEngine or not MegaMacroEngine.GetMacroIndexFromId then return nil end
    return MegaMacroEngine.GetMacroIndexFromId(id)
end

local function BoundKeys(id)
    local index = NativeMacroIndex(id)
    if not index then return {} end

    local name = GetMacroInfo(index)
    if not name then return {} end

    local action = "MACRO "..name
    local keys = { GetBindingKey(action) }
    local out = {}
    for _,key in ipairs(keys) do
        if key and key ~= "" then out[#out+1] = key end
    end
    return out
end

local function EnsurePulse(button)
    if button.__BPMM74Pulse then return button.__BPMM74Pulse end

    local p=EnsureIconStateTexture(
        button,"__BPMM74Pulse",ICON_STYLE.border,
        C.blue,ICON_STYLE.borderScale,6,"ADD"
    )
    p:Hide()
    return p
end

local function PulseMatches(matches)
    pulseToken = pulseToken + 1
    local token = pulseToken

    for _,entry in ipairs(matches) do
        EnsurePulse(entry.button):Show()
    end

    local count = 0
    local ticker
    ticker = C_Timer.NewTicker(.18, function()
        if token ~= pulseToken then
            if ticker then ticker:Cancel() end
            return
        end

        count = count + 1
        local show = (count % 2 == 1)

        for _,entry in ipairs(matches) do
            local p = EnsurePulse(entry.button)
            p:SetShown(show)
        end

        if count >= 8 then
            if ticker then ticker:Cancel() end
            for _,entry in ipairs(matches) do
                EnsurePulse(entry.button):Hide()
            end
            -- Restore the persistent selection highlight.
            if BPMM71 and BPMM71.RefreshBindPadHighlights then
                BPMM71.RefreshBindPadHighlights()
            end
        end
    end)
end

local function RevealAndPulseMatches(matches)
    if _G.BetterBindController and type(BetterBindController.RevealSlots) == "function" then
        BetterBindController.RevealSlots(matches)
    end
    -- Apply the glow after the deferred ScrollFrame range/position update.
    C_Timer.After(.05,function()
        PulseMatches(matches)
    end)
end

local locate

local function RefreshInspector()
    if not locate then return end

    local matches = VisibleBindPadMatches(selectedId)
    local keys = BoundKeys(selectedId)

    if not selectedId then
        locate:Disable()
        locate:SetAlpha(.45)
        return
    end

    locate:Enable()
    locate:SetAlpha(1)

    locate.__BPMM74Matches = matches
    locate.__BPMM74Keys = keys
end

local function BuildInspector()
    if locate or not MegaMacro_Frame then return end

    locate = CreateFrame("Button","BPMM74LocateButton",MegaMacro_Frame,"BackdropTemplate")
    locate:SetSize(86,26)
    locate:SetPoint("BOTTOMRIGHT",MegaMacro_Frame,"BOTTOMRIGHT",-12,9)
    locate:SetFrameLevel((MegaMacro_Frame:GetFrameLevel() or 1)+25)
    locate:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    locate:SetBackdropColor(unpack(C.bg))
    locate:SetBackdropBorderColor(unpack(C.border))

    local fs=locate:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText("Locate")
    fs:SetTextColor(unpack(C.text))
    locate.Text=fs

    locate:SetScript("OnEnter",function(self)
        self:SetBackdropColor(unpack(C.hover))
        self:SetBackdropBorderColor(unpack(C.blue))

        GameTooltip:SetOwner(self,"ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Locate BetterMacro",1,1,1)

        local matches=self.__BPMM74Matches or {}
        local keys=self.__BPMM74Keys or {}

        if selectedMacro then
            GameTooltip:AddLine(selectedMacro.DisplayName or ("Macro #"..tostring(selectedId)),.75,.85,1)
            GameTooltip:AddLine(" ")
        end

        if #matches==0 then
            GameTooltip:AddLine("Not present in the currently visible BetterBind profile.",.7,.7,.72,true)
        else
            GameTooltip:AddLine(("Visible BetterBind slots: %d"):format(#matches),.55,.80,1)
            for _,entry in ipairs(matches) do
                local name=entry.slot and entry.slot.name or "Macro"
                GameTooltip:AddLine(("Slot %d - %s"):format(entry.slotIndex,name),.82,.82,.85)
            end
        end

        if #keys>0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Direct macro keybinds:",.55,.80,1)
            GameTooltip:AddLine(table.concat(keys,", "),.82,.82,.85)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to reveal matching BetterBind slots.",.45,.75,1,true)
        GameTooltip:Show()
    end)

    locate:SetScript("OnLeave",function(self)
        self:SetBackdropColor(unpack(C.bg))
        self:SetBackdropBorderColor(unpack(C.border))
        GameTooltip:Hide()
    end)

    locate:SetScript("OnClick",function(self)
        if not selectedId then return end

        if BindPadFrame and not BindPadFrame:IsShown() then
            BindPadFrame:Show()
            C_Timer.After(.05,function()
                local matches=VisibleBindPadMatches(selectedId)
                self.__BPMM74Matches=matches
                RevealAndPulseMatches(matches)
                RefreshInspector()
            end)
            return
        end

        local matches=VisibleBindPadMatches(selectedId)
        self.__BPMM74Matches=matches
        RevealAndPulseMatches(matches)
        RefreshInspector()
    end)

    RefreshInspector()
end

local function SetSelected(macro)
    if macro then
        selectedId=macro.Id
        selectedMacro=macro
    else
        selectedId=nil
        selectedMacro=nil
    end
    RefreshInspector()
end

M.SetSelected=SetSelected
M.Refresh=RefreshInspector
M.GetVisibleMatches=function() return VisibleBindPadMatches(selectedId) end

local function InstallHooks()
    if M.hooksInstalled then return end

    if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
        hooksecurefunc("MegaMacro_MacroButton_OnClick",function(button)
            if button and button.Macro then
                SetSelected(button.Macro)
            end
        end)
    end

    if type(_G.BindPadSlot_UpdateState)=="function" then
        hooksecurefunc("BindPadSlot_UpdateState",function()
            if selectedId then
                C_Timer.After(0,RefreshInspector)
            end
        end)
    end

    if BindPadFrame then
        BindPadFrame:HookScript("OnShow",function()
            C_Timer.After(0,RefreshInspector)
        end)
    end

    if MegaMacro_Frame then
        MegaMacro_Frame:HookScript("OnShow",function()
            BuildInspector()
            C_Timer.After(0,RefreshInspector)
        end)
    end

    M.hooksInstalled=true
end

SLASH_BPMMWHERE1="/bbwhere"
SlashCmdList["BPMMWHERE"]=function()
    BuildInspector()
    RefreshInspector()

    if not selectedId then
        print("|cff4da9e8BetterBind|r No BetterMacro selected.")
        return
    end

    local matches=VisibleBindPadMatches(selectedId)
    local keys=BoundKeys(selectedId)

    print(("|cff4da9e8BPMM|r Macro #%d - %s"):format(
        selectedId,
        selectedMacro and selectedMacro.DisplayName or "Unknown"
    ))
    print(("Visible BetterBind slots: %d"):format(#matches))

    for _,entry in ipairs(matches) do
        print(("  Slot %d - %s"):format(
            entry.slotIndex,
            entry.slot and entry.slot.name or "Macro"
        ))
    end

    if #keys>0 then
        print("Direct macro keys: "..table.concat(keys,", "))
    end
end

RegisterEventHandler("PLAYER_LOGIN",function()
    C_Timer.After(.5,function()
        BuildInspector()
        InstallHooks()
    end)
end)
end
end

-- Shared cell styling
do
-- Shared cell styling for BetterBind and BetterMacro.
-- Each cell uses the same Plunderstorm backdrop, Cooldown Manager border and
-- Gear Enchant selected state.  These are texture regions, not square backdrop
-- frames, so every visible layer follows the requested icon silhouette.

local C={
    background={.32,.35,.39,.94},
    backgroundHover={.42,.46,.50,1},
    border={1,1,1,1},
    blue={.050,.565,.905,1},
}
local selectedBindPadCell=nil

local function UpdateCellVisualGeometry(button)
    local visual=button and button.__BetterBindCellVisual
    if not visual then return end
    SizeIconStyleTexture(visual.background,button,ICON_STYLE.backdropScale)
    SizeIconStyleTexture(visual.border,button,ICON_STYLE.borderScale)
    SizeIconStyleTexture(visual.selected,button,ICON_STYLE.stateScale)
end

local function EnsureCellVisual(button)
    if not button then return end
    local visual=button.__BetterBindCellVisual
    if not visual then
        local background=button:CreateTexture(nil,"BACKGROUND",nil,-8)
        background.__BetterBindOwned=true
        SetIconAtlas(background,ICON_STYLE.backdrop)
        background:SetDesaturated(true)

        local border=button:CreateTexture(nil,"OVERLAY",nil,3)
        border.__BetterBindOwned=true
        SetIconAtlas(border,ICON_STYLE.border)
        border:SetDesaturated(false)
        -- The Cooldown Manager atlas contains dark shading intended for
        -- action buttons. ADD keeps its edge detail without laying that shade
        -- over BetterBind's spell artwork.
        border:SetBlendMode("ADD")

        local selected=EnsureIconStateTexture(
            button,"__BetterBindSelectedTexture",ICON_STYLE.selected,
            ICON_STYLE.purple,ICON_STYLE.stateScale,4,"ADD"
        )
        selected:Hide()

        visual={background=background,border=border,selected=selected}
        button.__BetterBindCellVisual=visual
    end
    UpdateCellVisualGeometry(button)
    visual.background:SetAlpha(1)
    visual.border:SetAlpha(1)
    visual.selected:SetAlpha(1)
    visual.background:Show()
    visual.border:Show()
    return visual
end

local function HideNativeCellArtwork(button,icon)
    for _,region in ipairs({button:GetRegions()}) do
        local isFunctionalIcon=region==icon
            or region==button.subIcon
            or region==button.subIcon2
            or region==button.subIcon3
            or region.__BetterBindOwned
        if not isFunctionalIcon and region.GetObjectType
            and region:GetObjectType()=="Texture"
        then
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function RefreshCellVisual(button,isHover)
    local visual=button and button.__BetterBindCellVisual
    if not visual then return end
    visual.background:SetDesaturated(true)
    local icon=button.__BetterBindCellIcon
    local hasIcon=icon and icon:IsShown() and icon:GetTexture()~=nil
    if hasIcon then
        -- Preserve the requested Plunderstorm silhouette very faintly without
        -- tinting or shading populated spell art.
        visual.background:SetVertexColor(1,1,1,isHover and .08 or .02)
    else
        visual.background:SetVertexColor(unpack(isHover and C.backgroundHover or C.background))
    end
    local selected=button.__BetterBindBindPadSlot
        and selectedBindPadCell==button
    if not selected then
        selected=button.__BetterBindCellSelectable
            and button.GetChecked and button:GetChecked()
    end
    local edge=isHover and C.blue
        or button.__BetterBindCellAccent
        or C.border
    visual.border:SetDesaturated(isHover or button.__BetterBindCellAccent~=nil)
    visual.border:SetVertexColor(unpack(edge))
    visual.selected:SetShown(selected and true or false)
end

local function StyleCell(button,icon,isSelectable,accent)
    if not button then return end
    button.__BetterBindCellIcon=icon
    HideNativeCellArtwork(button,icon)
    EnsureCellVisual(button)
    button.__BetterBindCellAccent=accent
    button.__BetterBindCellSelectable=isSelectable and true or false

    if isSelectable then
        local checked=button.GetCheckedTexture and button:GetCheckedTexture()
        local highlight=button.GetHighlightTexture and button:GetHighlightTexture()
        if checked then checked:SetAlpha(0); checked:Hide() end
        if highlight then highlight:SetAlpha(0); highlight:Hide() end
    end

    if not button.__BetterBindCellHooks then
        button.__BetterBindCellHooks=true
        button:HookScript("OnEnter",function(self)
            RefreshCellVisual(self,true)
        end)
        button:HookScript("OnLeave",function(self)
            RefreshCellVisual(self,false)
        end)
        button:HookScript("OnSizeChanged",function(self)
            UpdateCellVisualGeometry(self)
        end)
    end

    RefreshCellVisual(button,false)
end

local function IsCellHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function SelectBindPadCell(button)
    if not button then return end
    local previous=selectedBindPadCell
    selectedBindPadCell=button
    if previous and previous~=button then
        RefreshCellVisual(previous,IsCellHovered(previous))
    end
    RefreshCellVisual(button,IsCellHovered(button))
end

local function ClearBindPadCellSelection()
    local previous=selectedBindPadCell
    selectedBindPadCell=nil
    if previous then
        RefreshCellVisual(previous,IsCellHovered(previous))
    end
end

local function StyleBindPadSlot(button)
    if button and button.border then
        button.border:SetAlpha(0)
        button.border:Hide()
    end
    if button then button.__BetterBindBindPadSlot=true end
    StyleCell(button,button and button.icon,false,nil)
end

local function StyleBetterMacroCell(button)
    StyleCell(button,button and button.Icon,true)
end

_G.BetterBindAppearance_StyleCell=StyleCell
_G.BetterBindAppearance_SelectBindPadCell=SelectBindPadCell
_G.BetterBindAppearance_ClearBindPadCellSelection=ClearBindPadCellSelection

local function RefreshBindPadCells()
    for index=1,250 do
        local button=_G["BindPadSlot"..index]
        if button then StyleBindPadSlot(button) end
    end
end

local function RefreshBetterMacroCells()
    for index=1,(HighestMaxMacroCount or 60) do
        local button=_G["MegaMacro_MacroButton"..index]
        if button then StyleBetterMacroCell(button) end
    end
end

_G.BetterBindAppearance_RefreshBetterMacroCells=RefreshBetterMacroCells

local function RefreshProfileCells()
    for index=1,5 do
        local button=_G["BindPadProfileTab"..index]
        local icon=button and button.GetNormalTexture and button:GetNormalTexture()
        if button and icon then StyleCell(button,icon,true) end
    end
end

local function Refresh()
    RefreshBindPadCells()
    RefreshBetterMacroCells()
    RefreshProfileCells()
end

if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",StyleBindPadSlot)
end
if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
    hooksecurefunc("MegaMacro_MacroButton_OnClick",RefreshBetterMacroCells)
end
if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",RefreshBetterMacroCells)
end
if type(_G.BindPadProfileTab_OnClick)=="function" then
    hooksecurefunc("BindPadProfileTab_OnClick",function()
        ClearBindPadCellSelection()
        RefreshProfileCells()
    end)
end
if type(_G.BindPadFrameTab_OnClick)=="function" then
    hooksecurefunc("BindPadFrameTab_OnClick",ClearBindPadCellSelection)
end
if _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        RefreshBindPadCells()
        RefreshProfileCells()
    end)
end
if _G.MegaMacro_Frame then MegaMacro_Frame:HookScript("OnShow",RefreshBetterMacroCells) end

RegisterEventHandler("PLAYER_LOGIN",function() C_Timer.After(.1,Refresh) end)
end

-- Final window layout
do
-- BindPad + MegaMacro target layout.
-- Matches the approved wide/tall composition while retaining the original
-- buttons, scripts, macro data, key bindings, profiles, and drag behavior.

local Goal={}
_G.BPMMGoalLayout=Goal

local WHITE="Interface\\Buttons\\WHITE8x8"
local WINDOW_ART="Interface\\AddOns\\BetterBind\\UI\\media\\circuit-background.png"
local C={
    shell={.045,.052,.060,.98},
    panel={.052,.060,.070,.90},
    panel2={.070,.080,.092,.94},
    border={.18,.21,.25,1},
    muted={.62,.64,.68,1},
    text={.93,.94,.96,1},
    yellow={1,.82,.02,1},
    blue={.02,.58,.94,1},
    purple={.56,.32,1,1},
    red={.42,.02,.02,1},
}
local CONTROL_HOVER={.085,.095,.108,.96}
local CONTROL_HOVER_EDGE={.28,.34,.40,1}
local CONTROL_HOVER_ACCENT={.18,.72,.72,1}

local BP_W,BP_H=532,696
local MM_W,MM_H=722,696
local BP_ICON,BP_GAP,BP_COLS,BP_ROWS=50,11,8,7
local BP_GRID_H=BP_ROWS*BP_ICON+(BP_ROWS-1)*BP_GAP
local MM_ICON,MM_X_GAP,MM_COLS,MM_ROWS=50,7,12,4
local SLOT_CONTROL_SIZE=36
local SLOT_CONTROL_GLYPH=22
local SLOT_CONTROL_THICKNESS=5
local CHECK_SIZE=20
local StyleGoalButton

local function GetAppearance(group,defaultSpacing)
    if _G.BetterBindAppearance_Get then
        return _G.BetterBindAppearance_Get(group)
    end
    return {spacing=defaultSpacing or 0}
end

local function UpdateIconGeometry(owner,icon)
    if not owner or not icon then return end
    local width,height=owner:GetSize()
    if not width or width<=0 then return end
    if not height or height<=0 then height=width end

    icon:ClearAllPoints()
    icon:SetPoint("CENTER",owner,"CENTER",0,0)
    icon:SetSize(width,height)
    icon:SetScale(ICON_STYLE.iconScale)

    local mask=icon.__BetterBindAppearanceMask
    if mask then
        mask:ClearAllPoints()
        mask:SetPoint("CENTER",owner,"CENTER",0,0)
        mask:SetSize(width*ICON_STYLE.maskScale,height*ICON_STYLE.maskScale)
    end
end

local function ApplyIconAppearance(owner,icon,group)
    if not owner or not icon then return end
    icon:SetTexCoord(0,1,0,1)

    local mask=icon.__BetterBindAppearanceMask
    if not mask and owner.CreateMaskTexture and icon.AddMaskTexture then
        -- MaskTextures belong to the icon's owning frame. Creating one from
        -- the Texture silently skipped the crop, leaving the enlarged square
        -- visible around the shaped backdrop and selection state.
        mask=owner:CreateMaskTexture()
        mask:SetTexture(ICON_STYLE.mask,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        if mask.SetHorizTile then mask:SetHorizTile(false) end
        if mask.SetVertTile then mask:SetVertTile(false) end
        mask:SetTexCoord(0,1,0,1)
        icon.__BetterBindAppearanceMask=mask
        pcall(icon.AddMaskTexture,icon,mask)
    end
    if mask then mask:Show() end

    owner.__BetterBindAppearanceIcon=icon
    if owner.HookScript and not owner.__BetterBindAppearanceSizeHook then
        owner.__BetterBindAppearanceSizeHook=true
        owner:HookScript("OnSizeChanged",function(self)
            UpdateIconGeometry(self,self.__BetterBindAppearanceIcon)
        end)
    end
    UpdateIconGeometry(owner,icon)
end

_G.BetterBindAppearance_ApplyTexture=ApplyIconAppearance

local function SetFontSize(region,size,flags)
    if not region or not region.GetFont or not region.SetFont then return end
    local path,_,oldFlags=region:GetFont()
    if path then region:SetFont(path,size,flags or oldFlags) end
end

local function StyleIconName(region)
    if not region then return end
    region:SetTextColor(1,1,1,1)
    region:SetAlpha(1)
    if region.SetShadowColor then region:SetShadowColor(0,0,0,1) end
    if region.SetShadowOffset then region:SetShadowOffset(0,0) end
    -- A zero-offset shadow sits directly beneath the foreground fill. The
    -- thin outline exposes that dark edge without moving it away from 0,0.
    SetFontSize(region,10,"OUTLINE")
end

local function Backdrop(frame,bg,border)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile=WHITE,
        edgeFile=WHITE,
        edgeSize=1,
    })
    frame:SetBackdropColor(unpack(bg or C.panel))
    frame:SetBackdropBorderColor(unpack(border or C.border))
end

local function EnsurePanel(parent,key)
    if not parent then return end
    local panel=parent[key]
    if not panel then
        panel=CreateFrame("Frame",nil,parent,"BackdropTemplate")
        panel:EnableMouse(false)
        if panel.SetMouseClickEnabled then panel:SetMouseClickEnabled(false) end
        if panel.SetMouseMotionEnabled then panel:SetMouseMotionEnabled(false) end
        parent[key]=panel
    end
    Backdrop(panel,C.panel,C.border)
    return panel
end

local function EnsurePatternTexture(owner,key,left,right,alpha,top,bottom)
    if not owner then return end
    local texture=owner[key]
    if not texture then
        texture=owner:CreateTexture(nil,"ARTWORK",nil,-8)
        texture.__BetterBindOwned=true
        texture:SetTexture(WINDOW_ART,"CLAMP","CLAMP")
        owner[key]=texture
    end
    texture:SetDrawLayer("ARTWORK",-8)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT",owner,"TOPLEFT",1,-1)
    texture:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT",-1,1)
    texture:SetTexCoord(left or 0,right or 1,top or 0,bottom or 1)
    texture:SetVertexColor(1,1,1,alpha or .80)
    texture:Show()
    return texture
end

_G.BetterBindAppearance_ApplyWindowPattern=EnsurePatternTexture

local function EnsureWindowShell(frame,left,right,top,bottom)
    local shell=EnsurePanel(frame,"__BetterBindShell")
    if not shell then return end
    shell:ClearAllPoints()
    shell:SetAllPoints(frame)
    shell:SetFrameLevel(math.max(0,(frame:GetFrameLevel() or 1)-4))
    Backdrop(shell,C.shell,C.border)
    EnsurePatternTexture(shell,"__BetterBindCircuit",left,right,.70,top,bottom)
    shell:Show()
    return shell
end

local function SetTabLayout(frame,prefix,count,startX,widths)
    local previous
    for i=1,count do
        local tab=_G[prefix..i]
        if tab then
            tab:ClearAllPoints()
            tab:SetSize(widths[i] or widths[1],40)
            if previous then
                tab:SetPoint("TOPLEFT",previous,"TOPRIGHT",0,0)
            else
                tab:SetPoint("TOPLEFT",frame,"TOPLEFT",startX,-40)
            end
            local fs=tab.GetFontString and tab:GetFontString()
            if fs then
                fs:Show()
                fs:SetAlpha(1)
                fs:SetTextColor(unpack(C.text))
                SetFontSize(fs,11)
            end
            previous=tab
        end
    end
end

local function CursorIsInHeader(frame)
    if not frame or not frame:IsMouseOver() then return false end
    local _,cursorY=GetCursorPosition()
    local scale=frame:GetEffectiveScale() or 1
    local top=frame:GetTop()
    if not cursorY or not top then return false end
    cursorY=cursorY/scale
    return cursorY<=top and cursorY>=top-38
end

local function InstallBindPadDrag(frame)
    if not frame or frame.__BetterBindDragInstalled then return end
    frame.__BetterBindDragInstalled=true
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)
        if InCombatLockdown() or not CursorIsInHeader(self) then return end
        self.__BetterBindDragging=true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop",function(self)
        if not self.__BetterBindDragging then return end
        self.__BetterBindDragging=nil
        self:StopMovingOrSizing()
        if type(_G.BPMM_SaveWindowPoint)=="function" then
            _G.BPMM_SaveWindowPoint(self,"BindPad")
        end
    end)
end

local function HideObject(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.EnableMouse then object:EnableMouse(false) end
    if object.Hide then object:Hide() end
    if object.HookScript and not object.__BetterBindKeepHidden then
        object.__BetterBindKeepHidden=true
        object:HookScript("OnShow",function(self)
            self:SetAlpha(0)
            if self.EnableMouse then self:EnableMouse(false) end
            self:Hide()
        end)
    end
end

-- Scrolling remains on the ScrollFrame itself.  Only the visual controllers
-- (native bars, arrows, old custom thumbs, and the GoalLayout track) are hidden.
local function HideScrollBar(scrollFrame)
    if not scrollFrame then return end
    local name=scrollFrame.GetName and scrollFrame:GetName()
    local bar=scrollFrame.ScrollBar or (name and _G[name.."ScrollBar"])

    HideObject(bar)
    if bar then
        HideObject(bar.Back)
        HideObject(bar.Forward)
        HideObject(bar.Track)
        HideObject(bar.ScrollUpButton)
        HideObject(bar.ScrollDownButton)
    end

    if name then
        for _,suffix in ipairs({
            "ScrollBar","ScrollBarScrollUpButton","ScrollBarScrollDownButton",
            "Top","Bottom","Middle",
        }) do
            HideObject(_G[name..suffix])
        end
    end

end

local function HideTextureRegions(frame)
    if not frame or not frame.GetRegions then return end
    for _,region in ipairs({frame:GetRegions()}) do
        if region and not region.__BetterBindOwned and region.GetObjectType
            and region:GetObjectType()=="Texture"
        then
            HideObject(region)
        end
    end
end

local function StyleTabSelection(frame,prefix,count,selectedIndex)
    if not frame then return end
    selectedIndex=tonumber(selectedIndex) or 1

    for i=1,count do
        local tab=_G[prefix..i]
        if tab then
            local surface=tab.__BetterBindTabSurface
            for _,region in ipairs({tab:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType()=="Texture" then
                    HideObject(region)
                end
            end

            if not surface then
                surface=CreateFrame("Frame",nil,tab,"BackdropTemplate")
                surface:SetPoint("TOPLEFT",tab,"TOPLEFT",1,-1)
                surface:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-1,1)
                surface:SetFrameLevel(math.max(0,(tab:GetFrameLevel() or 1)-1))
                surface:EnableMouse(false)
                surface:SetBackdrop({
                    bgFile=WHITE,
                    edgeFile=WHITE,
                    edgeSize=1,
                })
                tab.__BetterBindTabSurface=surface

                local underline=surface:CreateTexture(nil,"OVERLAY",nil,7)
                underline:SetPoint("BOTTOMLEFT",surface,"BOTTOMLEFT",0,0)
                underline:SetPoint("BOTTOMRIGHT",surface,"BOTTOMRIGHT",0,0)
                underline:SetHeight(1)
                surface.underline=underline

                tab:HookScript("OnEnter",function(self)
                    self.__BetterBindTabHovered=true
                    local item=self.__BetterBindTabSurface
                    if item and not self.__BetterBindTabSelected then
                        item:SetBackdropColor(unpack(CONTROL_HOVER))
                        item:SetBackdropBorderColor(unpack(CONTROL_HOVER_EDGE))
                        item.underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
                        item.underline:Show()
                        local text=self.GetFontString and self:GetFontString()
                        if text then text:SetTextColor(unpack(C.text)) end
                    end
                end)
                tab:HookScript("OnLeave",function(self)
                    self.__BetterBindTabHovered=false
                    local item=self.__BetterBindTabSurface
                    if item and not self.__BetterBindTabSelected then
                        item:SetBackdropColor(unpack(C.panel2))
                        item:SetBackdropBorderColor(unpack(C.border))
                        item.underline:Hide()
                        local text=self.GetFontString and self:GetFontString()
                        if text then text:SetTextColor(unpack(C.muted)) end
                    end
                end)
            end

            local selected=i==selectedIndex
            tab.__BetterBindTabSelected=selected
            surface:SetBackdropColor(
                selected and .080 or C.panel2[1],
                selected and .065 or C.panel2[2],
                selected and .115 or C.panel2[3],
                selected and .98 or C.panel2[4]
            )
            surface:SetBackdropBorderColor(unpack(selected and C.purple or C.border))
            surface.underline:SetColorTexture(unpack(C.purple))
            surface.underline:SetShown(selected)
            surface:Show()
            local fs=tab.GetFontString and tab:GetFontString()
            if fs then
                fs:SetTextColor(unpack(selected and C.text or C.muted))
            end
            if tab.UnlockHighlight then tab:UnlockHighlight() end
        end
    end
end

local function StripInsetArtwork(inset)
    if not inset then return end
    HideTextureRegions(inset)
    HideObject(inset.Bg)
    HideObject(inset.Background)
    HideObject(inset.Border)
    HideObject(inset.NineSlice)
end

local function HideLegacyBorders()
    local bind=_G.BindPadFrame
    local mega=_G.MegaMacro_Frame

    for _,frame in pairs({bind,mega}) do
        if frame then
            HideTextureRegions(frame)
            HideObject(frame.Bg)
            HideObject(frame.TopTileStreaks)
            HideObject(frame.NineSlice)
            HideObject(frame.PortraitContainer)
            HideObject(frame.Border)
            local name=frame.GetName and frame:GetName()
            if name then
                for _,suffix in ipairs({
                    "Bg","Background","TopLeftCorner","TopRightCorner",
                    "BottomLeftCorner","BottomRightCorner","TopBorder",
                    "BottomBorder","LeftBorder","RightBorder","TitleBg",
                }) do
                    HideObject(_G[name..suffix])
                end
                StripInsetArtwork(_G[name.."Inset"])
            end
            StripInsetArtwork(frame.Inset)
        end
    end

    local bindScroll=_G.BindPadScrollFrame
    local macroGrid=_G.MegaMacro_ButtonScrollFrame
    local macroEditor=_G.MegaMacro_FrameScrollFrame
    local formattedEditor=_G.MegaMacro_FormattedFrameScrollFrame
    for _,scroll in pairs({bindScroll,macroGrid,macroEditor,formattedEditor}) do
        HideScrollBar(scroll)
    end
    HideObject(_G.MacroFrameTextBackground)
    HideObject(_G.MacroFramePortrait)
end

local function StyleSlotControl(button,glyph)
    if not button then return end

    for _,texture in pairs({
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
    }) do
        HideObject(texture)
    end

    local bg=button.__BPMMGoalSlotControlBG
    if not bg then
        bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,button:GetFrameLevel()-1))
        bg:EnableMouse(false)
        button.__BPMMGoalSlotControlBG=bg
    end
    Backdrop(bg,C.panel2,C.border)

    local underline=button.__BPMMGoalSlotControlUnderline
    if not underline then
        underline=button:CreateTexture(nil,"OVERLAY",nil,7)
        underline:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1)
        underline:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
        underline:SetHeight(1)
        underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
        underline:Hide()
        button.__BPMMGoalSlotControlUnderline=underline
    end

    local horizontal=button.__BPMMGoalSlotControlHorizontal
    if not horizontal then
        horizontal=button:CreateTexture(nil,"OVERLAY",nil,7)
        horizontal:SetColorTexture(unpack(C.text))
        button.__BPMMGoalSlotControlHorizontal=horizontal
    end
    horizontal:ClearAllPoints()
    horizontal:SetPoint("CENTER",button,"CENTER",0,0)
    horizontal:SetSize(SLOT_CONTROL_GLYPH,SLOT_CONTROL_THICKNESS)
    horizontal:SetAlpha(1)
    horizontal:Show()

    local vertical=button.__BPMMGoalSlotControlVertical
    if not vertical then
        vertical=button:CreateTexture(nil,"OVERLAY",nil,7)
        vertical:SetColorTexture(unpack(C.text))
        button.__BPMMGoalSlotControlVertical=vertical
    end
    vertical:ClearAllPoints()
    vertical:SetPoint("CENTER",button,"CENTER",0,0)
    vertical:SetSize(SLOT_CONTROL_THICKNESS,SLOT_CONTROL_GLYPH)
    vertical:SetAlpha(1)
    vertical:SetShown(glyph=="+")
    button:SetAlpha(1)

    if not button.__BPMMGoalSlotControlHooks then
        button.__BPMMGoalSlotControlHooks=true
        button:HookScript("OnEnter",function(self)
            if self:IsEnabled() then
                self.__BPMMGoalSlotControlBG:SetBackdropColor(unpack(CONTROL_HOVER))
                self.__BPMMGoalSlotControlBG:SetBackdropBorderColor(unpack(CONTROL_HOVER_EDGE))
                self.__BPMMGoalSlotControlUnderline:Show()
            end
        end)
        button:HookScript("OnLeave",function(self)
            self.__BPMMGoalSlotControlBG:SetBackdropColor(unpack(C.panel2))
            self.__BPMMGoalSlotControlBG:SetBackdropBorderColor(unpack(C.border))
            self.__BPMMGoalSlotControlUnderline:Hide()
        end)
    end
end

local function StyleUtilityToggle(button)
    if not button then return end
    button:SetSize(CHECK_SIZE,CHECK_SIZE)

    local customMark=button.__BPMMGoalUtilityMark
    for _,region in ipairs({button:GetRegions()}) do
        if region~=customMark and region.GetObjectType
            and region:GetObjectType()=="Texture"
        then
            if region.SetTexture then region:SetTexture(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
    for _,texture in pairs({
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
        button.GetCheckedTexture and button:GetCheckedTexture(),
        button.GetDisabledCheckedTexture and button:GetDisabledCheckedTexture(),
    }) do
        if texture and texture~=customMark then
            if texture.SetTexture then texture:SetTexture(nil) end
            texture:SetAlpha(0)
            texture:Hide()
        end
    end

    local bg=button.__BPMMGoalUtilityBG
    if not bg then
        bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,button:GetFrameLevel()-1))
        bg:EnableMouse(false)
        button.__BPMMGoalUtilityBG=bg
    end
    Backdrop(bg,C.panel2,C.border)

    if not customMark then
        customMark=button:CreateTexture(nil,"OVERLAY",nil,7)
        button.__BPMMGoalUtilityMark=customMark
    end
    customMark:SetTexture(WHITE)
    customMark:ClearAllPoints()
    customMark:SetPoint("TOPLEFT",button,"TOPLEFT",4,-4)
    customMark:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-4,4)
    customMark:SetDesaturated(false)
    customMark:SetVertexColor(unpack(C.blue))
    customMark:SetBlendMode("BLEND")

    local function Refresh(self)
        self.__BPMMGoalUtilityMark:SetShown(self:GetChecked() and true or false)
        self.__BPMMGoalUtilityBG:SetBackdropColor(unpack(C.panel2))
        self.__BPMMGoalUtilityBG:SetBackdropBorderColor(unpack(C.border))
    end
    Refresh(button)
    button:SetAlpha(1)

    if not button.__BPMMGoalUtilityHooks then
        button.__BPMMGoalUtilityHooks=true
        button:HookScript("OnClick",Refresh)
        button:HookScript("OnShow",Refresh)
        button:HookScript("OnEnter",function(self)
            self.__BPMMGoalUtilityBG:SetBackdropColor(.085,.095,.108,.96)
            self.__BPMMGoalUtilityBG:SetBackdropBorderColor(.28,.34,.40,1)
        end)
        button:HookScript("OnLeave",Refresh)
    end
end

local PROFILE_NUMERALS={"I","II","III","IV","V"}

local function RefreshCurrentProfileLabel(button)
    local label=button.__BPMMGoalCurrentLabel
    if label then
        label:SetShown(button:IsShown()
            and BindPadCore.GetCurrentProfileNum()==button:GetID())
    end
end

if type(_G.BindPadProfileTab_OnShow)=="function" then
    hooksecurefunc("BindPadProfileTab_OnShow",RefreshCurrentProfileLabel)
end

local function EnsureProfileLabel(panel,button,index)
    local label=button.__BPMMGoalLabel
    if not label then
        label=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        button.__BPMMGoalLabel=label
    end
    label:SetText(PROFILE_NUMERALS[index])
    label:SetTextColor(unpack(C.text))
    label:SetWidth(46)
    label:SetJustifyH("CENTER")
    SetFontSize(label,9)
    label:Show()
    return label
end

local function LayoutBindPadGrid()
    local frame=_G.BindPadFrame
    local scroll=_G.BindPadScrollFrame
    local container=_G.BindPadSlotButtonContainer
    if not frame or not scroll or not container then return end

    BindPadVars=BindPadVars or {}
    BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
    BindPadVars.BPMMSettings.bindPadIconSize=BP_ICON
    local appearance=GetAppearance("bindpad",BP_GAP)
    local spacing=appearance.spacing
    local step=BP_ICON+spacing
    local gridWidth=BP_COLS*BP_ICON+(BP_COLS-1)*spacing
    BindPadVars.BPMMSettings.bindPadIconSpacing=spacing
    BindPadVars.BPMMSettings.bindPadColumns=BP_COLS

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-84)
    scroll:SetSize(BP_W-16,BP_GRID_H+20)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end

    container:SetScale(1)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)

    local count=tonumber(_G.BindPadCore and BindPadCore.useBindPadSlot) or 0
    if count<1 then
        for i=1,250 do
            local button=_G["BindPadSlot"..i]
            if not button or not button:IsShown() then break end
            count=i
        end
    end

    for i=1,count do
        local button=_G["BindPadSlot"..i]
        if not button then break end
        local col=(i-1)%BP_COLS
        local row=math.floor((i-1)/BP_COLS)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",container,"TOPLEFT",
            math.floor(((BP_W-16)-gridWidth)/2)+col*step,
            -14-row*step
        )
        button:SetSize(BP_ICON,BP_ICON)

        if button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetAllPoints(button)
            ApplyIconAppearance(button,button.icon,"bindpad")
        end
        if button.name then
            button.name:SetWidth(BP_ICON-2)
            button.name:SetDrawLayer("OVERLAY",7)
            StyleIconName(button.name)
        end
        if button.hotkey then
            button.hotkey:SetWidth(BP_ICON-2)
            button.hotkey:SetDrawLayer("OVERLAY",7)
            SetFontSize(button.hotkey,9,"OUTLINE")
        end
    end

    local totalRows=math.max(BP_ROWS,math.ceil(math.max(1,count)/BP_COLS))
    container:SetSize(BP_W-16,totalRows*BP_ICON+math.max(0,totalRows-1)*spacing+20)

    local range=scroll:GetVerticalScrollRange() or 0
    local current=scroll:GetVerticalScroll() or 0
    local snapped=math.floor((current/step)+.5)*step
    scroll:SetVerticalScroll(math.max(0,math.min(range,snapped)))
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(self,delta)
        local maxScroll=self:GetVerticalScrollRange() or 0
        local value=self:GetVerticalScroll() or 0
        value=value+(delta<0 and step or -step)
        self:SetVerticalScroll(math.max(0,math.min(maxScroll,value)))
    end)
    HideScrollBar(scroll)
end

local function LayoutBindPadLower()
    local frame=_G.BindPadFrame
    if not frame then return end

    local panel=EnsurePanel(frame,"__BetterBindProfilesPanel")
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,66)
    panel:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,66)
    panel:SetHeight(110)
    panel:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    Backdrop(panel,C.panel,C.border)

    local title=panel.__BPMMGoalTitle
    if not title then
        title=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        panel.__BPMMGoalTitle=title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT",panel,"TOPLEFT",10,-14)
    title:SetText("Specialization Profiles")
    title:SetTextColor(unpack(C.text))
    SetFontSize(title,14)
    title:Show()

    local showProfiles=not BindPadVars.BPMMSettings
        or BindPadVars.BPMMSettings.showProfileRow~=false
    local profileAppearance=GetAppearance("profiles",12)
    local profileStep=38+profileAppearance.spacing+5
    for i=1,5 do
        local button=_G["BindPadProfileTab"..i]
        if button then
            button:SetShown(showProfiles)
            button:SetSize(38,38)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",panel,"TOPLEFT",10+(i-1)*profileStep,-50)
            local oldBG=_G["BindPadProfileTab"..i.."Background"]
            if oldBG then oldBG:SetAlpha(0) end
            if showProfiles and BindPadProfileTab_OnShow then
                BindPadProfileTab_OnShow(button)
            end
            local profileIcon=button.GetNormalTexture and button:GetNormalTexture()
            if profileIcon then
                profileIcon:ClearAllPoints()
                profileIcon:SetAllPoints(button)
                ApplyIconAppearance(button,profileIcon,"profiles")
                if _G.BetterBindAppearance_StyleCell then
                    BetterBindAppearance_StyleCell(button,profileIcon,true)
                end
            end
            for _,subIcon in ipairs({button.subIcon,button.subIcon2,button.subIcon3}) do
                if subIcon then subIcon:SetDrawLayer("OVERLAY",7) end
            end
            local label=EnsureProfileLabel(panel,button,i)
            label:ClearAllPoints()
            label:SetPoint("BOTTOM",button,"TOP",0,3)
            label:SetShown(showProfiles)

            local current=button.__BPMMGoalCurrentLabel
            if not current then
                current=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                button.__BPMMGoalCurrentLabel=current
            end
            current:SetText("Current")
            current:SetTextColor(unpack(C.text))
            current:SetWidth(46)
            current:SetJustifyH("CENTER")
            SetFontSize(current,9)
            current:ClearAllPoints()
            current:SetPoint("TOP",button,"BOTTOM",0,-3)
            RefreshCurrentProfileLabel(button)
        end
    end

    local less=_G.BindPadShowLessSlotButton
    local more=_G.BindPadShowMoreSlotButton
    if less then
        less:SetParent(panel)
        less:SetSize(SLOT_CONTROL_SIZE,SLOT_CONTROL_SIZE)
        less:ClearAllPoints()
        less:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-50,-8)
        less:SetFrameLevel(panel:GetFrameLevel()+5)
        StyleSlotControl(less,"-")
    end
    if more then
        more:SetParent(panel)
        more:SetSize(SLOT_CONTROL_SIZE,SLOT_CONTROL_SIZE)
        more:ClearAllPoints()
        more:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-8,-8)
        more:SetFrameLevel(panel:GetFrameLevel()+5)
        StyleSlotControl(more,"+")
    end

    local oldFooter=_G.BindPadScrollFrameFooter
    if oldFooter then oldFooter:Hide(); oldFooter:SetHeight(0) end
    if _G.BindPadScrollFrameNumber then
        BindPadScrollFrameNumber:Hide()
        BindPadScrollFrameNumber:SetAlpha(0)
    end

    local footer=EnsurePanel(frame,"__BPMMGoalFooter")
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,1)
    footer:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)
    footer:SetHeight(65)
    footer:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))

    local delete=_G.BetterBind_DeleteButton
    if not delete then
        delete=CreateFrame("Button","BetterBind_DeleteButton",frame,"UIPanelButtonTemplate")
        delete:SetScript("OnClick",function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if _G.BetterBindController
                and type(BetterBindController.RequestDeleteSelectedSlot)=="function"
            then
                BetterBindController.RequestDeleteSelectedSlot()
            end
        end)
        delete:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(
                "Delete the selected BetterBind icon and remove its key binding.",
                nil,nil,nil,nil,true
            )
            GameTooltip:Show()
        end)
        delete:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    delete:SetParent(frame)
    delete:SetSize(84,32)
    delete:ClearAllPoints()
    delete:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",12,8)
    delete:SetFrameLevel(footer:GetFrameLevel()+5)
    StyleGoalButton(delete,"Delete",true)
    if _G.BetterBindController
        and type(BetterBindController.UpdateDeleteButton)=="function"
    then
        BetterBindController.UpdateDeleteButton()
    else
        delete:Disable()
    end

    local utilities={
        _G.BindPadFrameOpenSpellBookButton,
        _G.BindPadFrameOpenMacroButton,
        _G.BindPadFrameOpenBagButton,
    }
    for _,button in ipairs(utilities) do
        HideObject(button)
    end

    local function check(button,x,width)
        if not button then return end
        button:SetSize(CHECK_SIZE,CHECK_SIZE)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT",footer,"BOTTOMLEFT",x,22)
        button:SetHitRectInsets(0,-width,0,0)
        button:SetFrameLevel(footer:GetFrameLevel()+5)
        StyleUtilityToggle(button)
        local label=_G[(button:GetName() or "").."Text"]
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT",button,"RIGHT",7,0)
            label:SetWidth(width)
            label:SetJustifyH("LEFT")
            label:SetTextColor(unpack(C.text))
            SetFontSize(label,11)
        end
    end
    check(_G.BindPadFrameSaveAllKeysButton,112,118)
    check(_G.BindPadFrameShowHotkeyButton,300,118)
    if _G.BindPadFrameCharacterButton then BindPadFrameCharacterButton:Hide() end
end

local function LayoutBindPad()
    local frame=_G.BindPadFrame
    if not frame then return end
    frame:SetSize(BP_W,BP_H)
    EnsureWindowShell(frame,0,1,.173,.827)
    InstallBindPadDrag(frame)
    SetTabLayout(frame,"BindPadFrameTab",5,1,{106,106,106,106,106})
    local selected=(_G.BindPadVars and BindPadVars.tab)
        or (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(frame)) or 1
    StyleTabSelection(frame,"BindPadFrameTab",5,selected)
    LayoutBindPadGrid()
    LayoutBindPadLower()
end

local function EnsureMegaMacroSlotControls()
    local frame=_G.MegaMacro_Frame
    if not frame then return end

    local function ensure(name,glyph,direction,tooltip)
        local button=_G[name]
        if not button then
            button=CreateFrame("Button",name,frame)
            button:SetScript("OnClick",function()
                if _G.BetterMacro_AdjustVisibleSlots then
                    _G.BetterMacro_AdjustVisibleSlots(direction)
                end
            end)
            button:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip,nil,nil,nil,nil,true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        button:SetParent(frame)
        button:SetSize(SLOT_CONTROL_SIZE,SLOT_CONTROL_SIZE)
        button:ClearAllPoints()
        button:SetFrameLevel(frame:GetFrameLevel()+20)
        StyleSlotControl(button,glyph)
        return button
    end

    local less=ensure("BetterMacroShowLessSlotButton","-",-1,"Show 48 fewer macro slots")
    local more=ensure("BetterMacroShowMoreSlotButton","+",1,"Show 48 more macro slots")
    less:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-50,-342)
    more:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-8,-342)

    local selected=_G.BetterMacro_GetSelectedTabIndex and _G.BetterMacro_GetSelectedTabIndex() or 1
    local visible=_G.BetterMacro_GetVisibleSlotCount and _G.BetterMacro_GetVisibleSlotCount() or 48
    local minVisible,maxVisible=48,48
    if _G.BetterMacro_GetVisibleSlotBounds then
        minVisible,maxVisible=_G.BetterMacro_GetVisibleSlotBounds()
    end
    local show=selected~=6 and maxVisible>0
    less:SetShown(show)
    more:SetShown(show)
    if show and visible>minVisible then less:Enable() else less:Disable() end
    if show and visible<maxVisible then more:Enable() else more:Disable() end
    StyleSlotControl(less,"-")
    StyleSlotControl(more,"+")
end

local function LayoutMegaMacroGrid()
    local frame=_G.MegaMacro_Frame
    local scroll=_G.MegaMacro_ButtonScrollFrame
    local container=_G.MegaMacro_ButtonContainer
    if not frame or not scroll or not container then return end

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-84)
    scroll:SetSize(MM_W-18,252)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end

    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)

    local appearance=GetAppearance("bettermacro",MM_X_GAP)
    local spacing=appearance.spacing
    local step=MM_ICON+spacing
    local gridWidth=MM_COLS*MM_ICON+(MM_COLS-1)*spacing
    local count=_G.BetterMacro_GetVisibleSlotCount and _G.BetterMacro_GetVisibleSlotCount() or 48
    local frameCount=HighestMaxMacroCount or count
    for i=1,frameCount do
        local button=_G["MegaMacro_MacroButton"..i]
        if button then
            local col=(i-1)%MM_COLS
            local row=math.floor((i-1)/MM_COLS)
            button:SetSize(MM_ICON,MM_ICON)
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",container,"TOPLEFT",
                math.floor(((MM_W-18)-gridWidth)/2)+col*step,
                -14-row*step
            )
            if button.Icon then
                button.Icon:ClearAllPoints()
                button.Icon:SetAllPoints(button)
                ApplyIconAppearance(button,button.Icon,"bettermacro")
                if _G.BetterBindAppearance_StyleCell then
                    _G.BetterBindAppearance_StyleCell(button,button.Icon,true)
                end
            end
            if button.Name then
                button.Name:SetWidth(MM_ICON-2)
                button.Name:SetDrawLayer("OVERLAY",7)
                StyleIconName(button.Name)
            end
        end
    end
    local rows=math.max(MM_ROWS,math.ceil(count/MM_COLS))
    container:SetSize(MM_W-18,rows*MM_ICON+math.max(0,rows-1)*spacing+16)
    local range=scroll:GetVerticalScrollRange() or 0
    scroll:SetVerticalScroll(math.max(0,math.min(range,scroll:GetVerticalScroll() or 0)))
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(self,delta)
        local maxScroll=self:GetVerticalScrollRange() or 0
        local value=self:GetVerticalScroll() or 0
        value=value+(delta<0 and step or -step)
        self:SetVerticalScroll(math.max(0,math.min(maxScroll,value)))
    end)
    HideScrollBar(scroll)
    EnsureMegaMacroSlotControls()
end

StyleGoalButton=function(button,text,danger)
    if not button then return end

    -- Locate is a custom Button with its own FontString while the other
    -- controls inherit a normal button label.  Always reuse the existing
    -- label so styling and pressed offsets cannot leave duplicate text behind.
    local label=button.Text
    if not (label and label.GetObjectType and label:GetObjectType()=="FontString") then
        label=button.GetFontString and button:GetFontString()
    end
    if text then
        if label and label.SetText then label:SetText(text)
        elseif button.SetText then button:SetText(text) end
    end

    local function ApplyFont()
        if button.SetNormalFontObject then button:SetNormalFontObject("GameFontHighlight") end
        if button.SetDisabledFontObject then button:SetDisabledFontObject("GameFontHighlight") end
        local fs=label or (button.GetFontString and button:GetFontString())
        if fs then
            fs:SetTextColor(1,1,1,1)
            fs:SetAlpha(1)
            SetFontSize(fs,12)
        elseif button.Text then
            button.Text:SetTextColor(1,1,1,1)
            button.Text:SetAlpha(1)
            SetFontSize(button.Text,12)
        end
    end

    local function StripNativeArtwork()
        for _,region in ipairs({button:GetRegions()}) do
            if region~=button.__BPMMGoalFill
                and region and region.GetObjectType and region:GetObjectType()=="Texture"
            then
                if region.SetTexture then region:SetTexture(nil) end
                region:SetAlpha(0)
                region:Hide()
            end
        end
        for _,key in ipairs({
            "Left","Middle","Right","LeftDisabled","MiddleDisabled",
            "RightDisabled","NineSlice","Border",
        }) do
            local artwork=button[key]
            if artwork then HideObject(artwork) end
        end
        if button.SetBackdrop then button:SetBackdrop(nil) end
    end
    StripNativeArtwork()

    local goalFill=button.__BPMMGoalFill
    if not goalFill then
        goalFill=button:CreateTexture(nil,"BACKGROUND",nil,-8)
        goalFill:SetAllPoints()
        button.__BPMMGoalFill=goalFill
    end

    -- Keep a dedicated one-pixel border above inherited button artwork.  The
    -- Edit button's native template can otherwise erase the background-frame
    -- edge while the button remains enabled.
    local border=button.__BPMMGoalBorder
    if not border then
        border=CreateFrame("Frame",nil,button,"BackdropTemplate")
        border:SetAllPoints()
        border:SetFrameLevel(button:GetFrameLevel()+1)
        border:EnableMouse(false)
        border:SetBackdrop({edgeFile=WHITE,edgeSize=1})
        button.__BPMMGoalBorder=border
    end

    local underline=button.__BPMMGoalUnderline
    if not underline then
        underline=button:CreateTexture(nil,"OVERLAY",nil,7)
        underline:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1)
        underline:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
        underline:SetHeight(1)
        underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
        underline:Hide()
        button.__BPMMGoalUnderline=underline
    end

    local function ApplyColors(isHover)
        local fill=danger and C.red or (isHover and CONTROL_HOVER or C.panel2)
        local edge=isHover and CONTROL_HOVER_EDGE or (danger and {.68,.12,.10,1} or C.border)
        goalFill:SetColorTexture(unpack(fill))
        goalFill:SetAlpha(1)
        goalFill:Show()
        border:SetBackdropBorderColor(unpack(edge))
        underline:SetShown(isHover and true or false)
    end
    ApplyColors(false)
    button:Show()
    button:SetAlpha(1)
    if button.EnableMouse then button:EnableMouse(true) end
    ApplyFont()
    if not button.__BPMMGoalHoverHook then
        button.__BPMMGoalHoverHook=true
        button:HookScript("OnEnter",function(self)
            if self:IsEnabled() then ApplyColors(true) end
        end)
        button:HookScript("OnLeave",function()
            if label then
                label:ClearAllPoints()
                label:SetPoint("CENTER",button,"CENTER",0,0)
            end
            ApplyColors(false)
        end)
        button:HookScript("OnMouseDown",function(self,mouseButton)
            if mouseButton=="LeftButton" and self:IsEnabled() and label then
                label:ClearAllPoints()
                label:SetPoint("CENTER",self,"CENTER",1,-1)
            end
        end)
        button:HookScript("OnMouseUp",function(self)
            if label then
                label:ClearAllPoints()
                label:SetPoint("CENTER",self,"CENTER",0,0)
            end
            ApplyColors(self:IsMouseOver() and self:IsEnabled())
        end)
        button:HookScript("OnShow",function(self)
            C_Timer.After(0,function()
                if self:IsShown() then
                    StripNativeArtwork()
                    ApplyColors(false)
                    self:SetAlpha(1)
                    ApplyFont()
                end
            end)
        end)
        button:HookScript("OnEnable",function(self)
            C_Timer.After(0,function()
                StripNativeArtwork()
                ApplyColors(false)
                self:SetAlpha(1)
                ApplyFont()
            end)
        end)
        button:HookScript("OnDisable",function(self)
            C_Timer.After(0,function()
                StripNativeArtwork()
                ApplyColors(false)
                self:SetAlpha(1)
                ApplyFont()
            end)
        end)
    end
    ApplyFont()
end

local function FindTextRegion(frame,text)
    if not frame or not text then return end
    for _,region in ipairs({frame:GetRegions()}) do
        if region and region.GetObjectType
            and region:GetObjectType()=="FontString"
            and region.GetText and region:GetText()==text
        then
            return region
        end
    end
end

local KEYBIND_W,KEYBIND_H=520,200

local function KeybindingSettings()
    BindPadVars=BindPadVars or {}
    BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
    return BindPadVars.BPMMSettings
end

local function SaveKeybindingPoint(frame)
    local point,_,relativePoint,x,y=frame:GetPoint(1)
    if not point then return end
    KeybindingSettings().keybindingWindowPoint={
        point=point,
        relativePoint=relativePoint or point,
        x=tonumber(x) or 0,
        y=tonumber(y) or 0,
    }
end

local function RestoreKeybindingPoint(frame)
    if frame.__BetterBindKeybindingDragging then return end
    local saved=KeybindingSettings().keybindingWindowPoint
    if type(saved)~="table" or not saved.point then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        saved.point,UIParent,saved.relativePoint or saved.point,
        tonumber(saved.x) or 0,tonumber(saved.y) or 0
    )
end

local function InstallKeybindingDrag(frame)
    if frame.__BetterBindKeybindingDragHeader then return end
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local header=CreateFrame("Frame",nil,frame)
    header:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
    header:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-26,-1)
    header:SetHeight(34)
    header:SetFrameLevel(frame:GetFrameLevel()+20)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function()
        if InCombatLockdown() then return end
        frame.__BetterBindKeybindingDragging=true
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop",function()
        if not frame.__BetterBindKeybindingDragging then return end
        frame.__BetterBindKeybindingDragging=nil
        frame:StopMovingOrSizing()
        SaveKeybindingPoint(frame)
    end)
    frame.__BetterBindKeybindingDragHeader=header
end

local function EnsureKeybindingBackground(frame)
    local background=frame.__BetterBindKeybindingBackground
    if not background then
        background=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
        background.__BetterBindOwned=true
        frame.__BetterBindKeybindingBackground=background
    end
    background:ClearAllPoints()
    background:SetAllPoints(frame)
    background:SetColorTexture(.035,.042,.050,1)
    background:SetAlpha(1)
    background:Show()

    local border=frame.__BetterBindKeybindingBorder
    if not border then
        border=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        border:SetAllPoints(frame)
        border:SetFrameLevel(frame:GetFrameLevel()+10)
        border:EnableMouse(false)
        border:SetBackdrop({edgeFile=WHITE,edgeSize=1})
        frame.__BetterBindKeybindingBorder=border
    end
    border:SetBackdropBorderColor(unpack(C.border))
    border:SetAlpha(1)
    border:Show()
end

local function LayoutKeybindingDialog()
    local frame=_G.BindPadBindFrame
    if not frame then return end

    frame:SetSize(KEYBIND_W,KEYBIND_H)
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    HideTextureRegions(frame)
    EnsureKeybindingBackground(frame)
    InstallKeybindingDrag(frame)
    RestoreKeybindingPoint(frame)
    -- Keep the compact keybinding dialog on its earlier neutral solid shell;
    -- the circuit artwork is reserved for the three large browsers.
    if frame.__BetterBindKeybindCircuit then
        frame.__BetterBindKeybindCircuit:Hide()
    end

    HideObject(_G.BindPadBindFrameHeader)
    local nativeTitle=_G.BindPadBindFrameHeaderText
    local nativePress=FindTextRegion(frame,_G.BINDPAD_TEXT_PRESSKEY)
    local nativeAction=_G.BindPadBindFrameAction
    local nativeKey=_G.BindPadBindFrameKey

    if not nativePress then
        nativePress=frame.__BetterBindPressText
        if not nativePress then
            nativePress=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            frame.__BetterBindPressText=nativePress
        end
    end

    if nativeTitle then
        nativeTitle:Show(); nativeTitle:SetAlpha(1)
        nativeTitle:ClearAllPoints()
        nativeTitle:SetPoint("TOP",frame,"TOP",0,-11)
        nativeTitle:SetText(_G.BINDPAD_KEYBINDINGS_TITLE or "Keybinding")
        nativeTitle:SetTextColor(unpack(C.text))
        SetFontSize(nativeTitle,14)
    end

    nativePress:Show(); nativePress:SetAlpha(1)
    nativePress:ClearAllPoints()
    nativePress:SetPoint("TOP",frame,"TOP",0,-50)
    nativePress:SetText(_G.BINDPAD_TEXT_PRESSKEY or "Press a key to bind")
    nativePress:SetTextColor(unpack(C.text))
    SetFontSize(nativePress,12)

    if nativeAction then
        nativeAction:Show(); nativeAction:SetAlpha(1)
        nativeAction:ClearAllPoints()
        nativeAction:SetPoint("TOP",frame,"TOP",0,-76)
        nativeAction:SetWidth(KEYBIND_W-40)
        nativeAction:SetJustifyH("CENTER")
        nativeAction:SetTextColor(unpack(C.yellow))
        SetFontSize(nativeAction,15)
    end

    if nativeKey then
        nativeKey:Show(); nativeKey:SetAlpha(1)
        nativeKey:ClearAllPoints()
        nativeKey:SetPoint("TOP",frame,"TOP",0,-106)
        nativeKey:SetTextColor(unpack(C.text))
        SetFontSize(nativeKey,12)
    end

    local forAll=_G.BindPadBindFrameForAllCharacterButton
    if forAll then
        forAll:SetSize(CHECK_SIZE,CHECK_SIZE)
        forAll:ClearAllPoints()
        forAll:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",10,14)
        forAll:SetHitRectInsets(0,-130,0,0)
        forAll:SetFrameLevel(frame:GetFrameLevel()+5)
        StyleUtilityToggle(forAll)
        local label=_G[(forAll:GetName() or "").."Text"]
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT",forAll,"RIGHT",7,0)
            label:SetWidth(130)
            label:SetJustifyH("LEFT")
            label:SetTextColor(unpack(C.text))
            SetFontSize(label,11)
        end
    end

    local exit=_G.BindPadBindFrameExitButton
    if exit then
        exit:SetSize(88,30)
        exit:ClearAllPoints()
        exit:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-10,9)
        exit:SetFrameLevel(frame:GetFrameLevel()+5)
        StyleGoalButton(exit,"Exit",false)
    end

    local unbind=_G.BindPadBindFrameUnbindButton
    if unbind and exit then
        unbind:SetSize(88,30)
        unbind:ClearAllPoints()
        unbind:SetPoint("RIGHT",exit,"LEFT",-8,0)
        unbind:SetFrameLevel(frame:GetFrameLevel()+5)
        StyleGoalButton(unbind,"Unbind",true)
    end

    local close=_G.BindPadBindFrameCloseButton
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-5,-5)
        close:SetFrameLevel(frame:GetFrameLevel()+5)
        if type(_G.BetterBindAppearance_StyleClose)=="function" then
            _G.BetterBindAppearance_StyleClose(frame,close)
        end
    end
end

local function HideNativeTitle(frame)
    if not frame then return end
    local keep=frame.__BetterBindTitle
    if frame.TitleContainer then
        HideObject(frame.TitleContainer.TitleText)
    end
    local name=frame.GetName and frame:GetName()
    if name then HideObject(_G[name.."TitleText"]) end
    for _,region in ipairs({frame:GetRegions()}) do
        local text=region.GetText and region:GetText()
        if region~=keep and (text=="BindPad" or text=="MegaMacro"
            or text=="Mega Macro - Create Macros")
        then
            region:Hide()
            region:SetAlpha(0)
        end
    end
end

local function LayoutMegaMacroEditor()
    local frame=_G.MegaMacro_Frame
    if not frame then return end

    local background=_G.MegaMacro_FrameSelectedMacroBackground
    if background then
        background:SetSize(52,52)
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-352)
        background:SetAlpha(0)
    end

    local selected=_G.MegaMacro_FrameSelectedMacroButton
    if selected and background then
        selected:SetSize(52,52)
        selected:ClearAllPoints()
        selected:SetPoint("TOPLEFT",background,"TOPLEFT",0,0)

        local selectedIcon=_G.MegaMacro_FrameSelectedMacroButtonIcon
        for _,region in ipairs({selected:GetRegions()}) do
            if region~=selectedIcon and not region.__BetterBindOwned and region.GetObjectType
                and region:GetObjectType()=="Texture"
            then
                HideObject(region)
            end
        end

    end
    if _G.MegaMacro_FrameSelectedMacroButtonIcon then
        local icon=MegaMacro_FrameSelectedMacroButtonIcon
        icon:ClearAllPoints()
        icon:SetAllPoints(selected or background)
        icon:SetAlpha(1)
        icon:Show()
        ApplyIconAppearance(selected or frame,icon,"bettermacro")
        if selected and _G.BetterBindAppearance_StyleCell then
            BetterBindAppearance_StyleCell(selected,icon,false)
        end
    end

    local name=_G.MegaMacro_FrameSelectedMacroName
    if name and background then
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT",background,"TOPRIGHT",12,-3)
        name:SetSize(620,22)
        name:SetTextColor(unpack(C.yellow))
        SetFontSize(name,14)
    end

    local label=_G.MegaMacro_FrameEnterMacroText
    if label then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-415)
        label:SetTextColor(unpack(C.text))
        SetFontSize(label,11)
    end

    local rawSF=_G.MegaMacro_FrameScrollFrame
    local formattedSF=_G.MegaMacro_FormattedFrameScrollFrame
    for _,scroll in ipairs({rawSF,formattedSF}) do
        if scroll then
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",12,-432)
            scroll:SetSize(MM_W-26,172)
            if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
        end
    end

    if rawSF then
        local editorBackground=EnsurePanel(frame,"__BPMMGoalEditorBackground")
        editorBackground:ClearAllPoints()
        editorBackground:SetPoint("TOPLEFT",rawSF,"TOPLEFT",-1,1)
        editorBackground:SetPoint("BOTTOMRIGHT",rawSF,"BOTTOMRIGHT",1,-1)
        editorBackground:SetFrameLevel(math.max(frame:GetFrameLevel()+1,rawSF:GetFrameLevel()-1))
        Backdrop(editorBackground,{.075,.078,.088,1},C.border)
        editorBackground:SetAlpha(1)
        editorBackground:Show()
    end

    for _,edit in ipairs({_G.MegaMacro_FrameText,_G.MegaMacro_FormattedFrameText}) do
        if edit then
            edit:SetWidth(MM_W-30)
            edit:SetHeight(172)
            for _,region in ipairs({edit:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType()=="FontString" then
                    SetFontSize(region,12)
                end
            end
        end
    end

    if _G.MegaMacro_FrameTextButton then
        MegaMacro_FrameTextButton:SetSize(MM_W-30,172)
        MegaMacro_FrameTextButton:ClearAllPoints()
        MegaMacro_FrameTextButton:SetPoint("TOPLEFT",_G.MegaMacro_FrameText,"TOPLEFT",0,0)
    end

    HideScrollBar(rawSF)
    HideScrollBar(formattedSF)

    local edit=_G.MegaMacro_EditButton
    local save=_G.MegaMacro_SaveButton
    local cancel=_G.MegaMacro_CancelButton
    if edit and rawSF then
        edit:SetSize(96,32)
        edit:ClearAllPoints()
        edit:SetPoint("TOPRIGHT",rawSF,"BOTTOMRIGHT",-208,-8)
        StyleGoalButton(edit,"Edit",false)
    end
    if save and rawSF then
        save:SetSize(96,32)
        save:ClearAllPoints()
        save:SetPoint("TOPRIGHT",rawSF,"BOTTOMRIGHT",-104,-8)
        StyleGoalButton(save,"Save",false)
    end
    if cancel and rawSF then
        cancel:SetSize(96,32)
        cancel:ClearAllPoints()
        cancel:SetPoint("TOPRIGHT",rawSF,"BOTTOMRIGHT",0,-8)
        StyleGoalButton(cancel,"Cancel",false)
    end

    -- Apply the editor after the action row is anchored. A runtime problem in
    -- editor setup must never leave these buttons at their legacy XML points.
    if _G.BPMMBetterMacroEditor and _G.BPMMBetterMacroEditor.Apply then
        _G.BPMMBetterMacroEditor.Apply()
    end

    if _G.MegaMacro_FrameCharLimitText then
        MegaMacro_FrameCharLimitText:Hide()
        MegaMacro_FrameCharLimitText:SetAlpha(0)
    end
end

local function LayoutMegaMacroFooter()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    local footer=EnsurePanel(frame,"__BPMMGoalFooter")
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,1)
    footer:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)
    footer:SetHeight(48)
    footer:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))

    local delete=_G.MegaMacro_DeleteButton
    if delete then
        delete:SetSize(84,32)
        delete:ClearAllPoints()
        delete:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",12,8)
        StyleGoalButton(delete,"Delete",true)
    end

    local search=_G.BPMMUnifiedSearch
    if search then
        search:SetSize(366,36)
        search:ClearAllPoints()
        search:SetPoint("BOTTOM",frame,"BOTTOM",0,8)
        Backdrop(search,C.panel2,C.border)
        local underline=search.__BetterBindSearchUnderline
        if not underline then
            underline=search:CreateTexture(nil,"OVERLAY",nil,7)
            underline:SetPoint("BOTTOMLEFT",search,"BOTTOMLEFT",1,1)
            underline:SetPoint("BOTTOMRIGHT",search,"BOTTOMRIGHT",-1,1)
            underline:SetHeight(1)
            underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
            underline:Hide()
            search.__BetterBindSearchUnderline=underline
        end
        local edit=_G.BPMMUnifiedSearchEditBox
        if edit then
            SetFontSize(edit,11)
            if not edit.__BetterBindSearchSurfaceHooks then
                edit.__BetterBindSearchSurfaceHooks=true
                local function SetHovered(hovered)
                    search:SetBackdropColor(unpack(hovered and CONTROL_HOVER or C.panel2))
                    search:SetBackdropBorderColor(unpack(hovered and CONTROL_HOVER_EDGE or C.border))
                    underline:SetShown(hovered and true or false)
                end
                edit:HookScript("OnEnter",function() SetHovered(true) end)
                edit:HookScript("OnLeave",function(self) SetHovered(self:HasFocus()) end)
                edit:HookScript("OnEditFocusGained",function() SetHovered(true) end)
                edit:HookScript("OnEditFocusLost",function(self) SetHovered(self:IsMouseOver()) end)
                local clear=search.ClearButton
                if clear then
                    clear:HookScript("OnEnter",function() SetHovered(true) end)
                    clear:HookScript("OnLeave",function()
                        SetHovered(edit:HasFocus())
                    end)
                end
            end
        end
    end

    local locate=_G.BPMM74LocateButton
    if locate then
        locate:SetSize(108,32)
        locate:ClearAllPoints()
        locate:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-12,8)
        StyleGoalButton(locate,"Locate",false)
    end
end

Goal.ApplyMegaMacroFooter=LayoutMegaMacroFooter
Goal.ApplyBindPadLower=LayoutBindPadLower
Goal.ApplyBindPadGrid=LayoutBindPadGrid
Goal.ApplyMegaMacroGrid=LayoutMegaMacroGrid
Goal.ApplyKeybindingDialog=LayoutKeybindingDialog
Goal.HideLegacyBorders=HideLegacyBorders

function Goal.ApplyTitles()
    local bind=_G.BindPadFrame
    if bind then
        HideNativeTitle(bind)
        local title=bind.__BetterBindTitle
        if not title then
            title=bind:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            bind.__BetterBindTitle=title
        end
        title:Show(); title:SetAlpha(1); title:SetText("BetterBind")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints(); title:SetPoint("TOP",bind,"TOP",0,-11)
        SetFontSize(title,14)
    end

    local mega=_G.MegaMacro_Frame
    if mega then
        HideNativeTitle(mega)
        local title=mega.__BetterBindTitle
        if not title then
            title=mega:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            mega.__BetterBindTitle=title
        end
        title:Show(); title:SetAlpha(1); title:SetText("BetterMacro")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints(); title:SetPoint("TOP",mega,"TOP",0,-11)
        SetFontSize(title,15)
    end
    if type(_G.BetterBindAppearance_RefreshCloseButtons)=="function" then
        _G.BetterBindAppearance_RefreshCloseButtons()
    end
end

local function LayoutMegaMacro()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    frame:SetSize(MM_W,MM_H)
    EnsureWindowShell(frame,0,1,.259,.741)
    SetTabLayout(frame,"MegaMacro_FrameTab",5,1,{144,144,144,144,144})
    local selected=_G.BetterMacro_GetSelectedTabIndex and _G.BetterMacro_GetSelectedTabIndex()
        or (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(frame)) or 1
    StyleTabSelection(frame,"MegaMacro_FrameTab",5,selected)
    LayoutMegaMacroGrid()
    LayoutMegaMacroEditor()
    LayoutMegaMacroFooter()
    if _G.BetterAppearanceConfig_ApplyVisibility then
        _G.BetterAppearanceConfig_ApplyVisibility()
    end
end

local function RunLayoutStep(name,callback)
    local ok,message=xpcall(callback,function(errorMessage)
        local trace=debugstack and debugstack(2,20,20) or ""
        return ("BetterBind %s failed: %s\n%s"):format(
            name,tostring(errorMessage),trace
        )
    end)
    if not ok then
        local errorHandler=geterrorhandler and geterrorhandler()
        if errorHandler then errorHandler(message) end
    end
    return ok
end

function Goal.Apply()
    RunLayoutStep("BetterBind layout",LayoutBindPad)
    RunLayoutStep("BetterMacro layout",LayoutMegaMacro)
    RunLayoutStep("keybinding layout",LayoutKeybindingDialog)
    RunLayoutStep("legacy-art cleanup",HideLegacyBorders)
    RunLayoutStep("title and close controls",Goal.ApplyTitles)
end

local function ApplyBindPadNow()
    RunLayoutStep("BetterBind layout",LayoutBindPad)
    RunLayoutStep("legacy-art cleanup",HideLegacyBorders)
    RunLayoutStep("title and close controls",Goal.ApplyTitles)
end

Goal.ApplyBindPad=ApplyBindPadNow

RegisterEventHandler("PLAYER_LOGIN",function()
    C_Timer.After(.1,Goal.Apply)
    C_Timer.After(.65,Goal.Apply)
    C_Timer.After(1.3,Goal.Apply)
end)

if type(_G.BindPadFrame_OnShow)=="function" then
    hooksecurefunc("BindPadFrame_OnShow",ApplyBindPadNow)
elseif _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",ApplyBindPadNow)
end
if _G.BindPadBindFrame then
    BindPadBindFrame:HookScript("OnShow",function()
        RunLayoutStep("keybinding layout",LayoutKeybindingDialog)
        C_Timer.After(0,function()
            RunLayoutStep("keybinding layout",LayoutKeybindingDialog)
        end)
    end)
end
if type(_G.BindPadBindFrame_Update)=="function" then
    hooksecurefunc("BindPadBindFrame_Update",function()
        if _G.BindPadBindFrame and BindPadBindFrame:IsShown() then
            RunLayoutStep("keybinding layout",LayoutKeybindingDialog)
        end
    end)
end
if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Goal.Apply)
        C_Timer.After(.2,Goal.Apply)
    end)
end
if type(_G.BindPadFrameTab_OnClick)=="function" then
    hooksecurefunc("BindPadFrameTab_OnClick",function()
        ApplyBindPadNow()
    end)
end
if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        RunLayoutStep("BetterMacro layout",LayoutMegaMacro)
        RunLayoutStep("legacy-art cleanup",HideLegacyBorders)
        RunLayoutStep("title and close controls",Goal.ApplyTitles)
    end)
end
if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
    hooksecurefunc("MegaMacro_MacroButton_OnClick",function()
        C_Timer.After(0,function()
            RunLayoutStep("BetterMacro editor",LayoutMegaMacroEditor)
            RunLayoutStep("BetterMacro footer",LayoutMegaMacroFooter)
        end)
    end)
end
end

-- Public BetterBind identity
do
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

RegisterEventHandler("PLAYER_LOGIN",function()
    Apply()
    C_Timer.After(.5,Apply)
    if ChatFrame_ImportAllListsToHash then
        ChatFrame_ImportAllListsToHash()
    end
end)

if _G.BindPadFrame then BindPadFrame:HookScript("OnShow",Apply) end
if _G.MegaMacro_Frame then MegaMacro_Frame:HookScript("OnShow",Apply) end
end
