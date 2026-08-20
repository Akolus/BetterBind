-------------------------------------------------------------------
-- MEGAMACRO COMPATIBILITY SHIM (WoW 11.x / 12.x)
-------------------------------------------------------------------
-- This fixes "nil value" errors caused by Blizzard's API refactor.
-- We inject these into the Global (_G) and C_Spell tables.

local function ModernIsOverlayed(spellID)
    if not spellID then return false end
    -- 11.0+ uses the specialized C_SpellActivationOverlay namespace
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(spellID)
    end
    return false
end

local function ModernHideGlow(self)
    if not self then return end
    if self.SpellHighlightTexture then self.SpellHighlightTexture:Hide() end
    if SharedActionButton_RefreshSpellHighlight then
        SharedActionButton_RefreshSpellHighlight(self, false)
    end
end

local function ModernShowGlow(self)
    if not self then return end
    if self.SpellHighlightTexture then self.SpellHighlightTexture:Show() end
    if SharedActionButton_RefreshSpellHighlight then
        SharedActionButton_RefreshSpellHighlight(self, true)
    end
end

local function ModernClearCharges(self)
    if not self then return end
    local chargeCooldown = self.chargeCooldown
    if not chargeCooldown then return end

    if chargeCooldown.Clear then
        chargeCooldown:Clear()
    elseif chargeCooldown.SetCooldown then
        chargeCooldown:SetCooldown(0, 0)
    end
end

-- Only supply APIs that the client no longer exposes. Do not overwrite
-- Blizzard implementations or add non-Blizzard fields to C_ namespaces.
_G.IsOverlayed = _G.IsOverlayed or ModernIsOverlayed
_G.ActionButton_HideOverlayGlow = _G.ActionButton_HideOverlayGlow or ModernHideGlow
_G.ActionButton_ShowOverlayGlow = _G.ActionButton_ShowOverlayGlow or ModernShowGlow
_G.ClearChargeCooldown = _G.ClearChargeCooldown or ModernClearCharges

-------------------------------------------------------------------
-- END SHIM
-------------------------------------------------------------------

MegaMacroCachedClass = nil
MegaMacroCachedSpecialization = nil
MegaMacroFullyActive = false
MegaMacroSystemTime = GetTime()

local f = CreateFrame("Frame", "MegaMacro_EventFrame", UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local function OnUpdate(_, elapsed)
    MegaMacroSystemTime = GetTime()
    local elapsedMs = elapsed * 1000
    MegaMacroIconNavigator.OnUpdate()
    MegaMacroIconEvaluator.Update(elapsedMs)

    -- "Use native action bar" means Blizzard owns every protected action-bar
    -- visual.  The old visibility shortcut accidentally re-enabled our custom
    -- updater whenever BetterMacro was opened, which made /bb compare secret
    -- combat values such as GetActionCount().
    if not MegaMacroConfig['UseNativeActionBar'] then
        MegaMacroActionBarEngine.OnUpdate(elapsed)
    end
end

local function Initialize()
    MegaMacro_InitialiseConfig()
    MegaMacroIconNavigator.BeginLoadingIcons()

    SLASH_Mega1 = "/m"
    SLASH_Mega2 = "/macro"
    SLASH_Mega3 = "/bm"
    SLASH_Mega4 = "/bettermacro"
    SlashCmdList["Mega"] = function()
        MegaMacroWindow.Show()

        if not MegaMacroFullyActive then
            ShowMacroFrame()
        end
    end

    local specIndex = GetSpecialization()
    if specIndex then
        MegaMacroCachedClass = UnitClass("player")
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(specIndex))

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.Initialize()
        MegaMacroActionBarEngine.Initialize()
        MegaMacroEngine.SafeInitialize()
        MegaMacroEngine.ImportMacros()
        MegaMacroEngine.VerifyMacros()
        MegaMacroFullyActive = MegaMacroGlobalData.Activated and MegaMacroCharacterData.Activated
        f:SetScript("OnUpdate", OnUpdate)
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Initialize()
    elseif event == "PLAYER_LEAVING_WORLD" then
        f:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit and unit ~= "player" then
            return
        end

        local specIndex = GetSpecialization()
        if not specIndex then
            return
        end

        MegaMacroWindow.SaveMacro()

        local oldValue = MegaMacroCachedSpecialization
        MegaMacroCachedSpecialization = select(2, GetSpecializationInfo(specIndex))

        MegaMacroCodeInfo.ClearAll()
        MegaMacroIconEvaluator.ResetCache()

        if oldValue and MegaMacroCachedSpecialization and oldValue ~= MegaMacroCachedSpecialization and not InCombatLockdown() then
            MegaMacroEngine.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
            MegaMacroWindow.OnSpecializationChanged(oldValue, MegaMacroCachedSpecialization)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        MegaMacroActionBarEngine.OnTargetChanged()
    end
end)

MegaMacro_RegisterShiftClicks()

tinsert(UISpecialFrames, "MegaMacro_Frame")
UIPanelWindows["MegaMacro_Frame"] = nil
