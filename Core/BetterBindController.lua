-- BetterBind window controller.
--
-- The binding engine and SavedVariables schema remain in BindPad.lua.  This
-- module owns the window state, tab/profile transitions, slot rendering and
-- BetterMacro icon hand-off.  Keeping those concerns here gives the UI one
-- deterministic refresh path without changing existing bindings or profiles.

local Controller = {}
_G.BetterBindController = Controller

local TYPE_MACRO = "MACRO"
local TYPE_BINDPAD_MACRO = "CLICK"
local FIRST_TAB = 1
local LAST_TAB = 5
local PROFILE_COUNT = 5
local SLOT_INCREMENT = 40
local QUESTION_MARK = tonumber(_G.MegaMacroTexture) or 134400

local refreshing = false
local refreshAgain = false

local function IsTexture(value)
    return (type(value) == "number" and value > 0)
        or (type(value) == "string" and value ~= "")
end

local function IsQuestionMark(value)
    if value == QUESTION_MARK then return true end
    if type(value) ~= "string" then return false end
    local lower = value:lower()
    return lower:find("inv_misc_questionmark", 1, true) ~= nil
        or lower:find("questionmark", 1, true) ~= nil
end

local function GetNativeMacroIndexByName(name)
    if not name or name == "" then return nil end

    if type(_G.GetMacroIndexByName) == "function" then
        local index = GetMacroIndexByName(name)
        if type(index) == "number" and index > 0 then return index end
    end

    if type(_G.GetMacroInfo) ~= "function" then return nil end
    local globalLimit = (_G.MacroLimits and MacroLimits.MaxGlobalMacros) or 120
    local characterOffset = (_G.MacroIndexOffsets and MacroIndexOffsets.NativeCharacterMacros) or 120
    local characterLimit = (_G.MacroLimits and MacroLimits.MaxCharacterMacros) or 30

    for index = 1, globalLimit do
        if GetMacroInfo(index) == name then return index end
    end
    for index = characterOffset + 1, characterOffset + characterLimit do
        if GetMacroInfo(index) == name then return index end
    end
end

local function GetMacroIdFromNativeIndex(index)
    if type(index) ~= "number" or index < 1 then return nil end

    if _G.MegaMacroEngine and type(MegaMacroEngine.GetMacroIdFromIndex) == "function" then
        local id = MegaMacroEngine.GetMacroIdFromIndex(index)
        if id then return id end
    end

    -- The native macro body starts with BetterMacro's stable marker (#001,
    -- #151, ...).  This fallback also works during early login before the
    -- engine's native-index cache has finished rebuilding.
    if type(_G.GetMacroInfo) == "function" then
        local _, _, body = GetMacroInfo(index)
        if type(body) == "string" then
            return tonumber(body:match("^#(%d+)%s"))
                or tonumber(body:match("^#(%d+)$"))
        end
    end
end

local function GetMacroIdFromSlot(slot)
    if not slot or slot.type ~= TYPE_MACRO then return nil end
    if slot.megaMacroId and _G.MegaMacro and type(MegaMacro.GetById) == "function"
        and MegaMacro.GetById(slot.megaMacroId)
    then
        return slot.megaMacroId
    end

    local name = slot.name
    if (not name or name == "") and type(slot.action) == "string" then
        name = slot.action:match("^MACRO%s+(.+)$")
    end
    return GetMacroIdFromNativeIndex(GetNativeMacroIndexByName(name))
end

local function ResolveMegaMacroTexture(macroId)
    if not macroId or not _G.MegaMacro or type(MegaMacro.GetById) ~= "function" then
        return nil
    end

    local macro = MegaMacro.GetById(macroId)
    if not macro then return nil end

    if _G.MegaMacroIconEvaluator then
        if type(MegaMacroIconEvaluator.UpdateMacro) == "function" then
            MegaMacroIconEvaluator.UpdateMacro(macro)
        end
        if type(MegaMacroIconEvaluator.GetCachedData) == "function" then
            local data = MegaMacroIconEvaluator.GetCachedData(macroId)
            if data and IsTexture(data.Icon) and not IsQuestionMark(data.Icon) then
                return data.Icon
            end
        end
    end

    if IsTexture(macro.StaticTexture) and not IsQuestionMark(macro.StaticTexture) then
        return macro.StaticTexture
    end
end

function Controller.ResolveSlotTexture(slot, nativeIndex)
    if not slot or slot.type ~= TYPE_MACRO then
        return slot and slot.texture or nil
    end

    local macroId = GetMacroIdFromNativeIndex(nativeIndex) or GetMacroIdFromSlot(slot)
    local texture = ResolveMegaMacroTexture(macroId)
    if macroId then slot.megaMacroId = macroId end
    if IsTexture(texture) then
        slot.texture = texture
        return texture
    end

    return slot.texture
