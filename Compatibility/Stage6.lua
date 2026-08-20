-- BetterBind + BetterMacro Stage 6 consolidated runtime
-- Version: 0.6.5
-- Generated from the user's known-working Stage 6.4.2 installation.
-- Module order is preserved from BindPad.toc.
-- No macro/binding/SavedVariables migration code belongs here.

-- ============================================================
-- BEGIN CONSOLIDATED: Settings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.1
-- Settings layer: independent UI scale, linked movement, reset UI.
-- Stores only UI preferences inside BindPadVars.BPMMSettings.

local addonName, addon = ...

local DEFAULTS = {
    bindPadScale = 1.00,
    megaMacroScale = 1.00,
    linkedWindows = false,
}

local function EnsureSettings()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}

    for key,value in pairs(DEFAULTS) do
        if BindPadVars.BPMMSettings[key] == nil then
            BindPadVars.BPMMSettings[key] = value
        end
    end

    return BindPadVars.BPMMSettings
end

local function ClampScale(v)
    v = tonumber(v) or 1
    if v < 0.70 then return 0.70 end
    if v > 1.40 then return 1.40 end
    return math.floor(v * 100 + 0.5) / 100
end

local function ApplyScale()
    local s = EnsureSettings()

    if BindPadFrame then
        BindPadFrame:SetScale(ClampScale(s.bindPadScale))
    end

    if MegaMacro_Frame then
        MegaMacro_Frame:SetScale(ClampScale(s.megaMacroScale))
    end
end

local function ResetWindowPosition(frame)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function ResetUISettings()
    local s = EnsureSettings()

    s.bindPadScale = DEFAULTS.bindPadScale
    s.megaMacroScale = DEFAULTS.megaMacroScale
    s.linkedWindows = DEFAULTS.linkedWindows

    if BindPadVars then
        BindPadVars.BPMMWindowPosition = nil
    end

    if MegaMacroGlobalData and MegaMacroGlobalData.WindowInfo then
        MegaMacroGlobalData.WindowInfo = nil
    end

    ApplyScale()
    ResetWindowPosition(BindPadFrame)
    ResetWindowPosition(MegaMacro_Frame)

    if BPMMSettingsPanel and BPMMSettingsPanel.Refresh then
        BPMMSettingsPanel:Refresh()
    end
end

-- ============================================================
-- Linked-window movement
-- ============================================================
-- Stage 6.1.1: no continuous OnUpdate polling.
-- The dragged window moves at native WoW speed; when the drag finishes, the
-- companion window is shifted by the exact same delta.

local dragState = {}

local function CaptureFrame(frame, key)
    if not frame then return end
    dragState[key] = {
        left = frame:GetLeft(),
        top = frame:GetTop(),
    }
end

local function ShiftFrame(frame, dx, dy)
    if not frame or not dx or not dy then return end
    if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end

    frame:ClearAllPoints()
    frame:SetPoint(
        point,
        relativeTo or UIParent,
        relativePoint or point,
        (x or 0) + dx,
        (y or 0) + dy
    )
end

local function BeginLinkedDrag(frame, key)
    if not EnsureSettings().linkedWindows then return end
    CaptureFrame(frame, key)
end

local function EndLinkedDrag(frame, key, otherFrame)
    if not EnsureSettings().linkedWindows then
        dragState[key] = nil
        return
    end

    local start = dragState[key]
    dragState[key] = nil
    if not start or not frame or not otherFrame then return end

    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top or not start.left or not start.top then return end

    ShiftFrame(otherFrame, left - start.left, top - start.top)
end

local function HookNativeDrag(frame, key, otherFrame)
    if not frame or frame.__BPMMLinkedDragHook then return end
    frame.__BPMMLinkedDragHook = true

    frame:HookScript("OnDragStart", function(self)
        if self.SetMovable then self:SetMovable(true) end
        BeginLinkedDrag(self, key)
    end)

    frame:HookScript("OnDragStop", function(self)
        EndLinkedDrag(self, key, otherFrame)
    end)
end

-- MegaMacro has native OnDragStart/OnDragStop scripts.
HookNativeDrag(MegaMacro_Frame, "MegaMacro", BindPadFrame)

-- BindPad's custom title-drag overlay moves BindPadFrame, so hook the frame's
-- mouse-release path as a fallback and also watch its position only while the
-- left button is held over the title area.
local bindWatch = CreateFrame("Frame")
local bindDragging = false

bindWatch:SetScript("OnUpdate", function()
    if not EnsureSettings().linkedWindows or not BindPadFrame or not BindPadFrame:IsShown() then
        bindDragging = false
        return
    end

    local leftDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
    local over = BindPadFrame:IsMouseOver()

    if leftDown and over then
        local scale = BindPadFrame:GetEffectiveScale() or 1
        local _, cy = GetCursorPosition()
        local top = BindPadFrame:GetTop()

        if cy and top then
            cy = cy / scale
            local inTitle = cy <= top and cy >= top - 30

            if inTitle and not bindDragging then
                bindDragging = true
                BeginLinkedDrag(BindPadFrame, "BindPad")
            end
        end
    elseif bindDragging then
        bindDragging = false
        EndLinkedDrag(BindPadFrame, "BindPad", MegaMacro_Frame)
    end
end)
-- ============================================================
-- Settings panel
-- ============================================================

local function MakeBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left=1,right=1,top=1,bottom=1},
    })
    frame:SetBackdropColor(.035,.035,.04,.98)
    frame:SetBackdropBorderColor(0,0,0,1)
end

local function MakeButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 24)
    MakeBackdrop(b)
    b:SetBackdropColor(.08,.08,.09,1)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(.92,.92,.94,1)
    b.Text = fs

    b:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(.10,.55,.85,1)
        self:SetBackdropColor(.13,.13,.15,1)
    end)
    b:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0,0,0,1)
        self:SetBackdropColor(.08,.08,.09,1)
    end)

    return b
end

local function MakeCheckbox(parent, label)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22,22)

    local text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", c, "RIGHT", 4, 0)
    text:SetText(label)

    c.Label = text
    return c
end

local function MakeSlider(parent, label)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(320,48)

    local title = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local valueText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, holder, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetPoint("TOPRIGHT", 0, -20)
    slider:SetMinMaxValues(0.70, 1.40)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    if slider.Low then slider.Low:SetText("70%") end
    if slider.High then slider.High:SetText("140%") end
    if slider.Text then slider.Text:SetText("") end

    holder.Slider = slider
    holder.ValueText = valueText
    return holder
end

local panel = CreateFrame("Frame", "BPMMSettingsPanel", UIParent, "BackdropTemplate")
panel:SetSize(380,280)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()
MakeBackdrop(panel)

panel:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 14, -14)
title:SetText("BetterBind + BetterMacro")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetText("UI Settings")
subtitle:SetTextColor(.60,.60,.64,1)

local close = MakeButton(panel, "X", 24, 24)
close:SetPoint("TOPRIGHT", -8, -8)
close:SetScript("OnClick", function() panel:Hide() end)

local bindScale = MakeSlider(panel, "BetterBind UI Scale")
bindScale:SetPoint("TOPLEFT", 28, -66)

local megaScale = MakeSlider(panel, "BetterMacro UI Scale")
megaScale:SetPoint("TOPLEFT", 28, -124)

local linked = MakeCheckbox(panel, "Move both windows together")
linked:SetPoint("TOPLEFT", 28, -186)

local reset = MakeButton(panel, "Reset UI", 110, 26)
reset:SetPoint("BOTTOMLEFT", 28, 18)

local done = MakeButton(panel, "Done", 110, 26)
done:SetPoint("BOTTOMRIGHT", -28, 18)
done:SetScript("OnClick", function() panel:Hide() end)

function panel:Refresh()
    local s = EnsureSettings()

    bindScale.Slider:SetValue(ClampScale(s.bindPadScale))
    megaScale.Slider:SetValue(ClampScale(s.megaMacroScale))
    bindScale.ValueText:SetText(math.floor(ClampScale(s.bindPadScale)*100+0.5).."%")
    megaScale.ValueText:SetText(math.floor(ClampScale(s.megaMacroScale)*100+0.5).."%")
    linked:SetChecked(s.linkedWindows and true or false)
