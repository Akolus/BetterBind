-- BetterBind standalone macro editor diagnostic.
--
-- This module intentionally owns every frame, texture, input script, and
-- saved value it uses. It does not read or modify MegaMacro_FrameText and does
-- not call the BetterMacro editor module. Toggle it with /bbb.

local Demo={}
_G.BetterBindDemoEditor=Demo

local WHITE="Interface\\Buttons\\WHITE8x8"
local COLOR={
    shell={.018,.020,.024,.99},
    header={.035,.037,.043,1},
    editor={.075,.078,.088,1},
    button={.030,.034,.040,1},
    border={.13,.14,.16,1},
    text={.90,.93,.97,1},
    muted={.62,.64,.68,1},
    blue={.02,.58,.94,1},
    red={.42,.02,.02,1},
}
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
local MAX_LETTERS=1023
local LINE_SPACING=2
local WHEEL_LINES=3
local DOUBLE_CLICK_SECONDS=.50
local CARET_BLINK_SECONDS=.50
local CARET_WIDTH=1
local CARET_HEIGHT=20

local frame
local scroll
local edit
local syntaxSurface
local syntaxText
local statusText
local caretMask
local caretLine
local caretElapsed=0
local caretLit=true
local caretPositioned=false
local rightMouseWasDown=false
local loadingSavedText=false
local leftMouseDownX
local leftMouseDownY
local requestedItemData={}
local requestedSpellData={}