end

Controller.GetMacroIdFromSlot = GetMacroIdFromSlot
Controller.GetMacroIdFromNativeIndex = GetMacroIdFromNativeIndex

-- Persist BetterMacro's stable id at drop time.  Blizzard deliberately resets
-- the temporary native drag texture after PickupMacro(), so the native icon is
-- not a reliable source by the time BetterBind receives the drop.
local OriginalPlaceIntoSlot = BindPadCore.PlaceIntoSlot
function BindPadCore.PlaceIntoSlot(id, cursorType, detail, subdetail, spellId)
    OriginalPlaceIntoSlot(id, cursorType, detail, subdetail, spellId)
    local slot = BindPadCore.GetSlotInfo(id)
    if not slot then return end

    if cursorType == "macro" and slot.type == TYPE_MACRO then
        slot.megaMacroId = GetMacroIdFromNativeIndex(detail)
        Controller.ResolveSlotTexture(slot, detail)
    else
        slot.megaMacroId = nil
    end
end

local function RenderSlot(button)
    if not button then return end
    local slot = BindPadCore.GetSlotInfo(button:GetID())
    if slot and slot.type and slot.action then
        local texture = Controller.ResolveSlotTexture(slot)
        button.icon:SetTexture(texture)
        button.icon:Show()
        button.addbutton:Hide()
        button.name:SetText(slot.name or "")

        local key = GetBindingKey(slot.action)
        if key and BindPadVars.showHotkey then
            button.hotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1))
        else
            button.hotkey:SetText("")
        end

        if slot.type == TYPE_BINDPAD_MACRO then
            button.border:SetVertexColor(0, 1, 0, .35)
            button.border:Show()
        else
            button.border:Hide()
        end
    else
        button.icon:Hide()
        button.addbutton:Hide()
        button.name:SetText("")
        button.hotkey:SetText("")
        button.border:Hide()
    end
end

function BindPadSlot_UpdateState(button)
    RenderSlot(button)
end

function BindPadSlot_OnUpdateBindings(button)
    if BindPadCore.character then RenderSlot(button) end
end

function BindPadSlot_OnClick(button, mouseButton)
    if mouseButton == "RightButton" then
        if BindPadCore.CursorHasIcon() then BindPadCore.ClearCursor() end
        return
    end

    if BindPadCore.CursorHasIcon() then
        BindPadSlot_OnReceiveDrag(button)
    elseif IsShiftKeyDown() then
        BindPadSlot_OnDragStart(button)
    elseif BindPadCore.GetSlotInfo(button:GetID()) then
        BindPadCore.HideSubFrames()
        BindPadCore.selectedSlot = BindPadCore.GetSlotInfo(button:GetID())
        BindPadCore.selectedSlotButton = button
        BindPadBindFrame_Update()
        BindPadBindFrame:Show()
    end
end

function BindPadSlot_OnDragStart(button)
    if not BindPadCore.CanPickupSlot(button) then return end
    BindPadCore.PickupSlot(button, button:GetID(), true)
    RenderSlot(button)
end

function BindPadSlot_OnReceiveDrag(button)
    if button == BindPadCore.selectedSlotButton then BindPadCore.HideSubFrames() end
    if not BindPadCore.CanPickupSlot(button) then return end

    local cursorType, detail, subdetail, spellId = GetCursorInfo()
    if cursorType then
        if cursorType == "petaction" then
            detail = BindPadCore.PickupSpellBookItem_slot
            subdetail = BindPadCore.PickupSpellBookItem_bookType
        end
        ClearCursor()
        ResetCursor()
        BindPadCore.PickupSlot(button, button:GetID())
        BindPadCore.PlaceIntoSlot(button:GetID(), cursorType, detail, subdetail, spellId)
        RenderSlot(button)
        BindPadSlot_OnEnter(button)
    elseif BindPadCore.drag.type == TYPE_BINDPAD_MACRO then
        local drag = BindPadCore.drag
        ClearCursor()
        ResetCursor()
        BindPadCore.PickupSlot(button, button:GetID())
        BindPadCore.PlaceVirtualIconIntoSlot(button:GetID(), drag)
        RenderSlot(button)
        BindPadSlot_OnEnter(button)
    end
end

local function RefreshProfiles()
    for index = 1, PROFILE_COUNT do
        local button = _G["BindPadProfileTab" .. index]
        if button then
            button:SetChecked(BindPadCore.GetCurrentProfileNum() == index)
            BindPadProfileTab_OnShow(button)
        end
    end
end

