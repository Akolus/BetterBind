-- BindPad + MegaMacro target layout.
-- Matches the approved wide/tall composition while retaining the original
-- buttons, scripts, macro data, key bindings, profiles, and drag behavior.

local Goal={}
_G.BPMMGoalLayout=Goal

local WHITE="Interface\\Buttons\\WHITE8x8"
local C={
    shell={.018,.020,.024,.99},
    panel={.014,.017,.021,.99},
    panel2={.030,.034,.040,1},
    border={.13,.14,.16,1},
    muted={.62,.64,.68,1},
    text={.93,.94,.96,1},
    yellow={1,.82,.02,1},
    blue={.02,.58,.94,1},
    red={.42,.02,.02,1},
}

local BP_W,BP_H=532,696
local MM_W,MM_H=722,696
local BP_ICON,BP_GAP,BP_COLS,BP_ROWS=50,11,8,7
local BP_GRID_H=BP_ROWS*BP_ICON+(BP_ROWS-1)*BP_GAP
local MM_ICON,MM_X_GAP,MM_COLS,MM_ROWS=50,7,12,4
local SLOT_CONTROL_SIZE=36
local SLOT_CONTROL_GLYPH=22
local SLOT_CONTROL_THICKNESS=5

local function GetAppearance(group,defaultSpacing)
    if _G.BetterBindAppearance_Get then
        return _G.BetterBindAppearance_Get(group)
    end
    return {style="crop",zoom=0,spacing=defaultSpacing or 0}
end

local ROUNDED_MASK="Interface\\AddOns\\BetterBind\\UI\\media\\roundedmask"