end

bindScale.Slider:SetScript("OnValueChanged", function(self, value)
    local s = EnsureSettings()
    s.bindPadScale = ClampScale(value)
    bindScale.ValueText:SetText(math.floor(s.bindPadScale*100+0.5).."%")
    if BindPadFrame then BindPadFrame:SetScale(s.bindPadScale) end
end)

megaScale.Slider:SetScript("OnValueChanged", function(self, value)
    local s = EnsureSettings()
    s.megaMacroScale = ClampScale(value)
    megaScale.ValueText:SetText(math.floor(s.megaMacroScale*100+0.5).."%")
    if MegaMacro_Frame then MegaMacro_Frame:SetScale(s.megaMacroScale) end
end)

linked:SetScript("OnClick", function(self)
    EnsureSettings().linkedWindows = self:GetChecked() and true or false
end)

reset:SetScript("OnClick", function()
    ResetUISettings()
end)

local function ToggleSettings()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Refresh()
        panel:Show()
    end
end

-- BetterBind retires the settings slash command; scaling is handled directly
-- with Shift + mouse wheel over either window header.

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    EnsureSettings()
    ApplyScale()
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow", function()
        ApplyScale()
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow", function()
        ApplyScale()
    end)
end
end
-- END CONSOLIDATED: Settings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: RemoveLock.lua
-- ============================================================
do
-- Stage 6.1 permanent MegaMacro Lock-button suppression.
-- Loaded last so later MegaMacro refreshes cannot make it visible again.

local function IsLockControl(obj)
    if not obj then return false end
    local name = obj.GetName and obj:GetName() or ""
    if name and name:lower():find("lock",1,true) then return true end

    if obj.GetText then
        local text=obj:GetText()
        if type(text)=="string" and text:lower()=="lock" then return true end
    end
    return false
end

local function Suppress(obj)
    if not obj or obj.__BPMMLockSuppressed then return end
    obj.__BPMMLockSuppressed=true
    if obj.Hide then obj:Hide() end
    if obj.SetAlpha then obj:SetAlpha(0) end
    if obj.EnableMouse then obj:EnableMouse(false) end

    if obj.HookScript then
        obj:HookScript("OnShow",function(self)
            self:Hide()
        end)
    end
end

local function FindAndSuppress()
    local frame=_G.MegaMacro_Frame
    if not frame then return end

    -- Known/likely globals first.
    for _,name in ipairs({
        "MegaMacro_LockButton",
        "MegaMacro_Lock",
        "MegaMacroLockButton",
        "MegaMacro_FrameLockButton",
    }) do
        local obj=_G[name]
        if obj then Suppress(obj) end
    end

    -- Search children so this remains robust across MegaMacro layouts.
    local children={frame:GetChildren()}
    for _,child in ipairs(children) do
        if IsLockControl(child) then
            Suppress(child)
        end
        if child.GetChildren then
            local sub={child:GetChildren()}
            for _,obj in ipairs(sub) do
                if IsLockControl(obj) then Suppress(obj) end
            end
        end
    end
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(0,FindAndSuppress)
    C_Timer.After(.5,FindAndSuppress)
    C_Timer.After(2,FindAndSuppress)
end)

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,FindAndSuppress)
    end)
end
end
-- END CONSOLIDATED: RemoveLock.lua

-- ============================================================
-- BEGIN CONSOLIDATED: GridSettings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.2
-- Grid customization for BindPad. Presentation only.

local DEFAULT_GRID = {
    bindPadIconSize = 36,
    bindPadIconSpacing = 6,
    bindPadColumns = 7,
}

local function Settings()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    local s = BindPadVars.BPMMSettings
    for k,v in pairs(DEFAULT_GRID) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

local function Clamp(v,minv,maxv,step)
    v = tonumber(v) or minv
    v = math.max(minv,math.min(maxv,v))
    if step then
        v = math.floor((v/step)+0.5)*step
    end
    return v
end

local function GetSlots()
    local slots={}
    for i=1,250 do
        local b=_G["BindPadSlot"..i]
        if b then slots[#slots+1]=b end
    end
    return slots
end

local function ApplyGrid()
    if not BindPadFrame or not BindPadSlotButtonContainer then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadGrid then
        return BPMMGoalLayout.ApplyBindPadGrid()
    end

    local s=Settings()
    local size=Clamp(s.bindPadIconSize,28,48,1)
    local spacing=Clamp(s.bindPadIconSpacing,2,14,1)
    local columns=Clamp(s.bindPadColumns,5,9,1)
    s.bindPadIconSize=size
    s.bindPadIconSpacing=spacing
    s.bindPadColumns=columns

    local slots=GetSlots()
    if #slots==0 then return end

    local cell=size+spacing

    for index,b in ipairs(slots) do
        local col=(index-1)%columns
        local row=math.floor((index-1)/columns)

        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",BindPadSlotButtonContainer,"TOPLEFT",col*cell,-row*cell)
        b:SetSize(size,size)

        if b.icon then
            b.icon:ClearAllPoints()
            b.icon:SetAllPoints(b)
            b.icon:SetTexCoord(.07,.93,.07,.93)
        end

        if b.addbutton then
            local add=math.max(12,math.floor(size*.42))
            b.addbutton:SetSize(add,add)
        end

        if b.hotkey then
            b.hotkey:SetWidth(size+4)
        end
        if b.name then
            b.name:SetWidth(size+4)
        end
    end

    local rows=math.ceil(#slots/columns)
    local width=columns*size + math.max(0,columns-1)*spacing
    local height=rows*size + math.max(0,rows-1)*spacing

    BindPadSlotButtonContainer:SetWidth(math.max(285,width))
    BindPadSlotButtonContainer:SetHeight(height+42)

    if BindPadScrollFrameFooter then
        BindPadScrollFrameFooter:ClearAllPoints()
        BindPadScrollFrameFooter:SetPoint("TOPLEFT",BindPadSlotButtonContainer,"TOPLEFT",0,-height-6)
        BindPadScrollFrameFooter:SetWidth(math.max(285,width))
    end

    -- Give wider custom grids room without resizing the outer window wildly.
    if BindPadScrollFrame then
        local available=350
        if width > available then
            -- Fit oversized grids by scaling only the slot container.
            BindPadSlotButtonContainer:SetScale(available/width)
        else
            BindPadSlotButtonContainer:SetScale(1)
        end
    end
end

_G.BPMM_ApplyBindPadGrid = ApplyGrid

-- ============================================================
-- Extend retired settings UI
-- ============================================================

local function MakeSlider(parent,label,minv,maxv,step)
    local holder=CreateFrame("Frame",nil,parent)
    holder:SetSize(320,48)

    local title=holder:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    title:SetPoint("TOPLEFT",0,0)
    title:SetText(label)

    local value=holder:CreateFontString(nil,"OVERLAY","GameFontNormal")
    value:SetPoint("TOPRIGHT",0,0)

    local slider=CreateFrame("Slider",nil,holder,"OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",0,-20)
    slider:SetPoint("TOPRIGHT",0,-20)
    slider:SetMinMaxValues(minv,maxv)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    if slider.Low then slider.Low:SetText(tostring(minv)) end
    if slider.High then slider.High:SetText(tostring(maxv)) end
    if slider.Text then slider.Text:SetText("") end

    holder.Slider=slider
    holder.ValueText=value
    return holder
end

local function InstallSettingsControls()
    local panel=_G.BPMMSettingsPanel
    if not panel or panel.__BPMMGridControls then return end
    panel.__BPMMGridControls=true

    panel:SetHeight(470)

    local sep=panel:CreateTexture(nil,"ARTWORK")
    sep:SetColorTexture(.16,.16,.18,1)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",24,-236)
    sep:SetPoint("TOPRIGHT",-24,-236)

    local heading=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    heading:SetPoint("TOPLEFT",28,-252)
    heading:SetText("BetterBind Grid")

    local iconSize=MakeSlider(panel,"Icon Size",28,48,1)
    iconSize:SetPoint("TOPLEFT",28,-276)

    local spacing=MakeSlider(panel,"Icon Spacing",2,14,1)
    spacing:SetPoint("TOPLEFT",28,-332)

    local columns=MakeSlider(panel,"Icons Per Row",5,9,1)
    columns:SetPoint("TOPLEFT",28,-388)

    panel.__BPMMIconSize=iconSize
    panel.__BPMMIconSpacing=spacing
    panel.__BPMMColumns=columns

    local oldRefresh=panel.Refresh
    panel.Refresh=function(self,...)
        if oldRefresh then oldRefresh(self,...) end
        local s=Settings()

        iconSize.Slider:SetValue(s.bindPadIconSize)
        iconSize.ValueText:SetText(s.bindPadIconSize.." px")

        spacing.Slider:SetValue(s.bindPadIconSpacing)
        spacing.ValueText:SetText(s.bindPadIconSpacing.." px")

        columns.Slider:SetValue(s.bindPadColumns)
        columns.ValueText:SetText(tostring(s.bindPadColumns))
    end

    iconSize.Slider:SetScript("OnValueChanged",function(_,v)
        local s=Settings()
        s.bindPadIconSize=Clamp(v,28,48,1)
        iconSize.ValueText:SetText(s.bindPadIconSize.." px")
        ApplyGrid()
    end)

    spacing.Slider:SetScript("OnValueChanged",function(_,v)
        local s=Settings()
        s.bindPadIconSpacing=Clamp(v,2,14,1)
        spacing.ValueText:SetText(s.bindPadIconSpacing.." px")
        ApplyGrid()
    end)

    columns.Slider:SetScript("OnValueChanged",function(_,v)
        local s=Settings()
        s.bindPadColumns=Clamp(v,5,9,1)
        columns.ValueText:SetText(tostring(s.bindPadColumns))
        ApplyGrid()
    end)

    panel:HookScript("OnShow",function(self)
        self:Refresh()
    end)
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    Settings()
    C_Timer.After(.2,function()
        InstallSettingsControls()
        ApplyGrid()
    end)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,ApplyGrid)
        C_Timer.After(.1,ApplyGrid)
    end)
