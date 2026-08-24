-- BetterBind / BetterMacro appearance controls, Icon Browser skin and stable
-- BetterMacro title dragging.

local Appearance={}
_G.BetterAppearanceConfig=Appearance

local WHITE="Interface\\Buttons\\WHITE8x8"
local C={
    shell={.045,.052,.060,.98},
    panel={.052,.060,.070,.90},
    panel2={.070,.080,.092,.94},
    border={.18,.21,.25,1},
    muted={.62,.64,.68,1},
    text={.93,.94,.96,1},
    blue={.02,.58,.94,1},
}
local CONTROL_HOVER={.085,.095,.108,.96}
local CONTROL_HOVER_EDGE={.28,.34,.40,1}
local CONTROL_HOVER_ACCENT={.18,.72,.72,1}
local sections={}
local configBuilt=false

local definitions={
    {group="bindpad",title="BetterBind grid",spacingMax=11},
    {group="profiles",title="Specialization profiles",spacingMax=18},
    {group="bettermacro",title="BetterMacro grid",spacingMax=9},
    {group="browser",title="Icon Browser",spacingMax=8},
}

local function Backdrop(frame,bg,border)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
    frame:SetBackdropColor(unpack(bg or C.panel))
    frame:SetBackdropBorderColor(unpack(border or C.border))
end

local function SetFontSize(region,size,flags)
    if not region or not region.GetFont or not region.SetFont then return end
    local path,_,oldFlags=region:GetFont()
    if path then region:SetFont(path,size,flags or oldFlags) end
end

local function HideTexture(texture)
    if not texture then return end
    texture:SetAlpha(0)
    texture:Hide()
end

local function HideNativeArtwork(frame,recursive)
    if not frame then return end
    if frame.GetRegions then
        for _,region in ipairs({frame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType()=="Texture" then
                HideTexture(region)
            end
        end
    end
    for _,key in ipairs({"NineSlice","Border","Bg","Background"}) do
        local object=frame[key]
        if object then
            if object.GetRegions then HideNativeArtwork(object,false) end
            if object.Hide then object:Hide() end
        end
    end
    if recursive and frame.GetChildren then
        for _,child in ipairs({frame:GetChildren()}) do
            if not child.__BetterAppearanceOwned then
                HideNativeArtwork(child,true)
            end
        end
    end
end

local function StyleFlatButton(button,text)
    if not button then return end
    if text then button:SetText(text) end
    HideTexture(button.GetNormalTexture and button:GetNormalTexture())
    HideTexture(button.GetPushedTexture and button:GetPushedTexture())
    HideTexture(button.GetDisabledTexture and button:GetDisabledTexture())
    HideTexture(button.GetHighlightTexture and button:GetHighlightTexture())

    local bg=button.__BetterAppearanceBG
    if not bg then
        bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,button:GetFrameLevel()-1))
        bg:EnableMouse(false)
        bg.__BetterAppearanceOwned=true
        button.__BetterAppearanceBG=bg
    end
    Backdrop(bg,C.panel2,C.border)

    local underline=button.__BetterAppearanceUnderline
    if not underline then
        underline=button:CreateTexture(nil,"OVERLAY",nil,7)
        underline:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1)
        underline:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
        underline:SetHeight(1)
        underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
        underline:Hide()
        button.__BetterAppearanceUnderline=underline
    end

    local font=button.GetFontString and button:GetFontString() or button.Text
    if font then
        font:SetTextColor(unpack(C.text))
        SetFontSize(font,11)
    end

    if not button.__BetterAppearanceHooks then
        button.__BetterAppearanceHooks=true
        button:HookScript("OnEnter",function(self)
            if self:IsEnabled() then
                self.__BetterAppearanceBG:SetBackdropColor(unpack(CONTROL_HOVER))
                self.__BetterAppearanceBG:SetBackdropBorderColor(unpack(CONTROL_HOVER_EDGE))
                self.__BetterAppearanceUnderline:Show()
            end
        end)
        button:HookScript("OnLeave",function(self)
            self.__BetterAppearanceBG:SetBackdropColor(unpack(C.panel2))
            self.__BetterAppearanceBG:SetBackdropBorderColor(unpack(C.border))
            self.__BetterAppearanceUnderline:Hide()
        end)
    end
end

local function MakeText(parent,text,size)
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    font:SetText(text)
    font:SetTextColor(unpack(C.text))
    SetFontSize(font,size or 11)
    return font
end

local function SafeAppearanceCall(name,callback)
    if type(callback)~="function" then return false end
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

local function ApplyEverything()
    if _G.BPMMGoalLayout and _G.BPMMGoalLayout.Apply then
        _G.BPMMGoalLayout.Apply()
    end
    SafeAppearanceCall("Icon Browser layout",Appearance.LayoutIconBrowser)
    if Appearance.RefreshConfig then Appearance.RefreshConfig() end
end

