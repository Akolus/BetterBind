-- BindPad + MegaMacro Stage 8 consolidated visual/runtime layer
-- Version: 0.8.6
-- Generated from known-working Stage 8.1 through 8.5.1 modules.
-- Original active TOC order preserved.
-- No macro/binding/profile/SavedVariables migration code.

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_1.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.1
-- Visual redesign foundation.
-- Modern neutral dark shell + blue/cyan active accent.
-- No layout/data behavior changes.

local M = {}
_G.BPMM81 = M

local C = {
    shell      = {.020,.023,.028,.985},
    panel      = {.030,.034,.040,1},
    panel2     = {.045,.050,.058,1},
    border     = {.105,.115,.130,1},
    borderSoft = {.075,.082,.092,1},
    blue       = {.050,.565,.905,1},
    blueSoft   = {.050,.310,.470,.45},
    text       = {.93,.94,.96,1},
    muted      = {.66,.68,.72,1},
    black      = {0,0,0,1},
}

local function HideRegion(r)
    if r and r.SetAlpha then r:SetAlpha(0) end
end

local function HideKnownChrome(frame)
    if not frame then return end

    HideRegion(frame.Bg)
    HideRegion(frame.TopTileStreaks)

    if frame.NineSlice then
        frame.NineSlice:SetAlpha(0)
    end
    if frame.PortraitContainer then
        frame.PortraitContainer:SetAlpha(0)
    end

    -- Named regions from legacy templates.
    local name = frame.GetName and frame:GetName()
    if name then
        for _,suffix in ipairs({
            "Bg","Background","TopLeftCorner","TopRightCorner",
            "BottomLeftCorner","BottomRightCorner","TopBorder",
            "BottomBorder","LeftBorder","RightBorder","TitleBg",
        }) do
            HideRegion(_G[name..suffix])
        end
    end
end

local function EnsureShell(frame)
    if not frame then return end
    HideKnownChrome(frame)

    local shell = frame.__BPMM81Shell
    if not shell then
        shell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        shell:SetPoint("TOPLEFT", 0, 0)
        shell:SetPoint("BOTTOMRIGHT", 0, 0)
        shell:SetFrameLevel(math.max(0,(frame:GetFrameLevel() or 1)-4))
        shell:EnableMouse(false)
        shell:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        frame.__BPMM81Shell = shell
    end

    shell:SetBackdropColor(unpack(C.shell))
    shell:SetBackdropBorderColor(unpack(C.border))
end

local function EnsureHeader(frame)
    if not frame then return end

    local header = frame.__BPMM81Header
    if not header then
        header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(42)
        header:SetFrameLevel(math.max(0,(frame:GetFrameLevel() or 1)-2))
        header:EnableMouse(false)
        header:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
        })
        frame.__BPMM81Header = header

        local line = header:CreateTexture(nil,"ARTWORK")
        line:SetColorTexture(unpack(C.borderSoft))
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", 0, 0)
        header.__line = line
    end

    header:SetBackdropColor(.025,.028,.033,1)
end

local function CenterTitle(frame, text)
    if not frame then return end

    local title = frame.__BPMM81Title
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -13)
        title:SetJustifyH("CENTER")
        frame.__BPMM81Title = title
    end

    title:SetText(text or "")
    title:SetTextColor(unpack(C.text))

    -- Hide native title text if present.
    local native = frame.TitleContainer and frame.TitleContainer.TitleText
    if native then native:SetAlpha(0) end
    local name = frame.GetName and frame:GetName()
    if name then
        HideRegion(_G[name.."TitleText"])
    end
end

local function MakeFlatTab(tab)
    if not tab then return end

    if not tab.__BPMM81BG then
        local bg = CreateFrame("Frame", nil, tab, "BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(tab:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        tab.__BPMM81BG = bg
    end

    for _,region in ipairs({tab:GetRegions()}) do
        if region and region.GetObjectType then
            local kind = region:GetObjectType()
            if kind=="Texture" then
                region:SetAlpha(0)
            end
        end
    end

    if tab.GetNormalTexture and tab:GetNormalTexture() then
        tab:GetNormalTexture():SetAlpha(0)
    end
    if tab.GetPushedTexture and tab:GetPushedTexture() then
        tab:GetPushedTexture():SetAlpha(0)
    end
    if tab.GetHighlightTexture and tab:GetHighlightTexture() then
        tab:GetHighlightTexture():SetAlpha(0)
    end

    tab.__BPMM81BG:SetBackdropColor(unpack(C.panel))
    tab.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))
end

local function StyleTab(tab, selected)
    if not tab then return end
    MakeFlatTab(tab)

    if selected then
        tab.__BPMM81BG:SetBackdropColor(.035,.095,.135,1)
        tab.__BPMM81BG:SetBackdropBorderColor(unpack(C.blue))
    else
        tab.__BPMM81BG:SetBackdropColor(unpack(C.panel))
        tab.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))
    end

    local fs = tab.GetFontString and tab:GetFontString()
    if fs then
        fs:SetTextColor(unpack(selected and C.text or C.muted))
    end
end

local function StyleMegaTabs()
    if _G.BPMMGoalLayout then return end
    if not MegaMacro_Frame then return end

    local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(MegaMacro_Frame) or 1
    for i=1,6 do
        StyleTab(_G["MegaMacro_FrameTab"..i], i==selected)
    end
end

local function StyleBindTabs()
    if _G.BPMMGoalLayout then return end
    if not BindPadFrame then return end

    local selected = BindPadVars and BindPadVars.tab or 1
    for i=1,4 do
        local tab = _G["BindPadFrameTab"..i]
        if tab then
            StyleTab(tab, i==selected)
        end
    end
end

local function StyleFooterButton(button)
    if not button then return end

    if not button.__BPMM81BG then
        local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(button:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        button.__BPMM81BG = bg
    end

    local nt=button.GetNormalTexture and button:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt=button.GetPushedTexture and button:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local ht=button.GetHighlightTexture and button:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end

    button.__BPMM81BG:SetBackdropColor(unpack(C.panel))
    button.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))

    local fs=button.GetFontString and button:GetFontString()
    if fs then fs:SetTextColor(unpack(C.text)) end

    if not button.__BPMM81Hooks then
        button.__BPMM81Hooks=true

        button:HookScript("OnEnter",function(self)
            if self.__BPMM81BG then
                self.__BPMM81BG:SetBackdropColor(unpack(C.panel2))
                self.__BPMM81BG:SetBackdropBorderColor(unpack(C.blue))
            end
        end)

        button:HookScript("OnLeave",function(self)
            if self.__BPMM81BG then
                self.__BPMM81BG:SetBackdropColor(unpack(C.panel))
                self.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))
            end
        end)
    end
end

local function StyleSearch()
    local search = _G.BPMMUnifiedSearch
    if not search then return end

    search:SetBackdropColor(unpack(C.panel))
    search:SetBackdropBorderColor(unpack(C.borderSoft))

    -- Remove any old gold tint from the clear icon / field edge by resetting
    -- only the frame; Stage 7 behavior remains untouched.
    local edit = _G.BPMMUnifiedSearchEditBox
    if edit then
        edit:SetTextColor(unpack(C.text))
    end
end

local function StyleMegaMacro()
    if not MegaMacro_Frame then return end

    EnsureShell(MegaMacro_Frame)
    EnsureHeader(MegaMacro_Frame)
    CenterTitle(MegaMacro_Frame, "BetterMacro")
    StyleMegaTabs()
    StyleFooterButton(_G.MegaMacro_DeleteButton)
    StyleFooterButton(_G.BPMM74LocateButton)
    StyleSearch()

    -- Main working areas get clean dark panels without moving them.
    if MegaMacro_FrameInset then
        MegaMacro_FrameInset:SetAlpha(1)
        if not MegaMacro_FrameInset.__BPMM81BG then
            local bg=CreateFrame("Frame",nil,MegaMacro_FrameInset,"BackdropTemplate")
            bg:SetAllPoints()
            bg:SetFrameLevel(math.max(0,(MegaMacro_FrameInset:GetFrameLevel() or 1)-1))
            bg:EnableMouse(false)
            bg:SetBackdrop({
                bgFile="Interface\\Buttons\\WHITE8x8",
                edgeFile="Interface\\Buttons\\WHITE8x8",
                edgeSize=1,
            })
            MegaMacro_FrameInset.__BPMM81BG=bg
        end
        MegaMacro_FrameInset.__BPMM81BG:SetBackdropColor(.018,.021,.026,1)
        MegaMacro_FrameInset.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))
    end
end