end

for _,name in ipairs({"BindPadShowMoreSlotButton","BindPadShowLessSlotButton"}) do
    local b=_G[name]
    if b then
        b:HookScript("OnClick",function()
            C_Timer.After(0,ApplyGrid)
            C_Timer.After(.1,ApplyGrid)
        end)
    end
end
end
-- END CONSOLIDATED: GridSettings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: AppearanceSettings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.3
-- Window/background customization + settings-panel polish.
-- Presentation only. No macro/binding/profile assignment logic is modified.

local DEFAULTS = {
    bindPadOpacity = 0.98,
    megaMacroOpacity = 0.98,
    showProfileRow = true,
}

local function Settings()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    local s = BindPadVars.BPMMSettings

    for k,v in pairs(DEFAULTS) do
        if s[k] == nil then
            s[k] = v
        end
    end

    return s
end

local function Clamp(v,minv,maxv,step)
    v = tonumber(v) or minv
    v = math.max(minv,math.min(maxv,v))
    if step then
        v = math.floor((v/step)+0.5)*step
    end
    return v
end

local function ApplyShellOpacity(frame, alpha)
    if not frame then return end
    alpha = Clamp(alpha,0.40,1.00,0.01)

    if frame.__BPMMShell and frame.__BPMMShell.SetBackdropColor then
        frame.__BPMMShell:SetBackdropColor(.035,.035,.040,alpha)
    end

    -- Keep the internal panel legible without making child icons/text transparent.
    if frame.Inset and frame.Inset.__BPMMInsetBG and frame.Inset.__BPMMInsetBG.SetBackdropColor then
        frame.Inset.__BPMMInsetBG:SetBackdropColor(.060,.060,.070,math.max(.60,alpha))
    end
end

local function ApplyProfileVisibility()
    local show = Settings().showProfileRow

    for i=1,5 do
        local b=_G["BindPadProfileTab"..i]
        if b then
            if show then
                b:Show()
            else
                b:Hide()
            end
        end
    end
end

local function ApplyAppearance()
    local s=Settings()
    ApplyShellOpacity(BindPadFrame,s.bindPadOpacity)
    ApplyShellOpacity(MegaMacro_Frame,s.megaMacroOpacity)
    ApplyProfileVisibility()
end

_G.BPMM_ApplyStage63Appearance = ApplyAppearance

-- ============================================================
-- Settings panel extension
-- ============================================================

local function MakeSlider(parent,label,minv,maxv,step)
    local holder=CreateFrame("Frame",nil,parent)
    holder:SetSize(320,48)

    local title=holder:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    title:SetPoint("TOPLEFT",0,0)
    title:SetText(label)

    local value=holder:CreateFontString(nil,"OVERLAY","GameFontNormal")
    value:SetPoint("TOPRIGHT",0,0)

    local slider=CreateFrame("Slider",nil,holder,"OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",0,-20)
    slider:SetPoint("TOPRIGHT",0,-20)
    slider:SetMinMaxValues(minv,maxv)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    if slider.Low then slider.Low:SetText(math.floor(minv*100).."%") end
    if slider.High then slider.High:SetText(math.floor(maxv*100).."%") end
    if slider.Text then slider.Text:SetText("") end

    holder.Slider=slider
    holder.ValueText=value
    return holder
end

local function MakeCheckbox(parent,label)
    local c=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    c:SetSize(22,22)

    local text=c:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("LEFT",c,"RIGHT",4,0)
    text:SetText(label)
    c.Label=text
    return c
end

local function InstallControls()
    local panel=_G.BPMMSettingsPanel
    if not panel or panel.__BPMMStage63 then return end
    panel.__BPMMStage63=true

    -- Stage 6.2 uses a taller panel already. Extend it slightly and keep
    -- everything in one scroll-free settings window.
    panel:SetHeight(620)

    local sep=panel:CreateTexture(nil,"ARTWORK")
    sep:SetColorTexture(.16,.16,.18,1)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",24,-448)
    sep:SetPoint("TOPRIGHT",-24,-448)

    local heading=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    heading:SetPoint("TOPLEFT",28,-464)
    heading:SetText("Appearance")

    local bindOpacity=MakeSlider(panel,"BetterBind Background Opacity",0.40,1.00,0.05)
    bindOpacity:SetPoint("TOPLEFT",28,-488)

    local megaOpacity=MakeSlider(panel,"BetterMacro Background Opacity",0.40,1.00,0.05)
    megaOpacity:SetPoint("TOPLEFT",28,-544)

    local profiles=MakeCheckbox(panel,"Show specialization profile row")
    profiles:SetPoint("BOTTOMLEFT",28,18)

    -- Move the existing Reset/Done buttons slightly upward/right so they don't
    -- collide with the new checkbox.
    for _,child in ipairs({panel:GetChildren()}) do
        if child and child.Text and child.Text.GetText then
            local text=child.Text:GetText()
            if text=="Reset UI" then
                child:ClearAllPoints()
                child:SetPoint("BOTTOMRIGHT",-150,16)
            elseif text=="Done" then
                child:ClearAllPoints()
                child:SetPoint("BOTTOMRIGHT",-28,16)
            end
        end
    end

    local oldRefresh=panel.Refresh
    panel.Refresh=function(self,...)
        if oldRefresh then oldRefresh(self,...) end

        local s=Settings()
        bindOpacity.Slider:SetValue(s.bindPadOpacity)
        megaOpacity.Slider:SetValue(s.megaMacroOpacity)

        bindOpacity.ValueText:SetText(math.floor(s.bindPadOpacity*100+0.5).."%")
        megaOpacity.ValueText:SetText(math.floor(s.megaMacroOpacity*100+0.5).."%")
        profiles:SetChecked(s.showProfileRow and true or false)
    end

    bindOpacity.Slider:SetScript("OnValueChanged",function(_,v)
        local s=Settings()
        s.bindPadOpacity=Clamp(v,0.40,1.00,0.05)
        bindOpacity.ValueText:SetText(math.floor(s.bindPadOpacity*100+0.5).."%")
        ApplyShellOpacity(BindPadFrame,s.bindPadOpacity)
    end)

    megaOpacity.Slider:SetScript("OnValueChanged",function(_,v)
        local s=Settings()
        s.megaMacroOpacity=Clamp(v,0.40,1.00,0.05)
        megaOpacity.ValueText:SetText(math.floor(s.megaMacroOpacity*100+0.5).."%")
        ApplyShellOpacity(MegaMacro_Frame,s.megaMacroOpacity)
    end)

    profiles:SetScript("OnClick",function(self)
        Settings().showProfileRow=self:GetChecked() and true or false
        ApplyProfileVisibility()
    end)

    panel:HookScript("OnShow",function(self)
        self:Refresh()
    end)