local function CreateSlider(parent,group,key,minimum,maximum,width,suffix)
    local slider=CreateFrame("Slider",nil,parent)
    slider:SetSize(width,20)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum,maximum)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:EnableMouseWheel(true)

    local track=slider:CreateTexture(nil,"BACKGROUND")
    track:SetPoint("LEFT",slider,"LEFT",0,0)
    track:SetPoint("RIGHT",slider,"RIGHT",0,0)
    track:SetHeight(4)
    track:SetColorTexture(unpack(C.border))
    local trackFill=slider:CreateTexture(nil,"BORDER")
    trackFill:SetPoint("LEFT",track,"LEFT",1,0)
    trackFill:SetPoint("RIGHT",track,"RIGHT",-1,0)
    trackFill:SetHeight(2)
    trackFill:SetColorTexture(unpack(C.panel2))

    slider:SetThumbTexture(WHITE)
    local thumb=slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(9,18)
        thumb:SetColorTexture(unpack(C.blue))
    end

    local valueText=MakeText(parent,"",10)
    valueText:SetSize(44,18)
    valueText:SetJustifyH("LEFT")
    valueText:SetPoint("LEFT",slider,"RIGHT",8,0)

    slider.__Updating=true
    local current=_G.BetterBindAppearance_Get and BetterBindAppearance_Get(group) or {}
    slider:SetValue(tonumber(current[key]) or minimum)
    slider.__Updating=false

    local function UpdateValue(self,value)
        value=math.floor((tonumber(value) or minimum)+.5)
        valueText:SetText(value..(suffix or ""))
        if self.__Updating then return end
        if _G.BetterBindAppearance_Set then
            BetterBindAppearance_Set(group,key,value)
            ApplyEverything()
        end
    end
    slider:SetScript("OnValueChanged",UpdateValue)
    slider:SetScript("OnMouseWheel",function(self,delta)
        self:SetValue(math.max(minimum,math.min(maximum,self:GetValue()+(delta>0 and 1 or -1))))
    end)
    slider.__Updating=true
    UpdateValue(slider,slider:GetValue())
    slider.__Updating=false

    slider.__ValueText=valueText
    slider.__AppearanceGroup=group
    slider.__AppearanceKey=key
    slider.__Refresh=function(self,value)
        self.__Updating=true
        self:SetValue(value)
        self.__Updating=false
        valueText:SetText(math.floor(value+.5)..(suffix or ""))
    end
    return slider
end

local function CreateSection(container,definition,index)
    local panel=CreateFrame("Frame",nil,container,"BackdropTemplate")
    panel:SetPoint("TOPLEFT",container,"TOPLEFT",12,-54-(index-1)*122)
    panel:SetPoint("TOPRIGHT",container,"TOPRIGHT",-12,-54-(index-1)*122)
    panel:SetHeight(108)
    Backdrop(panel,C.panel2,C.border)

    local title=MakeText(panel,definition.title,13)
    title:SetPoint("TOPLEFT",12,-11)

    local styleLabel=MakeText(panel,"Fixed style",10)
    styleLabel:SetPoint("TOPLEFT",12,-42)
    local style=MakeText(panel,"Plunderstorm · Cooldown Manager · HUI Mask",10)
    style:SetPoint("LEFT",panel,"LEFT",112,11)
    style:SetTextColor(unpack(C.muted))

    local spacingLabel=MakeText(panel,"Spacing",10)
    spacingLabel:SetPoint("TOPLEFT",12,-78)
    local spacing=CreateSlider(panel,definition.group,"spacing",0,definition.spacingMax,260," px")
    spacing:SetPoint("LEFT",panel,"LEFT",112,-30)

    local section={
        panel=panel,
        group=definition.group,
        spacing=spacing,
    }
    sections[#sections+1]=section
    return section
end

function Appearance.RefreshConfig()
    for _,section in ipairs(sections) do
        local saved=_G.BetterBindAppearance_Get and BetterBindAppearance_Get(section.group)
            or {spacing=0}
        section.spacing:__Refresh(saved.spacing)
    end
end

local function BuildConfig()
    if configBuilt then
        Appearance.RefreshConfig()
        return
    end
    local frame=_G.MegaMacro_Frame
    local container=_G.MegaMacro_ConfigContainer
    if not frame or not container then return end
    configBuilt=true

    container:SetParent(frame)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-84)
    container:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-6,8)
    container:SetFrameLevel(frame:GetFrameLevel()+8)
    Backdrop(container,C.shell,C.border)
    HideNativeArtwork(container,false)

    local title=MakeText(container,"Icon appearance",16)
    title:SetPoint("TOPLEFT",14,-13)
    local subtitle=MakeText(container,"Fixed icon styling with independent spacing for each group.",10)
    subtitle:SetPoint("LEFT",title,"RIGHT",14,0)
    subtitle:SetTextColor(unpack(C.muted))

    for index,definition in ipairs(definitions) do
        CreateSection(container,definition,index)
    end
    Appearance.RefreshConfig()