local function SetRoundedCorners(owner,icon,show)
    if not owner or not icon then return end
    local mask=icon.__BPMMMask or icon.__BetterBindAppearanceMask
    if mask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture,icon,mask)
    end
    if show and icon.CreateMaskTexture and icon.AddMaskTexture then
        if not mask then
            mask=icon:CreateMaskTexture()
            mask:SetTexture(ROUNDED_MASK,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(icon)
            icon.__BetterBindAppearanceMask=mask
        end
        mask:Show()
        pcall(icon.AddMaskTexture,icon,mask)
    elseif mask then
        mask:Hide()
    end

    local corners=owner.__BetterBindRoundedCorners
    local needsFallback=show and not (icon.CreateMaskTexture and icon.AddMaskTexture)
    if not needsFallback then
        if corners then
            for _,corner in ipairs(corners) do corner:Hide() end
        end
        return
    end
    if not corners then
        corners={}
        for i=1,8 do
            local corner=owner:CreateTexture(nil,"OVERLAY",nil,7)
            corner:SetColorTexture(unpack(C.panel))
            corners[i]=corner
        end
        owner.__BetterBindRoundedCorners=corners
    end

    local anchors={
        {"TOPLEFT",3,1,0,0},{"TOPLEFT",1,3,0,0},
        {"TOPRIGHT",3,1,0,0},{"TOPRIGHT",1,3,0,0},
        {"BOTTOMLEFT",3,1,0,0},{"BOTTOMLEFT",1,3,0,0},
        {"BOTTOMRIGHT",3,1,0,0},{"BOTTOMRIGHT",1,3,0,0},
    }
    for i,corner in ipairs(corners) do
        corner:ClearAllPoints()
        corner:SetPoint(anchors[i][1],icon,anchors[i][1],anchors[i][4],anchors[i][5])
        corner:SetSize(anchors[i][2],anchors[i][3])
        corner:SetShown(needsFallback)
    end
end

local function ApplyIconAppearance(owner,icon,group)
    if not owner or not icon then return end
    local appearance=GetAppearance(group,0)
    local baseCrop=appearance.style=="full" and 0 or .06
    local zoom=math.max(0,tonumber(appearance.zoom) or 0)/100
    local span=(1-(2*baseCrop))/(1+zoom)
    local crop=math.max(0,math.min(.24,(1-span)/2))
    icon:SetTexCoord(crop,1-crop,crop,1-crop)
    SetRoundedCorners(owner,icon,appearance.style=="rounded")
end

_G.BetterBindAppearance_ApplyTexture=ApplyIconAppearance

local function SetFontSize(region,size,flags)
    if not region or not region.GetFont or not region.SetFont then return end
    local path,_,oldFlags=region:GetFont()
    if path then region:SetFont(path,size,flags or oldFlags) end
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
        parent[key]=panel
    end
    Backdrop(panel,C.panel,C.border)
    return panel
end

local function EnsureOverlay(parent,key,levelOffset)
    if not parent then return end
    local overlay=parent[key]
    if not overlay then
        overlay=CreateFrame("Frame",nil,parent)
        overlay:EnableMouse(false)
        parent[key]=overlay
    end
    overlay:ClearAllPoints()
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel((parent:GetFrameLevel() or 1)+(levelOffset or 20))
    overlay:Show()
    return overlay
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

    HideObject(scrollFrame.__BPMMGoalTrack)
    HideObject(scrollFrame.__BPMM84Thumb)
end

local function HideTextureRegions(frame)
    if not frame or not frame.GetRegions then return end
    for _,region in ipairs({frame:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType()=="Texture" then
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
            local fill=tab.__BPMMGoalTabFill
            local edges=tab.__BPMMGoalTabEdges
            for _,region in ipairs({tab:GetRegions()}) do
                local isCustom=region==fill
                if not isCustom and edges then
                    for _,edge in ipairs(edges) do
                        if region==edge then isCustom=true; break end
                    end
                end
                if not isCustom and region.GetObjectType and region:GetObjectType()=="Texture" then
                    HideObject(region)
                end
            end

            for _,key in ipairs({
                "__BPMMTabBG","__BPMM721BG","__BPMM73BG","__BPMM81BG",
                "__BPMM861BG","__BPMM862BG",
            }) do
                HideObject(tab[key])
            end

            if not fill then
                fill=tab:CreateTexture(nil,"BACKGROUND",nil,-8)
                fill:SetPoint("TOPLEFT",tab,"TOPLEFT",1,-1)
                fill:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-1,1)
                tab.__BPMMGoalTabFill=fill
            end
            if not edges then
                edges={}
                for edgeIndex=1,4 do
                    edges[edgeIndex]=tab:CreateTexture(nil,"BORDER",nil,7)
                end
                edges[1]:SetPoint("TOPLEFT",tab,"TOPLEFT",1,-1)
                edges[1]:SetPoint("TOPRIGHT",tab,"TOPRIGHT",-1,-1)
                edges[1]:SetHeight(1)
                edges[2]:SetPoint("BOTTOMLEFT",tab,"BOTTOMLEFT",1,1)
                edges[2]:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-1,1)
                edges[2]:SetHeight(1)
                edges[3]:SetPoint("TOPLEFT",tab,"TOPLEFT",1,-1)
                edges[3]:SetPoint("BOTTOMLEFT",tab,"BOTTOMLEFT",1,1)
                edges[3]:SetWidth(1)
                edges[4]:SetPoint("TOPRIGHT",tab,"TOPRIGHT",-1,-1)
                edges[4]:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-1,1)
                edges[4]:SetWidth(1)
                tab.__BPMMGoalTabEdges=edges
            end

            local selected=i==selectedIndex
            fill:SetColorTexture(
                selected and .025 or C.panel2[1],
                selected and .105 or C.panel2[2],
                selected and .165 or C.panel2[3],
                1
            )
            for _,edge in ipairs(edges) do
                if selected then
                    edge:SetColorTexture(unpack(C.blue))
                else
                    edge:SetColorTexture(unpack(C.border))
                end
                edge:SetAlpha(1)
                edge:Show()
            end
            fill:SetAlpha(1)
            fill:Show()
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
    HideObject(inset.__BPMMInsetBG)
    HideObject(inset.__BPMM81BG)
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

            -- Integration/UI.lua created an earlier full-frame shell.  It is
            -- still the MegaMacro drag hit-zone, so keep the frame alive but
            -- remove its obsolete backdrop beneath the Stage 8.1 shell.
            local oldShell=frame.__BPMMShell
            if oldShell and oldShell~=frame.__BPMM81Shell and oldShell.SetBackdrop then
                oldShell:SetBackdrop(nil)
            end
        end
    end

    local bindScroll=_G.BindPadScrollFrame
    local macroGrid=_G.MegaMacro_ButtonScrollFrame
    local macroEditor=_G.MegaMacro_FrameScrollFrame
    local formattedEditor=_G.MegaMacro_FormattedFrameScrollFrame
    for _,scroll in pairs({bindScroll,macroGrid,macroEditor,formattedEditor}) do
        if scroll then
            HideObject(scroll.__BPMM81BG)
            HideObject(scroll.__BPMM841Border)
            HideObject(scroll.__BPMM861ThinBorder)
            HideObject(scroll.__BPMM862Outline)
        end
        HideScrollBar(scroll)
    end

    if mega then
        HideObject(mega.__BPMM841GridBorder)
        HideObject(mega.__BPMM841EditorBorder)
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

    for _,key in ipairs({"__BPMMFlatBG","__BPMM84BG","__BPMM842BG"}) do
        HideObject(button[key])
    end
    for _,key in ipairs({"__BPMM84Glyph","__BPMM842Glyph"}) do
        local oldGlyph=button[key]
        if oldGlyph then oldGlyph:Hide(); oldGlyph:SetAlpha(0) end
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

    local oldLabel=button.__BPMMGoalSlotControlGlyph
    if oldLabel then
        oldLabel:SetAlpha(0)
        oldLabel:Hide()
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
                self.__BPMMGoalSlotControlBG:SetBackdropColor(.055,.075,.095,1)
                self.__BPMMGoalSlotControlBG:SetBackdropBorderColor(unpack(C.blue))
            end
        end)
        button:HookScript("OnLeave",function(self)
            self.__BPMMGoalSlotControlBG:SetBackdropColor(unpack(C.panel2))
            self.__BPMMGoalSlotControlBG:SetBackdropBorderColor(unpack(C.border))
        end)
    end