end

-- Extend Reset UI behavior without replacing Stage 6.1's function.
local function ResetStage63()
    local s=Settings()
    s.bindPadOpacity=DEFAULTS.bindPadOpacity
    s.megaMacroOpacity=DEFAULTS.megaMacroOpacity
    s.showProfileRow=DEFAULTS.showProfileRow
    ApplyAppearance()
end

local function HookResetButton()
    local panel=_G.BPMMSettingsPanel
    if not panel or panel.__BPMMStage63ResetHook then return end

    for _,child in ipairs({panel:GetChildren()}) do
        if child and child.Text and child.Text.GetText and child.Text:GetText()=="Reset UI" then
            child.__BPMMStage63ResetHook=true
            panel.__BPMMStage63ResetHook=true
            child:HookScript("OnClick",function()
                ResetStage63()
                C_Timer.After(0,function()
                    if panel.Refresh then panel:Refresh() end
                end)
            end)
            break
        end
    end
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    Settings()
    C_Timer.After(.2,function()
        InstallControls()
        HookResetButton()
        ApplyAppearance()
    end)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,ApplyAppearance)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,ApplyAppearance)
    end)
end
end
-- END CONSOLIDATED: AppearanceSettings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: CompactSettings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.3.1
-- Compact retired settings UI rebuild.
-- Replaces the stacked Blizzard sliders with compact horizontal rows and
-- custom wheel-enabled line controls.

local function S()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    local s=BindPadVars.BPMMSettings
    local d={
        bindPadScale=1.00, megaMacroScale=1.00, linkedWindows=false,
        bindPadIconSize=36, bindPadIconSpacing=6, bindPadColumns=7,
        bindPadOpacity=.98, megaMacroOpacity=.98, showProfileRow=true,
    }
    for k,v in pairs(d) do if s[k]==nil then s[k]=v end end
    return s
end

local function clamp(v,a,b,step)
    v=tonumber(v) or a
    v=math.max(a,math.min(b,v))
    if step then v=math.floor((v-a)/step+.5)*step+a end
    return v
end

local function Apply(key)
    local s=S()
    if key=="bindPadScale" and BindPadFrame then
        BindPadFrame:SetScale(s.bindPadScale)
    elseif key=="megaMacroScale" and MegaMacro_Frame then
        MegaMacro_Frame:SetScale(s.megaMacroScale)
    elseif key=="bindPadIconSize" or key=="bindPadIconSpacing" or key=="bindPadColumns" then
        if BPMM_ApplyBindPadGrid then BPMM_ApplyBindPadGrid() end
    elseif key=="bindPadOpacity" or key=="megaMacroOpacity" or key=="showProfileRow" then
        if BPMM_ApplyStage63Appearance then BPMM_ApplyStage63Appearance() end
    end
end

local function HideOldPanel()
    local p=_G.BPMMSettingsPanel
    if p then p:Hide() end
end

local C={
    bg={.025,.025,.030,.985},
    panel={.055,.055,.065,1},
    line={.20,.20,.23,1},
    accent={.92,.72,.08,1},
    text={.94,.94,.96,1},
    muted={.58,.58,.63,1},
}

local function backdrop(f,border)
    f:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    f:SetBackdropColor(unpack(C.bg))
    if border then f:SetBackdropBorderColor(unpack(C.line)) end
end

local panel=CreateFrame("Frame","BPMMCompactSettingsPanel",UIParent,"BackdropTemplate")
panel:SetSize(610,438)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()
backdrop(panel,true)

panel:SetScript("OnDragStart",function(self)
    if not InCombatLockdown() then self:StartMoving() end
end)
panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)

local title=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
title:SetPoint("TOPLEFT",18,-15)
title:SetText("BetterBind + BetterMacro")

local sub=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
sub:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-3)
sub:SetText("UI Settings")
sub:SetTextColor(unpack(C.muted))

-- clean close button, aligned to the panel's top-right inset
local close=CreateFrame("Button",nil,panel)
close:SetSize(24,24)
close:SetPoint("TOPRIGHT",-10,-10)
close:EnableMouse(true)
local l1=close:CreateTexture(nil,"ARTWORK")
l1:SetColorTexture(.82,.82,.86,1)
l1:SetSize(13,1)
l1:SetPoint("CENTER")
l1:SetRotation(math.rad(45))
local l2=close:CreateTexture(nil,"ARTWORK")
l2:SetColorTexture(.82,.82,.86,1)
l2:SetSize(13,1)
l2:SetPoint("CENTER")
l2:SetRotation(math.rad(-45))
close:SetScript("OnEnter",function()
    l1:SetColorTexture(1,.82,.15,1); l2:SetColorTexture(1,.82,.15,1)
end)
close:SetScript("OnLeave",function()
    l1:SetColorTexture(.82,.82,.86,1); l2:SetColorTexture(.82,.82,.86,1)
end)
close:SetScript("OnClick",function() panel:Hide() end)

local function section(text,y)
    local fs=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("TOPLEFT",18,y)
    fs:SetText(text)
    fs:SetTextColor(unpack(C.accent))
    local line=panel:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("LEFT",fs,"RIGHT",10,0)
    line:SetPoint("RIGHT",panel,"RIGHT",-18,0)
end