end

-- Replace the legacy checkbox/uninstall Config contents with appearance only.
_G.MecaMacro_GenerateConfig=BuildConfig

local function SetShown(object,shown)
    if object and object.SetShown then object:SetShown(shown) end
end

function Appearance.ApplyVisibility()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    local configSelected=_G.BetterMacro_GetSelectedTabIndex
        and _G.BetterMacro_GetSelectedTabIndex()==6

    local config=_G.MegaMacro_ConfigContainer
    if configSelected then
        BuildConfig()
        if config then config:Show() end
    elseif config then
        config:Hide()
    end

    for _,object in ipairs({
        _G.MegaMacro_ButtonScrollFrame,
        _G.MegaMacro_FrameSelectedMacroButton,
        _G.MegaMacro_FrameSelectedMacroName,
        _G.MegaMacro_FrameEnterMacroText,
        _G.MegaMacro_FrameScrollFrame,
        _G.MegaMacro_SaveButton,
        _G.MegaMacro_EditButton,
        _G.MegaMacro_CancelButton,
        _G.MegaMacro_DeleteButton,
        _G.BPMMUnifiedSearch,
        _G.BPMM74LocateButton,
        _G.BetterMacroShowLessSlotButton,
        _G.BetterMacroShowMoreSlotButton,
    }) do
        SetShown(object,not configSelected)
    end

    local footer=frame.__BPMMGoalFooter
    SetShown(footer,not configSelected)
    local selected=_G.MegaMacro_FrameSelectedMacroButton
    if selected then SetShown(selected.__BPMMGoalInfoBackground,not configSelected) end
    SetShown(frame.__BPMMGoalEditorBackground,not configSelected)

    -- These legacy layers stay hidden in both modes.
    SetShown(_G.MegaMacro_FrameSelectedMacroBackground,false)
    SetShown(_G.MegaMacro_FormattedFrameScrollFrame,false)
    SetShown(_G.MegaMacro_FrameTextButton,false)
    SetShown(_G.MacroFrameTextBackground,false)
    SetShown(_G.MegaMacro_FrameCharLimitText,false)

    if not configSelected and _G.BPMMBetterMacroEditor then
        _G.BPMMBetterMacroEditor.Apply()
    end
end

_G.BetterAppearanceConfig_ApplyVisibility=Appearance.ApplyVisibility

local function StylePopupEditBox(edit)
    if not edit then return end
    edit:SetTextColor(unpack(C.text))
    edit:SetTextInsets(6,6,0,0)
    SetFontSize(edit,11)
    local bg=edit.__BetterAppearanceInputBG
    if not bg then
        bg=CreateFrame("Frame",nil,edit:GetParent(),"BackdropTemplate")
        bg:SetPoint("TOPLEFT",edit,"TOPLEFT",-4,3)
        bg:SetPoint("BOTTOMRIGHT",edit,"BOTTOMRIGHT",4,-3)
        bg:SetFrameLevel(math.max(0,edit:GetFrameLevel()-1))
        bg:EnableMouse(false)
        bg.__BetterAppearanceOwned=true
        edit.__BetterAppearanceInputBG=bg
    end
    Backdrop(bg,C.panel2,C.border)
    local underline=edit.__BetterAppearanceInputUnderline
    if not underline then
        underline=bg:CreateTexture(nil,"OVERLAY",nil,7)
        underline:SetPoint("BOTTOMLEFT",bg,"BOTTOMLEFT",1,1)
        underline:SetPoint("BOTTOMRIGHT",bg,"BOTTOMRIGHT",-1,1)
        underline:SetHeight(1)
        underline:SetColorTexture(unpack(CONTROL_HOVER_ACCENT))
        underline:Hide()
        edit.__BetterAppearanceInputUnderline=underline
    end
    if not edit.__BetterAppearanceInputHooks then
        edit.__BetterAppearanceInputHooks=true
        local function SetHovered(hovered)
            bg:SetBackdropColor(unpack(hovered and CONTROL_HOVER or C.panel2))
            bg:SetBackdropBorderColor(unpack(hovered and CONTROL_HOVER_EDGE or C.border))
            underline:SetShown(hovered and true or false)
        end
        edit:HookScript("OnEnter",function() SetHovered(true) end)
        edit:HookScript("OnLeave",function(self) SetHovered(self:HasFocus()) end)
        edit:HookScript("OnEditFocusGained",function() SetHovered(true) end)
        edit:HookScript("OnEditFocusLost",function(self) SetHovered(self:IsMouseOver()) end)
    end
end

