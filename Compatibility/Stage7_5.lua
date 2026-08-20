-- BindPad + MegaMacro Stage 7 consolidated integration
-- Version: 0.7.5
-- Generated from known-working Stage 7.1 through 7.4 modules.
-- Existing TOC order preserved.
-- No macro/binding/profile/SavedVariables migration code.

-- ============================================================
-- BEGIN: Stage7.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 7.1
-- Direct integration layer.
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

    local h = CreateFrame("Frame", nil, button, "BackdropTemplate")
    h:SetPoint("TOPLEFT", -3, 3)
    h:SetPoint("BOTTOMRIGHT", 3, -3)
    h:SetFrameLevel((button:GetFrameLevel() or 1) + 8)
    h:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    h:SetBackdropBorderColor(1, .78, .08, 1)
    h:EnableMouse(false)
    h:Hide()

    button.__BPMM71Highlight = h
    return h
end

local function RefreshBindPadHighlights()
    if not BindPadCore then return end

    local i = 1
    while true do
        local button = _G["BindPadSlot" .. i]
        if not button then break end

        local highlight = EnsureHighlight(button)
        local padSlot = BindPadCore.GetSlotInfo and BindPadCore.GetSlotInfo(button:GetID())
        local id = GetMegaMacroIdFromPadSlot(padSlot)

        highlight:SetShown(selectedMegaMacroId ~= nil and id == selectedMegaMacroId)
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

        return originalBindPadSlotOnClick(self, button, down)
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

local dragWatcher = CreateFrame("Frame")
local lastCursorMegaId = nil
local elapsed = 0
dragWatcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < .08 then return end
    elapsed = 0

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
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    local delay = event == "PLAYER_LOGIN" and .5 or 0
    C_Timer.After(delay, function()
        InstallBindPadRightClickBridge()
        InstallMegaMacroSelectionBridge()
        InstallBindPadRefreshBridge()
        RefreshBindPadHighlights()
    end)
end)

-- Useful diagnostic without touching SavedVariables.
SLASH_BPMM71DIAG1 = "/bb71"
SlashCmdList["BPMM71DIAG"] = function()
    print("|cffffcc00BPMM Stage 7.1|r")
    print("Right-click bridge:", BPMM71.rightClickInstalled and "OK" or "NOT INSTALLED")
    print("Selection bridge:", BPMM71.selectionInstalled and "OK" or "NOT INSTALLED")
    print("Refresh bridge:", BPMM71.refreshInstalled and "OK" or "NOT INSTALLED")
    print("Selected BetterMacro ID:", selectedMegaMacroId or "none")
end
end
-- END: Stage7.lua