-- Arrow/line control:
-- < -------------o------------- >
-- mouse wheel anywhere over it adjusts one step.
local controls={}
local function lineControl(label,key,minv,maxv,step,formatter,y)
    local row=CreateFrame("Frame",nil,panel)
    row:SetSize(574,34)
    row:SetPoint("TOPLEFT",18,y)

    local lab=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    lab:SetPoint("LEFT",0,0)
    lab:SetWidth(205)
    lab:SetJustifyH("LEFT")
    lab:SetText(label)

    local value=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    value:SetPoint("RIGHT",0,0)
    value:SetWidth(62)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(unpack(C.accent))

    local track=CreateFrame("Frame",nil,row)
    track:SetPoint("LEFT",lab,"RIGHT",10,0)
    track:SetPoint("RIGHT",value,"LEFT",-10,0)
    track:SetHeight(24)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)

    local left=track:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    left:SetPoint("LEFT",0,0)
    left:SetText("<")
    left:SetTextColor(unpack(C.accent))

    local right=track:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    right:SetPoint("RIGHT",0,0)
    right:SetText(">")
    right:SetTextColor(unpack(C.accent))

    local line=track:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(unpack(C.accent))
    line:SetHeight(2)
    line:SetPoint("LEFT",left,"RIGHT",7,0)
    line:SetPoint("RIGHT",right,"LEFT",-7,0)

    local knob=track:CreateTexture(nil,"OVERLAY")
    knob:SetColorTexture(.96,.96,.98,1)
    knob:SetSize(5,12)

    local function refresh()
        local v=clamp(S()[key],minv,maxv,step)
        S()[key]=v
        value:SetText(formatter(v))
        local usable=math.max(1,track:GetWidth()-38)
        local t=(v-minv)/(maxv-minv)
        knob:ClearAllPoints()
        knob:SetPoint("CENTER",track,"LEFT",19+t*usable,0)
    end

    local function set(v)
        S()[key]=clamp(v,minv,maxv,step)
        refresh()
        Apply(key)
    end

    track:SetScript("OnMouseWheel",function(_,delta)
        set(S()[key] + (delta>0 and step or -step))
    end)
    track:SetScript("OnMouseDown",function(self,button)
        if button~="LeftButton" then return end
        local x=GetCursorPosition()/self:GetEffectiveScale()
        local leftEdge=self:GetLeft()+19
        local usable=math.max(1,self:GetWidth()-38)
        set(minv + math.max(0,math.min(1,(x-leftEdge)/usable))*(maxv-minv))
    end)
    track:SetScript("OnEnter",function()
        line:SetHeight(3)
        left:SetTextColor(1,.86,.28,1); right:SetTextColor(1,.86,.28,1)
    end)
    track:SetScript("OnLeave",function()
        line:SetHeight(2)
        left:SetTextColor(unpack(C.accent)); right:SetTextColor(unpack(C.accent))
    end)

    row.Refresh=refresh
    controls[#controls+1]=row
    return row
end

local function checkRow(label,key,y,applyKey)
    local row=CreateFrame("Button",nil,panel)
    row:SetSize(574,32)
    row:SetPoint("TOPLEFT",18,y)

    local box=CreateFrame("Frame",nil,row,"BackdropTemplate")
    box:SetSize(16,16)
    box:SetPoint("RIGHT",-1,0)
    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    box:SetBackdropColor(.025,.025,.03,1)
    box:SetBackdropBorderColor(.28,.28,.32,1)

    local tick=box:CreateFontString(nil,"OVERLAY","GameFontNormal")
    tick:SetPoint("CENTER",0,1)
    tick:SetText("x")
    tick:SetTextColor(unpack(C.accent))

    local lab=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    lab:SetPoint("LEFT",0,0)
    lab:SetText(label)

    local function refresh() tick:SetShown(S()[key] and true or false) end
    row:SetScript("OnClick",function()
        S()[key]=not S()[key]
        refresh()
        if applyKey then Apply(applyKey) end
    end)
    row:SetScript("OnEnter",function() lab:SetTextColor(1,.86,.28,1) end)
    row:SetScript("OnLeave",function() lab:SetTextColor(unpack(C.text)) end)
    row.Refresh=refresh
    controls[#controls+1]=row
end

section("WINDOWS",-66)
lineControl("BetterBind UI Scale","bindPadScale",.70,1.40,.05,function(v) return math.floor(v*100+.5).."%" end,-84)
lineControl("BetterMacro UI Scale","megaMacroScale",.70,1.40,.05,function(v) return math.floor(v*100+.5).."%" end,-116)
checkRow("Move both windows together","linkedWindows",-148)

section("BINDPAD GRID",-190)
lineControl("Icon Size","bindPadIconSize",28,48,1,function(v) return math.floor(v+.5).." px" end,-208)
lineControl("Icon Spacing","bindPadIconSpacing",2,14,1,function(v) return math.floor(v+.5).." px" end,-240)
lineControl("Icons Per Row","bindPadColumns",5,9,1,function(v) return tostring(math.floor(v+.5)) end,-272)

section("APPEARANCE",-314)
lineControl("BetterBind Background","bindPadOpacity",.40,1.00,.05,function(v) return math.floor(v*100+.5).."%" end,-332)
lineControl("BetterMacro Background","megaMacroOpacity",.40,1.00,.05,function(v) return math.floor(v*100+.5).."%" end,-364)
checkRow("Show specialization profile row","showProfileRow",-396,"showProfileRow")

local reset=CreateFrame("Button",nil,panel,"BackdropTemplate")
reset:SetSize(94,24)
reset:SetPoint("BOTTOMLEFT",18,10)
reset:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
reset:SetBackdropColor(.07,.07,.08,1)
reset:SetBackdropBorderColor(.22,.22,.25,1)
local rt=reset:CreateFontString(nil,"OVERLAY","GameFontNormal")
rt:SetPoint("CENTER"); rt:SetText("Reset UI")
reset:SetScript("OnClick",function()
    local s=S()
    s.bindPadScale=1; s.megaMacroScale=1; s.linkedWindows=false
    s.bindPadIconSize=36; s.bindPadIconSpacing=6; s.bindPadColumns=7
    s.bindPadOpacity=.98; s.megaMacroOpacity=.98; s.showProfileRow=true
    Apply("bindPadScale"); Apply("megaMacroScale"); Apply("bindPadIconSize")
    Apply("bindPadOpacity"); Apply("megaMacroOpacity"); Apply("showProfileRow")
    for _,c in ipairs(controls) do if c.Refresh then c:Refresh() end end
end)

local done=CreateFrame("Button",nil,panel,"BackdropTemplate")
done:SetSize(94,24)
done:SetPoint("BOTTOMRIGHT",-18,10)
done:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
done:SetBackdropColor(.07,.07,.08,1)
done:SetBackdropBorderColor(.22,.22,.25,1)
local dt=done:CreateFontString(nil,"OVERLAY","GameFontNormal")
dt:SetPoint("CENTER"); dt:SetText("Done")
done:SetScript("OnClick",function() panel:Hide() end)

function panel:Refresh()
    for _,c in ipairs(controls) do if c.Refresh then c:Refresh() end end
end

local function Toggle()
    HideOldPanel()
    if panel:IsShown() then panel:Hide() else panel:Refresh(); panel:Show() end
end

-- Replace only the slash handlers; old settings code remains intact for persistence/apply hooks.
-- No slash registration: BetterBind has no settings window command.

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.25,function()
        HideOldPanel()
        panel:Refresh()
    end)
end)
end
-- END CONSOLIDATED: CompactSettings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: ScrollableSettings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.3.2
-- Scrollable compact settings panel.
-- Keeps the current visual language but separates fixed footer buttons
-- from a scrollable content area for future settings growth.

local old = _G.BPMMCompactSettingsPanel
if old then old:Hide() end

local function S()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    local s=BindPadVars.BPMMSettings
    local d={
        bindPadScale=1.00, megaMacroScale=1.00, linkedWindows=false,
        bindPadIconSize=36, bindPadIconSpacing=6, bindPadColumns=7,
        bindPadOpacity=.98, megaMacroOpacity=.98, showProfileRow=true,
    }
    for k,v in pairs(d) do if s[k]==nil then s[k]=v end end
    return s
end

local function clamp(v,a,b,step)
    v=tonumber(v) or a
    v=math.max(a,math.min(b,v))
    if step then v=math.floor((v-a)/step+.5)*step+a end
    return v
end

local function Apply(key)
    local s=S()
    if key=="bindPadScale" and BindPadFrame then
        BindPadFrame:SetScale(s.bindPadScale)
    elseif key=="megaMacroScale" and MegaMacro_Frame then
        MegaMacro_Frame:SetScale(s.megaMacroScale)
    elseif key=="bindPadIconSize" or key=="bindPadIconSpacing" or key=="bindPadColumns" then
        if BPMM_ApplyBindPadGrid then BPMM_ApplyBindPadGrid() end
    elseif key=="bindPadOpacity" or key=="megaMacroOpacity" or key=="showProfileRow" then
        if BPMM_ApplyStage63Appearance then BPMM_ApplyStage63Appearance() end
    end
end

local C={
    bg={.025,.025,.030,.985},
    line={.20,.20,.23,1},
    accent={.92,.72,.08,1},
    text={.94,.94,.96,1},
    muted={.58,.58,.63,1},
}

local panel=CreateFrame("Frame","BPMMScrollableSettingsPanel",UIParent,"BackdropTemplate")
panel:SetSize(590,430)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()
panel:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8x8",
    edgeFile="Interface\\Buttons\\WHITE8x8",
    edgeSize=1,
})
panel:SetBackdropColor(unpack(C.bg))
panel:SetBackdropBorderColor(0,0,0,1)

panel:SetScript("OnDragStart",function(self)
    if not InCombatLockdown() then self:StartMoving() end
end)
panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)