local function StylePopupCheckBox(check)
    if not check then return end
    check:SetSize(20,20)
    HideTexture(check.GetNormalTexture and check:GetNormalTexture())
    HideTexture(check.GetPushedTexture and check:GetPushedTexture())
    HideTexture(check.GetHighlightTexture and check:GetHighlightTexture())
    HideTexture(check.GetCheckedTexture and check:GetCheckedTexture())
    HideTexture(check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())

    local bg=check.__BetterAppearanceCheckBG
    if not bg then
        bg=CreateFrame("Frame",nil,check,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,check:GetFrameLevel()-1))
        bg.__BetterAppearanceOwned=true
        check.__BetterAppearanceCheckBG=bg
        local mark=check:CreateTexture(nil,"OVERLAY",nil,6)
        mark:SetColorTexture(unpack(C.blue))
        mark:SetPoint("TOPLEFT",4,-4)
        mark:SetPoint("BOTTOMRIGHT",-4,4)
        check.__BetterAppearanceCheckMark=mark
    end
    local function Refresh(self,hovered)
        self.__BetterAppearanceCheckMark:SetShown(self:GetChecked() and true or false)
        self.__BetterAppearanceCheckBG:SetBackdropColor(
            hovered and .085 or C.panel2[1],
            hovered and .095 or C.panel2[2],
            hovered and .108 or C.panel2[3],
            hovered and .96 or C.panel2[4]
        )
        self.__BetterAppearanceCheckBG:SetBackdropBorderColor(
            hovered and .28 or C.border[1],
            hovered and .34 or C.border[2],
            hovered and .40 or C.border[3],1
        )
    end
    Backdrop(bg,C.panel2,C.border)
    Refresh(check,false)
    if not check.__BetterAppearanceCheckHooks then
        check.__BetterAppearanceCheckHooks=true
        check:HookScript("OnClick",function(self) Refresh(self,self:IsMouseOver()) end)
        check:HookScript("OnShow",function(self) Refresh(self,false) end)
        check:HookScript("OnEnter",function(self) Refresh(self,true) end)
        check:HookScript("OnLeave",function(self) Refresh(self,false) end)
    end
end

local function StyleBrowserButton(button)
    if not button then return end
    local icon=_G[(button:GetName() or "").."Icon"]
        or (button.GetNormalTexture and button:GetNormalTexture())
    if not icon then return end

    button:SetSize(41,41)
    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    icon:SetAlpha(1)
    icon:Show()

    -- SimplePopupButtonTemplate contributes Blizzard slot/background artwork.
    -- Retire it before the shared Plunderstorm/Cooldown Manager stack is added.
    for _,region in ipairs({button:GetRegions()}) do
        if region~=icon and not region.__BetterBindOwned
            and region.GetObjectType and region:GetObjectType()=="Texture"
        then
            HideTexture(region)
        end
    end
    for _,key in ipairs({"Border","Background","SlotBackground","IconBorder","NineSlice"}) do
        local artwork=button[key]
        if artwork and artwork~=icon then
            if artwork.GetRegions then HideNativeArtwork(artwork,true)
            elseif artwork.GetObjectType and artwork:GetObjectType()=="Texture" then HideTexture(artwork)
            elseif artwork.Hide then artwork:Hide() end
        end
    end
    HideTexture(button.GetHighlightTexture and button:GetHighlightTexture())
    HideTexture(button.GetCheckedTexture and button:GetCheckedTexture())

    if not button.__BetterAppearanceSelectionHook then
        button.__BetterAppearanceSelectionHook=true
        button:HookScript("OnClick",function(self)
            C_Timer.After(0,function()
                if self.__BetterAppearanceRefreshSelection then
                    self:__BetterAppearanceRefreshSelection()
                end
            end)
        end)
    end
    button.__BetterAppearanceRefreshSelection=function(self)
        if _G.BetterBindAppearance_StyleCell then
            BetterBindAppearance_StyleCell(self,icon,true)
        end
    end
    if _G.BetterBindAppearance_ApplyTexture then
        _G.BetterBindAppearance_ApplyTexture(button,icon,"browser")
    end
    if _G.BetterBindAppearance_StyleCell then
        BetterBindAppearance_StyleCell(button,icon,true)
    end
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel",function(_,delta)
        if type(_G.BetterMacro_IconBrowserScroll)=="function" then
            BetterMacro_IconBrowserScroll(delta)
        end
    end)
end

function Appearance.RefreshBrowserButtons()
    for i=1,(NUM_MACRO_ICONS_SHOWN or 100) do
        StyleBrowserButton(_G["MegaMacro_PopupButton"..i])
    end
end

local browserDrag={active=false}
local browserDragUpdater=CreateFrame("Frame")
browserDragUpdater:Hide()

local function BrowserCursorUI()
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    if not scale or scale==0 then scale=1 end
    return x/scale,y/scale
end

local function SaveBrowserPosition(popup)
    if not popup then return end
    local point,_,relativePoint,x,y=popup:GetPoint(1)
    if not point then return end
    MegaMacroConfig=type(MegaMacroConfig)=="table" and MegaMacroConfig or {}
    MegaMacroConfig.IconBrowserPosition={
        point=point,
        relativePoint=relativePoint or point,
        x=tonumber(x) or 0,
        y=tonumber(y) or 0,
    }
