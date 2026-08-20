--[[

For developer refererence, these are the features of an action bar button:
 - Texture
 - Cooldown (including silence/stun cooldown display)
 - Recharge cooldown
 - Is Usable
 - Insufficient Mana (or resource)
 - Is In Range
 - Is Current
 - Current Shapeshift Form (should appear as Is Current)
 - Count (spells or items). Example of spell count: Lesser Soul Fragments as displayed on Soul Cleave or Spirit Bomb.
 - Charges (spells only atm)
 - Spell Glow (such as on empowerments for Balance Druid)
 - Active Auto Attack Flash (flashes red when auto attack is active) - intentionally omitted from this addon

]]



local LibActionButton = nil
local ActionBarSystem = nil -- Blizzard or LAB or Dominos
local BlizzardActionBars = { "Action", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }

local rangeTimer = 5
local updateRange = false

local ActionsBoundToMegaMacros = {}
local Initialized = false

-- Midnight-era action APIs can return "secret" values while Blizzard is
-- protecting combat state.  Addon Lua may pass those values through approved
-- secure code, but it may not compare, concatenate, or branch on them.  The
-- custom action-bar renderer therefore leaves that individual visual under
-- Blizzard's control until the value becomes readable again.
local function HasSecretValue(...)
    if type(_G.issecretvalue) ~= "function" then
        return false
    end

    for i=1,select("#",...) do
        if issecretvalue(select(i,...)) then
            return true
        end
    end
    return false
end

local function UpdateCurrentActionState(button, functions, abilityId)
    local isCurrent = functions.IsCurrent(abilityId)
    local isAutoRepeat = functions.IsAutoRepeat(abilityId)
    if HasSecretValue(isCurrent,isAutoRepeat) then return end
    local isChecked = isCurrent or isAutoRepeat

    if not isChecked and functions == MegaMacroInfoFunctions.Spell then
        local shapeshiftFormIndex = GetShapeshiftForm()
        if shapeshiftFormIndex and shapeshiftFormIndex > 0 and abilityId == select(4, GetShapeshiftFormInfo(shapeshiftFormIndex)) then
            isChecked = true
        end
    end

    if isChecked then
        button:SetChecked(true)
    else
        button:SetChecked(false)
    end
end

local function UpdateUsable(button, functions, abilityId)
    local icon = button.icon
	local normalTexture = button.NormalTexture
	if not normalTexture then
		return;
	end

	local isUsable, notEnoughMana = functions.IsUsable(abilityId)
	if HasSecretValue(isUsable,notEnoughMana) then return end
	if isUsable then
		icon:SetVertexColor(1.0, 1.0, 1.0)
		normalTexture:SetVertexColor(1.0, 1.0, 1.0)
	elseif ( notEnoughMana ) then
		icon:SetVertexColor(0.5, 0.5, 1.0)
		normalTexture:SetVertexColor(0.5, 0.5, 1.0)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
		normalTexture:SetVertexColor(1.0, 1.0, 1.0)
	end

	-- local isLevelLinkLocked = functions.IsLocked(abilityId)
	-- if not icon:IsDesaturated() then
	-- 	icon:SetDesaturated(isLevelLinkLocked)
	-- end

	-- if button.LevelLinkLockIcon then
	-- 	button.LevelLinkLockIcon:SetShown(isLevelLinkLocked)
	-- end
end

local function LibActionButton_EndChargeCooldown(self)
    self:Hide()
    self:SetParent(UIParent)

    -- -----------------------------------------------------------------
    --  Defensive clean‑up – the parent may already be nil (see the
    --  earlier fix) and the pool table may not exist yet.
    -- -----------------------------------------------------------------
    if self.parent then
        self.parent.chargeCooldown = nil
        self.parent = nil
    end

    -- Ensure the pool table exists before inserting.
    if not LibActionButton.ChargeCooldowns then
        LibActionButton.ChargeCooldowns = {}
    end
    tinsert(LibActionButton.ChargeCooldowns, self)
end