local title=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
title:SetPoint("TOPLEFT",18,-14)
title:SetText("BetterBind + BetterMacro")

local sub=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
sub:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-3)
sub:SetText("UI Settings")
sub:SetTextColor(unpack(C.muted))

local close=CreateFrame("Button",nil,panel)
close:SetSize(22,22)
close:SetPoint("TOPRIGHT",-10,-10)
local l1=close:CreateTexture(nil,"ARTWORK")
l1:SetColorTexture(.82,.82,.86,1); l1:SetSize(12,1); l1:SetPoint("CENTER"); l1:SetRotation(math.rad(45))
local l2=close:CreateTexture(nil,"ARTWORK")
l2:SetColorTexture(.82,.82,.86,1); l2:SetSize(12,1); l2:SetPoint("CENTER"); l2:SetRotation(math.rad(-45))
close:SetScript("OnClick",function() panel:Hide() end)
close:SetScript("OnEnter",function()
    l1:SetColorTexture(1,.82,.15,1); l2:SetColorTexture(1,.82,.15,1)
end)
close:SetScript("OnLeave",function()
    l1:SetColorTexture(.82,.82,.86,1); l2:SetColorTexture(.82,.82,.86,1)
end)

-- fixed footer
local footer=CreateFrame("Frame",nil,panel)
footer:SetPoint("BOTTOMLEFT",0,0)
footer:SetPoint("BOTTOMRIGHT",0,0)
footer:SetHeight(44)

local divider=footer:CreateTexture(nil,"ARTWORK")
divider:SetColorTexture(unpack(C.line))
divider:SetHeight(1)
divider:SetPoint("TOPLEFT",18,0)
divider:SetPoint("TOPRIGHT",-18,0)

local function smallButton(parent,text)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(94,24)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    b:SetBackdropColor(.07,.07,.08,1)
    b:SetBackdropBorderColor(.22,.22,.25,1)
    local fs=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(.92,.92,.94,1)
    b.Text=fs
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.22,.22,.25,1) end)
    return b
end

local reset=smallButton(footer,"Reset UI")
reset:SetPoint("BOTTOMLEFT",18,10)

local done=smallButton(footer,"Done")
done:SetPoint("BOTTOMRIGHT",-18,10)
done:SetScript("OnClick",function() panel:Hide() end)

-- scroll viewport
local scroll=CreateFrame("ScrollFrame",nil,panel)
scroll:SetPoint("TOPLEFT",0,-58)
scroll:SetPoint("BOTTOMRIGHT",-14,50)
scroll:EnableMouseWheel(true)

local child=CreateFrame("Frame",nil,scroll)
child:SetSize(560,560)
scroll:SetScrollChild(child)

local thumbTrack=CreateFrame("Frame",nil,panel,"BackdropTemplate")
thumbTrack:SetPoint("TOPRIGHT",-5,-66)
thumbTrack:SetPoint("BOTTOMRIGHT",-5,54)
thumbTrack:SetWidth(6)
thumbTrack:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
thumbTrack:SetBackdropColor(.07,.07,.08,.55)

local thumb=thumbTrack:CreateTexture(nil,"ARTWORK")
thumb:SetColorTexture(.34,.34,.38,1)
thumb:SetWidth(6)

local function updateThumb()
    local range=scroll:GetVerticalScrollRange() or 0
    local h=thumbTrack:GetHeight()
    if range<=0 then
        thumb:Hide()
        return
    end
    thumb:Show()
    local viewport=scroll:GetHeight()
    local content=viewport+range
    local th=math.max(28,h*(viewport/content))
    local pos=(scroll:GetVerticalScroll()/range)*(h-th)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP",thumbTrack,"TOP",0,-pos)
end

scroll:SetScript("OnMouseWheel",function(self,delta)
    local range=self:GetVerticalScrollRange() or 0
    if range<=0 then return end
    local target=self:GetVerticalScroll()-(delta*42)
    target=math.max(0,math.min(range,target))
    self:SetVerticalScroll(target)
    updateThumb()
end)

local controls={}
local function section(text,y)
    local fs=child:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fs:SetPoint("TOPLEFT",18,y)
    fs:SetText(text)
    fs:SetTextColor(unpack(C.accent))
    local line=child:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("LEFT",fs,"RIGHT",10,0)
    line:SetPoint("RIGHT",child,"RIGHT",-18,0)
end

local function lineControl(label,key,minv,maxv,step,formatter,y)
    local row=CreateFrame("Frame",nil,child)
    row:SetSize(524,34)
    row:SetPoint("TOPLEFT",18,y)

    local lab=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    lab:SetPoint("LEFT",0,0)
    lab:SetWidth(190)
    lab:SetJustifyH("LEFT")
    lab:SetText(label)

    local value=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    value:SetPoint("RIGHT",0,0)
    value:SetWidth(60)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(unpack(C.accent))

    local track=CreateFrame("Frame",nil,row)
    track:SetPoint("LEFT",lab,"RIGHT",8,0)
    track:SetPoint("RIGHT",value,"LEFT",-8,0)
    track:SetHeight(24)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)

    local left=track:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    left:SetPoint("LEFT",0,0); left:SetText("<"); left:SetTextColor(unpack(C.accent))
    local right=track:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    right:SetPoint("RIGHT",0,0); right:SetText(">"); right:SetTextColor(unpack(C.accent))

    local line=track:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(unpack(C.accent))
    line:SetHeight(2)
    line:SetPoint("LEFT",left,"RIGHT",7,0)
    line:SetPoint("RIGHT",right,"LEFT",-7,0)

    local knob=track:CreateTexture(nil,"OVERLAY")
    knob:SetColorTexture(.96,.96,.98,1)
    knob:SetSize(5,12)

    local function refresh()
        local v=clamp(S()[key],minv,maxv,step)
        S()[key]=v
        value:SetText(formatter(v))
        local usable=math.max(1,track:GetWidth()-38)
        local t=(v-minv)/(maxv-minv)
        knob:ClearAllPoints()
        knob:SetPoint("CENTER",track,"LEFT",19+t*usable,0)
    end

    local function set(v)
        S()[key]=clamp(v,minv,maxv,step)
        refresh()
        Apply(key)
    end

    track:SetScript("OnMouseWheel",function(_,delta)
        set(S()[key]+(delta>0 and step or -step))
    end)
    track:SetScript("OnMouseDown",function(self,button)
        if button~="LeftButton" then return end
        local x=GetCursorPosition()/self:GetEffectiveScale()
        local leftEdge=self:GetLeft()+19
        local usable=math.max(1,self:GetWidth()-38)
        set(minv+math.max(0,math.min(1,(x-leftEdge)/usable))*(maxv-minv))
    end)
    track:SetScript("OnEnter",function()
        line:SetHeight(3)
        left:SetTextColor(1,.86,.28,1); right:SetTextColor(1,.86,.28,1)
    end)
    track:SetScript("OnLeave",function()
        line:SetHeight(2)
        left:SetTextColor(unpack(C.accent)); right:SetTextColor(unpack(C.accent))
    end)

    row.Refresh=refresh
    controls[#controls+1]=row
end

local function checkRow(label,key,y,applyKey)
    local row=CreateFrame("Button",nil,child)
    row:SetSize(524,32)
    row:SetPoint("TOPLEFT",18,y)

    local lab=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    lab:SetPoint("LEFT",0,0)
    lab:SetText(label)

    local box=CreateFrame("Frame",nil,row,"BackdropTemplate")
    box:SetSize(16,16)
    box:SetPoint("RIGHT",-1,0)
    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    box:SetBackdropColor(.025,.025,.03,1)
    box:SetBackdropBorderColor(.28,.28,.32,1)

    local tick=box:CreateFontString(nil,"OVERLAY","GameFontNormal")
    tick:SetPoint("CENTER",0,1)
    tick:SetText("x")
    tick:SetTextColor(unpack(C.accent))

    local function refresh() tick:SetShown(S()[key] and true or false) end
    row:SetScript("OnClick",function()
        S()[key]=not S()[key]
        refresh()
        if applyKey then Apply(applyKey) end
    end)
    row.Refresh=refresh
    controls[#controls+1]=row
end

section("WINDOWS",-6)
lineControl("BetterBind UI Scale","bindPadScale",.70,1.40,.05,function(v) return math.floor(v*100+.5).."%" end,-24)
lineControl("BetterMacro UI Scale","megaMacroScale",.70,1.40,.05,function(v) return math.floor(v*100+.5).."%" end,-56)
checkRow("Move both windows together","linkedWindows",-88)

section("BINDPAD GRID",-132)
lineControl("Icon Size","bindPadIconSize",28,48,1,function(v) return math.floor(v+.5).." px" end,-150)
lineControl("Icon Spacing","bindPadIconSpacing",2,14,1,function(v) return math.floor(v+.5).." px" end,-182)
lineControl("Icons Per Row","bindPadColumns",5,9,1,function(v) return tostring(math.floor(v+.5)) end,-214)

section("APPEARANCE",-258)
lineControl("BetterBind Background","bindPadOpacity",.40,1.00,.05,function(v) return math.floor(v*100+.5).."%" end,-276)
lineControl("BetterMacro Background","megaMacroOpacity",.40,1.00,.05,function(v) return math.floor(v*100+.5).."%" end,-308)
checkRow("Show specialization profile row","showProfileRow",-340,"showProfileRow")

-- intentional extra space at bottom for future settings
child:SetHeight(430)

local function refreshAll()
    for _,c in ipairs(controls) do if c.Refresh then c:Refresh() end end
    C_Timer.After(0,updateThumb)
end

panel:HookScript("OnShow",function()
    refreshAll()
    scroll:SetVerticalScroll(0)
    updateThumb()
end)

reset:SetScript("OnClick",function()
    local s=S()
    s.bindPadScale=1; s.megaMacroScale=1; s.linkedWindows=false
    s.bindPadIconSize=36; s.bindPadIconSpacing=6; s.bindPadColumns=7
    s.bindPadOpacity=.98; s.megaMacroOpacity=.98; s.showProfileRow=true
    Apply("bindPadScale"); Apply("megaMacroScale"); Apply("bindPadIconSize")
    Apply("bindPadOpacity"); Apply("megaMacroOpacity"); Apply("showProfileRow")
    refreshAll()
end)

local function Toggle()
    if old then old:Hide() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
-- No slash registration: BetterBind has no settings window command.

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.25,function()
        if old then old:Hide() end
        refreshAll()
    end)
end)
end
-- END CONSOLIDATED: ScrollableSettings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: CheckmarkFix.lua
-- ============================================================
do
-- Stage 6.3.3
-- Fixes compact settings checkbox placement/appearance.
-- Loaded after ScrollableSettings.lua.