end

local function EndBrowserDrag()
    if not browserDrag.active then return end
    local popup=browserDrag.frame
    browserDrag.active=false
    browserDrag.frame=nil
    browserDragUpdater:Hide()
    SaveBrowserPosition(popup)
end

local function BeginBrowserDrag(popup)
    if not popup or InCombatLockdown() or browserDrag.active then return end
    local point,relativeTo,relativePoint,x,y=popup:GetPoint(1)
    if not point then return end
    local cursorX,cursorY=BrowserCursorUI()
    browserDrag.active=true
    browserDrag.frame=popup
    browserDrag.point=point
    browserDrag.relativeTo=relativeTo or UIParent
    browserDrag.relativePoint=relativePoint or point
    browserDrag.x=tonumber(x) or 0
    browserDrag.y=tonumber(y) or 0
    browserDrag.cursorX=cursorX
    browserDrag.cursorY=cursorY
    browserDragUpdater:Show()
end

browserDragUpdater:SetScript("OnUpdate",function()
    local popup=browserDrag.frame
    if not browserDrag.active or not popup then
        browserDragUpdater:Hide()
        return
    end
    if not IsMouseButtonDown("LeftButton") then
        EndBrowserDrag()
        return
    end
    local x,y=BrowserCursorUI()
    popup:ClearAllPoints()
    popup:SetPoint(
        browserDrag.point,
        browserDrag.relativeTo,
        browserDrag.relativePoint,
        browserDrag.x+(x-browserDrag.cursorX),
        browserDrag.y+(y-browserDrag.cursorY)
    )
end)

local function RetireNativeButton(button)
    if not button then return end
    button:SetAlpha(0)
    button:EnableMouse(false)
    button:Hide()
    if not button.__BetterAppearanceRetired then
        button.__BetterAppearanceRetired=true
        button:HookScript("OnShow",function(self)
            self:SetAlpha(0)
            self:EnableMouse(false)
            self:Hide()
        end)
    end
end

local function CreateBrowserAction(popup,key,globalName,label,onClick)
    local button=popup[key]
    if not button then
        button=CreateFrame("Button",globalName,popup)
        button:SetNormalFontObject("GameFontHighlight")
        button:SetScript("OnClick",onClick)
        button.__BetterAppearanceOwned=true
        popup[key]=button
    end
    button:SetFrameLevel(popup:GetFrameLevel()+82)
    button:EnableMouse(true)
    button:Show()
    StyleFlatButton(button,label)
    return button
end

local function AlignBrowserPosition(popup)
    local mega=_G.MegaMacro_Frame
    popup:ClearAllPoints()
    if mega and mega:IsShown() and mega:GetRight() and mega:GetTop() then
        local uiScale=UIParent:GetEffectiveScale()
        if not uiScale or uiScale==0 then uiScale=1 end
        popup:SetPoint(
            "TOPLEFT",UIParent,"BOTTOMLEFT",
            mega:GetRight()+(4/uiScale),mega:GetTop()
        )
    else
        popup:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    popup.__BetterAppearancePositioned=true
end

local browserMacroMetadata={id=nil,isNew=true}

local function EnsureBrowserMacroMetadata(popup)
    if not popup then return nil end
    local cell=popup.__BetterAppearanceMacroMetadata
    if not cell then
        cell=CreateFrame("Frame",nil,popup,"BackdropTemplate")
        cell:SetSize(82,24)
        cell:SetFrameLevel(popup:GetFrameLevel()+2)
        cell:EnableMouse(false)
        cell.__BetterAppearanceOwned=true

        local label=cell:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        label:SetPoint("CENTER",cell,"CENTER",0,0)
        label:SetTextColor(unpack(C.blue))
        SetFontSize(label,10)
        cell.Label=label
        popup.__BetterAppearanceMacroMetadata=cell
    end

    Backdrop(cell,C.panel2,C.border)
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT",popup,"TOPLEFT",58,-41)
    if browserMacroMetadata.id then
        cell.Label:SetText("Macro #"..browserMacroMetadata.id)
    else
        cell.Label:SetText(browserMacroMetadata.isNew and "New Macro" or "Macro")
    end
    cell:Show()
    return cell
end

function Appearance.SetBrowserMacroMetadata(macroId,isNew)
    browserMacroMetadata.id=tonumber(macroId)
    browserMacroMetadata.isNew=isNew==true or not browserMacroMetadata.id
    EnsureBrowserMacroMetadata(_G.MegaMacro_PopupFrame)
end

_G.BetterBindAppearance_SetBrowserMacroMetadata=Appearance.SetBrowserMacroMetadata