local function NormalizeSelectedTab()
    local tab = math.floor(tonumber(BindPadVars.tab) or FIRST_TAB)
    tab = math.max(FIRST_TAB, math.min(LAST_TAB, tab))
    if GetCurrentBindingSet() == 1 then tab = FIRST_TAB end
    BindPadVars.tab = tab
    return tab
end

local function RefreshWindowNow()
    if not BindPadCore.character then return end

    local tab = NormalizeSelectedTab()
    if BindPadFrameTitleText then
        if tab == FIRST_TAB then
            BindPadFrameTitleText:SetText(BINDPAD_TITLE)
        else
            BindPadFrameTitleText:SetText(_G["BINDPAD_TITLE_" .. BindPadCore.GetCurrentProfileNum()] or BINDPAD_TITLE)
        end
    end
    PanelTemplates_SetTab(BindPadFrame, tab)

    if BindPadFrameCharacterButton then
        BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2)
    end
    if BindPadFrameSaveAllKeysButton then
        BindPadFrameSaveAllKeysButton:SetChecked(not not BindPadVars.saveAllKeysFlag)
    end

    BindPadVars.showHotkey = not not (BindPadVars.showHotkey or BindPadVars.showKeyInTooltipFlag)
    BindPadVars.showKeyInTooltipFlag = nil
    if BindPadFrameShowHotkeyButton then
        BindPadFrameShowHotkeyButton:SetChecked(BindPadVars.showHotkey)
    end

    RefreshProfiles()
    local tabInfo = BindPadCore.GetTabInfo(tab)
    BindPadCore.CreateBindPadSlot(tabInfo.numSlot)
    for index = 1, tabInfo.numSlot do
        RenderSlot(_G["BindPadSlot" .. index])
    end
end

function Controller.Refresh()
    if refreshing then
        refreshAgain = true
        return
    end
    refreshing = true
    local ok, problem = pcall(function()
        repeat
            refreshAgain = false
            RefreshWindowNow()
        until not refreshAgain
    end)
    refreshing = false
    if not ok then error(problem, 0) end
end

function BindPadFrame_OnShow()
    Controller.Refresh()
end

local function SelectTab(tab)
    tab = math.max(FIRST_TAB, math.min(LAST_TAB, tonumber(tab) or FIRST_TAB))
    if tab > FIRST_TAB and GetCurrentBindingSet() == 1 then
        local answer = BindPadCore.ShowDialog(BINDPAD_TEXT_CONFIRM_CHANGE_BINDING_PROFILE)
        if not answer then
            BindPadVars.tab = FIRST_TAB
            Controller.Refresh()
            return false
        end
        LoadBindings(2)
        BindPadCore.SaveBindings(2)
    end
    BindPadVars.tab = tab
    Controller.Refresh()
    return true
end

function BindPadFrameTab_OnClick(button)
    return coroutine.wrap(function()
        SelectTab(button:GetID())
    end)()
end

function BindPadProfileTab_OnClick(button)
    return coroutine.wrap(function()
        local profile = button:GetID()
        if BindPadVars.tab == FIRST_TAB and profile ~= BindPadCore.GetCurrentProfileNum() then
            if not SelectTab(2) then return end
        end
        BindPadCore.SwitchProfile(profile)
        Controller.Refresh()
        BindPadProfileTab_OnEnter(button)
    end)()
end

local function AdjustSlots(direction)
    local tabInfo = BindPadCore.GetTabInfo(BindPadVars.tab)
    local current = tonumber(tabInfo.numSlot) or SLOT_INCREMENT
    tabInfo.numSlot = math.max(SLOT_INCREMENT, current + direction * SLOT_INCREMENT)
    Controller.Refresh()
end

function BindPadShowLessSlotButton_OnClick()
    AdjustSlots(-1)
end

function BindPadShowMoreSlotButton_OnClick()
    AdjustSlots(1)
end

function BindPadFrame_ShowHotkeyToggle(button)
    BindPadVars.showHotkey = not not button:GetChecked()
    local count = tonumber(BindPadCore.useBindPadSlot) or 0
    for index = 1, count do RenderSlot(_G["BindPadSlot" .. index]) end
    BindPadCore.UpdateAllHotkeys()
end

function BindPadFrame_SaveAllKeysToggle(button)
    BindPadVars.saveAllKeysFlag = not not button:GetChecked()
    BindPadCore.DoSaveAllKeys()
    if BindPadVars.saveAllKeysFlag then
        BindPadFrame_OutputText("Save All Keys enabled: the complete keybinding set will follow each specialization profile.")
    else
        BindPadFrame_OutputText("Save All Keys disabled: only BetterBind bindings will follow specialization profiles.")
    end
end