end

local function StyleUtilityToggle(button)
    if not button then return end

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
        customMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        customMark:SetSize(30,30)
        customMark:SetPoint("CENTER",button,"CENTER",0,0)
        customMark:SetDesaturated(true)
        customMark:SetVertexColor(unpack(C.blue))
        customMark:SetBlendMode("ADD")
        button.__BPMMGoalUtilityMark=customMark
    end

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
            self.__BPMMGoalUtilityBG:SetBackdropColor(.055,.075,.095,1)
            self.__BPMMGoalUtilityBG:SetBackdropBorderColor(unpack(C.blue))
        end)
        button:HookScript("OnLeave",Refresh)
    end
end

local function EnsureProfileLabel(overlay,button,index)
    local label=button.__BPMMGoalLabel
    if not label then
        label=overlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        button.__BPMMGoalLabel=label
    end
    label:SetText("Profile "..index)
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
            SetFontSize(button.name,9)
        end
        if button.hotkey then
            button.hotkey:SetWidth(BP_ICON-2)
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

    local panel=frame.__BPMM82Lower or EnsurePanel(frame,"__BPMM82Lower")
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,66)
    panel:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,66)
    panel:SetHeight(110)
    panel:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    Backdrop(panel,C.panel,C.border)

    local overlay=EnsureOverlay(panel,"__BPMMGoalOverlay",30)
    if frame.__BPMM82LowerTitle then
        frame.__BPMM82LowerTitle:Hide()
        frame.__BPMM82LowerTitle:SetAlpha(0)
    end
    local title=overlay.__BPMMGoalTitle
    if not title then
        title=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        overlay.__BPMMGoalTitle=title
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
    local profileStep=38+profileAppearance.spacing
    for i=1,5 do
        local button=_G["BindPadProfileTab"..i]
        if button then
            button:SetShown(showProfiles)
            button:SetSize(38,38)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",panel,"TOPLEFT",10+(i-1)*profileStep,-38)
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
            end
            if button.__BPMM82Label then
                button.__BPMM82Label:Hide()
                button.__BPMM82Label:SetAlpha(0)
            end
            local label=EnsureProfileLabel(overlay,button,i)
            label:ClearAllPoints()
            label:SetPoint("TOP",button,"BOTTOM",0,-5)
            label:SetShown(showProfiles)
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
        button:SetSize(SLOT_CONTROL_SIZE,SLOT_CONTROL_SIZE)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT",footer,"BOTTOMLEFT",x,14)
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
    check(_G.BindPadFrameSaveAllKeysButton,18,118)
    check(_G.BindPadFrameShowHotkeyButton,270,118)
    if _G.BindPadFrameCharacterButton then BindPadFrameCharacterButton:Hide() end
end

local function LayoutBindPad()
    local frame=_G.BindPadFrame
    if not frame then return end
    frame:SetSize(BP_W,BP_H)
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
                button.Icon:SetPoint("TOPLEFT",button,"TOPLEFT",2,-2)
                button.Icon:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-2,2)
                ApplyIconAppearance(button,button.Icon,"bettermacro")
            end
            if button.Name then
                button.Name:SetWidth(MM_ICON-2)
                SetFontSize(button.Name,9)
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

local function StyleGoalButton(button,text,danger)
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
    end
    StripNativeArtwork()

    local bg=button.__BPMMGoalBG
    if not bg then
        bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,button:GetFrameLevel()-1))
        bg:EnableMouse(false)
        button.__BPMMGoalBG=bg
    end

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

    local function ApplyColors(isHover)
        local fill=danger and C.red or (isHover and {.055,.075,.095,1} or C.panel2)
        local edge=isHover and C.blue or (danger and {.68,.12,.10,1} or C.border)
        goalFill:SetColorTexture(unpack(fill))
        goalFill:SetAlpha(1)
        goalFill:Show()
        local keys={
            "__BPMMFlatBG","__BPMM721BG","__BPMM73BG","__BPMM81BG",
            "__BPMM842FlatBG","__BPMM85BG","__BPMM861BG","__BPMM862BG",
            "__BPMMGoalBG","__BPMMGoalBorder",
        }
        for _,key in ipairs(keys) do
            local layer=button[key]
            if layer and layer.SetBackdropColor then
                layer:SetBackdropColor(unpack(fill))
                layer:SetBackdropBorderColor(unpack(edge))
            end
        end
        if button.SetBackdropColor then
            button:SetBackdropColor(unpack(fill))
            button:SetBackdropBorderColor(unpack(edge))
        end
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