function Appearance.LayoutIconBrowser()
    local popup=_G.MegaMacro_PopupFrame
    local scroll=_G.MegaMacro_PopupScrollFrame
    local child=_G.MegaMacro_PopupScrollFrameScrollChildFrame
    if not popup or not scroll or not child then return end

    local appearance=_G.BetterBindAppearance_Get and BetterBindAppearance_Get("browser")
        or {spacing=4}
    local spacing=appearance.spacing
    local iconSize=41
    local columns=10
    local rows=10
    local step=iconSize+spacing
    local gridWidth=columns*iconSize+(columns-1)*spacing
    local gridHeight=rows*iconSize+(rows-1)*spacing
    local width=math.max(460,gridWidth+40)
    local height=(_G.MegaMacro_Frame and MegaMacro_Frame:GetHeight()) or 696
    MACRO_ICON_ROW_HEIGHT=step

    popup:SetSize(width,height)
    popup:SetScale((_G.MegaMacro_Frame and MegaMacro_Frame:GetScale()) or 1)
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel",function(_,delta)
        if type(_G.BetterMacro_IconBrowserScroll)=="function" then
            BetterMacro_IconBrowserScroll(delta)
        end
    end)
    AlignBrowserPosition(popup)
    popup:SetClampedToScreen(true)

    if popup.BG then HideTexture(popup.BG) end
    local borderBox=popup.BorderBox
    if popup.SetBackdrop then popup:SetBackdrop(nil) end
    if borderBox and borderBox.SetBackdrop then borderBox:SetBackdrop(nil) end
    HideNativeArtwork(borderBox,true)

    local shell=popup.__BetterAppearanceShell
    if not shell then
        shell=CreateFrame("Frame",nil,popup,"BackdropTemplate")
        shell:SetAllPoints()
        shell:SetFrameLevel(math.max(0,popup:GetFrameLevel()-1))
        shell:EnableMouse(false)
        shell.__BetterAppearanceOwned=true
        popup.__BetterAppearanceShell=shell
    end
    Backdrop(shell,C.shell,C.border)
    if _G.BetterBindAppearance_ApplyWindowPattern then
        BetterBindAppearance_ApplyWindowPattern(
            shell,"__BetterBindCircuit",0,1,.70,.142,.858
        )
    end

    local title=popup.__BetterAppearanceTitle
    if not title then
        title=MakeText(popup,"Icon Browser",15)
        popup.__BetterAppearanceTitle=title
    end
    title:ClearAllPoints()
    title:SetPoint("TOP",popup,"TOP",0,-13)

    local close=CreateBrowserAction(
        popup,
        "__BetterAppearanceCloseButton",
        "BetterMacroIconBrowserCloseButton",
        "X",
        function()
            if type(_G.MegaMacro_EditCancelButton_OnClick)=="function" then
                MegaMacro_EditCancelButton_OnClick()
            else
                popup:Hide()
            end
        end
    )
    close:SetSize(26,26)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-6,-6)
    if _G.BetterBindAppearance_StyleClose then
        -- A close-button skin must never prevent the rest of the browser from
        -- being laid out. This also keeps older clients usable if a cosmetic
        -- API is unavailable.
        pcall(_G.BetterBindAppearance_StyleClose,popup,close)
    end

    local header=popup.__BetterAppearanceDragHeader
    if not header then
        header=CreateFrame("Frame",nil,popup)
        header.__BetterAppearanceOwned=true
        popup.__BetterAppearanceDragHeader=header
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart",function() BeginBrowserDrag(popup) end)
        header:SetScript("OnDragStop",EndBrowserDrag)
        header:SetScript("OnMouseDown",function(_,button)
            if button=="LeftButton" then BeginBrowserDrag(popup) end
        end)
        header:SetScript("OnMouseUp",function(_,button)
            if button=="LeftButton" then EndBrowserDrag() end
        end)
    end
    header:SetFrameLevel(popup:GetFrameLevel()+78)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT",popup,"TOPLEFT",1,-1)
    header:SetPoint("TOPRIGHT",close,"TOPLEFT",-2,0)
    header:SetHeight(34)

    local nameLabel=_G.MegaMacro_DisplayNameLabel
    if nameLabel then
        nameLabel:SetText("Name")
        nameLabel:ClearAllPoints()
        nameLabel:SetPoint("TOPLEFT",popup,"TOPLEFT",14,-48)
        nameLabel:SetWidth(40)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetTextColor(unpack(C.text))
        SetFontSize(nameLabel,11)
    end
    EnsureBrowserMacroMetadata(popup)
    local nameEdit=_G.MegaMacro_PopupEditBox
    if nameEdit then
        nameEdit:SetSize(width-160,24)
        nameEdit:ClearAllPoints()
        nameEdit:SetPoint("TOPLEFT",popup,"TOPLEFT",146,-41)
        StylePopupEditBox(nameEdit)
    end
    for _,texture in ipairs({_G.MegaMacro_PopupNameLeft,_G.MegaMacro_PopupNameMiddle,_G.MegaMacro_PopupNameRight}) do
        HideTexture(texture)
    end

    local fallbackLabel=_G.MegaMacro_FallbackTextureLabel
    if fallbackLabel then
        fallbackLabel:SetText("Use as fallback icon")
        fallbackLabel:ClearAllPoints()
        fallbackLabel:SetPoint("TOPLEFT",popup,"TOPLEFT",42,-78)
        fallbackLabel:SetTextColor(unpack(C.text))
        SetFontSize(fallbackLabel,10)
    end
    local fallback=_G.MegaMacro_FallbackTextureCheckBox
    if fallback then
        fallback:ClearAllPoints()
        fallback:SetPoint("TOPLEFT",popup,"TOPLEFT",14,-72)
        StylePopupCheckBox(fallback)
    end
    if _G.MegaMacro_FallbackTextureDescription then
        MegaMacro_FallbackTextureDescription:Hide()
        MegaMacro_FallbackTextureDescription:SetAlpha(0)
    end

    local searchEdit=_G.MegaMacro_IconSearchBox
    if searchEdit then
        searchEdit:SetSize(width-28,24)
        searchEdit:ClearAllPoints()
        searchEdit:SetPoint("TOPLEFT",popup,"TOPLEFT",14,-101)
        StylePopupEditBox(searchEdit)
    end
    for _,texture in ipairs({_G.MegaMacro_IconSearchLeft,_G.MegaMacro_IconSearchMiddle,_G.MegaMacro_IconSearchRight}) do
        HideTexture(texture)
    end
    local placeholder=_G.MegaMacro_IconSearchPlaceholder
    if placeholder and searchEdit then
        placeholder:SetText("Search icons...")
        placeholder:ClearAllPoints()
        placeholder:SetPoint("LEFT",searchEdit,"LEFT",6,0)
        placeholder:SetTextColor(unpack(C.muted))
        SetFontSize(placeholder,10)
    end

    scroll:SetSize(gridWidth,gridHeight)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT",popup,"TOPLEFT",20,-130)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
    HideNativeArtwork(scroll,false)
    child:SetSize(gridWidth,gridHeight)
    child:ClearAllPoints()
    child:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)
    scroll:SetScript("OnVerticalScroll",nil)
    scroll:SetHorizontalScroll(0)
    scroll:SetVerticalScroll(0)

    for i=1,(NUM_MACRO_ICONS_SHOWN or 100) do
        local button=_G["MegaMacro_PopupButton"..i]
        if button then
            local column=(i-1)%columns
            local row=math.floor((i-1)/columns)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",child,"TOPLEFT",column*step,-row*step)
            StyleBrowserButton(button)
        end
    end

    local bar=scroll.ScrollBar or _G.MegaMacro_PopupScrollFrameScrollBar
    if bar then
        HideNativeArtwork(bar,true)
        bar:SetAlpha(0)
        bar:EnableMouse(false)
        if bar.SetMinMaxValues then bar:SetMinMaxValues(0,0) end
        if bar.SetValue then bar:SetValue(0) end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        if type(_G.BetterMacro_IconBrowserScroll)=="function" then
            BetterMacro_IconBrowserScroll(delta)
        end
    end)

    local okay=borderBox and borderBox.OkayButton
    local cancel=borderBox and borderBox.CancelButton
    RetireNativeButton(okay)
    RetireNativeButton(cancel)

    local applyButton=CreateBrowserAction(
        popup,
        "__BetterAppearanceApplyButton",
        "BetterMacroIconBrowserApplyButton",
        "Apply",
        function()
            if type(_G.MegaMacro_EditOkButton_OnClick)=="function" then
                MegaMacro_EditOkButton_OnClick()
            end
        end
    )
    applyButton:SetSize(94,30)
    applyButton:ClearAllPoints()
    applyButton:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-110,10)

    local cancelButton=CreateBrowserAction(
        popup,
        "__BetterAppearanceCancelButton",
        "BetterMacroIconBrowserCancelButton",
        "Cancel",
        function()
            if type(_G.MegaMacro_EditCancelButton_OnClick)=="function" then
                MegaMacro_EditCancelButton_OnClick()
            else
                popup:Hide()
            end
        end
    )
    cancelButton:SetSize(94,30)
    cancelButton:ClearAllPoints()
    cancelButton:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-10,10)

    local enabled=not okay or okay:IsEnabled()
    if enabled then applyButton:Enable() else applyButton:Disable() end
    applyButton:SetAlpha(enabled and 1 or .45)
    Appearance.RefreshBrowserButtons()
