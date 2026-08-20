-- BindPad + MegaMacro Stage 8.6.3
-- FINAL separator-line purge.
-- Targets the exact surviving horizontal lines seen:
--   * MegaMacro: line directly above DELETE / search / LOCATE
--   * BindPad: line directly below Show Hotkeys
--
-- No image generation, no data changes, no behavior changes.

local C={
    border={.10,.11,.125,1},
}

local function HideRegion(r)
    if r and r.SetAlpha then
        r:SetAlpha(0)
    end
end

local function HideThinHorizontalTextures(frame, minWidth, maxHeight, yBandTop, yBandBottom)
    if not frame then return end
    local ftop=frame:GetTop()
    local fbottom=frame:GetBottom()
    if not ftop or not fbottom then return end

    for _,r in ipairs({frame:GetRegions()}) do
        if r and r.GetObjectType and r:GetObjectType()=="Texture" then
            local w,h=r:GetSize()
            local top=r:GetTop()
            local bottom=r:GetBottom()
            if w and h and top and bottom then
                local inBand=true
                if yBandTop then
                    local relTop=top-fbottom
                    if relTop>yBandTop then inBand=false end
                end
                if yBandBottom then
                    local relBottom=bottom-fbottom
                    if relBottom<yBandBottom then inBand=false end
                end
                if inBand and w>=minWidth and h<=maxHeight then
                    r:SetAlpha(0)
                end
            end
        end
    end

    for _,child in ipairs({frame:GetChildren()}) do
        local w,h=child:GetSize()
        local top=child:GetTop()
        local bottom=child:GetBottom()
        if w and h and top and bottom and w>=minWidth and h<=maxHeight then
            local relTop=top-fbottom
            local relBottom=bottom-fbottom
            local inBand=true
            if yBandTop and relTop>yBandTop then inBand=false end
            if yBandBottom and relBottom<yBandBottom then inBand=false end
            if inBand then
                local hadTex=false
                for _,r in ipairs({child:GetRegions()}) do
                    if r.GetObjectType and r:GetObjectType()=="Texture" then
                        r:SetAlpha(0)
                        hadTex=true
                    end
                end
                if hadTex and child.SetAlpha then
                    child:SetAlpha(0)
                end
            end
        end
    end
end

local function KillMegaFooterLine()
    local f=_G.MegaMacro_Frame
    if not f then return end

    -- Exact footer zone: bottom ~45 px. Only kill long, very thin textures.
    HideThinHorizontalTextures(f, 250, 8, 48, 0)

    -- Also kill known Stage8 separator frames if they landed in footer.
    for _,child in ipairs({f:GetChildren()}) do
        local w,h=child:GetSize()
        local bottom=child:GetBottom()
        local fb=f:GetBottom()
        if w and h and bottom and fb and w>300 and h<=8 and bottom-fb<48 then
            for _,r in ipairs({child:GetRegions()}) do
                if r.GetObjectType and r:GetObjectType()=="Texture" then
                    r:SetAlpha(0)
                end
            end
            if child.SetAlpha then child:SetAlpha(0) end
        end
    end
end

local function KillBindPadBottomLine()
    local f=_G.BindPadFrame
    if not f then return end

    -- Exact bottom utility zone: line sits just under Show Hotkeys.
    HideThinHorizontalTextures(f, 220, 8, 60, 0)

    for _,child in ipairs({f:GetChildren()}) do
        local w,h=child:GetSize()
        local bottom=child:GetBottom()
        local fb=f:GetBottom()
        if w and h and bottom and fb and w>220 and h<=8 and bottom-fb<60 then
            for _,r in ipairs({child:GetRegions()}) do
                if r.GetObjectType and r:GetObjectType()=="Texture" then
                    r:SetAlpha(0)
                end
            end
            if child.SetAlpha then child:SetAlpha(0) end
        end
    end
end

local function Apply()
    KillMegaFooterLine()
    KillBindPadBottomLine()
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.4,Apply)
    C_Timer.After(.8,Apply)
    C_Timer.After(1.5,Apply)
end)

if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function()
        C_Timer.After(0,KillMegaFooterLine)
        C_Timer.After(.1,KillMegaFooterLine)
    end)
end

if _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",function()
        C_Timer.After(0,KillBindPadBottomLine)
        C_Timer.After(.1,KillBindPadBottomLine)
    end)
end
