-- BetterMacro native editor.
--
-- The original MegaMacro window stacked an editable EditBox and a parsed
-- display EditBox on top of one another.  That made the caret disappear as
-- soon as the parsed layer won the frame-level race.  BetterMacro keeps one
-- real EditBox for focus, selection, and the caret, then draws parsed text in
-- a non-interactive FontString inside that same scrolling child.

local Editor={}
_G.BPMMBetterMacroEditor=Editor

local WHITE="Interface\\Buttons\\WHITE8x8"
local BG={.075,.078,.088,1}
local BORDER={.13,.14,.16,1}
local FOCUS={.02,.58,.94,1}
local TEXT={.90,.93,.97,1}
local LINE_SPACING=2

local replacement
local legacyEdit
local nativeTextRegion
local syntaxText
local uniformBackground
local customCaret
local measurementFrame
local measurementText

local function SetEditorBorder(background,focused)
    if not background or not background.SetBackdropBorderColor then return end
    background:SetBackdropBorderColor(unpack(focused and FOCUS or BORDER))
end

local function EnsureBackground(frame,scroll)
    local background=frame.__BPMMGoalEditorBackground
    if not background then
        background=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        background:EnableMouse(false)
        frame.__BPMMGoalEditorBackground=background
    end

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT",scroll,"TOPLEFT",-1,1)
    background:SetPoint("BOTTOMRIGHT",scroll,"BOTTOMRIGHT",1,-1)
    background:SetFrameLevel(math.max(frame:GetFrameLevel()+1,scroll:GetFrameLevel()-1))
    background:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
    background:SetBackdropColor(unpack(BG))
    background:SetAlpha(1)
    background:Show()
    return background
end

local function HideLegacyEditor()
    local formattedScroll=_G.MegaMacro_FormattedFrameScrollFrame
    local formattedEdit=_G.MegaMacro_FormattedFrameText
    for _,object in ipairs({legacyEdit,formattedEdit,formattedScroll}) do
        if object then
            if object.EnableMouse then object:EnableMouse(false) end
            object:SetAlpha(0)
            object:Hide()
        end
    end
end

