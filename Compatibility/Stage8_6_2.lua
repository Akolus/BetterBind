-- BindPad + MegaMacro Stage 8.6.2
-- HARD cleanup pass after 8.6.1 failed to catch template/numeric textures.
-- This version does not rely on texture file names.
--
-- Goals:
--   * remove remaining Blizzard ornamental borders/separators
--   * force Config checkbox into Stage 8 style
--   * force UNINSTALL into Stage 8 style
--   * keep actual macro icons and text intact

local C={
    bg={.025,.029,.034,1},
    hover={.045,.052,.062,1},
    border={.095,.105,.120,1},
    blue={.05,.565,.905,1},
    text={.93,.94,.96,1},
}

local function HideTexture(tex)
    if tex and tex.SetAlpha then
        tex:SetAlpha(0)
    end
end

local function HideAllTextures(frame, exceptions)
    if not frame then return end
    exceptions=exceptions or {}

    local keep={}
    for _,x in ipairs(exceptions) do keep[x]=true end

    for _,r in ipairs({frame:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" and not keep[r] then
            r:SetAlpha(0)
        end
    end
end

local function HideNamed(name)
    local o=_G[name]
    if not o then return end
    if o.SetAlpha then o:SetAlpha(0) end
    if o.Hide then o:Hide() end
end

local function OnePixelOutline(frame,key)
    if not frame then return end

    if not frame[key] then
        local b=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        b:SetPoint("TOPLEFT",-1,1)
        b:SetPoint("BOTTOMRIGHT",1,-1)
        b:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
        b:EnableMouse(false)
        b:SetBackdrop({
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        frame[key]=b
    end
    frame[key]:SetBackdropBorderColor(unpack(C.border))
end

-- ============================================================================
-- GLOBAL LEGACY BORDER PURGE
-- ============================================================================

local function PurgeBindPadBorders()
    if not BindPadFrame then return end

    -- Outer inherited textures: Stage8 shell is already providing the real look.
    HideAllTextures(BindPadFrame)

    -- Restore only intentional Stage8-created textures/frames by virtue of them
    -- being children, not regions of BindPadFrame itself.

    local sf=_G.BindPadScrollFrame
    if sf then
        HideAllTextures(sf)

        if sf.ScrollBar then
            sf.ScrollBar:SetAlpha(0)
            sf.ScrollBar:Hide()
        end

        OnePixelOutline(sf,"__BPMM862Outline")
    end

    for _,n in ipairs({
        "BindPadScrollFrameTop",
        "BindPadScrollFrameBottom",
        "BindPadScrollFrameMiddle",
        "BindPadScrollFrameScrollBar",
        "BindPadScrollFrameScrollBarScrollUpButton",
        "BindPadScrollFrameScrollBarScrollDownButton",
    }) do
        HideNamed(n)
    end
end

local function PurgeMegaMacroBorders()
    if not MegaMacro_Frame then return end

    -- Do NOT hide all MegaMacro_Frame textures wholesale because the Stage8
    -- close/title system may share frame regions. Instead, purge the old
    -- content frames and named template pieces directly.

    local frames={
        _G.MegaMacro_ButtonScrollFrame,
        _G.MegaMacro_FrameScrollFrame,
        _G.MegaMacro_FormattedFrameScrollFrame,
        _G.MegaMacro_ConfigContainer,
        _G.MacroFrameTextBackground,
    }

    for _,f in ipairs(frames) do
        if f then
            HideAllTextures(f)
            if f.ScrollBar then
                f.ScrollBar:SetAlpha(0)
                f.ScrollBar:Hide()
            end
        end
    end

    for _,n in ipairs({
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

        "MegaMacro_HorizontalBarLeft",
        "MegaMacro_HorizontalBarRight",
        "MacroFrameTextBackground",
    }) do
        HideNamed(n)
    end

    -- Kill any old horizontal bar child whose geometry clearly identifies it
    -- as separator chrome. This catches numeric/fileID textures too.
    for _,child in ipairs({MegaMacro_Frame:GetChildren()}) do
        local w,h=child:GetSize()
        if w and h and w>250 and h<=20 then
            local hasTexture=false
            for _,r in ipairs({child:GetRegions()}) do
                if r.GetObjectType and r:GetObjectType()=="Texture" then
                    hasTexture=true
                    r:SetAlpha(0)
                end
            end
            if hasTexture and child.SetAlpha then
                child:SetAlpha(0)
            end
        end
    end

    OnePixelOutline(_G.MegaMacro_ButtonScrollFrame,"__BPMM862Outline")
    OnePixelOutline(_G.MegaMacro_FrameScrollFrame,"__BPMM862Outline")
    OnePixelOutline(_G.MegaMacro_ConfigContainer,"__BPMM862Outline")
end

-- ============================================================================
-- CONFIG TAB: FIND THE TWO IMPOSTERS BY WHAT THEY ARE, NOT BY NAME
-- ============================================================================

local function FindConfigObjects()
    local container=_G.MegaMacro_ConfigContainer
    if not container then return nil,nil end

    local checkbox,uninstall

    for _,child in ipairs({container:GetChildren()}) do
        if child.IsObjectType and child:IsObjectType("CheckButton") and not checkbox then
            checkbox=child
        elseif child.IsObjectType and child:IsObjectType("Button") then
            local fs=child.GetFontString and child:GetFontString()
            local text=fs and fs:GetText()
            if type(text)=="string" and string.upper(text):find("UNINSTALL",1,true) then
                uninstall=child
            end
        end
    end

    return checkbox,uninstall
end

local function StyleConfigCheckbox(cb)
    if not cb then return end

    -- Absolutely annihilate ALL template textures, regardless of texture source.
    HideAllTextures(cb)
    HideTexture(cb.GetNormalTexture and cb:GetNormalTexture())
    HideTexture(cb.GetPushedTexture and cb:GetPushedTexture())
    HideTexture(cb.GetHighlightTexture and cb:GetHighlightTexture())
    HideTexture(cb.GetCheckedTexture and cb:GetCheckedTexture())
    HideTexture(cb.GetDisabledTexture and cb:GetDisabledTexture())

    cb:SetSize(18,18)

    if not cb.__BPMM862Box then
        local box=CreateFrame("Frame",nil,cb,"BackdropTemplate")
        box:SetAllPoints()
        box:SetFrameLevel(math.max(0,cb:GetFrameLevel()-1))
        box:EnableMouse(false)
        box:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        cb.__BPMM862Box=box

        local mark=cb:CreateTexture(nil,"OVERLAY")
        mark:SetColorTexture(unpack(C.blue))
        mark:SetPoint("TOPLEFT",4,-4)
        mark:SetPoint("BOTTOMRIGHT",-4,4)
        cb.__BPMM862Mark=mark

        cb:HookScript("OnEnter",function(self)
            self.__BPMM862Box:SetBackdropBorderColor(unpack(C.blue))
        end)
        cb:HookScript("OnLeave",function(self)
            self.__BPMM862Box:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    cb.__BPMM862Box:SetBackdropColor(unpack(C.bg))
    cb.__BPMM862Box:SetBackdropBorderColor(unpack(C.border))
    cb.__BPMM862Mark:SetShown(cb:GetChecked() and true or false)

    if not cb.__BPMM862ClickHook then
        cb.__BPMM862ClickHook=true
        cb:HookScript("OnClick",function(self)
            self.__BPMM862Mark:SetShown(self:GetChecked() and true or false)
        end)
    end
end

local function StyleConfigUninstall(button)
    if not button then return end

    -- Same strategy: ALL inherited textures die, no file-path guessing.
    HideAllTextures(button)
    HideTexture(button.GetNormalTexture and button:GetNormalTexture())
    HideTexture(button.GetPushedTexture and button:GetPushedTexture())
    HideTexture(button.GetHighlightTexture and button:GetHighlightTexture())
    HideTexture(button.GetDisabledTexture and button:GetDisabledTexture())

    button:SetText("UNINSTALL")
    button:SetSize(110,26)

    if not button.__BPMM862BG then
        local bg=CreateFrame("Frame",nil,button,"BackdropTemplate")
        bg:SetAllPoints()
        bg:SetFrameLevel(math.max(0,button:GetFrameLevel()-1))
        bg:EnableMouse(false)
        bg:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8x8",
            edgeFile="Interface\\Buttons\\WHITE8x8",
            edgeSize=1,
        })
        button.__BPMM862BG=bg

        button:HookScript("OnEnter",function(self)
            self.__BPMM862BG:SetBackdropColor(unpack(C.hover))
            self.__BPMM862BG:SetBackdropBorderColor(unpack(C.blue))
        end)
        button:HookScript("OnLeave",function(self)
            self.__BPMM862BG:SetBackdropColor(unpack(C.bg))
            self.__BPMM862BG:SetBackdropBorderColor(unpack(C.border))
        end)
    end

    button.__BPMM862BG:SetBackdropColor(unpack(C.bg))
    button.__BPMM862BG:SetBackdropBorderColor(unpack(C.border))

    local fs=button.GetFontString and button:GetFontString()
    if fs then
        fs:SetTextColor(unpack(C.text))
    end
end

local function StyleConfigText()
    local container=_G.MegaMacro_ConfigContainer
    if not container then return end

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

local function ApplyConfig()
    local cb,uninstall=FindConfigObjects()
    StyleConfigCheckbox(cb)
    StyleConfigUninstall(uninstall)
    StyleConfigText()
end

local function Apply()
    PurgeBindPadBorders()
    PurgeMegaMacroBorders()
    ApplyConfig()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.5,Apply)
    C_Timer.After(1.0,Apply)
    C_Timer.After(2.0,Apply)
end)

if BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,PurgeBindPadBorders)
    end)
end

if MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,Apply)
        C_Timer.After(.1,ApplyConfig)
    end)
end

if type(_G.MegaMacro_FrameTab_OnClick)=="function" then
    hooksecurefunc("MegaMacro_FrameTab_OnClick",function()
        C_Timer.After(0,Apply)
        C_Timer.After(.1,ApplyConfig)
    end)
end