-- ============================================================
-- BEGIN: Stage7_2.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 7.2
-- Unified live search/filter across MegaMacro + visible BindPad slots.
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

    local m=CreateFrame("Frame",nil,button,"BackdropTemplate")
    m:SetPoint("TOPLEFT",-2,2)
    m:SetPoint("BOTTOMRIGHT",2,-2)
    m:SetFrameLevel((button:GetFrameLevel() or 1)+7)
    m:SetBackdrop({
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    -- Search uses a cool-blue edge so Stage 7.1 selected-link gold remains distinct.
    m:SetBackdropBorderColor(.10,.60,1.00,.95)
    m:EnableMouse(false)
    m:Hide()

    button.__BPMM72SearchMatch=m
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

    local visibleMegaMatches=0
    local visibleMegaTotal=0

    for i=1,(HighestMaxMacroCount or 60) do
        local b=_G["MegaMacro_MacroButton"..i]
        if b and b:IsShown() then
            -- Ignore MegaMacro's one "new macro" plus button as a result.
            if b.Macro then
                visibleMegaTotal=visibleMegaTotal+1
                if MegaMacroMatches(b.Macro,q) then
                    b:SetAlpha(1)
                    visibleMegaMatches=visibleMegaMatches+1
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
    local bindTotal=0
    local i=1

    while true do
        local b=_G["BindPadSlot"..i]
        if not b then break end

        local marker=EnsureMatchMarker(b)
        local padSlot=BindPadCore and BindPadCore.GetSlotInfo and BindPadCore.GetSlotInfo(b:GetID())

        if b:IsShown() and padSlot and padSlot.type then
            bindTotal=bindTotal+1
            if PadSlotMatches(padSlot,q) then
                b:SetAlpha(1)
                marker:Show()
                bindMatches=bindMatches+1
            else
                b:SetAlpha(.18)
                marker:Hide()
            end
        elseif b:IsShown() then
            b:SetAlpha(.10)
            marker:Hide()
        else
            marker:Hide()
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

    local c1=clear:CreateTexture(nil,"ARTWORK")
    c1:SetColorTexture(.58,.58,.62,1)
    c1:SetSize(9,1)
    c1:SetPoint("CENTER")
    c1:SetRotation(math.rad(45))

    local c2=clear:CreateTexture(nil,"ARTWORK")
    c2:SetColorTexture(.58,.58,.62,1)
    c2:SetSize(9,1)
    c2:SetPoint("CENTER")
    c2:SetRotation(math.rad(-45))

    clear:SetScript("OnEnter",function()
        c1:SetColorTexture(1,.78,.08,1)
        c2:SetColorTexture(1,.78,.08,1)
    end)
    clear:SetScript("OnLeave",function()
        c1:SetColorTexture(.58,.58,.62,1)
        c2:SetColorTexture(.58,.58,.62,1)
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

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    C_Timer.After(.5,function()
        BuildSearchUI()
        InstallRefreshHooks()
        QueueSearch()
    end)
end)
end
-- END: Stage7_2.lua

-- ============================================================
-- BEGIN: Stage7_2_1.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 7.2.1
-- Moves unified search to MegaMacro footer and restyles Delete button
-- to match the top tab/button visual language.

local function StyleFooterButton(button)
    if not button or button.__BPMM721Styled then return end
    button.__BPMM721Styled = true

    -- Hide inherited normal/pushed/highlight textures without invalid nil calls.
    local nt = button.GetNormalTexture and button:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt = button.GetPushedTexture and button:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local ht = button.GetHighlightTexture and button:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end
    local dt = button.GetDisabledTexture and button:GetDisabledTexture()
    if dt then dt:SetAlpha(0) end

    local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
    bg:SetAllPoints()
    bg:SetFrameLevel(math.max(0, button:GetFrameLevel()-1))
    bg:EnableMouse(false)
    bg:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    bg:SetBackdropColor(.045,.045,.052,1)
    bg:SetBackdropBorderColor(.15,.15,.17,1)

    button.__BPMM721BG = bg

    local fs = button.GetFontString and button:GetFontString()
    if fs then
        fs:SetTextColor(.90,.90,.92,1)
    end

    button:HookScript("OnEnter", function(self)
        if self.__BPMM721BG then
            self.__BPMM721BG:SetBackdropColor(.075,.075,.085,1)
            self.__BPMM721BG:SetBackdropBorderColor(.12,.62,.95,1)
        end
    end)

    button:HookScript("OnLeave", function(self)
        if self.__BPMM721BG then
            self.__BPMM721BG:SetBackdropColor(.045,.045,.052,1)
            self.__BPMM721BG:SetBackdropBorderColor(.15,.15,.17,1)
        end
    end)
end

local function RepositionSearch()
    local search = _G.BPMMUnifiedSearch
    local mega = _G.MegaMacro_Frame
    if not search or not mega then return end

    search:ClearAllPoints()
    search:SetSize(330, 26)

    local delete = _G.MegaMacro_DeleteButton
    if delete then
        search:SetPoint("BOTTOMLEFT", delete, "BOTTOMRIGHT", 12, 0)
    else
        search:SetPoint("BOTTOMLEFT", mega, "BOTTOMLEFT", 120, 10)
    end

    -- Keep it in the footer row, safely away from tabs/content.
    if search.SetFrameLevel then
        search:SetFrameLevel((mega:GetFrameLevel() or 1)+20)
    end

    -- Result text goes to the right of the search field.
    local edit = _G.BPMMUnifiedSearchEditBox
    if edit then
        local result
        for _,region in ipairs({mega:GetRegions()}) do
            if region.GetText and region:GetText() and region:GetText():find("MegaMacro") then
                -- Don't try to heuristically repurpose unrelated text.
            end
        end
    end
end

local function Apply()
    StyleFooterButton(_G.MegaMacro_DeleteButton)
    RepositionSearch()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(.5, Apply)
    C_Timer.After(1.0, Apply)
end)

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow", function()
        C_Timer.After(0, Apply)
    end)