local function LibActionButton_StartChargeCooldown(parent, chargeStart, chargeDuration, chargeModRate)
    -------------------------------------------------------------------------
    -- 1️⃣  Ensure the pool tables exist
    -------------------------------------------------------------------------
    if not LibActionButton.ChargeCooldowns then
        LibActionButton.ChargeCooldowns = {}
    end
    if not LibActionButton.NumChargeCooldowns then
        LibActionButton.NumChargeCooldowns = 0
    end

    -------------------------------------------------------------------------
    -- 2️⃣  Pull a frame from the pool (or create a fresh one)
    -------------------------------------------------------------------------
    if not parent.chargeCooldown then
        local cooldown = tremove(LibActionButton.ChargeCooldowns)
        if not cooldown then
            LibActionButton.NumChargeCooldowns = LibActionButton.NumChargeCooldowns + 1
            cooldown = CreateFrame(
                "Cooldown",
                "LAB10ChargeCooldown"..LibActionButton.NumChargeCooldowns,
                parent,
                "CooldownFrameTemplate"
            )
            cooldown:SetScript("OnCooldownDone", LibActionButton_EndChargeCooldown)
        end

        -----------------------------------------------------------------
        -- 3️⃣  **Critical** – always (re)assign the custom .parent field.
        -----------------------------------------------------------------
        cooldown.parent = parent

        -----------------------------------------------------------------
        -- 4️⃣  **Force the correct visual defaults** every time we take a frame.
        -----------------------------------------------------------------
        cooldown:SetHideCountdownNumbers(false)   -- <<< show the timer text
        cooldown:SetDrawSwipe(true)               -- <<< draw the normal spiral
        cooldown:SetEdgeTexture("Interface\\Cooldown\\edge") -- same edge as normal cooldown
        cooldown:SetSwipeColor(0, 0, 0)           -- default colour (matches normal)

        -----------------------------------------------------------------
        -- 5️⃣  Anchor the frame to the button
        -----------------------------------------------------------------
        cooldown:SetParent(parent)
        cooldown:SetAllPoints(parent)
        cooldown:SetFrameStrata("TOOLTIP")
        cooldown:Show()

        parent.chargeCooldown = cooldown
    end

    -------------------------------------------------------------------------
    -- 6️⃣  Visual configuration that depends on the button’s opacity
    -------------------------------------------------------------------------
    parent.chargeCooldown:SetDrawBling(parent.chargeCooldown:GetEffectiveAlpha() > 0.5)

    -------------------------------------------------------------------------
    -- 7️⃣  Feed the charge‑cooldown data into the frame
    -------------------------------------------------------------------------
    CooldownFrame_Set(parent.chargeCooldown, chargeStart, chargeDuration, true, true, chargeModRate)

    -------------------------------------------------------------------------
    -- 8️⃣  Masque support (unchanged)
    -------------------------------------------------------------------------
    if Masque and Masque.UpdateCharge then
        Masque:UpdateCharge(parent)
    end

    -------------------------------------------------------------------------
    -- 9️⃣  Edge case – if the charge is already ready, hide the frame
    -------------------------------------------------------------------------
    if not chargeStart or chargeStart == 0 then
        LibActionButton_EndChargeCooldown(parent.chargeCooldown)
    end
end