local function PatchCheckbox()
    local panel=_G.BPMMScrollableSettingsPanel
    if not panel then return end

    -- Find the scroll child.
    local scroll
    for _,f in ipairs({panel:GetChildren()}) do
        if f.GetScrollChild and f:GetScrollChild() then
            scroll=f
            break
        end
    end
    if not scroll then return end

    local child=scroll:GetScrollChild()
    if not child then return end

    -- Find the row containing the specialization setting by its FontString.
    for _,row in ipairs({child:GetChildren()}) do
        local label
        for _,region in ipairs({row:GetRegions()}) do
            if region.GetText and region:GetText()=="Show specialization profile row" then
                label=region
                break
            end
        end

        if label then
            -- Find the existing 16x16 checkbox frame.
            for _,box in ipairs({row:GetChildren()}) do
                local w,h=box:GetSize()
                if w and h and math.abs(w-16)<1 and math.abs(h-16)<1 then
                    box:ClearAllPoints()
                    box:SetPoint("LEFT",label,"RIGHT",10,0)
                    box:SetSize(16,16)

                    -- Make the box square and clearly visible.
                    if box.SetBackdrop then
                        box:SetBackdrop({
                            bgFile="Interface\\Buttons\\WHITE8x8",
                            edgeFile="Interface\\Buttons\\WHITE8x8",
                            edgeSize=1,
                        })
                        box:SetBackdropColor(.025,.025,.03,1)
                        box:SetBackdropBorderColor(.36,.36,.40,1)
                    end

                    -- Replace the font glyph check with two crisp gold strokes.
                    for _,region in ipairs({box:GetRegions()}) do
                        if region.GetText and region:GetText()=="x" then
                            region:SetText("")
                        end
                    end

                    if not box.__BPMMCheck1 then
                        local a=box:CreateTexture(nil,"OVERLAY")
                        a:SetColorTexture(.95,.76,.08,1)
                        a:SetSize(6,2)
                        a:SetPoint("CENTER",-2,0)
                        a:SetRotation(math.rad(-45))

                        local b=box:CreateTexture(nil,"OVERLAY")
                        b:SetColorTexture(.95,.76,.08,1)
                        b:SetSize(9,2)
                        b:SetPoint("CENTER",2,-1)
                        b:SetRotation(math.rad(45))

                        box.__BPMMCheck1=a
                        box.__BPMMCheck2=b
                    end

                    local function refreshMark()
                        local s=BindPadVars and BindPadVars.BPMMSettings
                        local shown=not s or s.showProfileRow~=false
                        box.__BPMMCheck1:SetShown(shown)
                        box.__BPMMCheck2:SetShown(shown)
                    end

                    row:HookScript("OnClick",function()
                        C_Timer.After(0,refreshMark)
                    end)
                    panel:HookScript("OnShow",refreshMark)
                    refreshMark()
                    return
                end
            end
        end
    end
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,PatchCheckbox)
end)

if BPMMScrollableSettingsPanel then
    C_Timer.After(0,PatchCheckbox)
end
end
-- END CONSOLIDATED: CheckmarkFix.lua

-- ============================================================
-- BEGIN CONSOLIDATED: BehaviorSettings.lua
-- ============================================================
do
-- BetterBind + BetterMacro Stage 6.4
-- Window behavior settings:
--  * Open BetterMacro together with /bb
--  * Remember window positions
--  * Reset window positions
-- Presentation/behavior only; macro and binding data are untouched.

local DEFAULTS = {
    openTogether = true,
    rememberWindowPositions = true,
}

local function S()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    local s = BindPadVars.BPMMSettings
    for k,v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    s.windowPositions = s.windowPositions or {}
    return s
end

