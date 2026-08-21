-- BPMM UI polish/compatibility patch 0.5.2
-- Loaded after consolidated UI.lua.

local function GetCloseButton(frame)
    if not frame then return nil end
    local name = frame.GetName and frame:GetName()
    return frame.CloseButton
        or frame.closeButton
        or (name and _G[name.."CloseButton"])
end

local function MakeCleanClose(frame)
    local button = GetCloseButton(frame)
    if not button then return end

    -- Remove every inherited/custom visual on the actual close button.
    for _,region in ipairs({button:GetRegions()}) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    button:SetSize(20,20)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    if not button.__BPMMCleanClose then
        local art = CreateFrame("Frame", nil, button, "BackdropTemplate")
        art:SetAllPoints()
        art:SetFrameLevel(button:GetFrameLevel()+1)
        art:EnableMouse(false)
        art:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
            insets={left=1,right=1,top=1,bottom=1},
        })
        art:SetBackdropColor(.055,.055,.065,.98)
        art:SetBackdropBorderColor(0,0,0,1)

        local line1=art:CreateTexture(nil,"OVERLAY")
        line1:SetTexture("Interface\\Buttons\\WHITE8x8")
        line1:SetSize(12,1.4)
        line1:SetPoint("CENTER")
        line1:SetRotation(math.rad(45))
        line1:SetVertexColor(.88,.88,.90,1)

        local line2=art:CreateTexture(nil,"OVERLAY")
        line2:SetTexture("Interface\\Buttons\\WHITE8x8")
        line2:SetSize(12,1.4)
        line2:SetPoint("CENTER")
        line2:SetRotation(math.rad(-45))
        line2:SetVertexColor(.88,.88,.90,1)

        button.__BPMMCleanClose={art=art,line1=line1,line2=line2}

        button:HookScript("OnEnter",function(self)
            local c=self.__BPMMCleanClose
            if c then
                c.art:SetBackdropColor(.14,.045,.045,1)
                c.art:SetBackdropBorderColor(.45,.08,.08,1)
                c.line1:SetVertexColor(1,.45,.45,1)
                c.line2:SetVertexColor(1,.45,.45,1)
            end
        end)
        button:HookScript("OnLeave",function(self)
            local c=self.__BPMMCleanClose
            if c then
                c.art:SetBackdropColor(.055,.055,.065,.98)
                c.art:SetBackdropBorderColor(0,0,0,1)
                c.line1:SetVertexColor(.88,.88,.90,1)
                c.line2:SetVertexColor(.88,.88,.90,1)
            end
        end)
    end

    local clean=button.__BPMMCleanClose
    if clean then
        clean.art:SetFrameLevel(button:GetFrameLevel()+1)
        clean.art:Show()
        clean.line1:Show()
        clean.line2:Show()
    end
end

local function HideScrollbarArrows()
    local sf=_G.BindPadScrollFrame or _G.BindPadFrameScrollFrame
    local sb=sf and sf.ScrollBar
    if not sb then return end

    for _,b in ipairs({sb.Back,sb.Forward,sb.ScrollUpButton,sb.ScrollDownButton}) do
        if b then
            b:Hide()
            b:SetAlpha(0)
            if b.EnableMouse then b:EnableMouse(false) end
        end
    end
end

local function RefreshProfileAppearance()
    if not BindPadFrame then return end

    -- Make space for a dedicated profile row between the icon grid and options.
    if BindPadScrollFrame then
        BindPadScrollFrame:SetHeight(330)
    end

    local startX=108
    local y=82
    local spacing=42

    for i=1,5 do
        local b=_G["BindPadProfileTab"..i]
        if b then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT",BindPadFrame,"BOTTOMLEFT",startX+(i-1)*spacing,y)
            b:SetSize(32,32)

            local bg=_G["BindPadProfileTab"..i.."Background"]
            if bg then bg:SetAlpha(0) end

            -- IMPORTANT: let BindPad itself decide which specialization(s)
            -- belong to each profile. This preserves the actual profile mapping.
            if BindPadProfileTab_OnShow then
                BindPadProfileTab_OnShow(b)
            end

            local tex=b:GetNormalTexture()
            if tex then
                tex:SetTexCoord(.07,.93,.07,.93)
            end
        end
    end
end

local function Refresh()
    MakeCleanClose(BindPadFrame)
    MakeCleanClose(MegaMacro_Frame)
    MakeCleanClose(BindPadBindFrame)
    HideScrollbarArrows()
    RefreshProfileAppearance()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_SPECIALIZATION_CHANGED" and unit and unit~="player" then return end
    C_Timer.After(0,Refresh)
    C_Timer.After(.2,Refresh)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,Refresh)
        C_Timer.After(.15,Refresh)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Refresh)
    end)
end

if BindPadBindFrame then
    BindPadBindFrame:HookScript("OnShow",function()
        MakeCleanClose(BindPadBindFrame)
    end)
end
