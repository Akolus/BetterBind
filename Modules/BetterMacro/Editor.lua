-- BetterMacro single native EditBox editor.
--
-- The window XML creates the only text input. This module styles it, supplies
-- scroll behavior and syntax feedback, and routes pointer gestures through a
-- transparent proxy so the legacy EditBox cannot also mutate the same drag.

local Editor={}
Editor.VERSION="1.0.78"
_G.BPMMBetterMacroEditor=Editor

local WHITE="Interface\\Buttons\\WHITE8x8"
local FONT_PATH="Interface\\AddOns\\BetterBind\\Fonts\\open-sans.light.ttf"
local EDITOR_FONT_SIZE=14
local BG={.075,.078,.088,1}
local BORDER={.13,.14,.16,1}
local TEXT={.90,.93,.97,1}
local HIGHLIGHT={.02,.58,.94,.55}
local FONT_SHADOW={0,0,0,.75}
local SYNTAX_COLOR={
    text="ffeeeeee",
    syntax="ff33ddff",
    command="ff55dd88",
    condition="ffff9900",
    target="ffffd700",
    comment="ff44ff44",
    error="ffff4444",
    spell="ffb388ff",
    item="ffffb84d",
    reference="ff7fd5ff",
}
local LINE_SPACING=0
local WHEEL_LINES=3
local DOUBLE_CLICK_SECONDS=.50
local CARET_BLINK_SECONDS=.50
local CARET_HEIGHT=14
local EDITOR_STRATA="DIALOG"
local EDITOR_FRAME_LEVEL=100

local backgroundTexture
local measurementFrame
local measurementText
local BuildVisualLines
local GetEditorLineHeight
local ScrollEditor
local selectionHighlights={}
local rightMouseWasDown=false
local leftMouseDownX
local leftMouseDownY
local leftMouseDownAnchor
local nativeLeft={
    down=false,
    edit=nil,
    anchor=nil,
    current=nil,
    updatingCursor=false,
}
local requestedItemData={}
local requestedSpellData={}
local caret={
    mask=nil,
    line=nil,
    edit=nil,
    elapsed=0,
    lit=true,
    positioned=false,
    x=nil,
    y=nil,
    width=nil,
    height=nil,
    lineX=nil,
    lineY=nil,
    lineHeight=nil,
    measuredX=nil,
    effectiveScale=nil,
}
local selection={
    dragging=false,
    edit=nil,
    button=nil,
    anchor=0,
    current=0,
    lastClickTime=0,
    lastClickPosition=nil,
    lastClickButton=nil,
    serial=0,
}
local verticalNavigation={
    edit=nil,
    preferredX=nil,
    serial=0,
}
local debugState={
    enabled=false,
    downEvents=0,
    upEvents=0,
    dragUpdates=0,
    applyCalls=0,
    lastPosition=nil,
    releaseMissed=false,
}

local function ApplyEditorFont(object)
    if object and object.SetFont then
        object:SetFont(FONT_PATH,EDITOR_FONT_SIZE,"")
    end
    if object and object.SetShadowColor then
        object:SetShadowColor(unpack(FONT_SHADOW))
    end
    if object and object.SetShadowOffset then
        object:SetShadowOffset(0,0)
    end
end

local KNOWN_COMMANDS={
    assist=true, cancelaura=true, cancelform=true, cast=true,
    castrandom=true, castsequence=true, changeactionbar=true, chatlist=true,
    chatwho=true, click=true, console=true, dismount=true, duel=true,
    equip=true, equipset=true, equipslot=true, focus=true, follow=true,
    help=true, inspect=true, invite=true, leavevehicle=true, logout=true,
    macro=true, macrohelp=true, party=true, petaggressive=true,
    petassist=true, petattack=true, petautocastoff=true, petautocaston=true,
    petdefensive=true, petdismiss=true, petfollow=true, petmoveto=true,
    petpassive=true, petstay=true, played=true, promote=true, pvp=true,
    quit=true, raid=true, readycheck=true, reload=true, removefriend=true,
    reply=true, run=true, say=true, script=true, startattack=true,
    stopattack=true, stopcasting=true, stopmacro=true, summonpet=true,
    target=true, targetenemy=true, targetexact=true, targetfriend=true,
    targetlastenemy=true, targetlastfriend=true, targetlasttarget=true,
    targetparty=true, targetraid=true, teamcaptain=true, teamdisband=true,
    teaminvite=true, teamquit=true, teamremove=true, time=true, trade=true,
    uninvite=true, use=true, userandom=true, whisper=true, yell=true,
}

local ABILITY_COMMANDS={
    cancelaura=true,
    cast=true,
    castrandom=true,
    castsequence=true,
    click=true,
    equip=true,
    equipslot=true,
    summonpet=true,
    use=true,
    userandom=true,
}

local ITEM_FIRST_COMMANDS={
    equip=true,
    equipslot=true,
    use=true,
}

local LIST_COMMANDS={
    castrandom=true,
    castsequence=true,
    userandom=true,
}

local function GetEditor()
    return _G.MegaMacro_FrameText
end

local function DebugFrameLabel(frame)
    if not frame then return "nil" end
    local name=frame.GetName and frame:GetName() or nil
    local kind=frame.GetObjectType and frame:GetObjectType() or "region"
    local level=frame.GetFrameLevel and frame:GetFrameLevel() or "-"
    local strata=frame.GetFrameStrata and frame:GetFrameStrata() or "-"
    return string.format(
        "%s[%s L%s %s]",
        name or "<anonymous>",kind,tostring(level),tostring(strata)
    )
end

local function DebugMouseFocusLabel()
    if type(_G.GetMouseFoci)=="function" then
        local results={pcall(_G.GetMouseFoci)}
        if results[1] then
            local foci=results[2]
            if type(foci)=="table" then
                return DebugFrameLabel(foci[1])
            end
            if foci then return DebugFrameLabel(foci) end
        end
    end
    if type(_G.GetMouseFocus)=="function" then
        local ok,focus=pcall(_G.GetMouseFocus)
        if ok then return DebugFrameLabel(focus) end
    end
    return "unavailable"
end

local function DebugLog(format,...)
    if not debugState.enabled then return end
    local ok,message=pcall(string.format,format,...)
    if not ok then message=tostring(format) end
    message="|cff33ddff[BBEdit]|r "..message
    if _G.DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif _G.print then
        print(message)
    end
end

local function CountShownSelectionHighlights()
    local shown=0
    for _,texture in ipairs(selectionHighlights) do
        if texture:IsShown() then shown=shown+1 end
    end
    return shown
end

local function ResetDebugGesture()
    debugState.downEvents=0
    debugState.upEvents=0
    debugState.dragUpdates=0
    debugState.applyCalls=0
    debugState.lastPosition=nil
    debugState.releaseMissed=false
end

local function Trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function ParsePositiveInteger(value)
    local text=Trim(value)
    if not string.match(text,"^%d+$") then return end
    local numeric=tonumber(text)
    if not numeric or numeric<1 or numeric%1~=0 then return end
    return numeric
end

local function EscapeDisplayText(text)
    return (tostring(text or ""):gsub("|","||"))
end

local function Paint(text,colour)
    if not text or text=="" then return "" end
    return "|c"..colour..EscapeDisplayText(text).."|r"
end

local function CollectSlashCommands()
    for globalName,value in pairs(_G) do
        if type(globalName)=="string" and string.match(globalName,"^SLASH_")
            and type(value)=="string" and string.sub(value,1,1)=="/"
        then
            local name=string.lower(string.match(value,"^/([^%s]+)") or "")
            if name~="" then KNOWN_COMMANDS[name]=true end
        end
    end
end

local function RequestSpellData(identifier)
    -- Only explicit numeric IDs may request data. Button references such as
    -- ExtraActionButton1 are not spell ID 1.
    local numeric=ParsePositiveInteger(identifier)
    if not numeric or requestedSpellData[numeric] then return end
    if C_Spell and C_Spell.RequestLoadSpellData then
        requestedSpellData[numeric]=true
        pcall(C_Spell.RequestLoadSpellData,numeric)
    end
end

local function RequestItemData(identifier)
    local numeric=ParsePositiveInteger(identifier)
    if not numeric or requestedItemData[numeric] then return end
    if C_Item and C_Item.RequestLoadItemDataByID then
        requestedItemData[numeric]=true
        pcall(C_Item.RequestLoadItemDataByID,numeric)
    end
end

local function IsValidSpell(identifier)
    identifier=Trim(identifier)
    if identifier=="" then return false end
    identifier=identifier:gsub("^!","")
    identifier=identifier:gsub("^[Ss][Pp][Ee][Ll][Ll]:","")

    local resolved=tonumber(identifier) or identifier
    if type(resolved)=="string" and C_Spell
        and C_Spell.GetSpellIDForSpellIdentifier
    then
        local ok,spellID=pcall(C_Spell.GetSpellIDForSpellIdentifier,resolved)
        if ok and spellID then resolved=spellID end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok,info=pcall(C_Spell.GetSpellInfo,resolved)
        if ok and info and info.name and (info.spellID or info.iconID) then
            return true
        end
    end
    if GetSpellInfo then
        local ok,name=pcall(GetSpellInfo,resolved)
        if ok and name then return true end
    end
    RequestSpellData(resolved)
    return false