end

local drag={
    active=false,frame=nil,startX=0,startY=0,
    point=nil,relativeTo=nil,relativePoint=nil,offsetX=0,offsetY=0,
}
local dragUpdater=CreateFrame("Frame")
dragUpdater:Hide()

local function CursorUI()
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    if not scale or scale==0 then scale=1 end
    return x/scale,y/scale
end

local function EndStableDrag()
    if not drag.active then return end
    local frame=drag.frame
    drag.active=false
    drag.frame=nil
    dragUpdater:Hide()
    if frame and _G.BPMM_SaveWindowPoint then
        _G.BPMM_SaveWindowPoint(frame,"MegaMacro")
    end
end

local function BeginStableDrag(frame)
    if not frame or InCombatLockdown() or drag.active then return end
    local point,relativeTo,relativePoint,offsetX,offsetY=frame:GetPoint(1)
    if not point then return end
    local x,y=CursorUI()
    drag.active=true
    drag.frame=frame
    drag.startX=x
    drag.startY=y
    drag.point=point
    drag.relativeTo=relativeTo or UIParent
    drag.relativePoint=relativePoint or point
    drag.offsetX=offsetX or 0
    drag.offsetY=offsetY or 0
    dragUpdater:Show()
end

dragUpdater:SetScript("OnUpdate",function()
    if not drag.active or not drag.frame then
        dragUpdater:Hide()
        return
    end
    if not IsMouseButtonDown("LeftButton") then
        EndStableDrag()
        return
    end
    local x,y=CursorUI()
    local frame=drag.frame
    frame:ClearAllPoints()
    frame:SetPoint(
        drag.point,drag.relativeTo,drag.relativePoint,
        drag.offsetX+(x-drag.startX),
        drag.offsetY+(y-drag.startY)
    )
end)