local function StyleBindPad()
    if not BindPadFrame then return end

    EnsureShell(BindPadFrame)
    EnsureHeader(BindPadFrame)
    CenterTitle(BindPadFrame, "BetterBind")
    StyleBindTabs()

    -- Clean main icon-grid viewport.
    if BindPadScrollFrame then
        if not BindPadScrollFrame.__BPMM81BG then
            local bg=CreateFrame("Frame",nil,BindPadScrollFrame,"BackdropTemplate")
            bg:SetPoint("TOPLEFT",-3,3)
            bg:SetPoint("BOTTOMRIGHT",3,-3)
            bg:SetFrameLevel(math.max(0,(BindPadScrollFrame:GetFrameLevel() or 1)-1))
            bg:EnableMouse(false)
            bg:SetBackdrop({
                bgFile="Interface\\Buttons\\WHITE8x8",
                edgeFile="Interface\\Buttons\\WHITE8x8",
                edgeSize=1,
            })
            BindPadScrollFrame.__BPMM81BG=bg
        end
        BindPadScrollFrame.__BPMM81BG:SetBackdropColor(.018,.021,.026,1)
        BindPadScrollFrame.__BPMM81BG:SetBackdropBorderColor(unpack(C.borderSoft))
    end
end

local function ApplyAll()
    StyleBindPad()
    StyleMegaMacro()
end

M.Apply=ApplyAll
M.StyleBindTabs=StyleBindTabs
M.StyleMegaTabs=StyleMegaTabs

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,ApplyAll)
    C_Timer.After(1.0,ApplyAll)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,StyleBindPad)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,StyleMegaMacro)
    end)
end

if type(_G.BindPadFrameTab_OnClick)=="function" then
    hooksecurefunc("BindPadFrameTab_OnClick",function()
        C_Timer.After(0,StyleBindTabs)
    end)
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        C_Timer.After(0,StyleMegaTabs)
    end)
end
end
-- END CONSOLIDATED: Stage8_1.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_2.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.2
-- BindPad lower-section / specialization profile redesign.
-- Visual/layout-only. Existing profile buttons and BindPad controls retain
-- their original scripts and behavior.

local M={}
_G.BPMM82=M

local C={
    panel={.024,.027,.032,.98},
    panel2={.035,.039,.046,1},
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
    muted={.65,.67,.71,1},
}

local function FlatButton(b)
    if not b then return end
    if not b.__BPMM82BG then
        local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        b.__BPMM82BG=bg
    end
    b.__BPMM82BG:SetBackdropColor(unpack(C.panel2))
    b.__BPMM82BG:SetBackdropBorderColor(unpack(C.border))
end

local function FindProfileButtons()
    local out={}
    -- Stage 6 specialization buttons are the three/four large square buttons
    -- in the lower portion of BindPad. Identify them conservatively by
    -- position/size rather than names so this works with the existing build.
    if not BindPadFrame then return out end

    local frameBottom=BindPadFrame:GetBottom()
    if not frameBottom then return out end

    local function consider(obj)
        if not obj or not obj.IsObjectType or not obj:IsObjectType("Button") then return end
        if obj==BindPadFrameCloseButton then return end
        local w,h=obj:GetSize()
        local bottom=obj:GetBottom()
        if not w or not h or not bottom then return end

        -- Existing profile buttons are roughly square, 32-55 px, and sit
        -- above the Save All Keys / Show Hotkeys row.
        if w>=30 and w<=60 and h>=30 and h<=60
           and bottom > frameBottom+55 and bottom < frameBottom+125 then
            local tex=obj.GetNormalTexture and obj:GetNormalTexture()
            if tex then out[#out+1]=obj end
        end
    end

    -- Enumerate known children only.
    for _,child in ipairs({BindPadFrame:GetChildren()}) do consider(child) end

    table.sort(out,function(a,b)
        return (a:GetLeft() or 0)<(b:GetLeft() or 0)
    end)
    return out
end

local function EnsureLowerPanel()
    if not BindPadFrame then return end

    local p=BindPadFrame.__BPMM82Lower
    if not p then
        p=CreateFrame("Frame",nil,BindPadFrame,"BackdropTemplate")
        p:SetPoint("BOTTOMLEFT",BindPadFrame,"BOTTOMLEFT",12,46)
        p:SetPoint("BOTTOMRIGHT",BindPadFrame,"BOTTOMRIGHT",-12,46)
        p:SetHeight(100)
        p:SetFrameLevel(math.max(0,(BindPadFrame:GetFrameLevel() or 1)-1))
        p:EnableMouse(false)
        p:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        p:SetBackdropColor(unpack(C.panel))
        p:SetBackdropBorderColor(unpack(C.border))
        BindPadFrame.__BPMM82Lower=p

        local title=BindPadFrame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        title:SetText("Specialization Profiles")
        title:SetTextColor(unpack(C.text))
        title:SetPoint("BOTTOMLEFT",p,"TOPLEFT",4,7)
        BindPadFrame.__BPMM82LowerTitle=title
    end
end

local function HideSlotCount()
    if not BindPadFrame then return end

    -- Stage 6's "N Slots shown" readout is useful during grid development,
    -- but it is visual debug/status noise in the final design.
    for _,r in ipairs({BindPadFrame:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="FontString" and r.GetText then
            local t=r:GetText()
            if type(t)=="string" and t:match("^%d+ Slots shown$") then
                r:SetAlpha(0)
                if not r.__BPMM82Hidden then
                    r.__BPMM82Hidden=true
                    hooksecurefunc(r,"SetText",function(self)
                        self:SetAlpha(0)
                    end)
                    hooksecurefunc(r,"SetFormattedText",function(self)
                        self:SetAlpha(0)
                    end)
                end
            end
        end
    end
end

local function ArrangeProfiles()
    if not BindPadFrame or not BindPadFrame.__BPMM82Lower then return end
    local buttons=FindProfileButtons()
    if #buttons==0 then return end

    local panel=BindPadFrame.__BPMM82Lower
    local startX=18
    local gap=18

    for i,b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",panel,"TOPLEFT",startX+(i-1)*(b:GetWidth()+gap),-18)
        FlatButton(b)

        if not b.__BPMM82Label then
            local label=BindPadFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            label:SetPoint("TOP",b,"BOTTOM",0,-5)
            label:SetText("Profile "..i)
            label:SetTextColor(unpack(C.text))
            b.__BPMM82Label=label
        else
            b.__BPMM82Label:ClearAllPoints()
            b.__BPMM82Label:SetPoint("TOP",b,"BOTTOM",0,-5)
            b.__BPMM82Label:SetText("Profile "..i)
        end
    end
end

local function StyleBottomControls()
    if not BindPadFrame then return end

    -- Preserve the existing utility buttons and checkboxes. We only normalize
    -- obvious button chrome; Stage 8.2 does not replace their scripts.
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child and child.IsObjectType and child:IsObjectType("Button") then
            local bottom=child:GetBottom()
            local fb=BindPadFrame:GetBottom()
            local w,h=child:GetSize()
            if bottom and fb and w and h and bottom<fb+58 and w>=28 and w<=55 and h>=28 and h<=55 then
                FlatButton(child)
            end
        end
    end
end

local function Apply()
    if not BindPadFrame then return end
    EnsureLowerPanel()
    HideSlotCount()
    ArrangeProfiles()
    StyleBottomControls()
end

M.Apply=Apply

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.6,Apply)
    C_Timer.After(1.1,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end
end
-- END CONSOLIDATED: Stage8_2.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_3.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.3
-- BindPad grid + scrollbar refinement.
-- Visual-only: slot scripts, drag/drop, bindings and profile data are untouched.

local M={}
_G.BPMM83=M

local C={
    slot={.030,.034,.040,1},
    slotBorder={.105,.115,.130,1},
    slotHover={.050,.058,.068,1},
    blue={.050,.565,.905,1},
    track={.025,.029,.034,1},
    thumb={.20,.22,.25,1},
    thumbHover={.30,.33,.37,1},
}

local function StyleSlot(b)
    if not b or b.__BPMM83Styled then return end
    b.__BPMM83Styled=true

    local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
    bg:SetPoint("TOPLEFT",-2,2)
    bg:SetPoint("BOTTOMRIGHT",2,-2)
    bg:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1))
    bg:EnableMouse(false)
    bg:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    bg:SetBackdropColor(unpack(C.slot))
    bg:SetBackdropBorderColor(unpack(C.slotBorder))
    b.__BPMM83BG=bg

    -- Do not hide icon artwork or Stage 7 overlays. Only suppress the
    -- inherited normal/pushed frame chrome where present.
    local nt=b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt=b.GetPushedTexture and b:GetPushedTexture()
    if pt then pt:SetAlpha(0) end

    b:HookScript("OnEnter",function(self)
        if self.__BPMM83BG then
            self.__BPMM83BG:SetBackdropColor(unpack(C.slotHover))
            self.__BPMM83BG:SetBackdropBorderColor(unpack(C.blue))
        end
    end)

    b:HookScript("OnLeave",function(self)
        if self.__BPMM83BG then
            self.__BPMM83BG:SetBackdropColor(unpack(C.slot))
            self.__BPMM83BG:SetBackdropBorderColor(unpack(C.slotBorder))
        end
    end)
end

local function StyleVisibleSlots()
    -- Named BindPad slot buttons are safest: this avoids touching profile
    -- buttons and bottom utility controls.
    local misses=0
    for i=1,200 do
        local b=_G["BindPadSlot"..i]
        if b then
            misses=0
            StyleSlot(b)
        else
            misses=misses+1
            if i>60 and misses>20 then break end
        end
    end
end

local function HideTexture(tex)
    if tex and tex.SetAlpha then tex:SetAlpha(0) end
end

local function StyleScrollBar()
    local sf=_G.BindPadScrollFrame
    if not sf then return end
    local sb=sf.ScrollBar
    if not sb then return end

    -- Modern retail MinimalScrollBar exposes Track/Back/Forward.
    if sb.Back then
        HideTexture(sb.Back:GetNormalTexture())
        HideTexture(sb.Back:GetPushedTexture())
        HideTexture(sb.Back:GetHighlightTexture())
        sb.Back:SetAlpha(.72)
    end
    if sb.Forward then
        HideTexture(sb.Forward:GetNormalTexture())
        HideTexture(sb.Forward:GetPushedTexture())
        HideTexture(sb.Forward:GetHighlightTexture())
        sb.Forward:SetAlpha(.72)
    end

    if sb.Track then
        for _,r in ipairs({sb.Track:GetRegions()}) do
            if r and r.GetObjectType and r:GetObjectType()=="Texture" then
                r:SetAlpha(0)
            end
        end

        if not sb.Track.__BPMM83BG then
            local track=sb.Track:CreateTexture(nil,"BACKGROUND")
            track:SetColorTexture(unpack(C.track))
            track:SetPoint("TOP",0,-2)
            track:SetPoint("BOTTOM",0,2)
            track:SetWidth(4)
            sb.Track.__BPMM83BG=track
        end
    end

    -- Find the proportional thumb texture/frame without assuming a legacy API.
    local thumb=sb.Thumb or sb.thumb or (sb.Track and (sb.Track.Thumb or sb.Track.thumb))
    if thumb then
        if thumb.SetColorTexture then
            thumb:SetColorTexture(unpack(C.thumb))
        elseif thumb.SetVertexColor then
            thumb:SetVertexColor(unpack(C.thumb))
        end
    end

    sb:SetAlpha(.82)

    if not sb.__BPMM83Hover then
        sb.__BPMM83Hover=true
        sb:HookScript("OnEnter",function(self)
            self:SetAlpha(1)
            local t=self.Thumb or self.thumb or (self.Track and (self.Track.Thumb or self.Track.thumb))
            if t then
                if t.SetColorTexture then t:SetColorTexture(unpack(C.thumbHover))
                elseif t.SetVertexColor then t:SetVertexColor(unpack(C.thumbHover)) end
            end
        end)
        sb:HookScript("OnLeave",function(self)
            self:SetAlpha(.82)
            local t=self.Thumb or self.thumb or (self.Track and (self.Track.Thumb or self.Track.thumb))
            if t then
                if t.SetColorTexture then t:SetColorTexture(unpack(C.thumb))
                elseif t.SetVertexColor then t:SetVertexColor(unpack(C.thumb)) end
            end
        end)
    end
end

local function CleanGridEdges()
    local sf=_G.BindPadScrollFrame
    if not sf then return end

    -- Stage 8.1 already supplies the dark viewport. 8.3 softens its border
    -- so the icons, not the frame, remain the visual focus.
    local bg=sf.__BPMM81BG
    if bg and bg.SetBackdropBorderColor then
        bg:SetBackdropBorderColor(.075,.082,.092,1)
    end
end

local function Apply()
    StyleVisibleSlots()
    StyleScrollBar()
    CleanGridEdges()
end

M.Apply=Apply

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.6,Apply)
    C_Timer.After(1.1,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end

if BindPadScrollFrame then
    BindPadScrollFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end
end
-- END CONSOLIDATED: Stage8_3.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_3_1.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.3.1
-- Fixes dynamically-created BindPad rows and applies Stage 8 cell styling
-- to MegaMacro's macro grid.
-- Visual only.

local C={
    bg={.030,.034,.040,1},
    border={.105,.115,.130,1},
    hover={.050,.058,.068,1},
    blue={.050,.565,.905,1},
}

local function IsLegacyCellTexture(tex)
    if not tex or not tex.GetTexture then return false end
    local path=tex:GetTexture()
    if type(path)~="string" then return false end
    path=string.lower(path)
    return path:find("quickslot",1,true)
        or path:find("emptyslot",1,true)
        or path:find("checkbuttonhilight",1,true)
        or path:find("buttonhilight",1,true)
end

local function EnsureCellBG(button,key)
    if not button then return nil end
    local existing=button[key]
    if existing then return existing end

    local bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
    bg:SetPoint("TOPLEFT",-2,2)
    bg:SetPoint("BOTTOMRIGHT",2,-2)
    bg:SetFrameLevel(math.max(0,(button:GetFrameLevel() or 1)-1))
    bg:EnableMouse(false)
    bg:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Buttons\\WHITE8x8",
        edgeSize=1,
    })
    bg:SetBackdropColor(unpack(C.bg))
    bg:SetBackdropBorderColor(unpack(C.border))
    button[key]=bg
    return bg