end

local function IsValidItem(identifier)
    identifier=Trim(identifier)
    if identifier=="" then return false end
    identifier=identifier:gsub("^[Ii][Tt][Ee][Mm]:","")

    if C_Item and C_Item.GetItemInfoInstant then
        local ok,itemID=pcall(C_Item.GetItemInfoInstant,identifier)
        if ok and itemID then return true end
    end
    if C_Item and C_Item.GetItemInfo then
        local ok,name=pcall(C_Item.GetItemInfo,identifier)
        if ok and name then return true end
    elseif GetItemInfo then
        local ok,name=pcall(GetItemInfo,identifier)
        if ok and name then return true end
    end
    RequestItemData(identifier)
    return false
end

local function ResolveAbilityColour(value,command)
    value=Trim(value)
    if value=="" then return SYNTAX_COLOR.text end

    if command=="click" then return SYNTAX_COLOR.reference end

    if string.match(string.lower(value),"^item:") then
        return IsValidItem(value) and SYNTAX_COLOR.item or SYNTAX_COLOR.error
    end
    if string.match(string.lower(value),"^spell:") then
        return IsValidSpell(value) and SYNTAX_COLOR.spell or SYNTAX_COLOR.error
    end

    if ITEM_FIRST_COMMANDS[command] then
        if IsValidItem(value) then return SYNTAX_COLOR.item end
        if IsValidSpell(value) then return SYNTAX_COLOR.spell end
    else
        if IsValidSpell(value) then return SYNTAX_COLOR.spell end
        if IsValidItem(value) then return SYNTAX_COLOR.item end
    end
    return SYNTAX_COLOR.text
end