local function InstallStableDrag()
    local frame=_G.MegaMacro_Frame
    if not frame then return end
    -- The visual shell is a full-window background. Keep dragging on its own
    -- transparent header so installing movement handlers cannot shrink or
    -- reposition the background artwork.
    local header=frame.__BetterMacroDragHeader
    if not header then
        header=CreateFrame("Frame",nil,frame)
        frame.__BetterMacroDragHeader=header
    end
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
    header:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-28,-1)
    header:SetHeight(36)
    header:SetFrameLevel(frame:GetFrameLevel()+35)
    header:EnableMouse(true)
    header:EnableMouseWheel(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() BeginStableDrag(frame) end)
    header:SetScript("OnDragStop",EndStableDrag)
    header:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then BeginStableDrag(frame) end
    end)
    header:SetScript("OnMouseUp",function(_,button)
        if button=="LeftButton" then EndStableDrag() end
    end)
    header:SetScript("OnMouseWheel",function(_,delta)
        if not IsShiftKeyDown() then return end
        BindPadVars=BindPadVars or {}
        BindPadVars.BPMMSettings=BindPadVars.BPMMSettings or {}
        local settings=BindPadVars.BPMMSettings
        local current=tonumber(settings.megaMacroScale) or frame:GetScale() or 1
        local nextScale=math.max(.70,math.min(1.40,current+(delta>0 and .05 or -.05)))
        nextScale=math.floor(nextScale/.05+.5)*.05
        settings.megaMacroScale=nextScale
        frame:SetScale(nextScale)
    end)

    -- The transparent header above is the only drag target. Registering the
    -- whole window for LeftButton drag steals the same gesture from the macro
    -- EditBox and prevents native text selection.
    frame:SetMovable(false)
    frame:RegisterForDrag()
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        Appearance.ApplyVisibility()
        C_Timer.After(0,Appearance.ApplyVisibility)
    end)
end
if _G.MegaMacro_PopupFrame then
    MegaMacro_PopupFrame:HookScript("OnShow",function()
        if type(_G.BetterMacro_RefreshIconBrowser)=="function" then
            BetterMacro_RefreshIconBrowser(true)
        end
        SafeAppearanceCall("Icon Browser layout",Appearance.LayoutIconBrowser)
        C_Timer.After(0,function()
            if type(_G.BetterMacro_RefreshIconBrowser)=="function" then
                BetterMacro_RefreshIconBrowser(true)
            end
            SafeAppearanceCall("Icon Browser layout",Appearance.LayoutIconBrowser)
        end)
    end)
end
if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,function()
            Appearance.ApplyVisibility()
            InstallStableDrag()
        end)
        C_Timer.After(.1,InstallStableDrag)
    end)
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    if _G.MegaMacro_InitialiseConfig then MegaMacro_InitialiseConfig() end
    C_Timer.After(.1,function()
        BuildConfig()
        Appearance.ApplyVisibility()
        SafeAppearanceCall("Icon Browser layout",Appearance.LayoutIconBrowser)
    end)
    -- Older layout stages also install drag handlers during login. Reapply
    -- this position-neutral handler after those deferred installers finish.
    C_Timer.After(.65,InstallStableDrag)
    C_Timer.After(1.15,InstallStableDrag)
end)

BuildConfig()
Appearance.ApplyVisibility()
InstallStableDrag()