function Controller.RefreshMacroSlots(macroId)
    if not macroId or not BindPadCore.character then return end
    local count = tonumber(BindPadCore.useBindPadSlot) or 0
    for index = 1, count do
        local slot = BindPadCore.GetSlotInfo(index)
        if slot and slot.type == TYPE_MACRO and GetMacroIdFromSlot(slot) == macroId then
            slot.megaMacroId = macroId
            Controller.ResolveSlotTexture(slot)
            RenderSlot(_G["BindPadSlot" .. index])
        end
    end
end

-- Scroll the BetterBind viewport just enough to make one of the requested
-- slots visible.  Locate passes every matching slot; prefer a match already in
-- view, otherwise choose the nearest row and keep a full seven-row viewport.
function Controller.RevealSlots(matches)
    local scroll = _G.BindPadScrollFrame
    if not scroll or type(matches) ~= "table" or #matches == 0 then return nil end

    if _G.BPMMGoalLayout and type(BPMMGoalLayout.ApplyBindPadGrid) == "function" then
        BPMMGoalLayout.ApplyBindPadGrid()
    end

    local settings = _G.BindPadVars and BindPadVars.BPMMSettings or nil
    local columns = math.max(1, math.floor(tonumber(settings and settings.bindPadColumns) or 8))
    local iconSize = math.max(1, tonumber(settings and settings.bindPadIconSize) or 50)
    local spacing = math.max(0, tonumber(settings and settings.bindPadIconSpacing) or 11)
    local step = iconSize + spacing
    local current = tonumber(scroll:GetVerticalScroll()) or 0
    local firstVisibleRow = math.max(0, math.floor((current / step) + .5))
    local viewportHeight = tonumber(scroll:GetHeight()) or (7 * iconSize + 6 * spacing)
    local visibleRows = math.max(1, math.floor((viewportHeight + spacing) / step))
    local lastVisibleRow = firstVisibleRow + visibleRows - 1

    local targetRow
    local nearestDistance
    for _, entry in ipairs(matches) do
        local slotIndex = tonumber(entry.slotIndex)
            or (entry.button and entry.button.GetID and tonumber(entry.button:GetID()))
        if slotIndex and slotIndex > 0 then
            local row = math.floor((slotIndex - 1) / columns)
            if row >= firstVisibleRow and row <= lastVisibleRow then
                targetRow = row
                nearestDistance = 0
                break
            end
            local distance = row < firstVisibleRow
                and (firstVisibleRow - row) or (row - lastVisibleRow)
            if not nearestDistance or distance < nearestDistance then
                targetRow = row
                nearestDistance = distance
            end
        end
    end
    if not targetRow or nearestDistance == 0 then return targetRow end

    local targetFirstRow
    if targetRow < firstVisibleRow then
        targetFirstRow = targetRow
    else
        targetFirstRow = math.max(0, targetRow - visibleRows + 1)
    end

    -- ScrollFrame range can remain zero until a layout pass has been rendered.
    -- Derive the authoritative range from the active grid instead of trusting
    -- that stale value (the reason Locate found slot 60 but did not move).
    local activeSlots = math.max(tonumber(BindPadCore.useBindPadSlot) or 0, targetRow * columns + 1)
    local totalRows = math.max(1, math.ceil(activeSlots / columns))
    local calculatedMaximum = math.max(0, (totalRows - visibleRows) * step)
    local reportedMaximum = tonumber(scroll:GetVerticalScrollRange()) or 0
    local maximum = math.max(calculatedMaximum, reportedMaximum)
    local target = math.max(0, math.min(maximum, targetFirstRow * step))
    local function ApplyTarget()
        if not scroll then return end
        if scroll.UpdateScrollChildRect then
            pcall(scroll.UpdateScrollChildRect,scroll)
        elseif type(_G.ScrollFrame_UpdateScrollChildRect) == "function" then
            pcall(ScrollFrame_UpdateScrollChildRect,scroll)
        end
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(target) end
    end
    ApplyTarget()
    if _G.C_Timer and type(C_Timer.After) == "function" then
        -- Reapply after the ScrollChild's new height has propagated.
        C_Timer.After(0,ApplyTarget)
        C_Timer.After(.04,ApplyTarget)
    end
    return targetRow, target
end

-- Existing UI integrations hook these globals after this module loads, so the
-- new controller remains the single source of state while visual polish and
-- BetterMacro right-click behavior continue to compose normally.
if _G.MegaMacroIconEvaluator and type(MegaMacroIconEvaluator.OnIconUpdated) == "function" then
    MegaMacroIconEvaluator.OnIconUpdated(function(macroId)
        Controller.RefreshMacroSlots(macroId)
    end)
end

if _G.BindPadFrame and BindPadFrame:IsShown() then
    Controller.Refresh()
end