local function FormatCondition(condition)
    local output={}
    local index=1
    while index<=#condition do
        local character=string.sub(condition,index,index)
        if character=="[" or character=="]" or character=="," then
            output[#output+1]=Paint(character,SYNTAX_COLOR.syntax)
            index=index+1
        elseif character=="@" then
            local finish=index
            while finish<#condition
                and string.match(string.sub(condition,finish+1,finish+1),"[%w_]")
            do
                finish=finish+1
            end
            output[#output+1]=Paint(
                string.sub(condition,index,finish),SYNTAX_COLOR.target
            )
            index=finish+1
        else
            local finish=index
            while finish<#condition do
                local following=string.sub(condition,finish+1,finish+1)
                if following=="[" or following=="]" or following=="," or following=="@" then
                    break
                end
                finish=finish+1
            end
            output[#output+1]=Paint(
                string.sub(condition,index,finish),SYNTAX_COLOR.condition
            )
            index=finish+1
        end
    end
    return table.concat(output)
end

local function FormatAbilityValue(value,command)
    local leading,content,trailing=string.match(value,"^(%s*)(.-)(%s*)$")
    leading,content,trailing=leading or "",content or value,trailing or ""
    if content=="" then return EscapeDisplayText(value) end

    local prefix=""
    if LIST_COMMANDS[command] then
        local reset,remaining=string.match(content,"^(reset=[^%s]+%s+)(.+)$")
        if reset then
            prefix=Paint(reset,SYNTAX_COLOR.condition)
            content=remaining
        end
    end

    local bang=""
    if string.sub(content,1,1)=="!" then
        bang=Paint("!",SYNTAX_COLOR.syntax)
        content=string.sub(content,2)
    end
    return EscapeDisplayText(leading)..prefix..bang
        ..Paint(content,ResolveAbilityColour(content,command))
        ..EscapeDisplayText(trailing)
end

local function FormatAbilityChunk(chunk,command)
    if not LIST_COMMANDS[command] then
        return FormatAbilityValue(chunk,command)
    end

    local output={}
    local start=1
    while start<=#chunk do
        local comma=string.find(chunk,",",start,true)
        local finish=comma and comma-1 or #chunk
        output[#output+1]=FormatAbilityValue(
            string.sub(chunk,start,finish),command
        )
        if not comma then break end
        output[#output+1]=Paint(",",SYNTAX_COLOR.syntax)
        start=comma+1
    end
    if chunk=="" then return "" end
    return table.concat(output)
end

local function FormatCommandBody(body,command)
    if not ABILITY_COMMANDS[command] then
        return Paint(body,SYNTAX_COLOR.text)
    end

    local output={}
    local chunkStart=1
    local index=1
    local function FlushChunk(last)
        if last>=chunkStart then
            output[#output+1]=FormatAbilityChunk(
                string.sub(body,chunkStart,last),command
            )
        end
    end

    while index<=#body do
        local character=string.sub(body,index,index)
        if character=="[" then
            FlushChunk(index-1)
            local close=string.find(body,"]",index+1,true)
            local finish=close or #body
            output[#output+1]=FormatCondition(string.sub(body,index,finish))
            chunkStart=finish+1
            index=finish+1
        elseif character==";" then
            FlushChunk(index-1)
            output[#output+1]=Paint(";",SYNTAX_COLOR.syntax)
            chunkStart=index+1
            index=index+1
        else
            index=index+1
        end
    end
    FlushChunk(#body)
    return table.concat(output)
end

local function FormatLine(line)
    local prefix=string.match(line,"^(%s*)") or ""
    local start=#prefix+1
    local marker=string.sub(line,start,start)

    if marker=="/" then
        local command=string.match(string.sub(line,start+1),"^([%w_]+)")
        if not command then return Paint(line,SYNTAX_COLOR.error) end
        local lower=string.lower(command)
        local body=string.sub(line,start+1+#command)
        return EscapeDisplayText(prefix)
            ..Paint("/",SYNTAX_COLOR.syntax)
            ..Paint(command,KNOWN_COMMANDS[lower]
                and SYNTAX_COLOR.command or SYNTAX_COLOR.error)
            ..FormatCommandBody(body,lower)
    end

    if marker=="#" then
        local directive=string.match(string.sub(line,start+1),"^([%w_]+)")
        if not directive then return Paint(line,SYNTAX_COLOR.comment) end
        local lower=string.lower(directive)
        if lower~="show" and lower~="showtooltip" and lower~="showicon" then
            return EscapeDisplayText(prefix)
                ..Paint(string.sub(line,start),SYNTAX_COLOR.comment)
        end
        local body=string.sub(line,start+1+#directive)
        return EscapeDisplayText(prefix)
            ..Paint("#",SYNTAX_COLOR.syntax)
            ..Paint(directive,SYNTAX_COLOR.command)
            ..FormatCommandBody(body,"cast")
    end

    if line=="" then return "" end
    return Paint(line,SYNTAX_COLOR.error)
end

local function FormatMacroText(source)
    local output={}
    local start=1
    while true do
        local newline=string.find(source,"\n",start,true)
        output[#output+1]=FormatLine(
            string.sub(source,start,newline and newline-1 or #source)
        )
        if not newline then break end
        output[#output+1]="\n"
        start=newline+1
    end
    return table.concat(output)
end

local function EnsureSyntaxText(edit)
    local syntax=edit.__BPMMSyntaxText
    if not syntax then
        -- A FontString region cannot capture the mouse. Attaching it directly
        -- to the EditBox lets the ARTWORK selection sit behind the glyphs and
        -- keeps the OVERLAY syntax below the custom caret on the same frame.
        syntax=edit:CreateFontString(
            "MegaMacro_FrameSyntaxText","OVERLAY","GameFontHighlightSmall"
        )
        if syntax.SetDrawLayer then syntax:SetDrawLayer("OVERLAY",5) end
        syntax:SetJustifyH("LEFT")
        syntax:SetJustifyV("TOP")
        syntax:SetWordWrap(true)
        if syntax.SetNonSpaceWrap then syntax:SetNonSpaceWrap(true) end
        if syntax.SetMaxLines then syntax:SetMaxLines(0) end
        if syntax.SetSpacing then syntax:SetSpacing(LINE_SPACING) end
        syntax:SetTextColor(1,1,1,1)
        edit.__BPMMSyntaxText=syntax
    end

    local left,right,top,bottom=edit:GetTextInsets()
    ApplyEditorFont(syntax)
    local source=edit:GetText() or ""
    local visualLineCount=1
    if BuildVisualLines then
        visualLineCount=#BuildVisualLines(edit,source)
    else
        local _,newlines=source:gsub("\n","")
        visualLineCount=newlines+1
    end
    local lineHeight=GetEditorLineHeight
        and GetEditorLineHeight(edit) or EDITOR_FONT_SIZE
    local safeHeight=math.max(1,visualLineCount)*math.max(1,lineHeight)+2
    syntax:ClearAllPoints()
    syntax:SetPoint(
        "TOPLEFT",edit,"TOPLEFT",tonumber(left) or 0,-(tonumber(top) or 0)
    )
    -- Size this surface explicitly instead of bottom-anchoring it. A bounded
    -- FontString can replace undisplayed lines with "..." even when the
    -- underlying EditBox still contains them.
    syntax:SetSize(
        math.max(
            1,
            edit:GetWidth()-(tonumber(left) or 0)-(tonumber(right) or 0)
        ),
        math.max(
            1,
            edit:GetHeight()-(tonumber(top) or 0)-(tonumber(bottom) or 0),
            safeHeight
        )
    )
    syntax:Show()
    syntax:SetAlpha(1)
    return syntax
end

local function RefreshSyntax(edit)
    if not edit then return end
    EnsureSyntaxText(edit):SetText(FormatMacroText(edit:GetText() or ""))
end

local function SetEditorBorder(background,focused)
    if not background or not background.SetBackdropBorderColor then return end
    background:SetBackdropBorderColor(unpack(BORDER))
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

local function EnsureBackgroundTexture(scroll)
    if not backgroundTexture then
        backgroundTexture=scroll:CreateTexture(nil,"BACKGROUND",nil,-8)
        backgroundTexture:SetAllPoints(scroll)
    end
    backgroundTexture:SetColorTexture(unpack(BG))
    backgroundTexture:SetAlpha(1)
    backgroundTexture:Show()
end

local function HideCaret()
    if caret.mask then caret.mask:Hide() end
    if caret.line then caret.line:Hide() end
end

local function GetOnePhysicalPixel(region)
    local scale=region and region:GetEffectiveScale() or 1
    if not scale or scale<=0 then scale=1 end

    if _G.PixelUtil and PixelUtil.GetNearestPixelSize then
        -- A zero UI-unit request with a one-pixel minimum resolves to exactly
        -- one physical pixel at the region's current effective scale.
        return PixelUtil.GetNearestPixelSize(0,scale,1)
    end

    if GetPhysicalScreenSize then
        local _,physicalHeight=GetPhysicalScreenSize()
        if physicalHeight and physicalHeight>0 then
            return (768/physicalHeight)/scale
        end
    end
    return 1
end

local function SetPixelSnappedPoint(region,relativeTo,x,y)
    region:ClearAllPoints()
    if _G.PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(
            region,
            "TOPLEFT",
            relativeTo,
            "TOPLEFT",
            x,
            y
        )
    else
        region:SetPoint("TOPLEFT",relativeTo,"TOPLEFT",x,y)
    end
end

local function EnsureCaret(edit)
    if caret.edit==edit and caret.mask and caret.line then return end

    EnsureSyntaxText(edit)

    caret.edit=edit
    -- These regions must share the EditBox's frame.  Keeping them on the
    -- lower syntax surface leaves WoW's native caret visible above our mask.
    -- Texture regions do not participate in hit testing, so clicks still go
    -- directly to the EditBox.
    caret.mask=edit:CreateTexture(nil,"OVERLAY",nil,6)
    caret.mask:SetColorTexture(unpack(BG))
    if caret.mask.SetSnapToPixelGrid then
        caret.mask:SetSnapToPixelGrid(true)
    end
    if caret.mask.SetTexelSnappingBias then
        caret.mask:SetTexelSnappingBias(0)
    end
    caret.line=edit:CreateTexture(nil,"OVERLAY",nil,7)
    caret.line:SetColorTexture(unpack(TEXT))
    if caret.line.SetSnapToPixelGrid then
        caret.line:SetSnapToPixelGrid(true)
    end
    if caret.line.SetTexelSnappingBias then
        caret.line:SetTexelSnappingBias(0)
    end
    caret.elapsed=0
    caret.lit=true
    caret.positioned=false
    caret.x,caret.y,caret.width,caret.height=nil,nil,nil,nil
    caret.lineX,caret.lineY,caret.lineHeight=nil,nil,nil
    caret.measuredX,caret.effectiveScale=nil,nil
    HideCaret()
end

local function SelectionIsVisible(edit)
    if selection.edit==edit and selection.anchor~=selection.current then
        return true
    end
    return false
end

local function RefreshCaretVisibility(edit)
    if caret.edit~=edit or not caret.positioned or not edit:IsVisible()
        or not edit:HasFocus() or SelectionIsVisible(edit)
    then
        HideCaret()
        return
    end

    -- The mask covers WoW's short, wide native caret. The one-pixel themed
    -- line above it supplies the taller shape and predictable blink cycle.
    caret.mask:Show()
    if caret.lit then caret.line:Show() else caret.line:Hide() end
end

local function PositionCaret(edit,x,y,width,height,visualX,visualY,visualHeight)
    EnsureCaret(edit)
    x=tonumber(x) or 0
    y=tonumber(y) or 0
    width=math.max(0,tonumber(width) or 0)
    height=math.max(1,tonumber(height) or 1)
    visualX=tonumber(visualX) or (x+(width/2))
    visualY=tonumber(visualY) or y
    visualHeight=math.max(1,tonumber(visualHeight) or height)
    local physicalPixel=GetOnePhysicalPixel(caret.line)
    local effectiveScale=caret.line:GetEffectiveScale() or 1
    -- Bias the pixel-grid choice toward the first pixel after the glyph edge
    -- without forcing a complete empty pixel at larger window scales.
    local lineX=visualX+(physicalPixel/2)
    local moved=not caret.positioned or caret.x~=x or caret.y~=y
        or caret.width~=width or caret.height~=height
        or caret.lineX~=lineX or caret.lineY~=visualY
        or caret.lineHeight~=visualHeight
        or caret.effectiveScale~=effectiveScale
    local desiredHeight=math.min(CARET_HEIGHT,visualHeight)
    SetPixelSnappedPoint(caret.mask,edit,x,y)
    caret.mask:SetSize(math.max(physicalPixel,width),height)

    -- WoW's native cursor rectangle follows the hidden EditBox text and does
    -- not reliably match the Open Sans syntax surface on either axis. Keep
    -- the mask on the native rectangle, but draw the themed caret immediately
    -- after the measured Open Sans glyph edge and at the visual-row top.
    SetPixelSnappedPoint(caret.line,edit,lineX,visualY)
    caret.line:SetSize(physicalPixel,desiredHeight)
    if moved then
        caret.elapsed=0
        caret.lit=true
    end
    caret.positioned=true
    caret.x,caret.y,caret.width,caret.height=x,y,width,height
    caret.lineX,caret.lineY,caret.lineHeight=lineX,visualY,visualHeight
    caret.measuredX,caret.effectiveScale=visualX,effectiveScale
    RefreshCaretVisibility(edit)
end

local function UpdateCaretBlink(edit,elapsed)
    if caret.edit~=edit or not caret.positioned then return end
    if not edit:HasFocus() or SelectionIsVisible(edit) then
        HideCaret()
        return
    end

    caret.elapsed=caret.elapsed+(tonumber(elapsed) or 0)
    if caret.elapsed>=CARET_BLINK_SECONDS then
        caret.elapsed=caret.elapsed%CARET_BLINK_SECONDS
        caret.lit=not caret.lit
    end
    RefreshCaretVisibility(edit)
end

local function GetTextRegion(edit)
    if not edit or not edit.GetRegions then return end
    for _,region in ipairs({edit:GetRegions()}) do
        if region~=edit.__BPMMSyntaxText and region and region.GetObjectType
            and region:GetObjectType()=="FontString"
        then
            return region
        end
    end
end

local function MakeNativeInputTransparent(edit)
    edit:SetTextColor(TEXT[1],TEXT[2],TEXT[3],0)
    local textRegion=GetTextRegion(edit)
    if textRegion then
        if textRegion.SetAlpha then textRegion:SetAlpha(1) end
        if textRegion.SetTextColor then
            textRegion:SetTextColor(TEXT[1],TEXT[2],TEXT[3],0)
        end
        if textRegion.Show then textRegion:Show() end
    end
end

local function ShowSyntaxDisplay(edit)
    MakeNativeInputTransparent(edit)
    EnsureSyntaxText(edit):Show()
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

    -- Width and line-height metrics are rasterization-scale dependent. The
    -- measurement surface must inherit the editor's effective scale instead
    -- of UIParent's scale, otherwise caret drift grows whenever BetterMacro is
    -- scaled below or above 100%.
    if edit and measurementFrame:GetParent()~=edit then
        measurementFrame:SetParent(edit)
        measurementFrame:SetScale(1)
    end

    ApplyEditorFont(measurementText)
    if measurementText.SetSpacing then measurementText:SetSpacing(LINE_SPACING) end
    return measurementText
end

local function MeasureTextWidth(edit,text)
    local measure=EnsureMeasurementText(edit)
    measure:SetText(text or "")
    return measure:GetStringWidth() or 0
end

-- Font size is not the same thing as the vertical line advance. Open Sans at
-- 14 px reports a different rendered step on some clients, which previously
-- accumulated into a one-row mouse error. Measure the actual two-line delta.
GetEditorLineHeight=function(edit)
    local measure=EnsureMeasurementText(edit)
    measure:SetText("Ag")
    local oneLine=tonumber(measure:GetStringHeight()) or 0
    measure:SetText("Ag\nAg")
    local twoLines=tonumber(measure:GetStringHeight()) or 0
    local advance=twoLines-oneLine
    measure:SetText("")
    if advance>0 then return advance end

    local _,fontSize=edit:GetFont()
    return math.max(1,tonumber(fontSize) or EDITOR_FONT_SIZE)
end

-- EditBox cursor positions are byte offsets. Keep calculated offsets on full
-- UTF-8 characters so localized spell and item names are never split.
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

local function PreviousCharacterBoundary(text,offset)
    local position=math.max(0,math.min(#text,tonumber(offset) or 0)-1)
    while position>0 do
        local byte=string.byte(text,position+1) or 0
        if byte<128 or byte>=192 then break end
        position=position-1
    end
    return position
end

local function CharacterAt(text,offset)
    if offset<0 or offset>=#text then return "" end
    return string.sub(text,offset+1,NextCharacterBoundary(text,offset))
end

local function IsWordCharacter(character)
    if not character or character=="" then return false end
    if #character>1 then return true end
    return character:match("[%w_]")~=nil
end

local function FindWordBounds(text,position)
    if text=="" then return end
    position=math.max(0,math.min(#text,tonumber(position) or 0))

    local probe=position
    if probe>=#text or not IsWordCharacter(CharacterAt(text,probe)) then
        if probe<=0 then return end
        local previous=PreviousCharacterBoundary(text,probe)
        if not IsWordCharacter(CharacterAt(text,previous)) then return end
        probe=previous
    end

    local first=probe
    while first>0 do
        local previous=PreviousCharacterBoundary(text,first)
        if not IsWordCharacter(CharacterAt(text,previous)) then break end
        first=previous
    end

    local last=NextCharacterBoundary(text,probe)
    while last<#text and IsWordCharacter(CharacterAt(text,last)) do
        last=NextCharacterBoundary(text,last)
    end
    return first,last
end

local function FindFittingOffset(edit,text,maximumWidth)
    local offset=0
    local fitting=0
    while offset<#text do
        offset=NextCharacterBoundary(text,offset)
        if MeasureTextWidth(edit,string.sub(text,1,offset))>maximumWidth then break end
        fitting=offset
    end
    if fitting==0 and #text>0 then fitting=NextCharacterBoundary(text,0) end
    return fitting
end

local function AddWrappedLine(edit,visualLines,line,lineStart,maximumWidth)
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

        local prefix=string.sub(remaining,1,fitting)
        local whitespace
        for position in string.gmatch(prefix,"()%s+") do whitespace=position end
        if whitespace and whitespace>1 then fitting=whitespace end
        visualLines[#visualLines+1]={
            text=string.sub(remaining,1,fitting),
            start=lineStart+consumed,
        }
        consumed=consumed+fitting
    end
end

BuildVisualLines=function(edit,source)
    local left,right=edit:GetTextInsets()
    local maximumWidth=math.max(
        1,
        edit:GetWidth()-(tonumber(left) or 0)-(tonumber(right) or 0)
    )
    local visualLines={}
    local lineStart=1

    while true do
        local newline=string.find(source,"\n",lineStart,true)
        local lineEnd=newline and newline-1 or #source
        AddWrappedLine(
            edit,
            visualLines,
            string.sub(source,lineStart,lineEnd),
            lineStart-1,
            maximumWidth
        )
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

local function HideSelectionHighlights()
    for _,texture in ipairs(selectionHighlights) do texture:Hide() end
end

local function FindOffsetInLine(edit,line,mouseX)
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

local function GetVisualLineIndex(lines,position)
    local lineIndex=1
    for index,line in ipairs(lines) do
        if line.start>position then break end
        lineIndex=index
    end
    return math.max(1,math.min(#lines,lineIndex))
end

local function GetTextPositionGeometry(edit,position,lines,lineIndex)
    if not edit then return end
    local source=edit:GetText() or ""
    position=math.max(0,math.min(#source,tonumber(position) or 0))
    lines=lines or BuildVisualLines(edit,source)

    -- For keyboard movement, choose the last visual row whose byte offset has
    -- begun. This puts a wrapped-line boundary at the start of the new row,
    -- while a real newline still leaves the preceding offset on the old row.
    if not lineIndex then lineIndex=GetVisualLineIndex(lines,position) end

    lineIndex=math.max(1,math.min(#lines,lineIndex))
    local line=lines[lineIndex]
    local withinLine=math.max(0,math.min(#line.text,position-line.start))
    local leftInset,_,topInset=edit:GetTextInsets()
    local lineHeight=GetEditorLineHeight(edit)
    local caretX=(tonumber(leftInset) or 0)
        +MeasureTextWidth(edit,string.sub(line.text,1,withinLine))
    local caretY=-(tonumber(topInset) or 0)-(lineIndex-1)*lineHeight
    return caretX,caretY,1,lineHeight
end

local function ResetVerticalNavigation()
    verticalNavigation.edit=nil
    verticalNavigation.preferredX=nil
    verticalNavigation.serial=verticalNavigation.serial+1
end

local function GetVerticalDestination(edit,position,direction,preferredX)
    local source=edit:GetText() or ""
    position=math.max(0,math.min(#source,tonumber(position) or 0))
    local lines=BuildVisualLines(edit,source)
    local lineIndex=GetVisualLineIndex(lines,position)
    local line=lines[lineIndex]
    local withinLine=math.max(0,math.min(#line.text,position-line.start))

    -- Retain the rendered horizontal column across consecutive vertical moves.
    -- This also behaves naturally with the proportional Open Sans font and
    -- returns to the original column after crossing a shorter line.
    if preferredX==nil then
        preferredX=MeasureTextWidth(
            edit,
            string.sub(line.text,1,withinLine)
        )
    end

    local targetLineIndex=math.max(
        1,
        math.min(#lines,lineIndex+direction)
    )
    if targetLineIndex==lineIndex then
        return position,preferredX,lineIndex,targetLineIndex
    end

    local destination=FindOffsetInLine(
        edit,
        lines[targetLineIndex],
        preferredX
    )
    return destination,preferredX,lineIndex,targetLineIndex
end

local function GetMouseTextPosition(edit)
    if not edit or not GetCursorPosition then return end
    local syntax=edit.__BPMMSyntaxText or EnsureSyntaxText(edit)
    local leftEdge,topEdge=syntax:GetLeft(),syntax:GetTop()
    if not leftEdge or not topEdge then return end

    local cursorX,cursorY=GetCursorPosition()
    local scale=edit:GetEffectiveScale()
    if not scale or scale==0 then return end
    cursorX,cursorY=cursorX/scale,cursorY/scale

    -- Measure from the rendered coloured surface itself. Its anchor already
    -- contains the EditBox insets and the ScrollFrame's current child offset.
    local mouseX=cursorX-leftEdge
    local mouseY=topEdge-cursorY

    local lineHeight=GetEditorLineHeight(edit)
    local lines=BuildVisualLines(edit,edit:GetText() or "")
    local lineIndex=math.floor(math.max(0,mouseY)/math.max(1,lineHeight))+1
    lineIndex=math.max(1,math.min(#lines,lineIndex))
    local line=lines[lineIndex]
    local offset=FindOffsetInLine(edit,line,mouseX)
    local caretX,caretY,width,height=GetTextPositionGeometry(
        edit,
        offset,
        lines,
        lineIndex
    )
    return offset,caretX,caretY,width,height,lineIndex,mouseX,mouseY,lineHeight
end

local function PublishNativeCaret(edit,position)
    if not edit or position==nil then return end
    local source=edit:GetText() or ""
    position=math.max(0,math.min(#source,tonumber(position) or 0))

    -- Setting the same cursor offset may not emit OnCursorChanged. Briefly
    -- move to an adjacent UTF-8 boundary, then restore the requested offset so
    -- WoW publishes the exact native rectangle used by the custom caret.
    if edit:GetCursorPosition()==position and #source>0 then
        local alternate
        if position>0 then
            alternate=PreviousCharacterBoundary(source,position)
        else
            alternate=NextCharacterBoundary(source,position)
        end
        if alternate~=position then edit:SetCursorPosition(alternate) end
    end
    edit:SetCursorPosition(position)
end

local function SetAuthoritativeCursor(edit,position,x,y,width,height)
    if not edit or position==nil then return end
    local length=#(edit:GetText() or "")
    position=math.max(0,math.min(length,tonumber(position) or 0))
    edit:SetFocus()
    PublishNativeCaret(edit,position)
    edit:HighlightText(position,position)
    HideSelectionHighlights()
    RefreshCaretVisibility(edit)
end

local function ApplySelection(edit,anchor,current)
    if not edit then return end
    local length=#(edit:GetText() or "")
    anchor=math.max(0,math.min(length,tonumber(anchor) or 0))
    current=math.max(0,math.min(length,tonumber(current) or 0))

    edit:SetFocus()
    edit:SetCursorPosition(current)
    edit:HighlightText(math.min(anchor,current),math.max(anchor,current))
    -- While focused, both the glyphs and the highlight come from this native
    -- EditBox. One renderer means their geometry cannot diverge.
    HideSelectionHighlights()
    if debugState.enabled then
        debugState.applyCalls=debugState.applyCalls+1
    end
    RefreshCaretVisibility(edit)
end

local function QueueSelectionReapply(edit,anchor,current,serial)
    local function Reapply()
        if selection.serial~=serial or selection.dragging
            or selection.edit~=edit
        then
            return
        end
        ApplySelection(edit,anchor,current)
    end
    C_Timer.After(0,Reapply)
    C_Timer.After(.05,Reapply)
end

local KEYBOARD_SELECTION_KEYS={
    LEFT=true,
    RIGHT=true,
    UP=true,
    DOWN=true,
    HOME=true,
    END=true,
}

local function QueueKeyboardSelectionRefresh(edit,key)
    if not KEYBOARD_SELECTION_KEYS[key] then return end

    selection.serial=selection.serial+1
    local serial=selection.serial
    selection.dragging=false
    local shifted=type(_G.IsShiftKeyDown)=="function" and IsShiftKeyDown()

    if not shifted then
        selection.edit=edit
        selection.button="Keyboard"
        selection.anchor=edit:GetCursorPosition()
        selection.current=selection.anchor
        HideSelectionHighlights()
        C_Timer.After(0,function()
            if selection.serial~=serial or selection.edit~=edit
                or not edit:HasFocus()
            then
                return
            end
            local current=edit:GetCursorPosition()
            selection.anchor=current
            selection.current=current
            HideSelectionHighlights()
            RefreshCaretVisibility(edit)
        end)
        return
    end

    local anchor=edit:GetCursorPosition()
    if selection.edit==edit and selection.anchor~=nil
        and selection.current~=nil and selection.anchor~=selection.current
    then
        anchor=selection.anchor
    end
    selection.edit=edit
    selection.button="Keyboard"
    selection.anchor=anchor
    selection.current=edit:GetCursorPosition()

    -- The EditBox updates its logical cursor after OnKeyDown. Read that final
    -- position on the next UI turn, then mirror the native selection exactly.
    C_Timer.After(0,function()
        if selection.serial~=serial or selection.edit~=edit
            or not edit:HasFocus()
        then
            return
        end
        local current=edit:GetCursorPosition()
        selection.current=current
        ApplySelection(edit,anchor,current)
    end)
end

local function HandleVerticalCaretKey(edit,key)
    if key~="UP" and key~="DOWN" then return false end

    local start=edit:GetCursorPosition() or 0
    local preferredX
    if verticalNavigation.edit==edit then
        preferredX=verticalNavigation.preferredX
    end
    local destination,measuredX,fromLine,toLine=GetVerticalDestination(
        edit,
        start,
        key=="UP" and -1 or 1,
        preferredX
    )
    local shifted=type(_G.IsShiftKeyDown)=="function" and IsShiftKeyDown()
    local anchor=start
    if shifted and selection.edit==edit and selection.anchor~=nil
        and selection.current~=nil and selection.anchor~=selection.current
    then
        anchor=selection.anchor
    end

    selection.serial=selection.serial+1
    local selectionSerial=selection.serial
    selection.dragging=false
    selection.edit=edit
    selection.button="Keyboard"
    selection.anchor=shifted and anchor or destination
    selection.current=destination

    verticalNavigation.serial=verticalNavigation.serial+1
    local navigationSerial=verticalNavigation.serial
    verticalNavigation.edit=edit
    verticalNavigation.preferredX=measuredX

    local function ApplyVerticalMove()
        if verticalNavigation.serial~=navigationSerial
            or selection.serial~=selectionSerial
            or selection.edit~=edit or not edit:HasFocus()
        then
            return
        end
        if shifted then
            ApplySelection(edit,anchor,destination)
        else
            SetAuthoritativeCursor(edit,destination)
            selection.anchor=destination
            selection.current=destination
        end
        verticalNavigation.edit=edit
        verticalNavigation.preferredX=measuredX
    end

    -- Apply immediately, then once on the next UI turn. The second pass wins
    -- over the EditBox's built-in key processing without changing how normal
    -- typing, Left/Right, Home, End, or Shift-selection behave.
    ApplyVerticalMove()
    C_Timer.After(0,ApplyVerticalMove)
    if debugState.enabled then
        DebugLog(
            "KEY %s from=%d line=%d to=%d line=%d x=%.1f shift=%s",
            key,start,fromLine,destination,toLine,measuredX or 0,
            tostring(shifted)
        )
    end
    return true
end

local function CancelSelectionGesture(clearDoubleClick)
    HideSelectionHighlights()
    nativeLeft.down=false
    nativeLeft.edit=nil
    nativeLeft.anchor=nil
    nativeLeft.current=nil
    nativeLeft.updatingCursor=false
    selection.dragging=false
    selection.edit=nil
    selection.button=nil
    selection.serial=selection.serial+1
    if clearDoubleClick then
        selection.lastClickPosition=nil
        selection.lastClickButton=nil
        selection.lastClickTime=0
    end
    local edit=GetEditor()
    if edit then RefreshCaretVisibility(edit) end
end

local function BeginMouseSelection(edit,button)
    if button~="LeftButton" and button~="RightButton" then return end
    ResetVerticalNavigation(edit)
    local position,x,y,width,height=GetMouseTextPosition(edit)
    if position==nil then return end

    selection.serial=selection.serial+1
    local serial=selection.serial
    local now=(GetTime and GetTime()) or 0
    local source=edit:GetText() or ""
    local wordStart,wordEnd=FindWordBounds(source,position)
    local lastPosition=selection.lastClickPosition
    local isDoubleClick=wordStart and wordEnd and lastPosition~=nil
        and now-selection.lastClickTime<=DOUBLE_CLICK_SECONDS
        and selection.lastClickButton==button
        and lastPosition>=wordStart and lastPosition<=wordEnd

    selection.lastClickTime=now
    selection.lastClickPosition=position
    selection.lastClickButton=button
    selection.edit=edit
    selection.button=button

    if isDoubleClick then
        selection.dragging=false
        selection.anchor=wordStart
        selection.current=wordEnd
        ApplySelection(edit,wordStart,wordEnd)
        QueueSelectionReapply(edit,wordStart,wordEnd,serial)
        return
    end

    selection.dragging=true
    selection.anchor=position
    selection.current=position
    ApplySelection(edit,position,position)
end

local function MirrorNativeLeftSelection(edit)
    if not nativeLeft.down or nativeLeft.edit~=edit then return false end
    local position,x,y,width,height=GetMouseTextPosition(edit)
    if position==nil then return false end
    if not nativeLeft.updatingCursor then
        nativeLeft.updatingCursor=true
        edit:SetCursorPosition(position)
        nativeLeft.updatingCursor=false
    end
    nativeLeft.current=position

    selection.edit=edit
    selection.button="LeftButton"
    selection.anchor=nativeLeft.anchor
    selection.current=position
    if debugState.enabled and debugState.lastPosition~=position then
        debugState.dragUpdates=debugState.dragUpdates+1
        debugState.lastPosition=position
    end
    -- Preserve the EditBox's real selection range. The focused editor displays
    -- native glyphs, so its own highlight is the single visible background.
    edit:HighlightText(
        math.min(selection.anchor,selection.current),
        math.max(selection.anchor,selection.current)
    )
    HideSelectionHighlights()
    RefreshCaretVisibility(edit)
    return selection.anchor~=selection.current
end

local function RestoreNativeLeftGesture(edit)
    if nativeLeft.down and nativeLeft.edit==edit then return true end
    if leftMouseDownAnchor==nil then return false end

    nativeLeft.down=true
    nativeLeft.edit=edit
    nativeLeft.anchor=leftMouseDownAnchor
    nativeLeft.current=leftMouseDownAnchor
    nativeLeft.updatingCursor=false
    selection.edit=edit
    selection.button="LeftButton"
    selection.anchor=leftMouseDownAnchor
    selection.current=leftMouseDownAnchor
    DebugLog("RESTORED anchor=%d after an external state reset",leftMouseDownAnchor)
    return true
end

local function BeginNativeLeftClick(edit)
    ResetVerticalNavigation(edit)
    if GetCursorPosition then
        leftMouseDownX,leftMouseDownY=GetCursorPosition()
    else
        leftMouseDownX,leftMouseDownY=nil,nil
    end
    local position,x,y,width,height,lineIndex,_,mouseY,lineHeight=
        GetMouseTextPosition(edit)
    if position==nil then
        leftMouseDownX,leftMouseDownY,leftMouseDownAnchor=nil,nil,nil
        return
    end
    leftMouseDownAnchor=position
    if debugState.enabled then
        ResetDebugGesture()
        debugState.downEvents=1
        debugState.lastPosition=position
        DebugLog(
            "DOWN anchor=%d line=%d localY=%.1f advance=%.2f cursor=%d focus=%s mouse=%s",
            position,lineIndex or -1,tonumber(mouseY) or -1,
            tonumber(lineHeight) or -1,
            edit:GetCursorPosition() or -1,
            tostring(edit:HasFocus()),DebugMouseFocusLabel()
        )
    end
    nativeLeft.down=true
    nativeLeft.edit=edit
    nativeLeft.anchor=position
    nativeLeft.current=position
    nativeLeft.updatingCursor=false
    selection.edit=edit
    selection.button="LeftButton"
    selection.anchor=position
    selection.current=position
    HideSelectionHighlights()
    SetAuthoritativeCursor(edit,position,x,y,width,height)
end

local function CompleteNativeLeftClick(edit)
    if leftMouseDownAnchor==nil
        and (not nativeLeft.down or nativeLeft.edit~=edit)
    then
        return
    end
    local clickTime=(GetTime and GetTime()) or 0
    local upX,upY
    if GetCursorPosition then upX,upY=GetCursorPosition() end
    local moved=leftMouseDownX and upX and (
        math.abs(upX-leftMouseDownX)>3 or math.abs(upY-leftMouseDownY)>3
    )
    moved=moved and true or false
    local position,x,y,width,height,lineIndex,_,mouseY,lineHeight=
        GetMouseTextPosition(edit)
    local anchor=nativeLeft.anchor or leftMouseDownAnchor or position or 0
    position=position or nativeLeft.current or anchor
    leftMouseDownX,leftMouseDownY,leftMouseDownAnchor=nil,nil,nil
    if anchor~=position then moved=true end
    if debugState.enabled then
        debugState.upEvents=debugState.upEvents+1
        DebugLog(
            "UP anchor=%d current=%d line=%d localY=%.1f advance=%.2f moved=%s updates=%d mouse=%s",
            anchor,position,lineIndex or -1,tonumber(mouseY) or -1,
            tonumber(lineHeight) or -1,tostring(moved),debugState.dragUpdates,
            DebugMouseFocusLabel()
        )
    end
    nativeLeft.down=false
    nativeLeft.edit=nil
    nativeLeft.anchor=nil
    nativeLeft.current=nil
    nativeLeft.updatingCursor=false

    selection.serial=selection.serial+1
    local serial=selection.serial
    selection.dragging=false
    selection.edit=edit
    selection.button="LeftButton"

    if moved and anchor~=position then
        selection.anchor=anchor
        selection.current=position
        ApplySelection(edit,anchor,position)
        QueueSelectionReapply(edit,anchor,position,serial)
        selection.lastClickTime=0
        selection.lastClickPosition=nil
        selection.lastClickButton=nil
        if debugState.enabled then
            C_Timer.After(.12,function()
                DebugLog(
                    "RESULT range=%d..%d cursor=%d apply=%d mirror=%d focus=%s releaseMissed=%s",
                    selection.anchor or -1,selection.current or -1,
                    edit:GetCursorPosition() or -1,debugState.applyCalls,
                    CountShownSelectionHighlights(),
                    tostring(edit:HasFocus()),tostring(debugState.releaseMissed)
                )
            end)
        end
        return
    end

    local source=edit:GetText() or ""
    local wordStart,wordEnd=FindWordBounds(source,position)
    local lastPosition=selection.lastClickPosition
    local isDoubleClick=wordStart and wordEnd and lastPosition~=nil
        and clickTime-selection.lastClickTime<=DOUBLE_CLICK_SECONDS
        and selection.lastClickButton=="LeftButton"
        and lastPosition>=wordStart and lastPosition<=wordEnd

    selection.lastClickTime=clickTime
    selection.lastClickPosition=position
    selection.lastClickButton="LeftButton"
    selection.anchor=position
    selection.current=position

    if isDoubleClick then
        selection.lastClickTime=0
        selection.lastClickPosition=nil
        selection.lastClickButton=nil
        selection.anchor=wordStart
        selection.current=wordEnd
        ApplySelection(edit,wordStart,wordEnd)
        QueueSelectionReapply(edit,wordStart,wordEnd,serial)
        return
    end

    HideSelectionHighlights()
    caret.elapsed=0
    caret.lit=true
    SetAuthoritativeCursor(edit,position,x,y,width,height)

    -- A proxy click can clear EditBox focus after its handler returns. Restore
    -- the cursor/focus after that default processing, then once more after the
    -- short click-settle window so the custom blink timer remains active.
    local function ReassertClick()
        if not edit:IsVisible()
            or selection.serial~=serial
            or selection.anchor~=selection.current
        then
            return
        end
        SetAuthoritativeCursor(edit,position,x,y,width,height)
    end
    C_Timer.After(0,ReassertClick)
    C_Timer.After(.05,ReassertClick)
    if debugState.enabled then
        C_Timer.After(.12,function()
            DebugLog(
                "CLICK cursor=%d focus=%s native=(%.1f,%.1f %.1fx%.1f) measuredX=%.1f visual=(%.1f,%.1f x%.1f) scale=%.3f lit=%s",
                edit:GetCursorPosition() or -1,tostring(edit:HasFocus()),
                tonumber(caret.x) or -1,tonumber(caret.y) or -1,
                tonumber(caret.width) or -1,tonumber(caret.height) or -1,
                tonumber(caret.measuredX) or -1,
                tonumber(caret.lineX) or -1,tonumber(caret.lineY) or -1,
                tonumber(caret.lineHeight) or -1,
                tonumber(caret.effectiveScale) or -1,
                tostring(caret.lit)
            )
        end)
    end
end

local function EndMouseSelection(edit,button)
    if not selection.dragging or selection.edit~=edit
        or selection.button~=button
    then
        return
    end

    local position,x,y,width,height=GetMouseTextPosition(edit)
    if position~=nil then selection.current=position end
    selection.dragging=false
    ApplySelection(edit,selection.anchor,selection.current)
    QueueSelectionReapply(
        edit,
        selection.anchor,
        selection.current,
        selection.serial
    )
    if selection.anchor~=selection.current then
        selection.lastClickPosition=nil
        selection.lastClickButton=nil
    end
end

local function UpdateMouseSelection(edit)
    if not selection.dragging or selection.edit~=edit then return end

    if not (IsMouseButtonDown and IsMouseButtonDown(selection.button)) then
        EndMouseSelection(edit,selection.button)
        return
    end

    local position,x,y,width,height=GetMouseTextPosition(edit)
    if position==nil or position==selection.current then return end
    selection.current=position
    ApplySelection(edit,selection.anchor,selection.current)
end

local function IsCursorInside(frame)
    if not frame or not GetCursorPosition then return false end
    local left,right,top,bottom=frame:GetLeft(),frame:GetRight(),frame:GetTop(),frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    local cursorX,cursorY=GetCursorPosition()
    local scale=frame:GetEffectiveScale()
    if not scale or scale==0 then return false end
    cursorX,cursorY=cursorX/scale,cursorY/scale
    return cursorX>=left and cursorX<=right and cursorY>=bottom and cursorY<=top
end

local function PollRightMouseSelection(edit)
    if not IsMouseButtonDown then return end
    local isDown=IsMouseButtonDown("RightButton") and true or false

    if isDown and not rightMouseWasDown then
        if IsCursorInside(edit:GetParent()) then
            BeginMouseSelection(edit,"RightButton")
        end
    elseif not isDown and rightMouseWasDown
        and selection.dragging and selection.edit==edit
        and selection.button=="RightButton"
    then
        EndMouseSelection(edit,"RightButton")
    end

    rightMouseWasDown=isDown
end

local function InstallMousePolling(scroll,edit)
    if scroll.__BPMMEditorMousePolling then return end
    scroll.__BPMMEditorMousePolling=true

    -- Keep selection polling separate from the EditBox's native OnUpdate.
    -- This hook runs only while the editor viewport is visible and cannot be
    -- replaced by ScrollingEdit_OnUpdate or another EditBox script.
    scroll:HookScript("OnUpdate",function()
        if not edit:IsVisible() then return end
        if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            if RestoreNativeLeftGesture(edit) then
                MirrorNativeLeftSelection(edit)
            end
        elseif nativeLeft.down or leftMouseDownAnchor~=nil then
            if debugState.enabled and not debugState.releaseMissed then
                debugState.releaseMissed=true
                DebugLog("RELEASE FALLBACK: completing outside mouse proxy")
            end
            CompleteNativeLeftClick(edit)
        end
        PollRightMouseSelection(edit)
        UpdateMouseSelection(edit)
    end)
    scroll:HookScript("OnHide",function()
        rightMouseWasDown=false
        leftMouseDownX,leftMouseDownY,leftMouseDownAnchor=nil,nil,nil
        CancelSelectionGesture(true)
    end)
end

local function EnsureMouseProxy(scroll,edit)
    local proxy=scroll.__BPMMEditorMouseProxy
    if not proxy then
        proxy=CreateFrame("Frame","BetterBindMacroEditorMouseProxy",scroll)
        scroll.__BPMMEditorMouseProxy=proxy
        proxy:EnableMouse(true)
        if proxy.SetMouseClickEnabled then proxy:SetMouseClickEnabled(true) end
        if proxy.SetMouseMotionEnabled then proxy:SetMouseMotionEnabled(true) end
        proxy:EnableMouseWheel(true)
    end

    proxy:ClearAllPoints()
    proxy:SetAllPoints(scroll)
    proxy:SetFrameStrata(EDITOR_STRATA)
    proxy:SetFrameLevel(edit:GetFrameLevel()+10)
    proxy:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then
            BeginNativeLeftClick(edit)
        elseif button=="RightButton" then
            rightMouseWasDown=true
            BeginMouseSelection(edit,button)
        end
    end)
    proxy:SetScript("OnMouseUp",function(_,button)
        if button=="LeftButton" then
            CompleteNativeLeftClick(edit)
        elseif button=="RightButton" then
            rightMouseWasDown=false
            EndMouseSelection(edit,button)
        end
    end)
    proxy:SetScript("OnMouseWheel",function(_,delta)
        ScrollEditor(edit,delta)
    end)
    proxy:Show()
    return proxy
end

local function UpdateScrollChild(edit)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end

    local lineHeight=GetEditorLineHeight(edit)
    local textRegion=GetTextRegion(edit)
    local measuredHeight=textRegion and textRegion:GetStringHeight() or 0
    local visualLineCount=#BuildVisualLines(edit,edit:GetText() or "")
    local _,_,topInset,bottomInset=edit:GetTextInsets()
    local insets=(tonumber(topInset) or 0)+(tonumber(bottomInset) or 0)+2
    local contentHeight=math.max(
        measuredHeight,
        math.max(1,visualLineCount)*lineHeight
    )+insets

    edit:SetHeight(math.max(1,scroll:GetHeight(),math.ceil(contentHeight)))
    EnsureSyntaxText(edit)
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end

    local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
    local current=math.max(0,scroll:GetVerticalScroll() or 0)
    if current>maximum then scroll:SetVerticalScroll(maximum) end
end

local function QueueScrollChildUpdate(edit)
    C_Timer.After(0,function()
        if GetEditor()==edit then UpdateScrollChild(edit) end
    end)
end

ScrollEditor=function(edit,delta)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end

    UpdateScrollChild(edit)
    local step=GetEditorLineHeight(edit)*WHEEL_LINES
    local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
    local current=math.max(0,scroll:GetVerticalScroll() or 0)
    local target=current-(tonumber(delta) or 0)*step
    scroll:SetVerticalScroll(math.max(0,math.min(maximum,target)))
end

local function RefreshCharacterCounter(edit)
    if not edit then return end
    local scroll=edit:GetParent()
    local counter=scroll and scroll.__BPMMCharacterCounter
    if not counter then return end

    local used=edit.GetNumLetters and edit:GetNumLetters()
        or #(edit:GetText() or "")
    local maximum=tonumber(_G.MegaMacroCodeMaxLength) or 250
    used=tonumber(used) or 0
    counter:SetFormattedText("%d / %d",used,maximum)
    if used>maximum then
        counter:SetTextColor(1,.28,.28,1)
    elseif used==maximum then
        counter:SetTextColor(1,.78,.20,1)
    else
        counter:SetTextColor(.62,.66,.72,1)
    end
    counter:Show()
end

local function EnsureCharacterCounter(edit)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end
    local counter=scroll.__BPMMCharacterCounter
    if not counter then
        counter=scroll:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        counter:SetDrawLayer("OVERLAY",7)
        counter:SetPoint("BOTTOMRIGHT",scroll,"BOTTOMRIGHT",-8,6)
        counter:SetJustifyH("RIGHT")
        counter:SetShadowColor(unpack(FONT_SHADOW))
        counter:SetShadowOffset(0,0)
        scroll.__BPMMCharacterCounter=counter
    end
    edit.__BPMMRefreshCharacterCounter=RefreshCharacterCounter
    RefreshCharacterCounter(edit)
end

local function ForwardTextChanged(self,userInput)
    local currentText=self:GetText() or ""
    local contentChanged=self.__BPMMLastText~=currentText
    self.__BPMMLastText=currentText
    -- Some client paths publish OnTextChanged while only moving the native
    -- cursor/selection. Do not erase an active drag unless the string itself
    -- actually changed.
    if contentChanged then CancelSelectionGesture(true) end
    if contentChanged then ResetVerticalNavigation(self) end
    if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
        _G.MegaMacro_TextBox_TextChanged(self,userInput)
    elseif _G.ScrollingEdit_OnTextChanged then
        ScrollingEdit_OnTextChanged(self,self:GetParent())
    end
    RefreshSyntax(self)
    ShowSyntaxDisplay(self)
    if self.__BPMMRefreshCharacterCounter then
        self:__BPMMRefreshCharacterCounter()
    end
    if contentChanged then
        C_Timer.After(0,function()
            if self:IsVisible() and self:HasFocus() then
                PublishNativeCaret(self,self:GetCursorPosition())
            end
        end)
    end
    QueueScrollChildUpdate(self)
end

local function KeepWindowShellNonInteractive(frame)
    local shell=frame and frame.__BetterBindShell
    if not shell then return end
    shell:EnableMouse(false)
    if shell.SetMouseClickEnabled then shell:SetMouseClickEnabled(false) end
    if shell.SetMouseMotionEnabled then shell:SetMouseMotionEnabled(false) end
end

local function RetireEditorBlocker(object)
    if not object then return end
    object:Hide()
    if object.EnableMouse then object:EnableMouse(false) end
    if object.EnableMouseWheel then object:EnableMouseWheel(false) end
    if object.SetMouseClickEnabled then object:SetMouseClickEnabled(false) end
    if object.SetMouseMotionEnabled then object:SetMouseMotionEnabled(false) end
    if object.HookScript and not object.__BPMMRetiredEditorBlocker then
        object.__BPMMRetiredEditorBlocker=true
        object:HookScript("OnShow",function(self) self:Hide() end)
    end
end

local function DisableEditorBlockers()
    RetireEditorBlocker(_G.MegaMacro_FrameTextButton)
    RetireEditorBlocker(_G.MegaMacro_FormattedFrameScrollFrame)
end

local function AnchorActionButtons(scroll)
    if not scroll then return end
    local detail=_G.MegaMacro_EditButton
    local save=_G.MegaMacro_SaveButton
    local cancel=_G.MegaMacro_CancelButton

    if detail then
        detail:SetSize(96,32)
        detail:ClearAllPoints()
        detail:SetPoint("TOPRIGHT",scroll,"BOTTOMRIGHT",-208,-8)
    end
    if save then
        save:SetSize(96,32)
        save:ClearAllPoints()
        save:SetPoint("TOPRIGHT",scroll,"BOTTOMRIGHT",-104,-8)
    end
    if cancel then
        cancel:SetSize(96,32)
        cancel:ClearAllPoints()
        cancel:SetPoint("TOPRIGHT",scroll,"BOTTOMRIGHT",0,-8)
    end
end

local function ConfigureEditor(edit,scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(1023)
    if edit.SetCountInvisibleLetters then edit:SetCountInvisibleLetters(true) end
    if edit.SetBlinkSpeed then edit:SetBlinkSpeed(CARET_BLINK_SECONDS) end
    ApplyEditorFont(edit)
    local textRegion=GetTextRegion(edit)
    ApplyEditorFont(textRegion)
    -- The EditBox owns keyboard input and the real selection range. Its glyphs
    -- remain transparent so the exactly matched syntax surface stays visible
    -- above the native highlight.
    if edit.SetHighlightColor then
        edit:SetHighlightColor(unpack(HIGHLIGHT))
    end
    edit:SetTextInsets(7,7,6,22)
    if edit.SetSpacing then edit:SetSpacing(LINE_SPACING) end
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetWidth(math.max(1,scroll:GetWidth()-4))
    edit:SetAlpha(1)
    edit:SetFrameStrata(EDITOR_STRATA)
    edit:SetFrameLevel(scroll:GetFrameLevel()+1)
    -- A dedicated transparent proxy owns all mouse gestures. Disabling native
    -- EditBox mouse input prevents WoW from applying a second cursor/drag
    -- operation after BetterBind has already established the measured range.
    edit:EnableMouse(false)
    if edit.SetMouseClickEnabled then edit:SetMouseClickEnabled(false) end
    if edit.SetMouseMotionEnabled then edit:SetMouseMotionEnabled(false) end
    if edit.SetPropagateMouseClicks then
        edit:SetPropagateMouseClicks(false)
    end
    if edit.SetPropagateMouseMotion then
        edit:SetPropagateMouseMotion(false)
    end
    edit:EnableMouseWheel(false)
    edit.__BPMMLastText=edit:GetText() or ""
    RefreshSyntax(edit)
    ShowSyntaxDisplay(edit)
    EnsureCharacterCounter(edit)

    edit:SetScript("OnMouseDown",nil)
    edit:SetScript("OnMouseUp",nil)
    edit:SetScript("OnMouseWheel",nil)
    edit:SetScript("OnKeyDown",function(self,key)
        if type(_G.MegaMacro_TextBox_OnKeyDown)=="function" then
            _G.MegaMacro_TextBox_OnKeyDown(self,key)
        end
        if not HandleVerticalCaretKey(self,key) then
            ResetVerticalNavigation(self)
            QueueKeyboardSelectionRefresh(self,key)
        end
    end)
    edit:SetScript("OnTextChanged",ForwardTextChanged)
    edit:SetScript("OnCursorChanged",function(self,x,y,width,height)
        if _G.ScrollingEdit_OnCursorChanged then
            ScrollingEdit_OnCursorChanged(self,x,y,width,height)
        end
        local visualX,visualY,_,visualHeight=
            GetTextPositionGeometry(self,self:GetCursorPosition())
        PositionCaret(
            self,x,y,width,height,
            visualX,visualY,visualHeight
        )
    end)
    edit:SetScript("OnUpdate",function(self,elapsed)
        if _G.ScrollingEdit_OnUpdate then
            ScrollingEdit_OnUpdate(self,elapsed,self:GetParent())
        end
        UpdateCaretBlink(self,elapsed)
    end)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained",function(self)
        HideSelectionHighlights()
        EnsureCaret(self)
        caret.elapsed=0
        caret.lit=true
        ShowSyntaxDisplay(self)
        RefreshCaretVisibility(self)
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,true) end
    end)
    edit:SetScript("OnEditFocusLost",function(self)
        ResetVerticalNavigation(self)
        HideSelectionHighlights()
        HideCaret()
        RefreshSyntax(self)
        ShowSyntaxDisplay(self)
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,false) end
    end)

    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        ScrollEditor(edit,delta)
    end)
    EnsureMouseProxy(scroll,edit)
    InstallMousePolling(scroll,edit)
end

function Editor.Apply()
    local frame=_G.MegaMacro_Frame
    local scroll=_G.MegaMacro_FrameScrollFrame
    local edit=GetEditor()
    if not frame or not scroll or not edit then return end

    KeepWindowShellNonInteractive(frame)
    DisableEditorBlockers()

    local configSelected=_G.BetterMacro_GetSelectedTabIndex
        and _G.BetterMacro_GetSelectedTabIndex()==6
    if configSelected then
        scroll:Hide()
        local background=frame.__BPMMGoalEditorBackground
        if background then background:Hide() end
        return
    end

    scroll:SetAlpha(1)
    -- Frame Stack can reveal mouse-follow frames from other addons above BM's
    -- normal MEDIUM strata. Raise only the editor viewport so those frames
    -- cannot intercept text clicks, drags, or wheel input.
    scroll:SetFrameStrata(EDITOR_STRATA)
    scroll:SetFrameLevel(EDITOR_FRAME_LEVEL)
    scroll:Show()

    AnchorActionButtons(scroll)
    ConfigureEditor(edit,scroll)
    edit:Show()
    EnsureBackgroundTexture(scroll)
    UpdateScrollChild(edit)

    local background=EnsureBackground(frame,scroll)
    SetEditorBorder(background,edit:HasFocus())
end

function Editor.GetStatus()
    local edit=GetEditor()
    local scroll=_G.MegaMacro_FrameScrollFrame
    return {
        editor=edit and edit:GetName() or nil,
        enabled=edit and edit:IsEnabled() or false,
        mouseEnabled=edit and edit:IsMouseEnabled() or false,
        visible=edit and edit:IsVisible() or false,
        scrollRange=scroll and scroll:GetVerticalScrollRange() or 0,
        syntax=edit and edit.__BPMMSyntaxText
            and edit.__BPMMSyntaxText:GetText() or nil,
    }
end

local function PrintDebugStatus()
    local edit=GetEditor()
    if not edit then
        DebugLog("STATUS editor=nil")
        return
    end

    DebugLog(
        "STATUS v%s focus=%s enabled=%s visible=%s cursor=%d mouse=%s",
        Editor.VERSION,tostring(edit:HasFocus()),tostring(edit:IsEnabled()),
        tostring(edit:IsVisible()),edit:GetCursorPosition() or -1,
        DebugMouseFocusLabel()
    )
    DebugLog(
        "GESTURE down=%d up=%d updates=%d apply=%d range=%d..%d mirror=%d releaseMissed=%s",
        debugState.downEvents,debugState.upEvents,debugState.dragUpdates,
        debugState.applyCalls,selection.anchor or -1,selection.current or -1,
        CountShownSelectionHighlights(),tostring(debugState.releaseMissed)
    )
    local scroll=edit:GetParent()
    local syntax=edit.__BPMMSyntaxText
    local maxLines=syntax and syntax.GetMaxLines and syntax:GetMaxLines()
        or "unavailable"
    DebugLog(
        "LAYOUT edit=%.0fx%.0f scroll=%.0fx%.0f syntax=%.0fx%.0f visualLines=%d maxLines=%s bytes=%d",
        tonumber(edit:GetWidth()) or 0,tonumber(edit:GetHeight()) or 0,
        scroll and (tonumber(scroll:GetWidth()) or 0) or 0,
        scroll and (tonumber(scroll:GetHeight()) or 0) or 0,
        syntax and (tonumber(syntax:GetWidth()) or 0) or 0,
        syntax and (tonumber(syntax:GetHeight()) or 0) or 0,
        #BuildVisualLines(edit,edit:GetText() or ""),tostring(maxLines),
        #(edit:GetText() or "")
    )
    local nativeText=GetTextRegion(edit)
    local measure=EnsureMeasurementText(edit)
    local _,editSize=edit:GetFont()
    local nativeSize
    if nativeText then _,nativeSize=nativeText:GetFont() end
    local syntaxSize
    if syntax then _,syntaxSize=syntax:GetFont() end
    local _,measureSize=measure:GetFont()
    local proxy=scroll and scroll.__BPMMEditorMouseProxy
    DebugLog(
        "METRICS font edit=%.1f native=%.1f syntax=%.1f measure=%.1f advance=%.2f scale edit=%.3f syntax=%.3f measure=%.3f proxy=%s proxyMouse=%s",
        tonumber(editSize) or -1,tonumber(nativeSize) or -1,
        tonumber(syntaxSize) or -1,tonumber(measureSize) or -1,
        GetEditorLineHeight(edit),
        tonumber(edit:GetEffectiveScale()) or -1,
        syntax and (tonumber(syntax:GetEffectiveScale()) or -1) or -1,
        tonumber(measure:GetEffectiveScale()) or -1,
        DebugFrameLabel(proxy),
        tostring(proxy and proxy:IsMouseEnabled() or false)
    )
    DebugLog(
        "CARET focus=%s positioned=%s lit=%s elapsed=%.2f native=(%.1f,%.1f %.1fx%.1f) measuredX=%.1f visual=(%.1f,%.1f x%.1f) scale=%.3f lineShown=%s",
        tostring(edit:HasFocus()),tostring(caret.positioned),tostring(caret.lit),
        tonumber(caret.elapsed) or 0,tonumber(caret.x) or -1,
        tonumber(caret.y) or -1,tonumber(caret.width) or -1,
        tonumber(caret.height) or -1,
        tonumber(caret.measuredX) or -1,
        tonumber(caret.lineX) or -1,tonumber(caret.lineY) or -1,
        tonumber(caret.lineHeight) or -1,
        tonumber(caret.effectiveScale) or -1,
        tostring(caret.line and caret.line:IsShown() or false)
    )
end

SLASH_BETTERBIND_EDITOR_DEBUG1="/bbedebug"
SlashCmdList.BETTERBIND_EDITOR_DEBUG=function(message)
    local command=string.lower(Trim(message))
    if command=="off" then
        if debugState.enabled then
            DebugLog("diagnostics disabled")
        end
        debugState.enabled=false
        return
    end

    if command=="on" or command=="" then
        debugState.enabled=true
        ResetDebugGesture()
        DebugLog(
            "diagnostics enabled (editor v%s); drag once, then run /bbedebug status",
            Editor.VERSION
        )
        return
    end

    if command=="status" then
        if not debugState.enabled then
            debugState.enabled=true
            DebugLog("diagnostics enabled for status")
        end
        PrintDebugStatus()
        return
    end

    debugState.enabled=true
    DebugLog("usage: /bbedebug on | status | off")
end

function Editor.FormatMacroText(source)
    return FormatMacroText(source or "")
end

local function QueueApply()
    C_Timer.After(0,Editor.Apply)
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("SPELL_DATA_LOAD_RESULT")
events:SetScript("OnEvent",function(_,eventName,eventValue)
    if eventName=="PLAYER_LOGIN" then
        CollectSlashCommands()
        QueueApply()
        C_Timer.After(.5,Editor.Apply)
        C_Timer.After(1.4,Editor.Apply)
    elseif eventName=="GET_ITEM_INFO_RECEIVED" then
        local edit=GetEditor()
        if edit and edit:IsVisible() then
            C_Timer.After(0,function()
                if edit:IsVisible() then RefreshSyntax(edit) end
            end)
        end
    elseif eventName=="SPELL_DATA_LOAD_RESULT" then
        local edit=GetEditor()
        if edit and edit:IsVisible() then
            C_Timer.After(0,function()
                if edit:IsVisible() then RefreshSyntax(edit) end
            end)
        end
    end
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