local function HideNativeMegaTitle()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    for _,region in ipairs({frame:GetRegions()}) do
        if region.GetText and region:GetText()=="Mega Macro - Create Macros" then
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
            if region~=selectedIcon and region.GetObjectType
                and region:GetObjectType()=="Texture"
            then
                HideObject(region)
            end
        end

        local infoBG=selected.__BPMMGoalInfoBackground
        if not infoBG then
            infoBG=CreateFrame("Frame",nil,selected,"BackdropTemplate")
            infoBG:SetAllPoints(selected)
            infoBG:EnableMouse(false)
            selected.__BPMMGoalInfoBackground=infoBG
        end
        infoBG:SetFrameLevel(math.max(0,selected:GetFrameLevel()-1))
        Backdrop(infoBG,C.panel2,C.border)
        infoBG:SetAlpha(1)
        infoBG:Show()
    end
    if _G.MegaMacro_FrameSelectedMacroButtonIcon then
        local icon=MegaMacro_FrameSelectedMacroButtonIcon
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT",selected or background,"TOPLEFT",2,-2)
        icon:SetPoint("BOTTOMRIGHT",selected or background,"BOTTOMRIGHT",-2,2)
        icon:SetAlpha(1)
        icon:Show()
        ApplyIconAppearance(selected or frame,icon,"bettermacro")
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

    if _G.BPMMBetterMacroEditor and _G.BPMMBetterMacroEditor.Apply then
        _G.BPMMBetterMacroEditor.Apply()
    end

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
        local edit=_G.BPMMUnifiedSearchEditBox
        if edit then SetFontSize(edit,11) end
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
Goal.HideLegacyBorders=HideLegacyBorders

function Goal.ApplyTitles()
    local bind=_G.BindPadFrame
    if bind then
        if bind.__BPMM81Title then
            bind.__BPMM81Title:Hide()
            bind.__BPMM81Title:SetAlpha(0)
        end
        local overlay=EnsureOverlay(bind,"__BPMMGoalTitleOverlay",60)
        local title=overlay.__BPMMGoalTitle
        if not title then
            title=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            overlay.__BPMMGoalTitle=title
        end
        title:Show(); title:SetAlpha(1); title:SetText("BetterBind")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints(); title:SetPoint("TOP",bind,"TOP",0,-11)
        SetFontSize(title,14)
    end

    local mega=_G.MegaMacro_Frame
    if mega then
        if mega.__BPMM81Title then
            mega.__BPMM81Title:Hide()
            mega.__BPMM81Title:SetAlpha(0)
        end
        HideNativeMegaTitle()
        local overlay=EnsureOverlay(mega,"__BPMMGoalTitleOverlay",60)
        local native=overlay.__BPMMGoalNativeTitle
        if native then
            native:Hide()
            native:SetAlpha(0)
        end

        local title=overlay.__BPMMGoalTitle
        if not title then
            title=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            overlay.__BPMMGoalTitle=title
        end
        title:Show(); title:SetAlpha(1); title:SetText("BetterMacro")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints(); title:SetPoint("TOP",mega,"TOP",0,-11)
        SetFontSize(title,15)
    end
end

local function LayoutMegaMacro()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    frame:SetSize(MM_W,MM_H)
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

function Goal.Apply()
    LayoutBindPad()
    LayoutMegaMacro()
    HideLegacyBorders()
    Goal.ApplyTitles()
end

local function ApplyBindPadNow()
    LayoutBindPad()
    HideLegacyBorders()
    Goal.ApplyTitles()
end

Goal.ApplyBindPad=ApplyBindPadNow

local event=CreateFrame("Frame")
event:RegisterEvent("PLAYER_LOGIN")
event:SetScript("OnEvent",function()
    C_Timer.After(.1,Goal.Apply)
    C_Timer.After(.65,Goal.Apply)
    C_Timer.After(1.3,Goal.Apply)
end)

if type(_G.BindPadFrame_OnShow)=="function" then
    hooksecurefunc("BindPadFrame_OnShow",ApplyBindPadNow)
elseif _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",ApplyBindPadNow)
end
if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Goal.Apply)
        C_Timer.After(.2,Goal.Apply)
    end)
end
if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        LayoutMegaMacro()
        HideLegacyBorders()
        Goal.ApplyTitles()
    end)
end
if type(_G.MegaMacro_MacroButton_OnClick)=="function" then
    hooksecurefunc("MegaMacro_MacroButton_OnClick",function()
        C_Timer.After(0,function()
            LayoutMegaMacroEditor()
            LayoutMegaMacroFooter()
        end)
    end)
end