local function UpdateCooldownLibActionButton(button, functions, abilityId)
    -- 1️⃣  Gather all cooldown‑related data
    local locStart, locDuration = functions.GetLossOfControlCooldown(abilityId)
    local start, duration, enable, modRate = functions.GetCooldown(abilityId)
    local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = functions.GetCharges(abilityId)

    if HasSecretValue(
        locStart,locDuration,start,duration,enable,modRate,
        charges,maxCharges,chargeStart,chargeDuration,chargeModRate
    ) then return end

    -------------------------------------------------------------------------
    -- 2️⃣  Normal cooldown handling (unchanged apart from a tiny refactor)
    -------------------------------------------------------------------------
    button.cooldown:SetDrawBling(button.cooldown:GetEffectiveAlpha() > 0.5)

    if (locStart + locDuration) > (start + duration) then
        if button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL then
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
            button.cooldown:SetSwipeColor(0.17, 0, 0)
            button.cooldown:SetHideCountdownNumbers(true)
            button.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
        end
        CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
    else
        if button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL then
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
            button.cooldown:SetSwipeColor(0, 0, 0)
            button.cooldown:SetHideCountdownNumbers(false)
            button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        end

        if locStart > 0 then
            button.cooldown:SetScript("OnCooldownDone",
                function() UpdateCooldownLibActionButton(button, functions, abilityId) end)
        end

         -----------------------------------------------------------------
        -- 3️⃣  **Charge‑cooldown handling**
        -----------------------------------------------------------------
        local hasCharges = charges and maxCharges and maxCharges > 1
        if hasCharges and charges > 0 and charges < maxCharges then
            -- *** NEW: use the main cooldown widget for the charge timer ***
            -- The fourth argument (enable) is always true for charge cooldowns.
            -- We keep the same modRate that the original code passed.
            CooldownFrame_Set(button.cooldown, chargeStart, chargeDuration, true, false, chargeModRate)

            -- Ensure the normal cooldown edge/colour is appropriate for a charge.
            button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
            button.cooldown:SetSwipeColor(0, 0, 0)
            button.cooldown:SetHideCountdownNumbers(false)   -- show numbers
        else
            -- No pending charge → clear any leftover charge timer.
            -- (The regular cooldown will be set later in the function.)
            button.cooldown:SetCooldown(0, 0)   -- clears the frame
        end

        -----------------------------------------------------------------
        -- 4️⃣  Finally set the *regular* cooldown (spell/item cooldown)
        -----------------------------------------------------------------
        CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
    end
end

local function UpdateCooldownBlizzard(button, functions, abilityId)
    local locStart, locDuration = functions.GetLossOfControlCooldown(abilityId)
    local start, duration, enable, modRate = functions.GetCooldown(abilityId)
    local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = functions.GetCharges(abilityId)

    if HasSecretValue(
        locStart,locDuration,start,duration,enable,modRate,
        charges,maxCharges,chargeStart,chargeDuration,chargeModRate
    ) then return end

	if ( (locStart + locDuration) > (start + duration) ) then
		if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL ) then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC")
			button.cooldown:SetSwipeColor(0.17, 0, 0)
			button.cooldown:SetHideCountdownNumbers(true)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
		end

		CooldownFrame_Set(button.cooldown, locStart, locDuration, true, true, modRate)
		ClearChargeCooldown(button)
	else
		if ( button.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL ) then
			button.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
			button.cooldown:SetSwipeColor(0, 0, 0)
			button.cooldown:SetHideCountdownNumbers(false)
			button.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
		end

		if( locStart > 0 ) then
			button.cooldown:SetScript("OnCooldownDone", ActionButton_OnCooldownDone)
		end

		if ( charges and maxCharges and maxCharges > 1 and charges < maxCharges ) then
            StartChargeCooldown(button, chargeStart, chargeDuration, chargeModRate)
		else
			ClearChargeCooldown(button)
		end

		CooldownFrame_Set(button.cooldown, start, duration, enable, false, modRate)
	end
end

local function UpdateCount(button, functions, abilityId)
    local countLabel = button.Count
    local count = functions.GetCount(abilityId)

    if HasSecretValue(count) then return end

    local isItem = functions == MegaMacroInfoFunctions.Item
    local isEquippableItem
    if isItem then
        isEquippableItem=C_Item.IsEquippableItem(abilityId)
        if HasSecretValue(isEquippableItem) then return end
    end
    local isNonEquippableItem = isItem and not isEquippableItem
    local isNonItemWithCount = not isItem and count and count > 0

    if isNonEquippableItem or isNonItemWithCount then
        countLabel:SetText(count > (button.maxDisplayCount or 9999) and "*" or count)
    else
        local charges, maxCharges = functions.GetCharges(abilityId)
		if HasSecretValue(charges,maxCharges) then return end
			if charges and maxCharges and maxCharges > 1 then
			countLabel:SetText(charges)
		else
			countLabel:SetText("")
        end
    end
end