end
end
-- END: Stage7_2_1.lua

-- ============================================================
-- BEGIN: Stage7_3.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 7.3
-- Footer alignment + accent normalization.
-- Search is centered exactly in MegaMacro's footer.
-- Accent policy: neutral dark UI, blue/cyan only for active/hover/focus states.

local C = {
    bg = {.035,.035,.042,1},
    bgHover = {.055,.060,.070,1},
    border = {.16,.16,.18,1},
    blue = {.08,.58,.88,1},
    text = {.90,.90,.92,1},
    muted = {.52,.52,.56,1},
}

local function StyleNeutralButton(button)
    if not button then return end

    local nt = button.GetNormalTexture and button:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt = button.GetPushedTexture and button:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local ht = button.GetHighlightTexture and button:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end
    local dt = button.GetDisabledTexture and button:GetDisabledTexture()
    if dt then dt:SetAlpha(0) end

    local bg = button.__BPMM73BG
    if not bg then
        bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(button:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        button.__BPMM73BG = bg
    end

    bg:SetBackdropColor(unpack(C.bg))
    bg:SetBackdropBorderColor(unpack(C.border))

    local fs = button.GetFontString and button:GetFontString()
    if fs then fs:SetTextColor(unpack(C.text)) end

    if not button.__BPMM73Hooked then
        button.__BPMM73Hooked = true

        button:HookScript("OnEnter", function(self)
            local b=self.__BPMM73BG
            if b then
                b:SetBackdropColor(unpack(C.bgHover))
                b:SetBackdropBorderColor(unpack(C.blue))
            end
        end)

        button:HookScript("OnLeave", function(self)
            local b=self.__BPMM73BG
            if b then
                b:SetBackdropColor(unpack(C.bg))
                b:SetBackdropBorderColor(unpack(C.border))
            end
        end)
    end
end

local function CenterSearch()
    local search = _G.BPMMUnifiedSearch
    local mega = _G.MegaMacro_Frame
    if not search or not mega then return end

    -- Exact bottom-center of the MegaMacro window, independent of Delete.
    search:ClearAllPoints()
    search:SetSize(340,26)
    search:SetPoint("BOTTOM", mega, "BOTTOM", 0, 9)

    if search.SetFrameLevel then
        search:SetFrameLevel((mega:GetFrameLevel() or 1)+25)
    end

    -- Neutral default, blue only when focused/hovered.
    if search.SetBackdropColor then
        search:SetBackdropColor(unpack(C.bg))
        search:SetBackdropBorderColor(unpack(C.border))
    end

    local edit = _G.BPMMUnifiedSearchEditBox
    if edit then
        local oldFocusGain = edit:GetScript("OnEditFocusGained")
        local oldFocusLost = edit:GetScript("OnEditFocusLost")

        edit:SetScript("OnEditFocusGained", function(self)
            if oldFocusGain then oldFocusGain(self) end
            if search.SetBackdropBorderColor then
                search:SetBackdropBorderColor(unpack(C.blue))
            end
        end)

        edit:SetScript("OnEditFocusLost", function(self)
            if oldFocusLost then oldFocusLost(self) end
            if search.SetBackdropBorderColor then
                search:SetBackdropBorderColor(unpack(C.border))
            end
        end)
    end

    if not search.__BPMM73Hover then
        search.__BPMM73Hover = true
        search:HookScript("OnEnter", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(unpack(C.blue))
            end
        end)
        search:HookScript("OnLeave", function(self)
            local e=_G.BPMMUnifiedSearchEditBox
            if not e or not e:HasFocus() then
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(unpack(C.border))
                end
            end
        end)
    end
end

local function NormalizeTabs()
    local mega = _G.MegaMacro_Frame
    if not mega then return end

    for i=1,6 do
        local tab=_G["MegaMacro_FrameTab"..i]
        if tab then
            -- Keep existing tab system, only neutralize non-selected colors.
            local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(mega) == i

            local nt=tab.GetNormalTexture and tab:GetNormalTexture()
            if nt and nt.SetVertexColor then
                if selected then
                    nt:SetVertexColor(.12,.35,.52,1)
                else
                    nt:SetVertexColor(.18,.18,.20,1)
                end
            end

            local fs=tab.GetFontString and tab:GetFontString()
            if fs then
                if selected then
                    fs:SetTextColor(.92,.95,.98,1)
                else
                    fs:SetTextColor(.78,.78,.80,1)
                end
            end
        end
    end
end

local function Apply()
    CenterSearch()

    -- Delete remains far left; visual language matches the tabs but stays neutral.
    StyleNeutralButton(_G.MegaMacro_DeleteButton)

    NormalizeTabs()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(.5, Apply)
    C_Timer.After(1.0, Apply)
end)

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow", function()
        C_Timer.After(0, Apply)
    end)
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick", function()
        C_Timer.After(0, NormalizeTabs)
    end)