local function SavePoint(frame, key)
    if not frame or not S().rememberWindowPositions then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end

    local relativeName = "UIParent"
    if relativeTo and relativeTo.GetName and relativeTo:GetName() then
        relativeName = relativeTo:GetName()
    end

    S().windowPositions[key] = {
        point = point,
        relativeTo = relativeName,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

local function RestorePoint(frame, key)
    if not frame or not S().rememberWindowPositions then return end
    local p = S().windowPositions[key]
    if not p then return end

    local relativeTo = _G[p.relativeTo or "UIParent"] or UIParent
    frame:ClearAllPoints()
    frame:SetPoint(
        p.point or "CENTER",
        relativeTo,
        p.relativePoint or p.point or "CENTER",
        p.x or 0,
        p.y or 0
    )
end

local function ResetPositions()
    S().windowPositions = {}

    if BindPadFrame then
        BindPadFrame:ClearAllPoints()
        BindPadFrame:SetPoint("CENTER", UIParent, "CENTER", -310, 0)
    end

    if MegaMacro_Frame then
        MegaMacro_Frame:ClearAllPoints()
        MegaMacro_Frame:SetPoint("CENTER", UIParent, "CENTER", 310, 0)
    end
end

_G.BPMM_SaveWindowPoint = SavePoint
_G.BPMM_RestoreWindowPoint = RestorePoint
_G.BPMM_ResetWindowPositions = ResetPositions

-- /bb integration is installed once by BehaviorSlashFix below. Keeping a
-- single wrapper avoids opening MegaMacro twice and preserves BindPad's
-- original subcommands.

-- ---------------------------------------------------------------------------
-- Movement persistence
-- ---------------------------------------------------------------------------

local function HookPosition(frame, key)
    if not frame or frame.__BPMM64PositionHook then return end
    frame.__BPMM64PositionHook = true

    frame:HookScript("OnDragStop", function(self)
        C_Timer.After(0, function()
            SavePoint(self, key)
        end)
    end)

    frame:HookScript("OnShow", function(self)
        if not self.__BPMM64Restored then
            self.__BPMM64Restored = true
            C_Timer.After(0, function()
                RestorePoint(self, key)
            end)
        end
    end)
end

-- BindPad uses a custom title-drag overlay in the merged UI, so also save its
-- final location when the left mouse button is released.
local bindReleaseWatcher = CreateFrame("Frame")
local wasDown = false
bindReleaseWatcher:SetScript("OnUpdate", function()
    local down = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
    if wasDown and not down and BindPadFrame and BindPadFrame:IsShown() then
        SavePoint(BindPadFrame, "BindPad")
    end
    wasDown = down and true or false
end)

-- ---------------------------------------------------------------------------
-- Extend the scrollable retired settings UI panel
-- ---------------------------------------------------------------------------

local C = {
    accent = {.92,.72,.08,1},
    text = {.94,.94,.96,1},
    line = {.20,.20,.23,1},
}

local function FindScrollChild(panel)
    if not panel then return end
    for _,f in ipairs({panel:GetChildren()}) do
        if f.GetScrollChild then
            local child = f:GetScrollChild()
            if child then return f, child end
        end
    end
end

local function AddBehaviorControls()
    local panel = _G.BPMMScrollableSettingsPanel
    if not panel or panel.__BPMM64 then return end

    local scroll, child = FindScrollChild(panel)
    if not child then return end
    panel.__BPMM64 = true

    child:SetHeight(560)

    local heading = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 18, -390)
    heading:SetText("BEHAVIOR")
    heading:SetTextColor(unpack(C.accent))

    local line = child:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("LEFT", heading, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", child, "RIGHT", -18, 0)

    local function checkRow(label, key, y)
        local row = CreateFrame("Button", nil, child)
        row:SetSize(524, 32)
        row:SetPoint("TOPLEFT", 18, y)

        local lab = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lab:SetPoint("LEFT", 0, 0)
        lab:SetText(label)

        local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
        box:SetSize(16,16)
        box:SetPoint("LEFT", lab, "RIGHT", 10, 0)
        box:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        box:SetBackdropColor(.025,.025,.03,1)
        box:SetBackdropBorderColor(.36,.36,.40,1)

        local a=box:CreateTexture(nil,"OVERLAY")
        a:SetColorTexture(.95,.76,.08,1)
        a:SetSize(6,2)
        a:SetPoint("CENTER",-2,0)
        a:SetRotation(math.rad(-45))

        local b=box:CreateTexture(nil,"OVERLAY")
        b:SetColorTexture(.95,.76,.08,1)
        b:SetSize(9,2)
        b:SetPoint("CENTER",2,-1)
        b:SetRotation(math.rad(45))

        local function refresh()
            local shown = S()[key] and true or false
            a:SetShown(shown)
            b:SetShown(shown)
        end

        row:SetScript("OnClick", function()
            S()[key] = not S()[key]
            refresh()
        end)

        row:SetScript("OnEnter", function()
            lab:SetTextColor(1,.86,.28,1)
        end)
        row:SetScript("OnLeave", function()
            lab:SetTextColor(unpack(C.text))
        end)

        row.Refresh = refresh
        refresh()
        return row
    end

    local openTogether = checkRow("Open BetterMacro together with /bb", "openTogether", -408)
    local remember = checkRow("Remember window positions", "rememberWindowPositions", -440)

    local reset = CreateFrame("Button", nil, child, "BackdropTemplate")
    reset:SetSize(150,24)
    reset:SetPoint("TOPLEFT", 18, -482)
    reset:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    reset:SetBackdropColor(.07,.07,.08,1)
    reset:SetBackdropBorderColor(.22,.22,.25,1)

    local text = reset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("Reset Window Positions")

    reset:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
    end)
    reset:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(.22,.22,.25,1)
    end)
    reset:SetScript("OnClick", function()
        ResetPositions()
    end)

    panel:HookScript("OnShow", function()
        openTogether:Refresh()
        remember:Refresh()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    S()

    C_Timer.After(.1, function()
        HookPosition(BindPadFrame, "BindPad")
        HookPosition(MegaMacro_Frame, "MegaMacro")
        RestorePoint(BindPadFrame, "BindPad")
        RestorePoint(MegaMacro_Frame, "MegaMacro")
    end)

    C_Timer.After(.4, AddBehaviorControls)
end)
end
-- END CONSOLIDATED: BehaviorSettings.lua

-- ============================================================
-- BEGIN CONSOLIDATED: BehaviorSlashFix.lua
-- ============================================================
do
-- Stage 6.4.2 slash wrapper guard.
-- Uses a normal local boolean instead of trying to store fields on a function.

local wrapperInstalled = false
local previousBindPadSlash

local function Settings64()
    BindPadVars = BindPadVars or {}
    BindPadVars.BPMMSettings = BindPadVars.BPMMSettings or {}
    if BindPadVars.BPMMSettings.openTogether == nil then
        BindPadVars.BPMMSettings.openTogether = true
    end
    return BindPadVars.BPMMSettings
end

local function AlignMainWindows()
    if not BindPadFrame or not MegaMacro_Frame
        or not BindPadFrame:IsShown() or not MegaMacro_Frame:IsShown()
    then
        return
    end

    local bindRight=BindPadFrame:GetRight()
    local bindTop=BindPadFrame:GetTop()
    if not bindRight or not bindTop then return end

    local uiScale=UIParent:GetEffectiveScale()
    if not uiScale or uiScale==0 then uiScale=1 end
    local gap=4/uiScale

    MegaMacro_Frame:ClearAllPoints()
    MegaMacro_Frame:SetPoint(
        "TOPLEFT",UIParent,"BOTTOMLEFT",
        bindRight+gap,bindTop
    )

    if type(_G.BPMM_SaveWindowPoint)=="function" then
        _G.BPMM_SaveWindowPoint(BindPadFrame,"BindPad")
        _G.BPMM_SaveWindowPoint(MegaMacro_Frame,"MegaMacro")
    end
end

local function QueueMainWindowAlignment()
    C_Timer.After(0,AlignMainWindows)
    C_Timer.After(.05,AlignMainWindows)
end

_G.BPMM_AlignMainWindows=AlignMainWindows
_G.BPMM_QueueMainWindowAlignment=QueueMainWindowAlignment

local function InstallWrapper()
    if wrapperInstalled then return end

    local current = SlashCmdList and SlashCmdList["BINDPAD"]
    if type(current) ~= "function" then return end

    previousBindPadSlash = current

    SlashCmdList["BINDPAD"] = function(msg)
        local trimmed = (msg or ""):match("^%s*(.-)%s*$") or ""

        if trimmed ~= "" then
            return previousBindPadSlash(msg)
        end

        -- /bb is an opener, not a toggle.  Calling the original empty slash
        -- handler while BetterBind was already visible used to close only BB
        -- and leave BM behind, defeating the paired-window behavior.
        if BindPadFrame and not BindPadFrame:IsShown() then
            if ShowUIPanel then
                local ok=pcall(ShowUIPanel,BindPadFrame)
                if not ok then BindPadFrame:Show() end
            else
                BindPadFrame:Show()
            end
        end

        if Settings64().openTogether and BindPadFrame and BindPadFrame:IsShown() then
            if MegaMacroWindow and type(MegaMacroWindow.Show) == "function" then
                if not MegaMacro_Frame or not MegaMacro_Frame:IsShown() then
                    MegaMacroWindow.Show()
                end
            elseif MegaMacro_Frame then
                MegaMacro_Frame:Show()
            end
            QueueMainWindowAlignment()
        end
    end

    wrapperInstalled = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(.35, InstallWrapper)
end)

C_Timer.After(0, InstallWrapper)
end
-- END CONSOLIDATED: BehaviorSlashFix.lua