local function GetNativeTextRegion(edit)
    if nativeTextRegion then return nativeTextRegion end
    if not edit or not edit.GetRegions then return end
    for _,region in ipairs({edit:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType()=="FontString" then
            nativeTextRegion=region
            return region
        end
    end
end

local function EnsureUniformBackground(scroll)
    if not scroll then return end
    if not uniformBackground then
        uniformBackground=scroll:CreateTexture(nil,"BACKGROUND",nil,-8)
        uniformBackground:SetAllPoints(scroll)
    end
    uniformBackground:SetColorTexture(unpack(BG))
    uniformBackground:SetAlpha(1)
    uniformBackground:Show()
end

local function EnsureSyntaxText(edit)
    if syntaxText then return syntaxText end
    if not edit then return end

    syntaxText=edit:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall",-2)
    syntaxText:SetFontObject("GameFontHighlightSmall")
    syntaxText:SetPoint("TOPLEFT",edit,"TOPLEFT",7,-6)
    syntaxText:SetPoint("TOPRIGHT",edit,"TOPRIGHT",-7,-6)
    syntaxText:SetJustifyH("LEFT")
    syntaxText:SetJustifyV("TOP")
    syntaxText:SetWordWrap(true)
    if syntaxText.SetNonSpaceWrap then syntaxText:SetNonSpaceWrap(true) end
    if syntaxText.SetSpacing then syntaxText:SetSpacing(LINE_SPACING) end
    syntaxText:SetTextColor(unpack(TEXT))
    return syntaxText
end

local function EnsureCaret(edit)
    if customCaret then return customCaret end
    if not edit then return end

    customCaret=edit:CreateTexture(nil,"OVERLAY",nil,7)
    customCaret:SetColorTexture(1,1,1,1)
    customCaret:SetSize(1,12)
    customCaret:Hide()
    return customCaret
end

local function PositionCaret(edit,x,y,width,height)
    local caret=EnsureCaret(edit)
    if not caret then return end

    edit.__BetterMacroCaretX=tonumber(x) or 0
    edit.__BetterMacroCaretY=tonumber(y) or 0
    edit.__BetterMacroCaretWidth=1
    edit.__BetterMacroCaretHeight=tonumber(height) or 12

    local changed=edit.__BetterMacroCaretDrawX~=edit.__BetterMacroCaretX
        or edit.__BetterMacroCaretDrawY~=edit.__BetterMacroCaretY
        or edit.__BetterMacroCaretDrawHeight~=edit.__BetterMacroCaretHeight
    edit.__BetterMacroCaretDrawX=edit.__BetterMacroCaretX
    edit.__BetterMacroCaretDrawY=edit.__BetterMacroCaretY
    edit.__BetterMacroCaretDrawHeight=edit.__BetterMacroCaretHeight

    local left,_,top=edit:GetTextInsets()
    caret:ClearAllPoints()
    caret:SetPoint(
        "TOPLEFT",edit,"TOPLEFT",
        edit.__BetterMacroCaretX+(tonumber(left) or 0),
        edit.__BetterMacroCaretY-(tonumber(top) or 0)+1
    )
    caret:SetSize(
        1,
        math.max(10,edit.__BetterMacroCaretHeight)+2
    )
    caret.__BetterMacroPositioned=true
    if changed then
        caret.__BetterMacroBlinkElapsed=0
        caret:SetShown(edit:HasFocus() and edit:IsEnabled())
    end
end

local function UpdateCaret(edit,elapsed)
    local caret=customCaret
    if not caret or not caret.__BetterMacroPositioned
        or not edit:HasFocus() or not edit:IsEnabled()
    then
        if caret then caret:Hide() end
        return
    end

    caret.__BetterMacroBlinkElapsed=(caret.__BetterMacroBlinkElapsed or 0)+(elapsed or 0)
    if caret.__BetterMacroBlinkElapsed>=1 then
        caret.__BetterMacroBlinkElapsed=caret.__BetterMacroBlinkElapsed%1
    end
    caret:SetShown(caret.__BetterMacroBlinkElapsed<.5)
end

local function EnsureMeasurementText(edit)
    if not measurementFrame then
        measurementFrame=CreateFrame("Frame",nil,UIParent)
        measurementFrame:SetSize(1,1)
        measurementFrame:SetAlpha(0)
        measurementFrame:Show()
        measurementText=measurementFrame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
        measurementText:SetWordWrap(false)
    end

    local path,size,flags
    if edit and edit.GetFont then path,size,flags=edit:GetFont() end
    if not path and syntaxText and syntaxText.GetFont then
        path,size,flags=syntaxText:GetFont()
    end
    if path then
        measurementText:SetFont(path,size,flags)
    else
        measurementText:SetFontObject("GameFontHighlightSmall")
    end
    return measurementText
end

local function MeasureTextWidth(edit,text)
    local measure=EnsureMeasurementText(edit)
    measure:SetText(text or "")
    return measure:GetStringWidth() or 0
end

-- EditBox cursor positions are byte offsets.  Keep every calculated boundary
-- on a complete UTF-8 character so localized macro text cannot be split.
local function NextCharacterBoundary(text,offset)
    if offset>=#text then return #text end
    local byte=string.byte(text,offset+1) or 0
    local length=1
    if byte>=240 then
        length=4
    elseif byte>=224 then
        length=3
    elseif byte>=192 then
        length=2
    end
    return math.min(#text,offset+length)
end

local function FindFittingOffset(edit,text,maximumWidth)
    local offset=0
    local fitting=0
    while offset<#text do
        offset=NextCharacterBoundary(text,offset)
        if MeasureTextWidth(edit,string.sub(text,1,offset))>maximumWidth then
            break
        end
        fitting=offset
    end
    if fitting==0 and #text>0 then
        fitting=NextCharacterBoundary(text,0)
    end
    return fitting
end

local function AddWrappedLogicalLine(edit,visualLines,line,lineStart,maximumWidth)
    if line=="" then
        visualLines[#visualLines+1]={text="",start=lineStart}
        return
    end

    local consumed=0
    while consumed<#line do
        local remaining=string.sub(line,consumed+1)
        local fitting=FindFittingOffset(edit,remaining,maximumWidth)
        if fitting>=#remaining then
            visualLines[#visualLines+1]={text=remaining,start=lineStart+consumed}
            return
        end

        -- Match the EditBox's normal word wrapping where possible, falling
        -- back to the character boundary for commands with no spaces.
        local prefix=string.sub(remaining,1,fitting)
        local whitespace
        for position in string.gmatch(prefix,"()%s+") do whitespace=position end
        if whitespace and whitespace>1 then
            fitting=whitespace
        end
        visualLines[#visualLines+1]={
            text=string.sub(remaining,1,fitting),
            start=lineStart+consumed,
        }
        consumed=consumed+fitting
    end
end

local function BuildVisualLines(edit,source)
    local left,right=edit:GetTextInsets()
    local maximumWidth=math.max(1,edit:GetWidth()-(tonumber(left) or 0)-(tonumber(right) or 0))
    local visualLines={}
    local lineStart=1

    while true do
        local newline=string.find(source,"\n",lineStart,true)
        local lineEnd=newline and newline-1 or #source
        local line=string.sub(source,lineStart,lineEnd)
        AddWrappedLogicalLine(edit,visualLines,line,lineStart-1,maximumWidth)
        if not newline then break end
        lineStart=newline+1
        if lineStart>#source then
            visualLines[#visualLines+1]={text="",start=#source}
            break
        end
    end

    if #visualLines==0 then visualLines[1]={text="",start=0} end
    return visualLines
end

local function FindCursorInVisualLine(edit,line,mouseX)
    if mouseX<=0 or line.text=="" then return line.start end

    local previousOffset=0
    local previousWidth=0
    local offset=0
    while offset<#line.text do
        offset=NextCharacterBoundary(line.text,offset)
        local width=MeasureTextWidth(edit,string.sub(line.text,1,offset))
        if mouseX<(previousWidth+width)/2 then
            return line.start+previousOffset
        end
        previousOffset=offset
        previousWidth=width
    end
    return line.start+#line.text
end

local function GetMouseCursorPosition(edit)
    if not edit or not edit.GetLeft or not GetCursorPosition then return end
    local leftEdge,topEdge=edit:GetLeft(),edit:GetTop()
    if not leftEdge or not topEdge then return end

    local cursorX,cursorY=GetCursorPosition()
    local scale=edit:GetEffectiveScale()
    if not scale or scale==0 then return end
    cursorX,cursorY=cursorX/scale,cursorY/scale

    local leftInset,_,topInset=edit:GetTextInsets()
    local mouseX=cursorX-leftEdge-(tonumber(leftInset) or 0)
    local mouseY=topEdge-cursorY-(tonumber(topInset) or 0)
    local scroll=edit:GetParent()
    if scroll and scroll.GetVerticalScroll then
        mouseY=mouseY+(scroll:GetVerticalScroll() or 0)
    end

    local _,fontSize=edit:GetFont()
    local lineHeight=(tonumber(fontSize) or 12)+LINE_SPACING
    local lines=BuildVisualLines(edit,edit:GetText() or "")
    local lineIndex=math.floor(math.max(0,mouseY)/math.max(1,lineHeight))+1
    lineIndex=math.max(1,math.min(#lines,lineIndex))
    return FindCursorInVisualLine(edit,lines[lineIndex],mouseX)
end

local function PlaceCursorFromMouse(edit)
    local position=GetMouseCursorPosition(edit)
    if position==nil then return end
    edit:SetFocus()
    edit:SetCursorPosition(position)

    -- WoW performs its native EditBox mouse placement after the script on
    -- some clients.  Reapply on the next frame so it cannot reset to the end.
    C_Timer.After(0,function()
        if replacement==edit and edit:HasFocus() then
            edit:SetCursorPosition(position)
        end
    end)
end

local function SyncEditorHeight(edit)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end
    local parsed=EnsureSyntaxText(edit)
    local contentHeight=(parsed and parsed:GetStringHeight() or 0)+12
    edit:SetHeight(math.max(1,scroll:GetHeight(),contentHeight))
end

local function UpdateSyntax(edit)
    if not edit then return end
    local parsed=EnsureSyntaxText(edit)
    if not parsed then return end

    local raw=GetNativeTextRegion(edit)
    if raw and raw.GetFont and parsed.SetFont then
        local path,size,flags=raw:GetFont()
        if path then parsed:SetFont(path,size,flags) end
    end
    -- FontString:SetText throws when a freshly-created FontString has not yet
    -- inherited a font.  Assign/copy the font before ever feeding it text.
    if parsed.GetFont and not parsed:GetFont() then
        parsed:SetFontObject("GameFontHighlightSmall")
    end

    local source=edit:GetText() or ""
    if _G.MegaMacroParser and type(MegaMacroParser.Parse)=="function" then
        parsed:SetText(MegaMacroParser.Parse(source))
    else
        parsed:SetText(source)
    end
    if raw then
        -- The native EditBox remains the input owner.  Only its glyphs are
        -- nearly transparent; its native caret and selection stay intact.
        raw:SetTextColor(unpack(TEXT))
        raw:SetAlpha(.01)
    end
    parsed:SetAlpha(1)
    parsed:Show()
    SyncEditorHeight(edit)
end

local function ForwardTextChanged(self,userInput)
    if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
        _G.MegaMacro_TextBox_TextChanged(self,userInput)
    elseif _G.ScrollingEdit_OnTextChanged then
        ScrollingEdit_OnTextChanged(self,self:GetParent())
    end
    UpdateSyntax(self)
    -- ScrollingEdit_OnTextChanged may resize the child to exactly the used
    -- line count.  Reassert the editor minimum after the stock handler so the
    -- background never ends at the last line of macro text.
    C_Timer.After(0,function()
        if replacement==self then
            UpdateSyntax(self)
        end
    end)
end

local function BuildReplacement()
    if replacement then return replacement end

    local scroll=_G.MegaMacro_FrameScrollFrame
    local old=_G.MegaMacro_FrameText
    if not scroll or not old then return end

    legacyEdit=old
    _G.BetterMacroLegacyFrameText=old

    local edit=CreateFrame("EditBox","BetterMacroEditorText",scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(1023)
    if edit.SetCountInvisibleLetters then edit:SetCountInvisibleLetters(true) end
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetTextColor(unpack(TEXT))
    edit:SetTextInsets(7,7,6,6)
    if edit.SetSpacing then edit:SetSpacing(LINE_SPACING) end
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetWidth(math.max(1,scroll:GetWidth()-4))
    edit:SetHeight(math.max(1,scroll:GetHeight()))

    -- Capture the widget's own FontString before adding the colored display
    -- FontString.  This prevents later region scans from confusing the two.
    GetNativeTextRegion(edit)
    EnsureSyntaxText(edit)
    EnsureCaret(edit)
    EnsureUniformBackground(scroll)

    local originalText=old:GetText() or ""
    edit:SetText(originalText)
    if old.IsEnabled and not old:IsEnabled() then edit:Disable() end

    edit:SetScript("OnKeyDown",function(self,key)
        if type(_G.MegaMacro_TextBox_OnKeyDown)=="function" then
            _G.MegaMacro_TextBox_OnKeyDown(self,key)
        end
    end)
    edit:SetScript("OnMouseDown",function(self,button)
        if button=="LeftButton" and self:IsEnabled() then
            PlaceCursorFromMouse(self)
        end
    end)
    edit:SetScript("OnTextChanged",ForwardTextChanged)
    edit:SetScript("OnCursorChanged",function(self,x,y,width,height)
        if _G.ScrollingEdit_OnCursorChanged then
            ScrollingEdit_OnCursorChanged(self,x,y,width,height)
        end
        PositionCaret(self,x,y,width,height)
    end)
    edit:SetScript("OnUpdate",function(self,elapsed)
        if _G.ScrollingEdit_OnUpdate then
            ScrollingEdit_OnUpdate(self,elapsed,self:GetParent())
        end
        UpdateCaret(self,elapsed)
    end)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained",function(self)
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,true) end
        PositionCaret(
            self,
            self.__BetterMacroCaretX,
            self.__BetterMacroCaretY,
            self.__BetterMacroCaretWidth,
            self.__BetterMacroCaretHeight
        )
        if customCaret then
            customCaret.__BetterMacroBlinkElapsed=0
            customCaret:Show()
        end
    end)
    edit:SetScript("OnEditFocusLost",function()
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,false) end
        if customCaret then customCaret:Hide() end
    end)

    scroll:SetScrollChild(edit)
    replacement=edit
    _G.MegaMacro_FrameText=edit
    UpdateSyntax(edit)
    HideLegacyEditor()
    return edit
end

function Editor.Apply()
    local frame=_G.MegaMacro_Frame
    local scroll=_G.MegaMacro_FrameScrollFrame
    local edit=BuildReplacement()
    if not frame or not scroll or not edit then return end

    HideLegacyEditor()

    local configSelected=_G.BetterMacro_GetSelectedTabIndex
        and _G.BetterMacro_GetSelectedTabIndex()==6
    if configSelected then
        scroll:Hide()
        local background=frame.__BPMMGoalEditorBackground
        if background then background:Hide() end
        return
    end

    scroll:SetAlpha(1)
    scroll:SetFrameLevel(frame:GetFrameLevel()+12)
    scroll:EnableMouse(true)
    scroll:Show()

    edit:SetAlpha(1)
    edit:SetFrameLevel(scroll:GetFrameLevel()+1)
    edit:SetWidth(math.max(1,scroll:GetWidth()-4))
    edit:SetTextColor(unpack(TEXT))
    edit:EnableMouse(true)
    edit:Show()

    EnsureUniformBackground(scroll)
    UpdateSyntax(edit)

    local background=EnsureBackground(frame,scroll)
    SetEditorBorder(background,edit:HasFocus())

    -- The replacement EditBox receives clicks directly; the legacy full-size
    -- button would otherwise sit above it and intercept selection/dragging.
    local clickTarget=_G.MegaMacro_FrameTextButton
    if clickTarget then
        clickTarget:EnableMouse(false)
        clickTarget:SetAlpha(0)
        clickTarget:Hide()
    end
end

local function QueueApply()
    C_Timer.After(0,Editor.Apply)
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    QueueApply()
    C_Timer.After(.5,Editor.Apply)
    C_Timer.After(1.4,Editor.Apply)
end)

if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        QueueApply()
        C_Timer.After(.25,Editor.Apply)
    end)
end

for _,functionName in ipairs({
    "MegaMacro_MacroButton_OnClick",
    "MegaMacro_FrameTab_OnClick",
    "MegaMacro_EditOkButton_OnClick",
}) do
    if type(_G[functionName])=="function" then
        hooksecurefunc(functionName,QueueApply)
    end
end

Editor.Apply()
