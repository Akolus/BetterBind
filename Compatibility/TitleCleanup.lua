-- BindPad + MegaMacro safe title cleanup
-- Hides only known original title strings and preserves tab labels.

local function CleanKnownTitle(frame, wantedText)
    if not frame then return end

    local keep = frame.__BPMM81Title
    if keep then
        keep:Show()
        keep:SetAlpha(1)
        keep:SetText(wantedText)
        keep:SetTextColor(.93,.94,.96,1)
    end

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetAlpha(0)
        frame.TitleContainer.TitleText:Hide()
    end

    local name = frame.GetName and frame:GetName()
    if name and _G[name.."TitleText"] then
        _G[name.."TitleText"]:SetAlpha(0)
        _G[name.."TitleText"]:Hide()
    end

    -- Only hide fontstrings whose actual text is an old title.
    local function inspect(container)
        if not container or not container.GetRegions then return end
        for _,r in ipairs({container:GetRegions()}) do
            if r and r.GetObjectType and r:GetObjectType()=="FontString" and r~=keep then
                local t=r:GetText()
                if t=="BindPad" or t=="MegaMacro" or t=="Mega Macro - Create Macros" then
                    r:SetAlpha(0)
                    r:Hide()
                end
            end
        end
    end

    inspect(frame)
    if frame.TitleContainer then inspect(frame.TitleContainer) end
end

local function Apply()
    if _G.BPMMGoalLayout and _G.BPMMGoalLayout.ApplyTitles then
        _G.BPMMGoalLayout.ApplyTitles()
        return
    end
    CleanKnownTitle(_G.BindPadFrame,"BetterBind")
    CleanKnownTitle(_G.MegaMacro_Frame,"BetterMacro")
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    C_Timer.After(.3,Apply)
    C_Timer.After(.8,Apply)
end)

if _G.BindPadFrame then
    BindPadFrame:HookScript("OnShow",function() C_Timer.After(0,Apply) end)
end
if _G.MegaMacro_Frame then
    MegaMacro_Frame:HookScript("OnShow",function() C_Timer.After(0,Apply) end)
end