local function UpdateEquipped(button, functions, abilityId)
    local isEquipped=functions.IsEquipped(abilityId)
    if HasSecretValue(isEquipped) then return end
    if isEquipped then
		button.Border:SetVertexColor(0, 1.0, 0, 0.35)
		button.Border:Show()
	else
		button.Border:Hide()
	end
end

local function UpdateOverlayGlow(button, abilityId)
    local isOverlayed=IsOverlayed(abilityId)
    if HasSecretValue(isOverlayed) then return end
    if isOverlayed then
        ActionButton_ShowOverlayGlow(button)
    else
        ActionButton_HideOverlayGlow(button)
    end
end

local function UpdateRangeTimer(elapsed)
    rangeTimer = rangeTimer - elapsed

    if rangeTimer < 0 then
        updateRange = true
        rangeTimer = 1
    else
        updateRange = false
    end
end

local function UpdateRange(button, functions, abilityId, target)
    local valid = functions.IsInRange(abilityId, target)
    if HasSecretValue(valid) then return end
    -- local valid = IsSpellInRange(spellName, target) or IsItemInRange(abilityId, target)
	-- local valid = true
    local checksRange = (valid ~= nil);
    local inRange = checksRange and valid;
	rangeTimer = 1;

	local hotkeyUpdated = false
	if Bartender4 then
		if checksRange and not inRange then
			if Bartender4.db.profile.outofrange == "button" then
				button.icon:SetVertexColor(
					Bartender4.db.profile.colors.range.r,
					Bartender4.db.profile.colors.range.g,
					Bartender4.db.profile.colors.range.b)
			elseif Bartender4.db.profile.outofrange == "hotkey" then
				button.HotKey:SetVertexColor(
					Bartender4.db.profile.colors.range.r,
					Bartender4.db.profile.colors.range.g,
					Bartender4.db.profile.colors.range.b)
			end
			return
		end
	end

    if button.HotKey:GetText() == RANGE_INDICATOR then
		if checksRange then
			button.HotKey:Show();
			if ( inRange ) then
				button.HotKey:SetVertexColor(LIGHTGRAY_FONT_COLOR:GetRGB());
			elseif not hotkeyUpdated then
				button.HotKey:SetVertexColor(RED_FONT_COLOR:GetRGB());
			end
		else
			button.HotKey:Hide();
		end
	else
		if checksRange and not inRange and not hotkeyUpdated then
			button.HotKey:SetVertexColor(RED_FONT_COLOR:GetRGB());
		else
			button.HotKey:SetVertexColor(LIGHTGRAY_FONT_COLOR:GetRGB());
		end
	end
end

local function UpdateActionBar(button, macroId)
    local data = MegaMacroIconEvaluator.GetCachedData(macroId)
    local functions = MegaMacroInfoFunctions.Unknown

	if data then
		if data.Type == "spell" then
			functions = MegaMacroInfoFunctions.Spell
		elseif data.Type == "item" then
			functions = MegaMacroInfoFunctions.Item
		elseif data.Type == "fallback" then
			functions = MegaMacroInfoFunctions.Fallback
		end

		UpdateCurrentActionState(button, functions, data.Id)
		UpdateUsable(button, functions, data.Id)
		UpdateCount(button, functions, data.Id)
		UpdateEquipped(button, functions, data.Id)
		UpdateOverlayGlow(button, data.Id)
		button.icon:SetTexture(data.Icon or MegaMacroTexture)

		if LibActionButton then
			UpdateCooldownLibActionButton(button, functions, data.Id)
		else
			UpdateCooldownBlizzard(button, functions, data.Id)
		end

		-- this throttle was causing a flickering icon issue for bartender users
		-- after having it disabled for about a month, I've noticed no performance drop
		--if updateRange then
		UpdateRange(button, functions, data.Id, data.Target)
		--end
	end
end

local function ResetActionBar(button)
	button:SetChecked(false)
	button.Count:SetText("")
	button.Border:Hide() -- reset eqipped border
	ActionButton_HideOverlayGlow(button)
	ClearChargeCooldown(button)
	UpdateRange(button, MegaMacroInfoFunctions.Unknown)
	button.icon:SetVertexColor(1.0, 1.0, 1.0) -- reset opacity (is usable visuals)

	local normalTexture = button.NormalTexture
	if normalTexture then
		normalTexture:SetVertexColor(1.0, 1.0, 1.0) -- reset blue shift
	end