end

local function StyleBindPadSlot(button)
    if not button then return end

    local bg=EnsureCellBG(button,"__BPMM831BG")
    if bg then
        bg:SetBackdropColor(unpack(C.bg))
        bg:SetBackdropBorderColor(unpack(C.border))
    end

    -- Hide only legacy slot-frame artwork, never the actual icon.
    for _,r in ipairs({button:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" and IsLegacyCellTexture(r) then
            r:SetAlpha(0)
        end
    end

    if not button.__BPMM831Hooks then
        button.__BPMM831Hooks=true
        button:HookScript("OnEnter",function(self)
            local f=self.__BPMM831BG
            if f then
                f:SetBackdropColor(unpack(C.hover))
                f:SetBackdropBorderColor(unpack(C.blue))
            end
        end)
        button:HookScript("OnLeave",function(self)
            local f=self.__BPMM831BG
            if f then
                f:SetBackdropColor(unpack(C.bg))
                f:SetBackdropBorderColor(unpack(C.border))
            end
        end)
    end
end

local function StyleAllBindPadSlots()
    -- No early break. BindPad creates additional rows dynamically, so every
    -- currently-existing named slot must be checked each refresh.
    for i=1,250 do
        local b=_G["BindPadSlot"..i]
        if b then StyleBindPadSlot(b) end
    end
end

local function StyleMegaMacroCell(button)
    if not button then return end

    local bg=EnsureCellBG(button,"__BPMM831MacroBG")
    if bg then
        bg:SetBackdropColor(unpack(C.bg))
        bg:SetBackdropBorderColor(unpack(C.border))
    end

    -- SelectorButtonTemplate supplies Blizzard quickslot/highlight artwork.
    -- Remove only those known frame textures; preserve icon textures.
    for _,r in ipairs({button:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" and IsLegacyCellTexture(r) then
            r:SetAlpha(0)
        end
    end

    local checked=button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetAlpha(0) end
    local highlight=button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end

    if not button.__BPMM831Hooks then
        button.__BPMM831Hooks=true
        button:HookScript("OnEnter",function(self)
            local f=self.__BPMM831MacroBG
            if f then
                f:SetBackdropColor(unpack(C.hover))
                f:SetBackdropBorderColor(unpack(C.blue))
            end
        end)
        button:HookScript("OnLeave",function(self)
            local f=self.__BPMM831MacroBG
            if f then
                f:SetBackdropColor(unpack(C.bg))
                if self.GetChecked and self:GetChecked() then
                    f:SetBackdropBorderColor(unpack(C.blue))
                else
                    f:SetBackdropBorderColor(unpack(C.border))
                end
            end
        end)
    end

    if button.GetChecked and button:GetChecked() then
        bg:SetBackdropBorderColor(unpack(C.blue))
    end
end

local function StyleMegaMacroGrid()
    local max=HighestMaxMacroCount or 60
    for i=1,max do
        local b=_G["MegaMacro_MacroButton"..i]
        if b then StyleMegaMacroCell(b) end
    end
end

local function RefreshMegaSelectedCell()
    local max=HighestMaxMacroCount or 60
    for i=1,max do
        local b=_G["MegaMacro_MacroButton"..i]
        if b and b.__BPMM831MacroBG then
            if b.GetChecked and b:GetChecked() then
                b.__BPMM831MacroBG:SetBackdropBorderColor(unpack(C.blue))
            else
                b.__BPMM831MacroBG:SetBackdropBorderColor(unpack(C.border))
            end
        end
    end
end

local function Apply()
    StyleAllBindPadSlots()
    StyleMegaMacroGrid()
    RefreshMegaSelectedCell()
end

-- Critical fix for BindPad's later-created rows: style the slot as soon as
-- BindPad updates it, instead of relying on login-time enumeration.
if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",function(button)
        if button then StyleBindPadSlot(button) end
    end)
end

if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
    hooksecurefunc("MegaMacro_MacroButton_OnClick",function()
        C_Timer.After(0,RefreshMegaSelectedCell)
    end)
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        C_Timer.After(0,function()
            StyleMegaMacroGrid()
            RefreshMegaSelectedCell()
        end)
    end)
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.6,Apply)
    C_Timer.After(1.2,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,StyleAllBindPadSlots)
        C_Timer.After(.1,StyleAllBindPadSlots)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end
end
-- END CONSOLIDATED: Stage8_3_1.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_4.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.4
-- Approved layout pass:
--  * BindPad fixed 8x6 viewport (48px icons, 11px spacing)
--  * one-row wheel scrolling
--  * 5-profile strip (38px, 5px spacing)
--  * +/- slot controls moved into the lower profile section
--  * borderless 3x30 scrollbar thumbs
--  * MegaMacro cells stripped of Blizzard slot chrome
--  * formatted macro syntax made fully vibrant
--
-- Visual/layout behavior only. No macro, binding or profile data is rewritten.

local M={}
_G.BPMM84=M

local GRID_ICON=50
local GRID_GAP=11
local GRID_COLS=8
local GRID_ROWS=7
local GRID_STEP=GRID_ICON+GRID_GAP
local GRID_W=GRID_COLS*GRID_ICON+(GRID_COLS-1)*GRID_GAP
local GRID_H=GRID_ROWS*GRID_ICON+(GRID_ROWS-1)*GRID_GAP

local PROFILE_ICON=38
local PROFILE_GAP=5

local C={
    bg={.026,.030,.036,1},
    border={.10,.11,.125,1},
    hover={.05,.058,.068,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
    muted={.55,.58,.62,1},
    thumb={.38,.40,.44,1},
}

local function ForceGridSettings()
    BindPadVars=BindPadVars or {}
    BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
    local s=BindPadVars.BPMMSettings
    s.bindPadIconSize=GRID_ICON
    s.bindPadIconSpacing=GRID_GAP
    s.bindPadColumns=GRID_COLS
end

local function SlotList()
    local t={}
    for i=1,250 do
        local b=_G["BindPadSlot"..i]
        if b then t[#t+1]=b end
    end
    return t
end

local function LayoutGrid()
    if not BindPadSlotButtonContainer then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadGrid then
        return BPMMGoalLayout.ApplyBindPadGrid()
    end
    ForceGridSettings()

    local slots=SlotList()
    for index,b in ipairs(slots) do
        local col=(index-1)%GRID_COLS
        local row=math.floor((index-1)/GRID_COLS)

        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",BindPadSlotButtonContainer,"TOPLEFT",
            col*GRID_STEP,-row*GRID_STEP)
        b:SetSize(GRID_ICON,GRID_ICON)

        if b.icon then
            b.icon:ClearAllPoints()
            b.icon:SetAllPoints(b)
            b.icon:SetTexCoord(.07,.93,.07,.93)
        end
    end

    local totalRows=math.max(1,math.ceil(#slots/GRID_COLS))
    BindPadSlotButtonContainer:SetScale(1)
    BindPadSlotButtonContainer:SetWidth(GRID_W)
    BindPadSlotButtonContainer:SetHeight(totalRows*GRID_ICON+math.max(0,totalRows-1)*GRID_GAP)

    local sf=_G.BindPadScrollFrame
    if sf then
        sf:SetSize(GRID_W+8,GRID_H)
    end
end

local function RowWheel(delta)
    local sf=_G.BindPadScrollFrame
    if not sf then return end
    local range=sf:GetVerticalScrollRange() or 0
    local current=sf:GetVerticalScroll() or 0
    local row=math.floor((current/GRID_STEP)+.5)
    row=row+(delta<0 and 1 or -1)
    local target=math.max(0,math.min(range,row*GRID_STEP))
    sf:SetVerticalScroll(target)
end

local function InstallRowWheel()
    local sf=_G.BindPadScrollFrame
    if not sf or sf.__BPMM84RowWheel then return end
    sf.__BPMM84RowWheel=true
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel",function(_,delta)
        RowWheel(delta)
    end)
end

local function HideGridOptions()
    local panel=_G.BPMMScrollableSettingsPanel
    if not panel then return end

    for _,f in ipairs({panel:GetChildren()}) do
        if f.GetScrollChild then
            local child=f:GetScrollChild()
            if child then
                for _,row in ipairs({child:GetChildren()}) do
                    local hide=false
                    for _,region in ipairs({row:GetRegions()}) do
                        if region.GetText then
                            local t=region:GetText()
                            if t=="Icon Size" or t=="Icon Spacing" or t=="Icons Per Row" then
                                hide=true
                            end
                        end
                    end
                    if hide then row:Hide() end
                end
            end
        end
    end
end

local function ProfileButtons()
    local out={}
    if not BindPadFrame then return out end
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.__BPMM82Label then
            out[#out+1]=child
        end
    end
    table.sort(out,function(a,b)
        local ta=a.__BPMM82Label and a.__BPMM82Label:GetText() or ""
        local tb=b.__BPMM82Label and b.__BPMM82Label:GetText() or ""
        return ta<tb
    end)
    return out
end

local function FlatGlyphButton(b,glyph)
    if not b then return end

    local nt=b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt=b.GetPushedTexture and b:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local ht=b.GetHighlightTexture and b:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end

    if not b.__BPMM84BG then
        local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        b.__BPMM84BG=bg

        local fs=b:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
        fs:SetPoint("CENTER",0,1)
        b.__BPMM84Glyph=fs

        b:HookScript("OnEnter",function(self)
            self.__BPMM84BG:SetBackdropColor(unpack(C.hover))
            self.__BPMM84BG:SetBackdropBorderColor(unpack(C.blue))
        end)
        b:HookScript("OnLeave",function(self)
            self.__BPMM84BG:SetBackdropColor(unpack(C.bg))
            self.__BPMM84BG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    b.__BPMM84BG:SetBackdropColor(unpack(C.bg))
    b.__BPMM84BG:SetBackdropBorderColor(unpack(C.border))
    b.__BPMM84Glyph:SetText(glyph)
    b.__BPMM84Glyph:SetTextColor(unpack(C.text))
end

local function LayoutLowerSection()
    if not BindPadFrame then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadLower then
        return BPMMGoalLayout.ApplyBindPadLower()
    end
    local panel=BindPadFrame.__BPMM82Lower
    if not panel then return end

    local profiles=ProfileButtons()
    for i,b in ipairs(profiles) do
        if i<=5 then
            b:SetSize(PROFILE_ICON,PROFILE_ICON)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",
                14+(i-1)*(PROFILE_ICON+PROFILE_GAP),-18)

            if b.__BPMM82Label then
                b.__BPMM82Label:ClearAllPoints()
                b.__BPMM82Label:SetPoint("TOP",b,"BOTTOM",0,-5)
                b.__BPMM82Label:SetText("Profile "..i)
            end
        end
    end

    local less=_G.BindPadShowLessSlotButton
    local more=_G.BindPadShowMoreSlotButton

    if less then
        less:SetSize(38,38)
        less:ClearAllPoints()
        less:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-58,-18)
        FlatGlyphButton(less,"-")
    end
    if more then
        more:SetSize(38,38)
        more:ClearAllPoints()
        more:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-14,-18)
        FlatGlyphButton(more,"+")
    end
end

local function HideNativeScrollbar(sf)
    if not sf then return end

    local sb=sf.ScrollBar or _G[(sf.GetName and sf:GetName() or "").."ScrollBar"]
    if sb then sb:SetAlpha(0) end

    local name=sf.GetName and sf:GetName()
    if name then
        for _,suffix in ipairs({
            "ScrollBar","ScrollBarScrollUpButton","ScrollBarScrollDownButton",
            "Top","Bottom","Middle",
        }) do
            local obj=_G[name..suffix]
            if obj and obj.SetAlpha then obj:SetAlpha(0) end
        end
    end
end

local function MinimalThumb(sf)
    if not sf or sf.__BPMM84Thumb then return end
    HideNativeScrollbar(sf)

    local thumb=sf:CreateTexture(nil,"OVERLAY")
    thumb:SetColorTexture(unpack(C.thumb))
    thumb:SetSize(3,30)
    sf.__BPMM84Thumb=thumb

    local function update()
        local range=sf:GetVerticalScrollRange() or 0
        if range<=0 then
            thumb:Hide()
            return
        end
        thumb:Show()
        local scroll=sf:GetVerticalScroll() or 0
        local h=sf:GetHeight()
        local travel=math.max(0,h-30)
        local y=(scroll/range)*travel
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT",sf,"TOPRIGHT",-1,-y)
    end

    sf.__BPMM84UpdateThumb=update
    sf:HookScript("OnVerticalScroll",update)
    sf:HookScript("OnShow",function()
        HideNativeScrollbar(sf)
        C_Timer.After(0,update)
    end)
    C_Timer.After(0,update)
end

local function StyleAllScrollbars()
    MinimalThumb(_G.BindPadScrollFrame)
    MinimalThumb(_G.MegaMacro_ButtonScrollFrame)
    MinimalThumb(_G.MegaMacro_FrameScrollFrame)
    MinimalThumb(_G.MegaMacro_FormattedFrameScrollFrame)
end

local function CleanMacroCell(b)
    if not b then return end

    local icon=b.Icon

    for _,r in ipairs({b:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" and r~=icon then
            r:SetAlpha(0)
        end
    end

    local checked=b.GetCheckedTexture and b:GetCheckedTexture()
    if checked then checked:SetAlpha(0) end
    local hi=b.GetHighlightTexture and b:GetHighlightTexture()
    if hi then hi:SetAlpha(0) end

    if not b.__BPMM84CellBG then
        local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
        bg:SetPoint("TOPLEFT",-2,2)
        bg:SetPoint("BOTTOMRIGHT",2,-2)
        bg:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        b.__BPMM84CellBG=bg
    end
    b.__BPMM84CellBG:SetBackdropColor(unpack(C.bg))
    if b.GetChecked and b:GetChecked() then
        b.__BPMM84CellBG:SetBackdropBorderColor(unpack(C.blue))
    else
        b.__BPMM84CellBG:SetBackdropBorderColor(unpack(C.border))
    end
end

local function CleanAllMacroCells()
    for i=1,(HighestMaxMacroCount or 60) do
        CleanMacroCell(_G["MegaMacro_MacroButton"..i])
    end
end

local function MakeEditorVibrant()
    -- Retired with the formatted editor. The old implementation reduced the
    -- native EditBox region to 3% opacity, which also made its selection
    -- feedback effectively invisible.
end

local function Apply()
    ForceGridSettings()
    LayoutGrid()
    InstallRowWheel()
    HideGridOptions()
    LayoutLowerSection()
    StyleAllScrollbars()
    CleanAllMacroCells()
    MakeEditorVibrant()
end

M.Apply=Apply

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.6,Apply)
    C_Timer.After(1.2,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end

if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",function()
        if _G.BPMMGoalLayout then return end
        C_Timer.After(0,LayoutGrid)
    end)
end

if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
    hooksecurefunc("MegaMacro_MacroButton_OnClick",function()
        C_Timer.After(0,function()
            CleanAllMacroCells()
            MakeEditorVibrant()
        end)
    end)
end

if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
    hooksecurefunc("MegaMacro_TextBox_TextChanged",function()
        C_Timer.After(0,MakeEditorVibrant)
    end)
end
end
-- END CONSOLIDATED: Stage8_4.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_4_1.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.4.1
-- Precision cleanup after 8.4:
--  * exact 7x6 BindPad clipping
--  * profile strip truly left-aligned
--  * +/- controls forcibly moved into profile section
--  * parser-coloured MegaMacro text placed above raw editor
--  * legacy thick separators replaced by 1px borders
--  * BINDPAD GRID section fully removed from retired settings UI layout

local C={
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    thumb={.38,.40,.44,1},
    text={.93,.94,.96,1},
}

local GRID_ICON=50
local GRID_GAP=11
local GRID_COLS=8
local GRID_ROWS=7
local GRID_W=GRID_COLS*GRID_ICON+(GRID_COLS-1)*GRID_GAP
local GRID_H=GRID_ROWS*GRID_ICON+(GRID_ROWS-1)*GRID_GAP

local function ExactBindPadViewport()
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadGrid then
        return BPMMGoalLayout.ApplyBindPadGrid()
    end
    local sf=_G.BindPadScrollFrame
    if not sf then return end
    sf:SetWidth(GRID_W+4)
    sf:SetHeight(GRID_H)
    if sf.SetClipsChildren then sf:SetClipsChildren(true) end

    -- Keep the Stage 8 viewport border extremely thin.
    local old=sf.__BPMM81BG
    if old then old:Hide() end

    if not sf.__BPMM841Border then
        local border=CreateFrame("Frame",nil,sf,"BackdropTemplate")
        border:SetPoint("TOPLEFT",-1,1)
        border:SetPoint("BOTTOMRIGHT",1,-1)
        border:SetFrameLevel(math.max(0,(sf:GetFrameLevel() or 1)-1))
        border:EnableMouse(false)
        border:SetBackdrop({
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        sf.__BPMM841Border=border
    end
    sf.__BPMM841Border:SetBackdropBorderColor(unpack(C.border))
end

local function FindProfileButtons()
    local out={}
    if not BindPadFrame then return out end
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.__BPMM82Label then out[#out+1]=child end
    end
    table.sort(out,function(a,b)
        local an=tonumber((a.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        local bn=tonumber((b.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        return an<bn
    end)
    return out
end

local function ForceLowerLayout()
    if not BindPadFrame then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadLower then
        return BPMMGoalLayout.ApplyBindPadLower()
    end
    local panel=BindPadFrame.__BPMM82Lower
    if not panel then return end

    -- Lower panel spans almost the whole content width.
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",BindPadFrame,"BOTTOMLEFT",12,46)
    panel:SetPoint("BOTTOMRIGHT",BindPadFrame,"BOTTOMRIGHT",-12,46)
    panel:SetHeight(92)

    local title=BindPadFrame.__BPMM82LowerTitle
    if title then
        title:ClearAllPoints()
        title:SetPoint("BOTTOMLEFT",panel,"TOPLEFT",0,7)
    end

    -- Profiles begin flush with the left edge of the lower panel.
    for i,b in ipairs(FindProfileButtons()) do
        if i<=5 then
            b:SetSize(38,38)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",(i-1)*43,-15)
            if b.__BPMM82Label then
                b.__BPMM82Label:ClearAllPoints()
                b.__BPMM82Label:SetPoint("TOP",b,"BOTTOM",0,-5)
                b.__BPMM82Label:SetText("Profile "..i)
            end
        end
    end

    -- These names are from BindPad itself. Re-anchor every time because older
    -- Stage 6/8 hooks can redraw them back inside the grid.
    local less=_G.BindPadShowLessSlotButton
    local more=_G.BindPadShowMoreSlotButton

    if less then
        less:ClearAllPoints()
        less:SetSize(38,38)
        less:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-48,-15)
    end
    if more then
        more:ClearAllPoints()
        more:SetSize(38,38)
        more:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,-15)
    end
end

local function CleanLegacyBorders()
    -- BindPad thick viewport/scroll textures.
    local bsf=_G.BindPadScrollFrame
    if bsf then
        for _,r in ipairs({bsf:GetRegions()}) do
            if r and r.GetObjectType and r:GetObjectType()=="Texture" then
                r:SetAlpha(0)
            end
        end
    end

    -- MegaMacro old ClassTrainer separator bars.
    if _G.MegaMacro_HorizontalBarLeft then
        _G.MegaMacro_HorizontalBarLeft:SetAlpha(0)
    end
    if MegaMacro_Frame then
        for _,r in ipairs({MegaMacro_Frame:GetRegions()}) do
            if r and r.GetObjectType and r:GetObjectType()=="Texture" and r.GetTexture then
                local p=r:GetTexture()
                if type(p)=="string" and string.lower(p):find("ui-classtrainer-horizontalbar",1,true) then
                    r:SetAlpha(0)
                end
            end
        end
    end

    -- Editor's inherited tooltip-style border is replaced with 1px.
    if _G.MacroFrameTextBackground then
        _G.MacroFrameTextBackground:SetAlpha(0)
    end

    if MegaMacro_Frame and not MegaMacro_Frame.__BPMM841EditorBorder then
        local ed=CreateFrame("Frame",nil,MegaMacro_Frame,"BackdropTemplate")
        if _G.MegaMacro_FrameScrollFrame then
            ed:SetPoint("TOPLEFT",MegaMacro_FrameScrollFrame,"TOPLEFT",-2,2)
            ed:SetPoint("BOTTOMRIGHT",MegaMacro_FrameScrollFrame,"BOTTOMRIGHT",2,-2)
        end
        ed:SetFrameLevel(math.max(0,(MegaMacro_FrameScrollFrame and MegaMacro_FrameScrollFrame:GetFrameLevel() or 1)-1))
        ed:EnableMouse(false)
        ed:SetBackdrop({
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        ed:SetBackdropBorderColor(unpack(C.border))
        MegaMacro_Frame.__BPMM841EditorBorder=ed
    end

    if MegaMacro_Frame and _G.MegaMacro_ButtonScrollFrame and not MegaMacro_Frame.__BPMM841GridBorder then
        local gd=CreateFrame("Frame",nil,MegaMacro_Frame,"BackdropTemplate")
        gd:SetPoint("TOPLEFT",MegaMacro_ButtonScrollFrame,"TOPLEFT",-2,2)
        gd:SetPoint("BOTTOMRIGHT",MegaMacro_ButtonScrollFrame,"BOTTOMRIGHT",2,-2)
        gd:SetFrameLevel(math.max(0,MegaMacro_ButtonScrollFrame:GetFrameLevel()-1))
        gd:EnableMouse(false)
        gd:SetBackdrop({
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        gd:SetBackdropBorderColor(unpack(C.border))
        MegaMacro_Frame.__BPMM841GridBorder=gd
    end
end

local function FixMacroSyntaxLayer()
    -- Retired with the formatted editor. Never hide the native EditBox.
end

local function ShiftObjectY(obj,dy)
    if not obj or not obj.GetPoint then return end
    local point,relativeTo,relativePoint,x,y=obj:GetPoint(1)
    if not point then return end
    obj:ClearAllPoints()
    obj:SetPoint(point,relativeTo,relativePoint,x or 0,(y or 0)+dy)
end

local function RemoveBPUIGridSection()
    local panel=_G.BPMMScrollableSettingsPanel
    if not panel or panel.__BPMM841GridRemoved then return end

    local scroll,child
    for _,f in ipairs({panel:GetChildren()}) do
        if f.GetScrollChild and f:GetScrollChild() then
            scroll=f
            child=f:GetScrollChild()
            break
        end
    end
    if not child then return end

    local gridHeading,appearanceHeading,behaviorHeading

    for _,r in ipairs({child:GetRegions()}) do
        if r.GetText then
            local t=r:GetText()
            if t=="BINDPAD GRID" then gridHeading=r end
            if t=="APPEARANCE" then appearanceHeading=r end
            if t=="BEHAVIOR" then behaviorHeading=r end
        end
    end

    -- Hide grid heading and its line.
    if gridHeading then
        gridHeading:Hide()
        for _,r in ipairs({child:GetRegions()}) do
            if r.GetObjectType and r:GetObjectType()=="Texture" then
                local _,relativeTo=r:GetPoint(1)
                if relativeTo==gridHeading then r:Hide() end
            end
        end
    end

    local shift=126

    -- Hide the three obsolete grid rows; move everything below them upward.
    for _,row in ipairs({child:GetChildren()}) do
        local label
        for _,r in ipairs({row:GetRegions()}) do
            if r.GetText then
                local t=r:GetText()
                if t=="Icon Size" or t=="Icon Spacing" or t=="Icons Per Row" then
                    label=t
                end
            end
        end
        if label then
            row:Hide()
        else
            local top=row:GetTop()
            local childTop=child:GetTop()
            if top and childTop and top < childTop-240 then
                ShiftObjectY(row,shift)
            end
        end
    end

    if appearanceHeading then ShiftObjectY(appearanceHeading,shift) end
    if behaviorHeading then ShiftObjectY(behaviorHeading,shift) end

    child:SetHeight(math.max(320,child:GetHeight()-shift))
    panel.__BPMM841GridRemoved=true
end

local function Apply()
    ExactBindPadViewport()
    ForceLowerLayout()
    CleanLegacyBorders()
    FixMacroSyntaxLayer()
    RemoveBPUIGridSection()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.6,Apply)
    C_Timer.After(1.2,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
        C_Timer.After(.15,ForceLowerLayout)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end

if _G.BPMMScrollableSettingsPanel then
    BPMMScrollableSettingsPanel:HookScript("OnShow",function()
        C_Timer.After(0,RemoveBPUIGridSection)
    end)
end

if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
    hooksecurefunc("MegaMacro_TextBox_TextChanged",function()
        C_Timer.After(0,FixMacroSyntaxLayer)
    end)
end

if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",function()
        if _G.BPMMGoalLayout then return end
        C_Timer.After(.05,ForceLowerLayout)
    end)
end
end
-- END CONSOLIDATED: Stage8_4_1.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_4_2.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.4.2
-- Precision correction:
-- 1) BindPad exact 7x6: footer removed from scroll child after +/- reparent
-- 2) +/- controls moved into specialization profile panel
-- 3) MegaMacro scroll indicators completely hidden
-- 4) SAVE / CANCEL / DELETE restyled to flat Stage 8 theme and uppercase

local C={
    bg={.028,.032,.038,1},
    hover={.050,.058,.068,1},
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
}

-- ---------------------------------------------------------------------------
-- BindPad: remove the footer from the scrolling content entirely.
-- The original BindPad XML places Show Less / Show More inside
-- BindPadScrollFrameFooter, which is itself inside BindPadSlotButtonContainer.
-- That is why the footer / half-row kept appearing in the 7x6 viewport.
-- ---------------------------------------------------------------------------

local function StyleGlyphButton(b,glyph)
    if not b then return end

    local nt=b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt=b.GetPushedTexture and b:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local dt=b.GetDisabledTexture and b:GetDisabledTexture()
    if dt then dt:SetAlpha(0) end
    local ht=b.GetHighlightTexture and b:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end

    if not b.__BPMM842BG then
        local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        b.__BPMM842BG=bg

        local fs=b:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
        fs:SetPoint("CENTER",0,1)
        b.__BPMM842Glyph=fs

        b:HookScript("OnEnter",function(self)
            self.__BPMM842BG:SetBackdropColor(unpack(C.hover))
            self.__BPMM842BG:SetBackdropBorderColor(unpack(C.blue))
        end)
        b:HookScript("OnLeave",function(self)
            self.__BPMM842BG:SetBackdropColor(unpack(C.bg))
            self.__BPMM842BG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    b.__BPMM842BG:SetBackdropColor(unpack(C.bg))
    b.__BPMM842BG:SetBackdropBorderColor(unpack(C.border))
    b.__BPMM842Glyph:SetText(glyph)
    b.__BPMM842Glyph:SetTextColor(unpack(C.text))
end

local function MoveSlotControlsOutOfGrid()
    if not BindPadFrame then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadLower then
        return BPMMGoalLayout.ApplyBindPadLower()
    end
    local panel=BindPadFrame.__BPMM82Lower
    local less=_G.BindPadShowLessSlotButton
    local more=_G.BindPadShowMoreSlotButton
    local footer=_G.BindPadScrollFrameFooter
    if not panel or not less or not more then return end

    -- Actual fix: these buttons must no longer be children of the scrolling footer.
    less:SetParent(panel)
    more:SetParent(panel)

    less:ClearAllPoints()
    less:SetSize(38,38)
    less:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-48,-15)

    more:ClearAllPoints()
    more:SetSize(38,38)
    more:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,-15)

    less:SetFrameLevel(panel:GetFrameLevel()+5)
    more:SetFrameLevel(panel:GetFrameLevel()+5)

    StyleGlyphButton(less,"-")
    StyleGlyphButton(more,"+")

    -- The original 36px footer is what was visually producing the "6.5th row".
    -- Once its two buttons are reparented, it serves no purpose in the scroll child.
    if footer then
        footer:Hide()
        footer:SetHeight(0)
        footer:ClearAllPoints()
        footer:SetPoint("BOTTOMLEFT",BindPadSlotButtonContainer,"BOTTOMLEFT",0,0)
    end

    if _G.BindPadScrollFrameNumber then
        BindPadScrollFrameNumber:Hide()
        BindPadScrollFrameNumber:SetAlpha(0)
    end
end

local function LockExactViewport()
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadGrid then
        return BPMMGoalLayout.ApplyBindPadGrid()
    end
    local sf=_G.BindPadScrollFrame
    if not sf then return end

    -- 6*48 + 5*11 = 343px. This is exactly six complete icon rows.
    sf:SetHeight(343)
    if sf.SetClipsChildren then sf:SetClipsChildren(true) end

    -- Snap any residual fractional scroll position onto a whole row.
    local step=59
    local current=sf:GetVerticalScroll() or 0
    local range=sf:GetVerticalScrollRange() or 0
    local snapped=math.floor((current/step)+.5)*step
    sf:SetVerticalScroll(math.max(0,math.min(range,snapped)))
end

-- ---------------------------------------------------------------------------
-- MegaMacro: no scroll thumb / column at all.
-- ---------------------------------------------------------------------------

local function HideScrollUI(sf)
    if not sf then return end

    -- Stage 8.4 custom thumb.
    if sf.__BPMM84Thumb then
        sf.__BPMM84Thumb:Hide()
        sf.__BPMM84Thumb:SetAlpha(0)
    end

    -- Any native scrollbar.
    local sb=sf.ScrollBar
    if sb then
        sb:Hide()
        sb:SetAlpha(0)
    end

    local name=sf.GetName and sf:GetName()
    if name then
        for _,suffix in ipairs({
            "ScrollBar",
            "ScrollBarScrollUpButton",
            "ScrollBarScrollDownButton",
            "Top","Bottom","Middle",
        }) do
            local o=_G[name..suffix]
            if o then
                if o.Hide then o:Hide() end
                if o.SetAlpha then o:SetAlpha(0) end
            end
        end
    end
end

local function RemoveMegaScrollIndicators()
    HideScrollUI(_G.MegaMacro_ButtonScrollFrame)
    HideScrollUI(_G.MegaMacro_FrameScrollFrame)
    HideScrollUI(_G.MegaMacro_FormattedFrameScrollFrame)
end

-- ---------------------------------------------------------------------------
-- Flat footer/editor buttons.
-- ---------------------------------------------------------------------------

local function StyleFlatButton(button,label)
    if not button then return end

    button:SetText(label)

    local nt=button.GetNormalTexture and button:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt=button.GetPushedTexture and button:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local ht=button.GetHighlightTexture and button:GetHighlightTexture()
    if ht then ht:SetAlpha(0) end
    local dt=button.GetDisabledTexture and button:GetDisabledTexture()
    if dt then dt:SetAlpha(0) end

    -- Hide all inherited button-template textures.
    for _,r in ipairs({button:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" then
            r:SetAlpha(0)
        end
    end

    if not button.__BPMM842FlatBG then
        local bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(button:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        button.__BPMM842FlatBG=bg

        button:HookScript("OnEnter",function(self)
            if self:IsEnabled() then
                self.__BPMM842FlatBG:SetBackdropColor(unpack(C.hover))
                self.__BPMM842FlatBG:SetBackdropBorderColor(unpack(C.blue))
            end
        end)
        button:HookScript("OnLeave",function(self)
            self.__BPMM842FlatBG:SetBackdropColor(unpack(C.bg))
            self.__BPMM842FlatBG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    button.__BPMM842FlatBG:SetBackdropColor(unpack(C.bg))
    button.__BPMM842FlatBG:SetBackdropBorderColor(unpack(C.border))

    local fs=button.GetFontString and button:GetFontString()
    if fs then
        fs:SetTextColor(unpack(C.text))
    end
end

local function StyleMegaButtons()
    StyleFlatButton(_G.MegaMacro_SaveButton,"SAVE")
    StyleFlatButton(_G.MegaMacro_CancelButton,"CANCEL")
    StyleFlatButton(_G.MegaMacro_DeleteButton,"DELETE")
end

local function Apply()
    MoveSlotControlsOutOfGrid()
    LockExactViewport()
    RemoveMegaScrollIndicators()
    StyleMegaButtons()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,Apply)
    C_Timer.After(1.0,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
        C_Timer.After(.1,function()
            MoveSlotControlsOutOfGrid()
            LockExactViewport()
        end)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,function()
            RemoveMegaScrollIndicators()
            StyleMegaButtons()
        end)
    end)
end

if type(_G.BindPadSlot_UpdateState)=="function" then
    hooksecurefunc("BindPadSlot_UpdateState",function()
        if _G.BPMMGoalLayout then return end
        C_Timer.After(.05,function()
            MoveSlotControlsOutOfGrid()
            LockExactViewport()
        end)
    end)
end
end
-- END CONSOLIDATED: Stage8_4_2.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_5.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.5
-- Final Stage 8 layout polish.
-- Focus:
--  * clean BindPad profile alignment / labels / heading
--  * modernize lower utility controls toward neutral + blue/cyan
--  * remove MegaMacro ghost/native title remnants
--  * give character counter and centered search separate footer space
--  * preserve stable 7x6 grid geometry and all Stage 7/8 behavior

local C={
    bg={.028,.032,.038,1},
    hover={.050,.058,.068,1},
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
    muted={.62,.65,.69,1},
}

-- ---------------------------------------------------------------------------
-- BindPad profile section
-- ---------------------------------------------------------------------------

local function GetProfiles()
    local t={}
    if not BindPadFrame then return t end
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.__BPMM82Label then
            t[#t+1]=child
        end
    end
    table.sort(t,function(a,b)
        local ai=tonumber((a.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        local bi=tonumber((b.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        return ai<bi
    end)
    return t
end

local function PolishProfiles()
    if not BindPadFrame then return end
    if _G.BPMMGoalLayout and BPMMGoalLayout.ApplyBindPadLower then
        return BPMMGoalLayout.ApplyBindPadLower()
    end
    local panel=BindPadFrame.__BPMM82Lower
    if not panel then return end

    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",BindPadFrame,"BOTTOMLEFT",12,46)
    panel:SetPoint("BOTTOMRIGHT",BindPadFrame,"BOTTOMRIGHT",-12,46)
    panel:SetHeight(96)

    local title=BindPadFrame.__BPMM82LowerTitle
    if title then
        title:Show()
        title:SetText("Specialization Profiles")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints()
        title:SetPoint("BOTTOMLEFT",panel,"TOPLEFT",0,7)
    end

    local profiles=GetProfiles()
    local colW=48
    local icon=38
    local startX=0

    for i,b in ipairs(profiles) do
        if i<=5 then
            b:SetSize(icon,icon)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",startX+(i-1)*colW,-15)

            local label=b.__BPMM82Label
            if label then
                label:Show()
                label:SetText("Profile "..i)
                label:SetWidth(colW)
                label:SetJustifyH("CENTER")
                label:ClearAllPoints()
                label:SetPoint("TOP",b,"BOTTOM",0,-5)
                label:SetTextColor(unpack(C.text))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- BindPad bottom utility area
-- ---------------------------------------------------------------------------

local function FindTextByExact(root,text)
    if not root then return nil end
    for _,r in ipairs({root:GetRegions()}) do
        if r.GetText and r:GetText()==text then return r end
    end
    for _,child in ipairs({root:GetChildren()}) do
        for _,r in ipairs({child:GetRegions()}) do
            if r.GetText and r:GetText()==text then return r,child end
        end
    end
end

local function ColorUtilityText()
    if not BindPadFrame then return end

    for _,labelText in ipairs({"Save All Keys","Show Hotkeys"}) do
        local fs=FindTextByExact(BindPadFrame,labelText)
        if fs then
            fs:SetTextColor(unpack(C.text))
        end
    end

    -- Recolor checkmark textures toward the single Stage 8 accent.
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("CheckButton") then
            local checked=child.GetCheckedTexture and child:GetCheckedTexture()
            if checked and checked.SetVertexColor then
                checked:SetVertexColor(unpack(C.blue))
            end
            local hi=child.GetHighlightTexture and child:GetHighlightTexture()
            if hi and hi.SetVertexColor then
                hi:SetVertexColor(unpack(C.blue))
            end
        end
    end
end

local function FlatUtilityButton(b)
    if not b or b.__BPMM85Util then return end

    local fb=BindPadFrame and BindPadFrame:GetBottom()
    local bottom=b:GetBottom()
    local w,h=b:GetSize()
    if not fb or not bottom or not w or not h then return end
    if bottom>fb+58 or w<25 or w>58 or h<25 or h>58 then return end

    b.__BPMM85Util=true

    -- Keep original pictograms, but remove old ornamental button chrome.
    local nt=b.GetNormalTexture and b:GetNormalTexture()
    local pt=b.GetPushedTexture and b:GetPushedTexture()
    local ht=b.GetHighlightTexture and b:GetHighlightTexture()
    if pt then pt:SetAlpha(0) end
    if ht then ht:SetAlpha(0) end

    if not b.__BPMM85BG then
        local bg=CreateFrame("Frame",nil,b,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,b:GetFrameLevel()-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        b.__BPMM85BG=bg

        b:HookScript("OnEnter",function(self)
            self.__BPMM85BG:SetBackdropColor(unpack(C.hover))
            self.__BPMM85BG:SetBackdropBorderColor(unpack(C.blue))
        end)
        b:HookScript("OnLeave",function(self)
            self.__BPMM85BG:SetBackdropColor(unpack(C.bg))
            self.__BPMM85BG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    b.__BPMM85BG:SetBackdropColor(unpack(C.bg))
    b.__BPMM85BG:SetBackdropBorderColor(unpack(C.border))

    -- Keep icon art readable.
    if nt then nt:SetAlpha(1) end
end

local function PolishUtilities()
    if not BindPadFrame then return end
    ColorUtilityText()
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("Button") then
            FlatUtilityButton(child)
        end
    end
end

-- ---------------------------------------------------------------------------
-- MegaMacro titles
-- ---------------------------------------------------------------------------

local function RemoveGhostTitles()
    if not MegaMacro_Frame then return end

    if MegaMacro_Frame.TitleContainer and MegaMacro_Frame.TitleContainer.TitleText then
        MegaMacro_Frame.TitleContainer.TitleText:SetAlpha(0)
    end

    if _G.MegaMacro_FrameTitleText then
        MegaMacro_FrameTitleText:SetAlpha(0)
    end

    -- Hide legacy title font strings in the very top strip, except our Stage 8 title.
    local top=MegaMacro_Frame:GetTop()
    if top then
        for _,r in ipairs({MegaMacro_Frame:GetRegions()}) do
            if r.GetObjectType and r:GetObjectType()=="FontString" and r~=MegaMacro_Frame.__BPMM81Title then
                local rt=r:GetTop()
                if rt and rt>top-38 then
                    local t=r:GetText()
                    if t=="Mega Macro - Create Macros" or t=="MegaMacro" then
                        r:SetAlpha(0)
                    end
                end
            end
        end
    end

    if MegaMacro_Frame.__BPMM81Title then
        MegaMacro_Frame.__BPMM81Title:SetText("BetterMacro")
        MegaMacro_Frame.__BPMM81Title:SetTextColor(unpack(C.text))
    end
end

-- ---------------------------------------------------------------------------
-- MegaMacro footer
-- ---------------------------------------------------------------------------

local function PolishFooter()
    if not MegaMacro_Frame then return end

    if _G.BPMMGoalLayout and _G.BPMMGoalLayout.ApplyMegaMacroFooter then
        _G.BPMMGoalLayout.ApplyMegaMacroFooter()
        return
    end

    local search=_G.BPMMUnifiedSearch
    local char=_G.MegaMacro_FrameCharLimitText
    local del=_G.MegaMacro_DeleteButton
    local loc=_G.BPMM74LocateButton

    -- Search stays centered, but slightly lower in its own footer row.
    if search then
        search:ClearAllPoints()
        search:SetSize(340,26)
        search:SetPoint("BOTTOM",MegaMacro_Frame,"BOTTOM",0,8)
    end

    -- Character counter gets its own centered line just above footer controls.
    if char then
        char:ClearAllPoints()
        char:SetPoint("BOTTOM",MegaMacro_Frame,"BOTTOM",0,38)
        char:SetWidth(220)
        char:SetJustifyH("CENTER")
        char:SetTextColor(unpack(C.muted))
        char:SetAlpha(1)
    end

    -- Keep DELETE left and Locate right with symmetric footer margins.
    if del then
        del:ClearAllPoints()
        del:SetPoint("BOTTOMLEFT",MegaMacro_Frame,"BOTTOMLEFT",12,8)
        del:SetSize(96,26)
    end
    if loc then
        loc:ClearAllPoints()
        loc:SetPoint("BOTTOMRIGHT",MegaMacro_Frame,"BOTTOMRIGHT",-12,8)
        loc:SetSize(96,26)
    end
end

local function Apply()
    PolishProfiles()
    PolishUtilities()
    RemoveGhostTitles()
    PolishFooter()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,Apply)
    C_Timer.After(1.0,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,function()
            PolishProfiles()
            PolishUtilities()
        end)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,function()
            RemoveGhostTitles()
            PolishFooter()
        end)
    end)
end

if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
    hooksecurefunc("MegaMacro_TextBox_TextChanged",function()
        C_Timer.After(0,PolishFooter)
    end)
end
end
-- END CONSOLIDATED: Stage8_5.lua

-- ============================================================
-- BEGIN CONSOLIDATED: Stage8_5_1.lua
-- ============================================================
do
-- BindPad + MegaMacro Stage 8.5.1
-- Surgical MegaMacro drag correction.
-- No visual/layout/grid/macro/profile changes.
--
-- Stage 6 introduced a custom shell-based drag system. Later layout stages can
-- leave MegaMacro_Frame with non-CENTER anchors. Calling StartMoving() on that
-- anchored frame lets WoW normalize the anchor at drag start, producing the
-- diagonal "jump" before normal movement begins.
--
-- This patch does NOT use StartMoving().
-- It records:
--   1) the cursor position at mouse-down
--   2) the frame's current screen-space center
-- Then OnUpdate applies only the cursor delta to that original center.
-- Therefore mouse-down itself cannot change the frame position.

local drag = {
    active = false,
    frame = nil,
    shell = nil,
    startCursorX = 0,
    startCursorY = 0,
    startCenterX = 0,
    startCenterY = 0,
    scale = 1,
}

local function GetCursorUI()
    local x,y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    if not s or s == 0 then s = 1 end
    return x/s, y/s
end

local function SavePosition(frame)
    if not frame then return end

    local cx,cy = frame:GetCenter()
    if not cx or not cy then return end

    -- Preserve the position in the same CENTER-relative form used by the
    -- consolidated UI code, without touching any macro data.
    local ux,uy = UIParent:GetCenter()
    if not ux or not uy then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER",UIParent,"CENTER",cx-ux,cy-uy)

    -- If Stage 6 exposed a position saver, let it persist the now-correct
    -- anchor. We intentionally support the known historical names without
    -- requiring one of them.
    local saver =
        _G.BPMM_SaveMegaMacroPosition or
        _G.BPMM_SaveWindowPositions or
        _G.BPMMSavePositions

    if type(saver)=="function" then
        pcall(saver)
    end
end

local mover = CreateFrame("Frame")
mover:Hide()

mover:SetScript("OnUpdate",function()
    if not drag.active or not drag.frame then
        mover:Hide()
        return
    end

    if not IsMouseButtonDown("LeftButton") then
        drag.active=false
        SavePosition(drag.frame)
        drag.frame=nil
        drag.shell=nil
        mover:Hide()
        return
    end

    local x,y = GetCursorUI()
    local dx=x-drag.startCursorX
    local dy=y-drag.startCursorY

    -- Use only the cursor delta. No anchor conversion occurs during movement.
    local frame=drag.frame
    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "BOTTOMLEFT",
        drag.startCenterX+dx,
        drag.startCenterY+dy
    )
end)

local function BeginDrag(frame,shell)
    if not frame or InCombatLockdown() then return end

    local cx,cy=frame:GetCenter()
    if not cx or not cy then return end

    local x,y=GetCursorUI()

    drag.active=true
    drag.frame=frame
    drag.shell=shell
    drag.startCursorX=x
    drag.startCursorY=y
    drag.startCenterX=cx
    drag.startCenterY=cy

    -- Critical point: do not ClearAllPoints(), SetPoint(), or StartMoving()
    -- here. Mouse-down must be position-neutral.
    mover:Show()
end

local function EndDrag()
    if not drag.active then return end
    drag.active=false

    if drag.frame then
        SavePosition(drag.frame)
    end

    drag.frame=nil
    drag.shell=nil
    mover:Hide()
end

local function Install()
    if _G.BetterAppearanceConfig then return end
    local frame=_G.MegaMacro_Frame
    if not frame then return end

    local shell=frame.__BPMMShell
    if not shell then
        shell=CreateFrame("Frame",nil,frame)
        frame.__BPMMShell=shell
    end

    -- Compatibility/UI originally creates this shell across the entire BM
    -- window. Once it becomes mouse-enabled for dragging it can sit over the
    -- macro editor and consume clicks/wheel input. Always reduce it to the
    -- actual title bar, even when the shell already existed.
    shell:ClearAllPoints()
    shell:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
    shell:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    shell:SetHeight(38)
    shell:SetFrameLevel(frame:GetFrameLevel()+20)

    shell:EnableMouse(true)
    shell:RegisterForDrag("LeftButton")

    -- Replace the Stage 6 drag scripts on this shell. SetScript is deliberate:
    -- leaving the old StartMoving handler hooked would still produce the jump.
    shell:SetScript("OnDragStart",function(self)
        BeginDrag(frame,self)
    end)

    shell:SetScript("OnDragStop",function()
        EndDrag()
    end)

    -- Some prior stages used mouse-down/up instead of drag-start/stop.
    -- Keep these position-neutral and use them only as a fallback.
    shell:SetScript("OnMouseDown",function(self,button)
        if button=="LeftButton" then
            BeginDrag(frame,self)
        end
    end)

    shell:SetScript("OnMouseUp",function(self,button)
        if button=="LeftButton" then
            EndDrag()
        end
    end)

    frame:SetMovable(false) -- guarantees no legacy StartMoving path can fire
    frame:SetClampedToScreen(false)

    frame.__BPMM851DragInstalled=true
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,Install)
    C_Timer.After(1.0,Install)
end)

if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Install)
    end)
end
end
-- END CONSOLIDATED: Stage8_5_1.lua
