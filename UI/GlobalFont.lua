-- BetterBind-wide bundled font application.
--
-- Only BetterBind-owned frame trees are visited. This module intentionally
-- avoids hooksecurefunc and never replaces a layout method: editor layout,
-- background construction, caret placement, and selection remain untouched.

local Font={}
Font.PATH="Interface\\AddOns\\BetterBind\\Fonts\\open-sans.light.ttf"
Font.EDITOR_SIZE=14
Font.SHADOW_COLOR={0,0,0,.75}
Font.SHADOW_X=0
Font.SHADOW_Y=0
_G.BetterBindGlobalFont=Font

local ROOT_NAMES={
    "BindPadFrame",
    "BindPadBindFrame",
    "BindPadMacroPopupFrame",
    "BindPadMacroFrame",
    "BindPadDialogFrame",
    "MegaMacro_Frame",
    "MegaMacro_PopupFrame",
}

local hookedRoots=setmetatable({},{__mode="k"})
local applyQueued=false

local function IsFontRegion(object)
    if not object or not object.GetObjectType
        or not object.GetFont or not object.SetFont
    then
        return false
    end
    local kind=object:GetObjectType()
    return kind=="FontString" or kind=="EditBox"
end

local function ApplyFont(object)
    if not IsFontRegion(object) then return end
    if object.SetShadowColor then
        pcall(object.SetShadowColor,object,unpack(Font.SHADOW_COLOR))
    end
    if object.SetShadowOffset then
        pcall(
            object.SetShadowOffset,
            object,
            Font.SHADOW_X,
            Font.SHADOW_Y
        )
    end

    local editor=_G.MegaMacro_FrameText
    if object==editor
        or object==_G.MegaMacro_FrameSyntaxText
        or (editor and object.GetParent and object:GetParent()==editor)
    then
        -- The editor applies the bundled face directly to every text surface
        -- so selection, syntax, caret measurement, and glyph layout match.
        -- Its shadow is still normalized above with the rest of the addon.
        return
    end

    local _,size,flags=object:GetFont()
    size=tonumber(size) or 12
    flags=flags or ""
    pcall(object.SetFont,object,Font.PATH,size,flags)
end

local function WalkFrame(frame,seen)
    if not frame or seen[frame] then return end
    seen[frame]=true

    ApplyFont(frame)
    if frame.GetRegions then
        local regions={frame:GetRegions()}
        for index=1,#regions do
            ApplyFont(regions[index])
        end
    end
    if frame.GetChildren then
        local children={frame:GetChildren()}
        for index=1,#children do
            WalkFrame(children[index],seen)
        end
    end
end

local function ApplyRoot(root)
    if root then WalkFrame(root,{}) end
end

local function ScheduleApply(delay)
    C_Timer.After(delay,function()
        Font.Apply()
    end)
end

local function QueueApply()
    if applyQueued then return end
    applyQueued=true
    C_Timer.After(0,function()
        applyQueued=false
        Font.Apply()
    end)
end

local function InstallRootHooks()
    for _,name in ipairs(ROOT_NAMES) do
        local root=_G[name]
        if root and root.HookScript and not hookedRoots[root] then
            hookedRoots[root]=true
            root:HookScript("OnShow",function()
                QueueApply()
                ScheduleApply(.25)
            end)
        end
    end
end

function Font.Apply()
    InstallRootHooks()
    for _,name in ipairs(ROOT_NAMES) do
        ApplyRoot(_G[name])
    end
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    Font.Apply()
    ScheduleApply(.10)
    ScheduleApply(.75)
    ScheduleApply(1.50)
end)

Font.Apply()
QueueApply()
