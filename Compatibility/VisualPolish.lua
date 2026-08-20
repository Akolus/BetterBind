-- BindPad + MegaMacro visual polish
-- No functional/storage changes.

local C={
    bg={.028,.032,.038,1},
    hover={.050,.058,.068,1},
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
    muted={.62,.65,.69,1},
}

local function RestoreTabLabels()
    if _G.BindPadFrame then
        for i=1,4 do
            local tab=_G["BindPadFrameTab"..i]
            if tab then
                local fs=tab:GetFontString()
                if fs then
                    fs:Show()
                    fs:SetAlpha(1)
                    fs:SetTextColor(unpack(C.text))
                end
            end
        end
    end

    if _G.MegaMacro_Frame then
        for i=1,6 do
            local tab=_G["MegaMacro_FrameTab"..i]
            if tab then
                local fs=tab:GetFontString()
                if fs then
                    fs:Show()
                    fs:SetAlpha(1)
                    fs:SetTextColor(unpack(C.text))
                end
            end
        end
    end
end

local function PolishTitles()
    if _G.BindPadFrame and BindPadFrame.__BPMM81Title then
        local t=BindPadFrame.__BPMM81Title
        t:Show(); t:SetAlpha(1); t:SetText("BetterBind"); t:SetTextColor(unpack(C.text))
    end
    if _G.MegaMacro_Frame and MegaMacro_Frame.__BPMM81Title then
        local t=MegaMacro_Frame.__BPMM81Title
        t:Show(); t:SetAlpha(1); t:SetText("BetterMacro"); t:SetTextColor(unpack(C.text))
    end
end

local function GetProfiles()
    local out={}
    if not _G.BindPadFrame then return out end
    for _,child in ipairs({BindPadFrame:GetChildren()}) do
        if child.__BPMM82Label then out[#out+1]=child end
    end
    table.sort(out,function(a,b)
        local ai=tonumber((a.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        local bi=tonumber((b.__BPMM82Label:GetText() or ""):match("(%d+)")) or 99
        return ai<bi
    end)
    return out
end

local function PolishProfiles()
    if not _G.BindPadFrame then return end
    local panel=BindPadFrame.__BPMM82Lower
    if not panel then return end

    local title=BindPadFrame.__BPMM82LowerTitle
    if title then
        title:Show()
        title:SetText("Specialization Profiles")
        title:SetTextColor(unpack(C.text))
        title:ClearAllPoints()
        title:SetPoint("BOTTOMLEFT",panel,"TOPLEFT",0,8)
    end

    local profiles=GetProfiles()
    local colW=52
    for i,b in ipairs(profiles) do
        if i<=5 then
            b:SetSize(38,38)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",(i-1)*colW,-14)
            if b.__BPMM82Label then
                local fs=b.__BPMM82Label
                fs:Show()
                fs:SetText("Profile "..i)
                fs:SetWidth(colW)
                fs:SetJustifyH("CENTER")
                fs:SetTextColor(unpack(C.text))
                fs:ClearAllPoints()
                fs:SetPoint("TOP",b,"BOTTOM",0,-5)
            end
        end
    end
end

local function PolishCheckButtons()
    if not _G.BindPadFrame then return end
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

    for _,txt in ipairs({"Save All Keys","Show Hotkeys"}) do
        for _,r in ipairs({BindPadFrame:GetRegions()}) do
            if r.GetText and r:GetText()==txt then
                r:SetTextColor(unpack(C.text))
            end
        end
        for _,child in ipairs({BindPadFrame:GetChildren()}) do
            for _,r in ipairs({child:GetRegions()}) do
                if r.GetText and r:GetText()==txt then
                    r:SetTextColor(unpack(C.text))
                end
            end
        end
    end
end

local function PolishMegaMacroSelectedName()
    if not _G.MegaMacro_Frame then return end

    -- Known selected macro name labels vary by build, so target yellow-looking
    -- fontstrings in the editor header zone only.
    local top=MegaMacro_Frame:GetTop()
    if not top then return end

    for _,r in ipairs({MegaMacro_Frame:GetRegions()}) do
        if r.GetObjectType and r:GetObjectType()=="FontString" then
            local rt=r:GetTop()
            if rt and rt<top-220 and rt>top-380 then
                local rr,gg,bb=r:GetTextColor()
                if rr>.7 and gg>.55 and bb<.3 then
                    r:SetTextColor(unpack(C.text))
                end
            end
        end
    end
end

local function PolishFooter()
    if not _G.MegaMacro_Frame then return end

    local search=_G.BPMMUnifiedSearch
    local char=_G.MegaMacro_FrameCharLimitText
    local del=_G.MegaMacro_DeleteButton
    local loc=_G.BPMM74LocateButton

    if search then
        search:ClearAllPoints()
        search:SetPoint("BOTTOM",MegaMacro_Frame,"BOTTOM",0,9)
    end
    if char then
        char:ClearAllPoints()
        char:SetPoint("BOTTOM",MegaMacro_Frame,"BOTTOM",0,38)
        char:SetJustifyH("CENTER")
        char:SetTextColor(unpack(C.muted))
    end
    if del then
        del:ClearAllPoints()
        del:SetPoint("BOTTOMLEFT",MegaMacro_Frame,"BOTTOMLEFT",12,9)
    end
    if loc then
        loc:ClearAllPoints()
        loc:SetPoint("BOTTOMRIGHT",MegaMacro_Frame,"BOTTOMRIGHT",-12,9)
    end
end

local function Apply()
    if _G.BPMMGoalLayout and _G.BPMMGoalLayout.Apply then
        _G.BPMMGoalLayout.Apply()
        return
    end
    RestoreTabLabels()
    PolishTitles()
    PolishProfiles()
    PolishCheckButtons()
    PolishMegaMacroSelectedName()
    PolishFooter()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.4,Apply)
    C_Timer.After(.9,Apply)
end)

if _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",function() C_Timer.After(0,Apply) end)
end
if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function() C_Timer.After(0,Apply) end)
end
if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function() C_Timer.After(0,Apply) end)
end
if type(_G.BindPadFrameTab_OnClick)=="function" then
    hooksecurefunc("BindPadFrameTab_OnClick",function() C_Timer.After(0,Apply) end)
end
