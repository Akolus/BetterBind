-- BetterMacro single native EditBox editor.
--
-- The window XML creates the only text input. This module styles it, supplies
-- scroll behavior, and adds non-interactive selection feedback without placing
-- another mouse-enabled layer over the EditBox.

local Editor={}
_G.BPMMBetterMacroEditor=Editor

local WHITE="Interface\\Buttons\\WHITE8x8"
local BG={.075,.078,.088,1}
local BORDER={.13,.14,.16,1}
local TEXT={.90,.93,.97,1}
local HIGHLIGHT={.02,.58,.94,.55}
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
local LINE_SPACING=2
local WHEEL_LINES=3
local DOUBLE_CLICK_SECONDS=.50
local CARET_BLINK_SECONDS=.50
local CARET_WIDTH=1
local CARET_HEIGHT=20
local EDITOR_STRATA="DIALOG"
local EDITOR_FRAME_LEVEL=100

local backgroundTexture
local measurementFrame
local measurementText
local selectionHighlights={}
local rightMouseWasDown=false
local leftMouseDownX
local leftMouseDownY
local nativeLeft={
    down=false,
    edit=nil,
    anchor=nil,
    current=nil,
    fallbackAnchor=nil,
    initialCursor=nil,
    usingFallback=false,
    updatingCursor=false,
    serial=0,
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

local function Trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
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
    local numeric=tonumber(tostring(identifier or ""):match("(%d+)$"))
    if not numeric or requestedSpellData[numeric] then return end
    if C_Spell and C_Spell.RequestLoadSpellData then
        requestedSpellData[numeric]=true
        pcall(C_Spell.RequestLoadSpellData,numeric)
    end
end

local function RequestItemData(identifier)
    local numeric=tonumber(tostring(identifier or ""):match("(%d+)$"))
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
    if command=="click" then return SYNTAX_COLOR.reference end
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

local function EnsureSyntaxSurface(edit)
    local surface=edit.__BPMMSyntaxSurface
    if not surface then
        surface=CreateFrame("Frame",nil,edit:GetParent())
        surface:EnableMouse(false)
        if surface.SetMouseClickEnabled then
            surface:SetMouseClickEnabled(false)
        end
        if surface.SetMouseMotionEnabled then
            surface:SetMouseMotionEnabled(false)
        end
        edit.__BPMMSyntaxSurface=surface
    end

    surface:ClearAllPoints()
    surface:SetAllPoints(edit)
    surface:SetFrameLevel(edit:GetFrameLevel()+10)
    if surface.SetFrameStrata then surface:SetFrameStrata(EDITOR_STRATA) end
    surface:SetAlpha(1)
    surface:Show()
    return surface
end

local function EnsureSyntaxText(edit)
    local syntax=edit.__BPMMSyntaxText
    if not syntax then
        local surface=EnsureSyntaxSurface(edit)
        syntax=surface:CreateFontString(
            "MegaMacro_FrameSyntaxText","OVERLAY","GameFontHighlightSmall"
        )
        syntax:SetJustifyH("LEFT")
        syntax:SetJustifyV("TOP")
        syntax:SetWordWrap(true)
        if syntax.SetNonSpaceWrap then syntax:SetNonSpaceWrap(true) end
        if syntax.SetSpacing then syntax:SetSpacing(LINE_SPACING) end
        syntax:SetTextColor(1,1,1,1)
        edit.__BPMMSyntaxText=syntax
    end

    EnsureSyntaxSurface(edit)
    local left,right,top,bottom=edit:GetTextInsets()
    syntax:ClearAllPoints()
    syntax:SetPoint(
        "TOPLEFT",edit,"TOPLEFT",tonumber(left) or 0,-(tonumber(top) or 0)
    )
    syntax:SetPoint(
        "BOTTOMRIGHT",edit,"BOTTOMRIGHT",
        -(tonumber(right) or 0),tonumber(bottom) or 0
    )
    local path,size,flags=edit:GetFont()
    if path then syntax:SetFont(path,size,flags) end
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

local function EnsureCaret(edit)
    if caret.edit==edit and caret.mask and caret.line then return end

    EnsureSyntaxText(edit)

    local surface=EnsureSyntaxSurface(edit)
    caret.edit=edit
    caret.mask=surface:CreateTexture(nil,"OVERLAY",nil,6)
    caret.mask:SetColorTexture(unpack(BG))
    caret.line=surface:CreateTexture(nil,"OVERLAY",nil,7)
    caret.line:SetColorTexture(unpack(TEXT))
    caret.elapsed=0
    caret.lit=true
    caret.positioned=false
    caret.x,caret.y,caret.width,caret.height=nil,nil,nil,nil
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

local function PositionCaret(edit,x,y,width,height)
    EnsureCaret(edit)
    x=tonumber(x) or 0
    y=tonumber(y) or 0
    width=math.max(1,tonumber(width) or 1)
    height=math.max(1,tonumber(height) or 1)
    local moved=not caret.positioned or caret.x~=x or caret.y~=y
        or caret.width~=width or caret.height~=height
    local desiredHeight=math.max(CARET_HEIGHT,height)
    caret.mask:ClearAllPoints()
    caret.mask:SetPoint("TOPLEFT",edit,"TOPLEFT",x,y)
    caret.mask:SetSize(width,height)

    caret.line:ClearAllPoints()
    caret.line:SetPoint(
        "TOPLEFT",
        edit,
        "TOPLEFT",
        x,
        y+(desiredHeight-height)/2
    )
    caret.line:SetSize(CARET_WIDTH,desiredHeight)
    if moved then
        caret.elapsed=0
        caret.lit=true
    end
    caret.positioned=true
    caret.x,caret.y,caret.width,caret.height=x,y,width,height
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

local function EnsureMeasurementText(edit)
    if not measurementFrame then
        measurementFrame=CreateFrame("Frame",nil,UIParent)
        measurementFrame:SetSize(1,1)
        measurementFrame:SetAlpha(0)
        measurementFrame:Show()
        measurementText=measurementFrame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
        measurementText:SetWordWrap(false)
    end

    local path,size,flags=edit:GetFont()
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

local function BuildVisualLines(edit,source)
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

local function GetSelectionHighlight(edit,index)
    local texture=selectionHighlights[index]
    if not texture then
        local owner=EnsureSyntaxSurface(edit)
        texture=owner:CreateTexture(nil,"ARTWORK",nil,6)
        texture:SetColorTexture(unpack(HIGHLIGHT))
        selectionHighlights[index]=texture
    end
    texture:Show()
    return texture
end

local function ShowSelectionHighlights(edit,anchor,current)
    HideSelectionHighlights()
    if not edit or anchor==current then return end

    local first=math.min(anchor,current)
    local last=math.max(anchor,current)
    local source=edit:GetText() or ""
    local lines=BuildVisualLines(edit,source)
    local leftInset,_,topInset=edit:GetTextInsets()
    local _,fontSize=edit:GetFont()
    local lineHeight=(tonumber(fontSize) or 12)+LINE_SPACING
    local used=0

    for index,line in ipairs(lines) do
        local lineFirst=line.start
        local lineLast=line.start+#line.text
        local segmentFirst=math.max(first,lineFirst)
        local segmentLast=math.min(last,lineLast)
        local highlightNewline=segmentFirst==segmentLast
            and first<=lineLast and last>lineLast

        if segmentFirst<segmentLast or highlightNewline then
            local before=math.max(0,segmentFirst-lineFirst)
            local through=math.max(before,segmentLast-lineFirst)
            local x1=MeasureTextWidth(edit,string.sub(line.text,1,before))
            local x2=MeasureTextWidth(edit,string.sub(line.text,1,through))
            used=used+1
            local texture=GetSelectionHighlight(edit,used)
            texture:ClearAllPoints()
            texture:SetPoint(
                "TOPLEFT",
                edit,
                "TOPLEFT",
                (tonumber(leftInset) or 0)+x1,
                -(tonumber(topInset) or 0)-(index-1)*lineHeight
            )
            texture:SetSize(math.max(3,x2-x1),lineHeight)
        end
    end

    for index=used+1,#selectionHighlights do
        selectionHighlights[index]:Hide()
    end
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

local function GetMouseTextOffset(edit)
    if not edit or not GetCursorPosition then return end
    local scroll=edit:GetParent()
    if not scroll then return end
    local leftEdge,topEdge=scroll:GetLeft(),scroll:GetTop()
    if not leftEdge or not topEdge then return end

    local cursorX,cursorY=GetCursorPosition()
    local scale=edit:GetEffectiveScale()
    if not scale or scale==0 then return end
    cursorX,cursorY=cursorX/scale,cursorY/scale

    local leftInset,_,topInset=edit:GetTextInsets()
    local mouseX=cursorX-leftEdge-(tonumber(leftInset) or 0)
    local mouseY=topEdge-cursorY+(scroll:GetVerticalScroll() or 0)
        -(tonumber(topInset) or 0)

    local _,fontSize=edit:GetFont()
    local lineHeight=(tonumber(fontSize) or 12)+LINE_SPACING
    local lines=BuildVisualLines(edit,edit:GetText() or "")
    local lineIndex=math.floor(math.max(0,mouseY)/math.max(1,lineHeight))+1
    lineIndex=math.max(1,math.min(#lines,lineIndex))
    return FindOffsetInLine(edit,lines[lineIndex],mouseX)
end

local function ApplySelection(edit,anchor,current)
    if not edit then return end
    local length=#(edit:GetText() or "")
    anchor=math.max(0,math.min(length,tonumber(anchor) or 0))
    current=math.max(0,math.min(length,tonumber(current) or 0))

    edit:SetFocus()
    edit:SetCursorPosition(current)
    edit:HighlightText(math.min(anchor,current),math.max(anchor,current))
    ShowSelectionHighlights(edit,anchor,current)
    RefreshCaretVisibility(edit)
end

local function QueueSelectionReapply(edit,anchor,current,serial)
    local function Reapply()
        if selection.serial~=serial or selection.dragging
            or selection.edit~=edit or not edit:HasFocus()
        then
            return
        end
        ApplySelection(edit,anchor,current)
    end
    C_Timer.After(0,Reapply)
    C_Timer.After(.05,Reapply)
end

local function CancelSelectionGesture(clearDoubleClick)
    HideSelectionHighlights()
    nativeLeft.down=false
    nativeLeft.edit=nil
    nativeLeft.anchor=nil
    nativeLeft.current=nil
    nativeLeft.fallbackAnchor=nil
    nativeLeft.initialCursor=nil
    nativeLeft.usingFallback=false
    nativeLeft.updatingCursor=false
    nativeLeft.serial=nativeLeft.serial+1
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
    local position=GetMouseTextOffset(edit)
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
    local length=#(edit:GetText() or "")
    local position=math.max(
        0,
        math.min(length,edit:GetCursorPosition() or 0)
    )
    if nativeLeft.usingFallback and not nativeLeft.updatingCursor then
        local estimated=GetMouseTextOffset(edit)
        if estimated~=nil and estimated~=position then
            nativeLeft.updatingCursor=true
            edit:SetCursorPosition(estimated)
            nativeLeft.updatingCursor=false
            position=estimated
        end
    end
    if nativeLeft.anchor==nil then nativeLeft.anchor=position end
    nativeLeft.current=position

    selection.edit=edit
    selection.button="LeftButton"
    selection.anchor=nativeLeft.anchor
    selection.current=position
    ShowSelectionHighlights(edit,selection.anchor,selection.current)
    RefreshCaretVisibility(edit)
    return selection.anchor~=selection.current
end

local function BeginNativeLeftClick(edit)
    if GetCursorPosition then
        leftMouseDownX,leftMouseDownY=GetCursorPosition()
    else
        leftMouseDownX,leftMouseDownY=nil,nil
    end
    nativeLeft.serial=nativeLeft.serial+1
    local serial=nativeLeft.serial
    nativeLeft.down=true
    nativeLeft.edit=edit
    nativeLeft.anchor=nil
    nativeLeft.current=nil
    nativeLeft.fallbackAnchor=GetMouseTextOffset(edit)
    nativeLeft.initialCursor=edit:GetCursorPosition() or 0
    nativeLeft.usingFallback=false
    nativeLeft.updatingCursor=false

    -- OnMouseDown fires before some clients publish the new native caret.
    -- Capture it on the next UI turn if OnCursorChanged did not do so first.
    C_Timer.After(0,function()
        if nativeLeft.down and nativeLeft.edit==edit
            and nativeLeft.serial==serial and nativeLeft.anchor==nil
        then
            local published=edit:GetCursorPosition() or 0
            if published==nativeLeft.initialCursor
                and nativeLeft.fallbackAnchor~=nil
            then
                nativeLeft.usingFallback=true
                nativeLeft.anchor=nativeLeft.fallbackAnchor
                nativeLeft.current=nativeLeft.fallbackAnchor
                nativeLeft.updatingCursor=true
                edit:SetCursorPosition(nativeLeft.fallbackAnchor)
                nativeLeft.updatingCursor=false
            end
            MirrorNativeLeftSelection(edit)
        end
    end)
end

local function CompleteNativeLeftClick(edit)
    local clickTime=(GetTime and GetTime()) or 0
    local upX,upY
    if GetCursorPosition then upX,upY=GetCursorPosition() end
    local moved=leftMouseDownX and upX and (
        math.abs(upX-leftMouseDownX)>3 or math.abs(upY-leftMouseDownY)>3
    )
    local mouseUpOffset=GetMouseTextOffset(edit)
    leftMouseDownX,leftMouseDownY=nil,nil

    if nativeLeft.edit==edit then MirrorNativeLeftSelection(edit) end
    local trackedAnchor=nativeLeft.anchor
    local trackedCurrent=nativeLeft.current
    local fallbackAnchor=nativeLeft.fallbackAnchor
    local initialCursor=nativeLeft.initialCursor
    local nativeAnchor=nativeLeft.anchor or nativeLeft.fallbackAnchor
        or edit:GetCursorPosition() or 0
    local nativeCurrent=nativeLeft.current
        or (moved and mouseUpOffset) or edit:GetCursorPosition() or 0
    local fallbackRange=false
    if moved and fallbackAnchor~=nil and mouseUpOffset~=nil
        and (trackedAnchor==nil or (
            trackedAnchor==trackedCurrent and trackedAnchor==initialCursor
        ))
    then
        nativeAnchor=fallbackAnchor
        nativeCurrent=mouseUpOffset
        fallbackRange=true
    end
    if trackedAnchor~=nil and trackedCurrent~=nil
        and trackedAnchor~=trackedCurrent
    then
        moved=true
    end
    nativeLeft.down=false
    nativeLeft.edit=nil
    nativeLeft.anchor=nil
    nativeLeft.current=nil
    nativeLeft.fallbackAnchor=nil
    nativeLeft.initialCursor=nil
    nativeLeft.usingFallback=false
    nativeLeft.updatingCursor=false

    -- Mouse-up is the first point where WoW's native EditBox caret is final.
    -- Reading it one frame later retains native click/drag behavior and makes
    -- word selection use the exact rendered character rather than estimates.
    C_Timer.After(0,function()
        if not edit:IsVisible() then return end
        local position=math.max(
            0,
            math.min(#(edit:GetText() or ""),edit:GetCursorPosition() or 0)
        )
        if not moved and fallbackAnchor~=nil and initialCursor~=nil
            and position==initialCursor and fallbackAnchor~=position
        then
            position=fallbackAnchor
            edit:SetCursorPosition(position)
        end
        nativeCurrent=math.max(
            0,
            math.min(#(edit:GetText() or ""),nativeCurrent)
        )
        nativeAnchor=math.max(
            0,
            math.min(#(edit:GetText() or ""),nativeAnchor)
        )
        if moved and not fallbackRange then nativeCurrent=position end
        selection.serial=selection.serial+1
        selection.dragging=false
        selection.edit=edit
        selection.button="LeftButton"

        if moved then
            selection.anchor=nativeAnchor
            selection.current=nativeCurrent
            local serial=selection.serial
            ApplySelection(edit,nativeAnchor,nativeCurrent)
            QueueSelectionReapply(edit,nativeAnchor,nativeCurrent,serial)
            selection.lastClickTime=0
            selection.lastClickPosition=nil
            selection.lastClickButton=nil
            RefreshCaretVisibility(edit)
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
            local serial=selection.serial
            selection.lastClickTime=0
            selection.lastClickPosition=nil
            selection.lastClickButton=nil
            selection.anchor=wordStart
            selection.current=wordEnd
            ApplySelection(edit,wordStart,wordEnd)
            QueueSelectionReapply(edit,wordStart,wordEnd,serial)
        else
            HideSelectionHighlights()
            caret.elapsed=0
            caret.lit=true
            RefreshCaretVisibility(edit)
        end
    end)
end

local function EndMouseSelection(edit,button)
    if not selection.dragging or selection.edit~=edit
        or selection.button~=button
    then
        return
    end

    local position=GetMouseTextOffset(edit)
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

    local position=GetMouseTextOffset(edit)
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
            MirrorNativeLeftSelection(edit)
        end
        PollRightMouseSelection(edit)
        UpdateMouseSelection(edit)
    end)
    scroll:HookScript("OnHide",function()
        rightMouseWasDown=false
        CancelSelectionGesture(true)
    end)
end

local function UpdateScrollChild(edit)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end

    local _,fontSize=edit:GetFont()
    local lineHeight=(tonumber(fontSize) or 12)+LINE_SPACING
    local textRegion=GetTextRegion(edit)
    local measuredHeight=textRegion and textRegion:GetStringHeight() or 0
    local lineCount=edit.GetNumLines and edit:GetNumLines() or 1
    local _,_,topInset,bottomInset=edit:GetTextInsets()
    local insets=(tonumber(topInset) or 0)+(tonumber(bottomInset) or 0)+2
    local contentHeight=math.max(measuredHeight,(tonumber(lineCount) or 1)*lineHeight)+insets

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

local function ScrollEditor(edit,delta)
    if not edit then return end
    local scroll=edit:GetParent()
    if not scroll then return end

    UpdateScrollChild(edit)
    local _,fontSize=edit:GetFont()
    local step=((tonumber(fontSize) or 12)+LINE_SPACING)*WHEEL_LINES
    local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
    local current=math.max(0,scroll:GetVerticalScroll() or 0)
    local target=current-(tonumber(delta) or 0)*step
    scroll:SetVerticalScroll(math.max(0,math.min(maximum,target)))
end

local function ForwardTextChanged(self,userInput)
    CancelSelectionGesture(true)
    if type(_G.MegaMacro_TextBox_TextChanged)=="function" then
        _G.MegaMacro_TextBox_TextChanged(self,userInput)
    elseif _G.ScrollingEdit_OnTextChanged then
        ScrollingEdit_OnTextChanged(self,self:GetParent())
    end
    RefreshSyntax(self)
    MakeNativeInputTransparent(self)
    QueueScrollChildUpdate(self)
end

local function RestrictDragShellToHeader(frame)
    local shell=frame and frame.__BPMMShell
    if not shell then return end

    shell:ClearAllPoints()
    shell:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
    shell:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    shell:SetHeight(38)
    shell:SetFrameLevel(frame:GetFrameLevel()+20)
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
    edit:SetFontObject("GameFontHighlightSmall")
    -- The native selection remains functional but its opaque rendering would
    -- cover the syntax layer. Mirror it with our non-interactive textures.
    if edit.SetHighlightColor then
        edit:SetHighlightColor(HIGHLIGHT[1],HIGHLIGHT[2],HIGHLIGHT[3],0)
    end
    edit:SetTextInsets(7,7,6,6)
    if edit.SetSpacing then edit:SetSpacing(LINE_SPACING) end
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetWidth(math.max(1,scroll:GetWidth()-4))
    edit:SetAlpha(1)
    edit:SetFrameStrata(EDITOR_STRATA)
    edit:SetFrameLevel(scroll:GetFrameLevel()+1)
    edit:EnableMouse(true)
    edit:EnableMouseWheel(true)
    EnsureCaret(edit)
    RefreshSyntax(edit)
    MakeNativeInputTransparent(edit)

    -- Keep native left-click placement and drag selection. Add exact word
    -- selection after the native mouse-up, plus right-button drag selection.
    edit:SetScript("OnMouseDown",function(self,button)
        if button=="LeftButton" then
            BeginNativeLeftClick(self)
        elseif button=="RightButton" then
            -- Fallback for clients that do deliver right-button events.
            rightMouseWasDown=true
            BeginMouseSelection(self,button)
        end
    end)
    edit:SetScript("OnMouseUp",function(self,button)
        if button=="LeftButton" then
            CompleteNativeLeftClick(self)
        else
            if button=="RightButton" then rightMouseWasDown=false end
            EndMouseSelection(self,button)
        end
    end)
    edit:SetScript("OnMouseWheel",function(self,delta)
        ScrollEditor(self,delta)
    end)
    edit:SetScript("OnKeyDown",function(self,key)
        CancelSelectionGesture(true)
        if type(_G.MegaMacro_TextBox_OnKeyDown)=="function" then
            _G.MegaMacro_TextBox_OnKeyDown(self,key)
        end
    end)
    edit:SetScript("OnTextChanged",ForwardTextChanged)
    edit:SetScript("OnCursorChanged",function(self,x,y,width,height)
        if _G.ScrollingEdit_OnCursorChanged then
            ScrollingEdit_OnCursorChanged(self,x,y,width,height)
        end
        PositionCaret(self,x,y,width,height)
        MirrorNativeLeftSelection(self)
    end)
    edit:SetScript("OnUpdate",function(self,elapsed)
        UpdateCaretBlink(self,elapsed)
        if _G.ScrollingEdit_OnUpdate then
            ScrollingEdit_OnUpdate(self,elapsed,self:GetParent())
        end
    end)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained",function(self)
        caret.elapsed=0
        caret.lit=true
        RefreshCaretVisibility(self)
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,true) end
    end)
    edit:SetScript("OnEditFocusLost",function()
        CancelSelectionGesture(true)
        HideCaret()
        local frame=_G.MegaMacro_Frame
        if frame then SetEditorBorder(frame.__BPMMGoalEditorBackground,false) end
    end)

    scroll:SetScrollChild(edit)
    InstallMousePolling(scroll,edit)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        ScrollEditor(edit,delta)
    end)
end

function Editor.Apply()
    local frame=_G.MegaMacro_Frame
    local scroll=_G.MegaMacro_FrameScrollFrame
    local edit=GetEditor()
    if not frame or not scroll or not edit then return end

    RestrictDragShellToHeader(frame)

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
        requestedItemData[tonumber(eventValue) or eventValue]=nil
        local edit=GetEditor()
        if edit and edit:IsVisible() then RefreshSyntax(edit) end
    elseif eventName=="SPELL_DATA_LOAD_RESULT" then
        requestedSpellData[tonumber(eventValue) or eventValue]=nil
        local edit=GetEditor()
        if edit and edit:IsVisible() then RefreshSyntax(edit) end
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