end
end
-- END: Stage7_3.lua

-- ============================================================
-- BEGIN: Stage7_4.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 7.4
-- "Where is this macro used?" inspector.
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

    local p = CreateFrame("Frame", nil, button, "BackdropTemplate")
    p:SetPoint("TOPLEFT",-4,4)
    p:SetPoint("BOTTOMRIGHT",4,-4)
    p:SetFrameLevel((button:GetFrameLevel() or 1)+12)
    p:SetBackdrop({
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=2,
    })
    p:SetBackdropBorderColor(unpack(C.blue))
    p:EnableMouse(false)
    p:Hide()

    button.__BPMM74Pulse = p
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
            -- Restore Stage 7.1 selection highlight.
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
local countText

local function RefreshInspector()
    if not locate then return end

    local matches = VisibleBindPadMatches(selectedId)
    local keys = BoundKeys(selectedId)

    if not selectedId then
        countText:SetText("No macro selected")
        locate:Disable()
        locate:SetAlpha(.45)
        return
    end

    locate:Enable()
    locate:SetAlpha(1)

    if #matches == 0 then
        countText:SetText("BetterBind: 0")
    elseif #matches == 1 then
        countText:SetText("BetterBind: 1 slot")
    else
        countText:SetFormattedText("BetterBind: %d slots", #matches)
    end

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

    countText=MegaMacro_Frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    countText:SetPoint("RIGHT",locate,"LEFT",-10,0)
    countText:SetWidth(120)
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(unpack(C.muted))

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

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,function()
        BuildInspector()
        InstallHooks()
    end)
end)
end
-- END: Stage7_4.lua

-- ============================================================
-- STAGE 7.6 FINAL FOOTER CLEANUP
-- ============================================================
do
-- BPMM Stage 7.5.1
-- Locate footer cleanup:
-- Stage 7.4 created a separate status FontString immediately to the left of
-- Locate ("BindPad: 1 slot"). In the compact footer it collides with the
-- centered search field. Hide that persistent label; the Locate tooltip and
-- /bbwhere still provide the full count/details.

local function FixLocateFooter()
    local locate = _G.BPMM74LocateButton
    local mega = _G.MegaMacro_Frame
    if not locate or not mega then return end

    -- Find only FontStrings anchored RIGHT -> LEFT of the Locate button.
    -- This structurally identifies Stage 7.4's countText without touching
    -- MegaMacro's native "Characters Used" counter or search UI.
    for _, region in ipairs({mega:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local n = region:GetNumPoints() or 0
            for i=1,n do
                local point, relativeTo, relativePoint = region:GetPoint(i)
                if point == "RIGHT" and relativeTo == locate and relativePoint == "LEFT" then
                    region:SetText("")
                    region:Hide()

                    -- Stage 7.4 RefreshInspector keeps calling SetText().
                    -- Keep the footer clean even after selecting another macro.
                    if not region.__BPMM751Hidden then
                        region.__BPMM751Hidden = true
                        hooksecurefunc(region, "SetText", function(self)
                            if self:IsShown() then self:Hide() end
                        end)
                        hooksecurefunc(region, "SetFormattedText", function(self)
                            if self:IsShown() then self:Hide() end
                        end)
                    end
                end
            end
        end
    end
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(.5, FixLocateFooter)
    C_Timer.After(1.0, FixLocateFooter)
end)

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow", function()
        C_Timer.After(0, FixLocateFooter)
    end)
end
end
