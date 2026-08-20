-- BindPad + MegaMacro Stage 8.6.1
-- "Annihilate the imposters" patch.
-- Removes surviving Blizzard-style borders/chrome and restyles the two
-- MegaMacro Config-tab controls (checkbox + Uninstall) to Stage 8 styling.
-- No data, macro, binding, profile, or behavior changes.

local C={
    bg={.028,.032,.038,1},
    panel={.022,.026,.031,1},
    hover={.050,.058,.068,1},
    border={.10,.11,.125,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
    muted={.62,.65,.69,1},
}

local function HideTex(obj)
    if obj and obj.SetAlpha then
        obj:SetAlpha(0)
        if obj.Hide then obj:Hide() end
    end
end

local function TexturePath(tex)
    if not tex or not tex.GetTexture then return nil end
    local p=tex:GetTexture()
    if type(p)=="string" then return string.lower(p) end
end

local function IsBlizzardChrome(tex)
    local p=TexturePath(tex)
    if not p then return false end

    return
        p:find("uipanel",1,true) or
        p:find("dialogframe",1,true) or
        p:find("tooltip",1,true) or
        p:find("classtrainer",1,true) or
        p:find("paperdoll",1,true) or
        p:find("scrollbar",1,true) or
        p:find("common%-tab",1,false) or
        p:find("button%-",1,false) or
        p:find("ui%-dialogbox",1,false) or
        p:find("ui%-character",1,false)
end

local function StripFrameTextures(frame, preserve)
    if not frame then return end

    for _,r in ipairs({frame:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" and r~=preserve then
            if IsBlizzardChrome(r) then
                HideTex(r)
            end
        end
    end
end

local function ThinBorder(frame,key,inset)
    if not frame then return end

    local b=frame[key]
    if not b then
        b=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        inset=inset or 0
        b:SetPoint("TOPLEFT",frame,"TOPLEFT",-inset,inset)
        b:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",inset,-inset)
        b:SetFrameLevel(math.max(0,(frame:GetFrameLevel() or 1)-1))
        b:EnableMouse(false)
        b:SetBackdrop({
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        frame[key]=b
    end
    b:SetBackdropBorderColor(unpack(C.border))
end

local function KillNamedLegacyPieces()
    local names={
        -- BindPad legacy/scroll chrome
        "BindPadScrollFrameTop",
        "BindPadScrollFrameBottom",
        "BindPadScrollFrameMiddle",
        "BindPadScrollFrameScrollBar",
        "BindPadScrollFrameScrollBarScrollUpButton",
        "BindPadScrollFrameScrollBarScrollDownButton",

        -- MegaMacro grid/editor scroll chrome
        "MegaMacro_ButtonScrollFrameTop",
        "MegaMacro_ButtonScrollFrameBottom",
        "MegaMacro_ButtonScrollFrameMiddle",
        "MegaMacro_ButtonScrollFrameScrollBar",
        "MegaMacro_ButtonScrollFrameScrollBarScrollUpButton",
        "MegaMacro_ButtonScrollFrameScrollBarScrollDownButton",

        "MegaMacro_FrameScrollFrameScrollBar",
        "MegaMacro_FrameScrollFrameScrollBarScrollUpButton",
        "MegaMacro_FrameScrollFrameScrollBarScrollDownButton",

        "MegaMacro_FormattedFrameScrollFrameScrollBar",
        "MegaMacro_FormattedFrameScrollFrameScrollBarScrollUpButton",
        "MegaMacro_FormattedFrameScrollFrameScrollBarScrollDownButton",

        -- surviving inherited backdrops / separators
        "MacroFrameTextBackground",
        "MegaMacro_HorizontalBarLeft",
        "MegaMacro_HorizontalBarRight",
    }

    for _,name in ipairs(names) do
        local o=_G[name]
        if o then
            if o.SetAlpha then o:SetAlpha(0) end
            if o.Hide then o:Hide() end
        end
    end
end

local function CleanMainFrames()
    if BindPadFrame then
        StripFrameTextures(BindPadFrame)
        if BindPadScrollFrame then
            StripFrameTextures(BindPadScrollFrame)
            ThinBorder(BindPadScrollFrame,"__BPMM861ThinBorder",1)
        end
    end

    if MegaMacro_Frame then
        StripFrameTextures(MegaMacro_Frame)

        if MegaMacro_ButtonScrollFrame then
            StripFrameTextures(MegaMacro_ButtonScrollFrame)
            ThinBorder(MegaMacro_ButtonScrollFrame,"__BPMM861ThinBorder",1)
        end

        if MegaMacro_FrameScrollFrame then
            StripFrameTextures(MegaMacro_FrameScrollFrame)
            ThinBorder(MegaMacro_FrameScrollFrame,"__BPMM861ThinBorder",1)
        end
    end

    KillNamedLegacyPieces()
end

local function FlatButton(button,label)
    if not button then return end

    if label then button:SetText(label) end

    HideTex(button.GetNormalTexture and button:GetNormalTexture())
    HideTex(button.GetPushedTexture and button:GetPushedTexture())
    HideTex(button.GetHighlightTexture and button:GetHighlightTexture())
    HideTex(button.GetDisabledTexture and button:GetDisabledTexture())

    StripFrameTextures(button)

    if not button.__BPMM861BG then
        local bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,(button:GetFrameLevel() or 1)-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        button.__BPMM861BG=bg

        button:HookScript("OnEnter",function(self)
            if self:IsEnabled() then
                self.__BPMM861BG:SetBackdropColor(unpack(C.hover))
                self.__BPMM861BG:SetBackdropBorderColor(unpack(C.blue))
            end
        end)

        button:HookScript("OnLeave",function(self)
            self.__BPMM861BG:SetBackdropColor(unpack(C.bg))
            self.__BPMM861BG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    button.__BPMM861BG:SetBackdropColor(unpack(C.bg))
    button.__BPMM861BG:SetBackdropBorderColor(unpack(C.border))

    local fs=button.GetFontString and button:GetFontString()
    if fs then fs:SetTextColor(unpack(C.text)) end
end

local function FindConfigCheckbox()
    local candidates={
        _G.MegaMacro_BlizMacroCheckButton,
        _G.MegaMacro_BlizMacroCheckbox,
        _G.MegaMacro_BlizzardActionBarIconsCheckButton,
        _G.MegaMacro_BlizzardActionBarIconsCheckbox,
    }
    for _,b in ipairs(candidates) do
        if b then return b end
    end

    local container=_G.MegaMacro_ConfigContainer
    if not container then return nil end

    for _,child in ipairs({container:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("CheckButton") then
            return child
        end
    end
end

local function FindConfigUninstallButton()
    local candidates={
        _G.MegaMacro_UninstallButton,
        _G.MegaMacro_BlizMacroUninstallButton,
        _G.MegaMacro_ConfigUninstallButton,
    }
    for _,b in ipairs(candidates) do
        if b then return b end
    end

    local container=_G.MegaMacro_ConfigContainer
    if not container then return nil end

    for _,child in ipairs({container:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("Button") then
            local fs=child.GetFontString and child:GetFontString()
            local t=fs and fs:GetText()
            if type(t)=="string" and string.upper(t)=="UNINSTALL" then
                return child
            end
        end
    end
end

local function StyleConfigCheckbox(cb)
    if not cb then return end

    -- Kill inherited Blizzard checkbox artwork.
    HideTex(cb.GetNormalTexture and cb:GetNormalTexture())
    HideTex(cb.GetPushedTexture and cb:GetPushedTexture())
    HideTex(cb.GetHighlightTexture and cb:GetHighlightTexture())
    HideTex(cb.GetDisabledTexture and cb:GetDisabledTexture())
    HideTex(cb.GetCheckedTexture and cb:GetCheckedTexture())

    StripFrameTextures(cb)

    cb:SetSize(22,22)

    if not cb.__BPMM861Box then
        local box=CreateFrame("Frame",nil,cb,"BackdropTemplate")
        box:SetAllPoints()
        box:SetFrameLevel(math.max(0,cb:GetFrameLevel()-1))
        box:EnableMouse(false)
        box:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        cb.__BPMM861Box=box

        local mark=cb:CreateTexture(nil,"OVERLAY")
        mark:SetColorTexture(unpack(C.blue))
        mark:SetSize(10,10)
        mark:SetPoint("CENTER")
        cb.__BPMM861Mark=mark

        local function refresh()
            mark:SetShown(cb:GetChecked() and true or false)
        end
        cb.__BPMM861Refresh=refresh
        cb:HookScript("OnClick",refresh)
        cb:HookScript("OnShow",refresh)

        cb:HookScript("OnEnter",function(self)
            self.__BPMM861Box:SetBackdropBorderColor(unpack(C.blue))
        end)
        cb:HookScript("OnLeave",function(self)
            self.__BPMM861Box:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    cb.__BPMM861Box:SetBackdropColor(unpack(C.bg))
    cb.__BPMM861Box:SetBackdropBorderColor(unpack(C.border))
    cb.__BPMM861Refresh()
end

local function CleanConfigPanel()
    local container=_G.MegaMacro_ConfigContainer
    if not container then return end

    StripFrameTextures(container)
    ThinBorder(container,"__BPMM861ThinBorder",0)

    -- Also remove any inherited panel chrome from child frames.
    for _,child in ipairs({container:GetChildren()}) do
        StripFrameTextures(child)
    end

    local cb=FindConfigCheckbox()
    local uninstall=FindConfigUninstallButton()

    StyleConfigCheckbox(cb)
    FlatButton(uninstall,"UNINSTALL")

    -- Normalize config text color to the Stage 8 palette.
    for _,r in ipairs({container:GetRegions()}) do
        if r.GetObjectType and r:GetObjectType()=="FontString" then
            r:SetTextColor(unpack(C.text))
        end
    end
    for _,child in ipairs({container:GetChildren()}) do
        for _,r in ipairs({child:GetRegions()}) do
            if r.GetObjectType and r:GetObjectType()=="FontString" then
                r:SetTextColor(unpack(C.text))
            end
        end
    end
end

local function Apply()
    CleanMainFrames()
    CleanConfigPanel()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,Apply)
    C_Timer.After(1.0,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,CleanMainFrames)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
    end)
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        C_Timer.After(0,function()
            CleanMainFrames()
            CleanConfigPanel()
        end)
    end)
end