end

local function ForEachLibActionButton(func)
    for button, _ in pairs(LibActionButton.buttonRegistry) do
        func(button)
    end
end

local function ForEachDominosButton(func)
	for i=1, 120 do
		local button = nil
		if i <= 12 then
			button = _G[('ActionButton%d'):format(i)]
		elseif i <= 24 then
			button = _G["DominosActionButton"..(i - 12)]
		elseif i <= 36 then
			button = _G[('MultiBarRightButton%d'):format(i - 24)]
		elseif i <= 48 then
			button = _G[('MultiBarLeftButton%d'):format(i - 36)]
		elseif i <= 60 then
			button = _G[('MultiBarBottomRightButton%d'):format(i - 48)]
		elseif i <= 72 then
			button = _G[('MultiBarBottomLeftButton%d'):format(i - 60)]
		else
			button = _G["DominosActionButton"..(i - 60)]
		end
		if button then
			func(button)
		end
	end
end

local function ForEachBlizzardActionButton(func)
    for actionBarIndex=1, #BlizzardActionBars do
        for i=1, 12 do
            local button = _G[BlizzardActionBars[actionBarIndex].."Button"..i]
            if button then
                func(button)
            end
        end
    end
end

MegaMacroActionBarEngine = {}

function MegaMacroActionBarEngine.Initialize()
    if Initialized then
        return
    end

    if _G["BT4Button1"] then
        LibActionButton = LibStub("LibActionButton-1.0")
		ActionBarSystem = "LAB"
    elseif _G["ElvUI_Bar1Button1"] then
		LibActionButton = LibStub("LibActionButton-1.0-ElvUI")
		ActionBarSystem = "LAB"
	elseif Dominos then
		ActionBarSystem = "Dominos"
	else
		ActionBarSystem = "Blizzard"
    end

    MegaMacroIconEvaluator.OnIconUpdated(function()
        rangeTimer = -1
    end)

    Initialized = true
end

function MegaMacroActionBarEngine.OnUpdate(elapsed)
    UpdateRangeTimer(elapsed)

    local focus = GetMouseFoci()[1]
    local iterator = ForEachBlizzardActionButton

    if ActionBarSystem == "LAB" then
        iterator = ForEachLibActionButton
    elseif ActionBarSystem == "Dominos" then
        iterator = ForEachDominosButton
    end

	iterator(function(button)
	        local action = button:GetAttribute("action")
	        if HasSecretValue(action) then return end
	        if action == nil then action = button.action end
	        if HasSecretValue(action) then return end
	        local macroName = GetActionText(action)
	        if HasSecretValue(macroName) then return end
	        local macroCode = macroName and GetMacroBody(macroName) or nil
	        local actionType, actionArg1 = GetActionInfo(action)
	        if HasSecretValue(macroCode,actionType,actionArg1) then return end
	        local macroId = actionType == "macro" and macroCode and tonumber(string.sub(macroCode, 2, 4))

        if macroId then
            ActionsBoundToMegaMacros[button] = true

            -- MacroEffectData is already cached and incrementally evaluated.
            -- Button state is live: cooldowns, charges, counts, range,
            -- usability, current action and proc glow must refresh every tick.
            UpdateActionBar(button, macroId)

            if button == focus then
                ShowToolTipForMegaMacro(macroId)
            end
        elseif ActionsBoundToMegaMacros[button] then
            ActionsBoundToMegaMacros[button] = nil
            if not actionArg1 then
                ResetActionBar(button)
            end
        end
    end)
end

function MegaMacroActionBarEngine.OnTargetChanged()
    rangeTimer = -1
end

if type(_G.ActionButton_UpdateRangeIndicator) == "function" then
    hooksecurefunc("ActionButton_UpdateRangeIndicator", function()
        rangeTimer = -1
    end)
end