local selection={
    dragging=false,
    button=nil,
    anchor=0,
    current=0,
    lastClickTime=0,
    lastClickPosition=nil,
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

local function Backdrop(target,bg,border)
    target:SetBackdrop({
        bgFile=WHITE,
        edgeFile=WHITE,
        edgeSize=1,
    })
    target:SetBackdropColor(unpack(bg or COLOR.shell))
    target:SetBackdropBorderColor(unpack(border or COLOR.border))
end

local function SetFontSize(region,size)
    if not region or not region.GetFont or not region.SetFont then return end
    local path,_,flags=region:GetFont()
    if path then region:SetFont(path,size,flags) end
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

local function AddSlashCommand(command)
    if type(command)~="string" or string.sub(command,1,1)~="/" then return end
    local name=string.lower(string.match(command,"^/([^%s]+)") or "")
    if name~="" then KNOWN_COMMANDS[name]=true end
end

local function CollectSlashCommands()
    for globalName,value in pairs(_G) do
        if type(globalName)=="string" and string.match(globalName,"^SLASH_") then
            AddSlashCommand(value)
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

local function FormatCommandLine(line,prefixLength)
    local prefix=string.sub(line,1,prefixLength or 0)
    local commandStart=(prefixLength or 0)+1
    local marker=string.sub(line,commandStart,commandStart)
    local nameStart=commandStart+1
    local command=string.match(string.sub(line,nameStart),"^([%w_]+)")
    if not command then return Paint(line,SYNTAX_COLOR.error) end

    local lowerCommand=string.lower(command)
    local bodyStart=nameStart+#command
    local body=string.sub(line,bodyStart)
    local commandColour=KNOWN_COMMANDS[lowerCommand]
        and SYNTAX_COLOR.command or SYNTAX_COLOR.error
    return EscapeDisplayText(prefix)
        ..Paint(marker,SYNTAX_COLOR.syntax)
        ..Paint(command,commandColour)
        ..FormatCommandBody(body,lowerCommand)
end

local function FormatDirectiveLine(line,prefixLength)
    local prefix=string.sub(line,1,prefixLength or 0)
    local start=(prefixLength or 0)+1
    local directive=string.match(string.sub(line,start+1),"^([%w_]+)")
    if not directive then return Paint(line,SYNTAX_COLOR.comment) end
    local lower=string.lower(directive)
    if lower~="show" and lower~="showtooltip" and lower~="showicon" then
        return EscapeDisplayText(prefix)..Paint(
            string.sub(line,start),SYNTAX_COLOR.comment
        )
    end
    local body=string.sub(line,start+1+#directive)
    return EscapeDisplayText(prefix)
        ..Paint("#",SYNTAX_COLOR.syntax)
        ..Paint(directive,SYNTAX_COLOR.command)
        ..FormatCommandBody(body,"cast")
end

local function FormatLine(line)
    local prefix=string.match(line,"^(%s*)") or ""
    local marker=string.sub(line,#prefix+1,#prefix+1)
    if marker=="/" then return FormatCommandLine(line,#prefix) end
    if marker=="#" then return FormatDirectiveLine(line,#prefix) end
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

local function RefreshSyntax()
    if syntaxText and edit then
        syntaxText:SetText(FormatMacroText(edit:GetText() or ""))
    end
end

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

local measurementFrame
local measurementText

local function EnsureMeasurementText()
    if not measurementFrame then
        measurementFrame=CreateFrame("Frame",nil,UIParent)
        measurementFrame:SetSize(1,1)
        measurementFrame:SetAlpha(0)
        measurementFrame:Show()
        measurementText=measurementFrame:CreateFontString(
            nil,"ARTWORK","GameFontHighlightSmall"
        )
        measurementText:SetWordWrap(false)
    end
    local path,size,flags=edit:GetFont()
    if path then measurementText:SetFont(path,size,flags) end
    return measurementText
end

local function MeasureTextWidth(text)
    local measure=EnsureMeasurementText()
    measure:SetText(text or "")
    return measure:GetStringWidth() or 0
end

local function FindFittingOffset(text,maximumWidth)
    local offset=0
    local fitting=0
    while offset<#text do
        offset=NextCharacterBoundary(text,offset)
        if MeasureTextWidth(string.sub(text,1,offset))>maximumWidth then break end
        fitting=offset
    end
    if fitting==0 and #text>0 then fitting=NextCharacterBoundary(text,0) end
    return fitting
end

local function AddWrappedLine(lines,line,lineStart,maximumWidth)
    if line=="" then
        lines[#lines+1]={text="",start=lineStart}
        return
    end

    local consumed=0
    while consumed<#line do
        local remaining=string.sub(line,consumed+1)
        local fitting=FindFittingOffset(remaining,maximumWidth)
        if fitting>=#remaining then
            lines[#lines+1]={text=remaining,start=lineStart+consumed}
            return
        end

        local prefix=string.sub(remaining,1,fitting)
        local whitespace
        for position in string.gmatch(prefix,"()%s+") do whitespace=position end
        if whitespace and whitespace>1 then fitting=whitespace end
        lines[#lines+1]={
            text=string.sub(remaining,1,fitting),
            start=lineStart+consumed,
        }
        consumed=consumed+fitting
    end
end

local function BuildVisualLines(source)
    local left,right=edit:GetTextInsets()
    local maximumWidth=math.max(
        1,
        edit:GetWidth()-(tonumber(left) or 0)-(tonumber(right) or 0)
    )
    local lines={}
    local lineStart=1

    while true do
        local newline=string.find(source,"\n",lineStart,true)
        local lineEnd=newline and newline-1 or #source
        AddWrappedLine(
            lines,
            string.sub(source,lineStart,lineEnd),
            lineStart-1,
            maximumWidth
        )
        if not newline then break end
        lineStart=newline+1
        if lineStart>#source then
            lines[#lines+1]={text="",start=#source}
            break
        end
    end

    if #lines==0 then lines[1]={text="",start=0} end
    return lines
end

local function FindOffsetInLine(line,mouseX)
    if mouseX<=0 or line.text=="" then return line.start end

    local previousOffset=0
    local previousWidth=0
    local offset=0
    while offset<#line.text do
        offset=NextCharacterBoundary(line.text,offset)
        local width=MeasureTextWidth(string.sub(line.text,1,offset))
        if mouseX<(previousWidth+width)/2 then
            return line.start+previousOffset
        end
        previousOffset=offset
        previousWidth=width
    end
    return line.start+#line.text
end

local function GetMouseTextOffset()
    if not edit or not scroll or not GetCursorPosition then return end
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
    local lines=BuildVisualLines(edit:GetText() or "")
    local lineIndex=math.floor(math.max(0,mouseY)/math.max(1,lineHeight))+1
    lineIndex=math.max(1,math.min(#lines,lineIndex))
    return FindOffsetInLine(lines[lineIndex],mouseX)
end

local function SelectionIsVisible()
    if selection.anchor~=selection.current then return true end
    if edit and edit.GetHighlightText then
        local ok,highlighted=pcall(edit.GetHighlightText,edit)
        if ok and highlighted and highlighted~="" then return true end
    end
    return false
end

local function HideCaret()
    if caretMask then caretMask:Hide() end
    if caretLine then caretLine:Hide() end
end

local function RefreshCaret()
    if not caretPositioned or not frame:IsShown() or not edit:HasFocus()
        or SelectionIsVisible()
    then
        HideCaret()
        return
    end
    caretMask:Show()
    if caretLit then caretLine:Show() else caretLine:Hide() end
end

local function PositionCaret(x,y,width,height)
    x=tonumber(x) or 0
    y=tonumber(y) or 0
    width=math.max(2,tonumber(width) or 0)
    height=math.max(1,tonumber(height) or 1)
    local desiredHeight=math.max(CARET_HEIGHT,height)

    -- OnCursorChanged already reports the rendered cursor coordinates. Do not
    -- add the EditBox insets a second time; doing so visibly shifts the caret
    -- away from the clicked character.
    caretMask:ClearAllPoints()
    caretMask:SetPoint("TOPLEFT",edit,"TOPLEFT",x,y)
    caretMask:SetSize(width,height)

    caretLine:ClearAllPoints()
    caretLine:SetPoint(
        "TOPLEFT",edit,"TOPLEFT",x,y+(desiredHeight-height)/2
    )
    caretLine:SetSize(CARET_WIDTH,desiredHeight)
    caretElapsed=0
    caretLit=true
    caretPositioned=true
    RefreshCaret()
end

local function ResetCaretBlink()
    caretElapsed=0
    caretLit=true
    RefreshCaret()
end

local function ApplySelection(anchor,current)
    local length=#(edit:GetText() or "")
    anchor=math.max(0,math.min(length,tonumber(anchor) or 0))
    current=math.max(0,math.min(length,tonumber(current) or 0))
    selection.anchor=anchor
    selection.current=current
    edit:SetFocus()
    edit:SetCursorPosition(current)
    edit:HighlightText(math.min(anchor,current),math.max(anchor,current))
    RefreshCaret()
end

local function QueueSelectionReapply(anchor,current,serial)
    local function Reapply()
        if selection.serial~=serial or selection.dragging
            or not edit:HasFocus()
        then
            return
        end
        ApplySelection(anchor,current)
    end
    C_Timer.After(0,Reapply)
    C_Timer.After(.05,Reapply)
end

local function CancelSelection(clearDoubleClick)
    selection.dragging=false
    selection.button=nil
    selection.anchor=edit and edit:GetCursorPosition() or 0
    selection.current=selection.anchor
    selection.serial=selection.serial+1
    if clearDoubleClick then
        selection.lastClickTime=0
        selection.lastClickPosition=nil
    end
    RefreshCaret()
end

local function BeginLeftMouse()
    if GetCursorPosition then
        leftMouseDownX,leftMouseDownY=GetCursorPosition()
    else
        leftMouseDownX,leftMouseDownY=nil,nil
    end
end

local function CompleteLeftMouse()
    local clickTime=(GetTime and GetTime()) or 0
    local upX,upY
    if GetCursorPosition then upX,upY=GetCursorPosition() end
    local moved=leftMouseDownX and upX and (
        math.abs(upX-leftMouseDownX)>3 or math.abs(upY-leftMouseDownY)>3
    )
    leftMouseDownX,leftMouseDownY=nil,nil

    C_Timer.After(0,function()
        if not edit:IsVisible() then return end
        local position=math.max(
            0,
            math.min(#(edit:GetText() or ""),edit:GetCursorPosition() or 0)
        )
        selection.serial=selection.serial+1
        selection.dragging=false
        selection.button="LeftButton"

        if moved then
            selection.anchor=position
            selection.current=position
            selection.lastClickTime=0
            selection.lastClickPosition=nil
            RefreshCaret()
            return
        end

        local source=edit:GetText() or ""
        local wordStart,wordEnd=FindWordBounds(source,position)
        local lastPosition=selection.lastClickPosition
        local isDoubleClick=wordStart and wordEnd and lastPosition~=nil
            and clickTime-selection.lastClickTime<=DOUBLE_CLICK_SECONDS
            and lastPosition>=wordStart and lastPosition<=wordEnd

        selection.lastClickTime=clickTime
        selection.lastClickPosition=position
        selection.anchor=position
        selection.current=position

        if isDoubleClick then
            local serial=selection.serial
            selection.lastClickTime=0
            selection.lastClickPosition=nil
            ApplySelection(wordStart,wordEnd)
            QueueSelectionReapply(wordStart,wordEnd,serial)
        else
            ResetCaretBlink()
        end
    end)
end

local function BeginRightSelection()
    local position=GetMouseTextOffset()
    if position==nil then return end
    selection.serial=selection.serial+1
    selection.dragging=true
    selection.button="RightButton"
    selection.anchor=position
    selection.current=position
    selection.lastClickPosition=nil
    ApplySelection(position,position)
end

local function EndSelection(button)
    if not selection.dragging or selection.button~=button then return end
    local position=GetMouseTextOffset()
    if position~=nil then selection.current=position end
    selection.dragging=false
    ApplySelection(selection.anchor,selection.current)
    QueueSelectionReapply(
        selection.anchor,selection.current,selection.serial
    )
    if SelectionIsVisible() then selection.lastClickPosition=nil end
end

local function UpdateSelection()
    if not selection.dragging then return end
    if not (IsMouseButtonDown and IsMouseButtonDown(selection.button)) then
        EndSelection(selection.button)
        return
    end
    local position=GetMouseTextOffset()
    if position==nil or position==selection.current then return end
    selection.current=position
    ApplySelection(selection.anchor,selection.current)
end

local function CursorInside(target)
    if not target or not GetCursorPosition then return false end
    local left,right=target:GetLeft(),target:GetRight()
    local top,bottom=target:GetTop(),target:GetBottom()
    if not left or not right or not top or not bottom then return false end
    local x,y=GetCursorPosition()
    local scale=target:GetEffectiveScale()
    if not scale or scale==0 then return false end
    x,y=x/scale,y/scale
    return x>=left and x<=right and y>=bottom and y<=top
end

local function PollRightSelection()
    if not IsMouseButtonDown then return end
    local isDown=IsMouseButtonDown("RightButton") and true or false
    if isDown and not rightMouseWasDown and CursorInside(scroll) then
        BeginRightSelection()
    elseif not isDown and rightMouseWasDown
        and selection.dragging and selection.button=="RightButton"
    then
        EndSelection("RightButton")
    end
    rightMouseWasDown=isDown
end

local function GetTextRegion()
    for _,region in ipairs({edit:GetRegions()}) do
        if region and region.GetObjectType
            and region:GetObjectType()=="FontString"
        then
            return region
        end
    end
end

local function UpdateScrollBounds()
    local _,fontSize=edit:GetFont()
    local lineHeight=(tonumber(fontSize) or 12)+LINE_SPACING
    local region=GetTextRegion()
    local measuredHeight=region and region:GetStringHeight() or 0
    local lineCount=edit.GetNumLines and edit:GetNumLines() or 1
    local _,_,topInset,bottomInset=edit:GetTextInsets()
    local contentHeight=math.max(
        measuredHeight,
        (tonumber(lineCount) or 1)*lineHeight
    )+(tonumber(topInset) or 0)+(tonumber(bottomInset) or 0)+2

    edit:SetWidth(math.max(1,scroll:GetWidth()))
    edit:SetHeight(math.max(scroll:GetHeight(),math.ceil(contentHeight)))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
    if (scroll:GetVerticalScroll() or 0)>maximum then
        scroll:SetVerticalScroll(maximum)
    end
end

local function QueueScrollBoundsUpdate()
    C_Timer.After(0,function()
        if edit and frame and frame:IsShown() then UpdateScrollBounds() end
    end)
end

local function ScrollByWheel(delta)
    UpdateScrollBounds()
    local _,fontSize=edit:GetFont()
    local step=((tonumber(fontSize) or 12)+LINE_SPACING)*WHEEL_LINES
    local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
    local current=math.max(0,scroll:GetVerticalScroll() or 0)
    local target=current-(tonumber(delta) or 0)*step
    scroll:SetVerticalScroll(math.max(0,math.min(maximum,target)))
end

local function UpdateStatus()
    if not statusText or not edit then return end
    local count=edit:GetNumLetters()
    statusText:SetFormattedText(
        "%d / %d characters  •  |c%sSpell|r  •  |c%sItem|r  •  Draft saves automatically",
        count,
        MAX_LETTERS,
        SYNTAX_COLOR.spell,
        SYNTAX_COLOR.item
    )
end

local function SaveDraft()
    if loadingSavedText or not edit then return end
    _G.BetterBindDemoData=_G.BetterBindDemoData or {}
    BetterBindDemoData.text=edit:GetText() or ""
end

local function SavePosition()
    _G.BetterBindDemoData=_G.BetterBindDemoData or {}
    local point,_,relativePoint,x,y=frame:GetPoint(1)
    BetterBindDemoData.position={
        point=point,
        relativePoint=relativePoint,
        x=x,
        y=y,
    }
end

local function RestorePosition()
    local position=_G.BetterBindDemoData and BetterBindDemoData.position
    if not position then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or position.point or "CENTER",
        tonumber(position.x) or 0,
        tonumber(position.y) or 0
    )
end

local function StyleButton(button,label,danger)
    for _,region in ipairs({button:GetRegions()}) do
        if region and region.GetObjectType
            and region:GetObjectType()=="Texture"
        then
            if region.SetTexture then region:SetTexture(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
    button:SetNormalFontObject("GameFontHighlight")
    button:SetText(label)
    local background=button:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(danger and COLOR.red or COLOR.button))
    local border=CreateFrame("Frame",nil,button,"BackdropTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(button:GetFrameLevel()+1)
    border:EnableMouse(false)
    border:SetBackdrop({edgeFile=WHITE,edgeSize=1})
    border:SetBackdropBorderColor(unpack(COLOR.border))
    button.__DemoBackground=background
    button.__DemoBorder=border
    button:HookScript("OnEnter",function(self)
        self.__DemoBorder:SetBackdropBorderColor(unpack(COLOR.blue))
    end)
    button:HookScript("OnLeave",function(self)
        self.__DemoBorder:SetBackdropBorderColor(unpack(COLOR.border))
    end)
end

local function CreateCloseButton()
    local button=CreateFrame("Button","BetterBindDemoEditorCloseButton",frame)
    button:SetSize(20,20)
    button:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-6,-6)
    button:SetFrameLevel(frame:GetFrameLevel()+30)

    local art=CreateFrame("Frame",nil,button,"BackdropTemplate")
    art:SetAllPoints()
    art:SetFrameLevel(button:GetFrameLevel()+1)
    art:EnableMouse(false)
    Backdrop(art,{.055,.055,.065,.98},{0,0,0,1})
    local line1=art:CreateTexture(nil,"OVERLAY")
    line1:SetTexture(WHITE)
    line1:SetSize(12,1.4)
    line1:SetPoint("CENTER")
    line1:SetRotation(math.rad(45))
    line1:SetVertexColor(.88,.88,.90,1)
    local line2=art:CreateTexture(nil,"OVERLAY")
    line2:SetTexture(WHITE)
    line2:SetSize(12,1.4)
    line2:SetPoint("CENTER")
    line2:SetRotation(math.rad(-45))
    line2:SetVertexColor(.88,.88,.90,1)

    button:SetScript("OnClick",function() frame:Hide() end)
    button:SetScript("OnEnter",function()
        art:SetBackdropColor(.14,.045,.045,1)
        art:SetBackdropBorderColor(.45,.08,.08,1)
        line1:SetVertexColor(1,.45,.45,1)
        line2:SetVertexColor(1,.45,.45,1)
    end)
    button:SetScript("OnLeave",function()
        art:SetBackdropColor(.055,.055,.065,.98)
        art:SetBackdropBorderColor(0,0,0,1)
        line1:SetVertexColor(.88,.88,.90,1)
        line2:SetVertexColor(.88,.88,.90,1)
    end)
end

local function CreateWindow()
    frame=CreateFrame(
        "Frame","BetterBindDemoEditorFrame",UIParent,"BackdropTemplate"
    )
    frame:SetSize(720,470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(40)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    Backdrop(frame,COLOR.shell,COLOR.border)

    local headerTexture=frame:CreateTexture(nil,"BACKGROUND")
    headerTexture:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
    headerTexture:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1)
    headerTexture:SetHeight(31)
    headerTexture:SetColorTexture(unpack(COLOR.header))

    local title=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    title:SetPoint("TOP",frame,"TOP",0,-9)
    title:SetText("BetterBind Standalone Macro Editor")
    title:SetTextColor(unpack(COLOR.text))
    SetFontSize(title,13)

    local drag=CreateFrame("Frame",nil,frame)
    drag:SetPoint("TOPLEFT",frame,"TOPLEFT",4,-4)
    drag:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-30,-4)
    drag:SetHeight(24)
    drag:SetFrameLevel(frame:GetFrameLevel()+20)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function()
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop",function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)

    CreateCloseButton()

    local description=frame:CreateFontString(
        nil,"OVERLAY","GameFontDisableSmall"
    )
    description:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-47)
    description:SetText(
        "Independent test editor — no BetterMacro frames or handlers are used."
    )
    description:SetTextColor(unpack(COLOR.muted))

    local label=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-70)
    label:SetText("Enter Macro Commands:")
    label:SetTextColor(unpack(COLOR.text))

    scroll=CreateFrame(
        "ScrollFrame","BetterBindDemoEditorScrollFrame",frame
    )
    scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-88)
    scroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,66)
    scroll:SetFrameLevel(frame:GetFrameLevel()+5)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end

    local editorBackground=scroll:CreateTexture(nil,"BACKGROUND")
    editorBackground:SetAllPoints()
    editorBackground:SetColorTexture(unpack(COLOR.editor))

    edit=CreateFrame(
        "EditBox","BetterBindDemoEditorText",scroll
    )
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(MAX_LETTERS)
    if edit.SetCountInvisibleLetters then edit:SetCountInvisibleLetters(true) end
    if edit.SetBlinkSpeed then edit:SetBlinkSpeed(CARET_BLINK_SECONDS) end
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetHighlightColor(COLOR.blue[1],COLOR.blue[2],COLOR.blue[3],.55)
    edit:SetTextInsets(7,7,6,6)
    if edit.SetSpacing then edit:SetSpacing(LINE_SPACING) end
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetWidth(684)
    edit:SetHeight(316)
    edit:EnableMouse(true)
    edit:EnableMouseWheel(true)
    scroll:SetScrollChild(edit)

    syntaxSurface=CreateFrame("Frame",nil,edit)
    syntaxSurface:SetAllPoints(edit)
    syntaxSurface:SetFrameLevel(edit:GetFrameLevel()+10)
    syntaxSurface:EnableMouse(false)
    if syntaxSurface.SetMouseMotionEnabled then
        syntaxSurface:SetMouseMotionEnabled(false)
    end

    syntaxText=syntaxSurface:CreateFontString(
        "BetterBindDemoEditorSyntaxText","OVERLAY","GameFontHighlightSmall"
    )
    syntaxText:SetPoint("TOPLEFT",syntaxSurface,"TOPLEFT",7,-6)
    syntaxText:SetPoint("BOTTOMRIGHT",syntaxSurface,"BOTTOMRIGHT",-7,6)
    syntaxText:SetJustifyH("LEFT")
    syntaxText:SetJustifyV("TOP")
    syntaxText:SetWordWrap(true)
    if syntaxText.SetNonSpaceWrap then syntaxText:SetNonSpaceWrap(true) end
    if syntaxText.SetSpacing then syntaxText:SetSpacing(LINE_SPACING) end
    syntaxText:SetTextColor(1,1,1,1)

    caretMask=syntaxSurface:CreateTexture(nil,"OVERLAY")
    caretMask:SetColorTexture(unpack(COLOR.editor))
    caretMask:Hide()
    caretLine=syntaxSurface:CreateTexture(nil,"OVERLAY")
    caretLine:SetColorTexture(unpack(COLOR.text))
    caretLine:Hide()

    -- Keep the native EditBox as the only input target. Its glyph/caret layer
    -- becomes transparent only after the higher, mouse-disabled syntax
    -- surface and one-pixel caret have been created successfully.
    edit:SetTextColor(COLOR.text[1],COLOR.text[2],COLOR.text[3],0)

    edit:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then BeginLeftMouse() end
    end)
    edit:SetScript("OnMouseUp",function(_,button)
        if button=="LeftButton" then
            CompleteLeftMouse()
        else
            EndSelection(button)
        end
    end)
    edit:SetScript("OnMouseWheel",function(_,delta)
        ScrollByWheel(delta)
    end)
    edit:SetScript("OnCursorChanged",function(_,x,y,width,height)
        PositionCaret(x,y,width,height)
        local cursorTop=-y
        local cursorBottom=cursorTop+(tonumber(height) or 0)
        local viewTop=scroll:GetVerticalScroll() or 0
        local viewBottom=viewTop+scroll:GetHeight()
        if cursorTop<viewTop then
            scroll:SetVerticalScroll(math.max(0,cursorTop))
        elseif cursorBottom>viewBottom then
            local maximum=math.max(0,scroll:GetVerticalScrollRange() or 0)
            scroll:SetVerticalScroll(
                math.min(maximum,cursorBottom-scroll:GetHeight())
            )
        end
    end)
    edit:SetScript("OnUpdate",function(_,elapsed)
        if not edit:HasFocus() or SelectionIsVisible() then
            HideCaret()
            return
        end
        caretElapsed=caretElapsed+(tonumber(elapsed) or 0)
        if caretElapsed>=CARET_BLINK_SECONDS then
            caretElapsed=caretElapsed%CARET_BLINK_SECONDS
            caretLit=not caretLit
        end
        RefreshCaret()
    end)
    edit:SetScript("OnTextChanged",function()
        CancelSelection(true)
        SaveDraft()
        RefreshSyntax()
        UpdateStatus()
        QueueScrollBoundsUpdate()
    end)
    edit:SetScript("OnKeyDown",function()
        CancelSelection(true)
    end)
    edit:SetScript("OnEscapePressed",function() edit:ClearFocus() end)
    edit:SetScript("OnEditFocusGained",function()
        ResetCaretBlink()
    end)
    edit:SetScript("OnEditFocusLost",function()
        CancelSelection(true)
        HideCaret()
    end)

    scroll:SetScript("OnMouseWheel",function(_,delta)
        ScrollByWheel(delta)
    end)
    scroll:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then
            edit:SetFocus()
            local position=GetMouseTextOffset()
            if position~=nil then
                edit:SetCursorPosition(position)
                ApplySelection(position,position)
            end
        end
    end)
    scroll:SetScript("OnUpdate",function()
        PollRightSelection()
        UpdateSelection()
    end)

    statusText=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",18,40)
    statusText:SetTextColor(unpack(COLOR.muted))

    local instructions=frame:CreateFontString(
        nil,"OVERLAY","GameFontDisableSmall"
    )
    instructions:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",18,19)
    instructions:SetText(
        "Double-click: select word   •   Right-drag: select text   •   Wheel: scroll"
    )
    instructions:SetTextColor(unpack(COLOR.muted))

    local clear=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    clear:SetSize(86,30)
    clear:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,18)
    StyleButton(clear,"Clear",true)
    clear:SetScript("OnClick",function()
        edit:SetText("")
        edit:SetFocus()
        edit:SetCursorPosition(0)
    end)

    frame:SetScript("OnShow",function()
        rightMouseWasDown=false
        RefreshSyntax()
        UpdateScrollBounds()
        UpdateStatus()
        C_Timer.After(0,function()
            if frame:IsShown() then
                edit:SetFocus()
                edit:SetCursorPosition(#(edit:GetText() or ""))
            end
        end)
    end)
    frame:SetScript("OnHide",function()
        rightMouseWasDown=false
        CancelSelection(true)
        HideCaret()
        SaveDraft()
    end)

    if UISpecialFrames then
        table.insert(UISpecialFrames,"BetterBindDemoEditorFrame")
    end
end

function Demo.Show()
    if not frame then CreateWindow() end
    frame:Show()
    frame:Raise()
end

function Demo.Hide()
    if frame then frame:Hide() end
end

function Demo.Toggle()
    if not frame then CreateWindow() end
    if frame:IsShown() then frame:Hide() else Demo.Show() end
end

function Demo.GetStatus()
    return {
        shown=frame and frame:IsShown() or false,
        editor=edit and edit:GetName() or nil,
        textLength=edit and #(edit:GetText() or "") or 0,
        scrollRange=scroll and scroll:GetVerticalScrollRange() or 0,
        syntax=syntaxText and syntaxText:GetText() or nil,
        independent=true,
    }
end

function Demo.FormatMacroText(source)
    return FormatMacroText(source or "")
end

SLASH_BETTERBIND_DEMO_EDITOR1="/bbb"
SlashCmdList.BETTERBIND_DEMO_EDITOR=function()
    Demo.Toggle()
end

local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("SPELL_DATA_LOAD_RESULT")
events:SetScript("OnEvent",function(_,eventName,eventValue)
    if eventName=="ADDON_LOADED" and eventValue=="BetterBind" then
        _G.BetterBindDemoData=_G.BetterBindDemoData or {}
        CollectSlashCommands()
        if not frame then CreateWindow() end
        RestorePosition()
        loadingSavedText=true
        edit:SetText(BetterBindDemoData.text or "")
        loadingSavedText=false
        UpdateStatus()
        UpdateScrollBounds()
        RefreshSyntax()
    elseif eventName=="GET_ITEM_INFO_RECEIVED" then
        requestedItemData[tonumber(eventValue) or eventValue]=nil
        if frame and frame:IsShown() then RefreshSyntax() end
    elseif eventName=="SPELL_DATA_LOAD_RESULT" then
        requestedSpellData[tonumber(eventValue) or eventValue]=nil
        if frame and frame:IsShown() then RefreshSyntax() end
    elseif eventName=="PLAYER_LOGOUT" then
        SaveDraft()
        if frame then SavePosition() end
    end
end)
