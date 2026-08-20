MacroLimits = {
	-- limit: 120 non-character specific macro slots
	GlobalCount = 60,
	PerClassCount = 30,
	PerSpecializationCount = 30,
	-- limit: 18 character specific macro slots
	PerCharacterCount = 30,
	PerCharacterSpecializationCount = 0,
	InactiveCount = 160,
	MaxGlobalMacros = 120,
	MaxCharacterMacros = 30
}

MacroIndexOffsets = {
	Global = 0,
	PerClass = MacroLimits.GlobalCount,
	PerSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount,
	PerCharacter = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount,
	PerCharacterSpecialization = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount,
	Inactive = MacroLimits.GlobalCount + MacroLimits.PerClassCount + MacroLimits.PerSpecializationCount + MacroLimits.PerCharacterCount + MacroLimits.PerCharacterSpecializationCount,
	NativeCharacterMacros = 120
}

MegaMacroScopes = {
    Global = "gg",
    Class = "gc",
    Specialization = "gs",
    Character = "ch",
    CharacterSpecialization = "cs",
    Inactive = "in"
}

PetActionTextures = {
	Attack = 132152,
	Assist = 524348,
	Passive = 132311,
	Defensive = 132110,
	Follow = 132328,
	MoveTo = 457329,
	Stay = 136106,
	Dismiss = 136095
}

MegaMacroTexture = 134400
MegaMacroActiveStanceTexture = 136116
MegaMacroCodeMaxLength = 250
MegaMacroCodeMaxLengthForNative = 250
MegaMacroSlotPageSize = 48
HighestMaxMacroCount = math.ceil(math.max(
	MacroLimits.GlobalCount,
	MacroLimits.PerClassCount,
	MacroLimits.PerSpecializationCount,
	MacroLimits.PerCharacterCount,
	MacroLimits.PerCharacterSpecializationCount,
	MacroLimits.InactiveCount
) / MegaMacroSlotPageSize) * MegaMacroSlotPageSize

MegaMacroInfoFunctions = {
	Spell = {
		GetCooldown = function(abilityId)
			local spellCooldownInfo = C_Spell.GetSpellCooldown(abilityId);
			if spellCooldownInfo then
				return spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isEnabled, spellCooldownInfo.modRate;
			end
		end,
		GetCount = C_Spell.GetSpellCastCount,
			GetCharges = function(spellId)
				local currentCharges,maxCharges,cooldownStartTime,cooldownDuration,chargeModRate = C_Spell.GetSpellCharges(spellId)
				if type(currentCharges) == "table" then
					local chargeInfo=currentCharges
					return chargeInfo.currentCharges,chargeInfo.maxCharges,
						chargeInfo.cooldownStartTime,chargeInfo.cooldownDuration,
						chargeInfo.chargeModRate
				end
				return currentCharges,maxCharges,cooldownStartTime,cooldownDuration,chargeModRate
			end,
		IsUsable = C_Spell.IsSpellUsable,
			IsInRange = function(spellId, target)
				local result = C_Spell.IsSpellInRange(spellId, target)
				if type(_G.issecretvalue) == "function" and issecretvalue(result) then
					return result
				end
				if result == nil then
					return nil
				end
				return result == true or result == 1
			end,
		IsCurrent = C_Spell.IsCurrentSpell,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = C_Spell.IsAutoRepeatSpell,
		IsLocked = C_LevelLink.IsSpellLocked,
			GetLossOfControlCooldown = function(spellId)
				local startTime,duration = C_Spell.GetSpellLossOfControlCooldown(spellId)
				if type(startTime) == "table" then
					local locInfo=startTime
					return locInfo.startTime, locInfo.duration
				end
				return startTime,duration
			end,
		IsOverlayed = IsSpellOverlayed
	},
 	Item = {
		GetCooldown = C_Item.GetItemCooldown,
		GetCount = function(itemId) return C_Item.GetItemCount(itemId, false, true) end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
		IsUsable = function(itemId) return C_Item.IsUsableItem(itemId), false end,
		IsInRange = function(itemId)
			if C_Item.GetItemInfo(itemId) then
				return function(unit)
					return C_Item.IsItemInRange(itemId, unit)
				end
			end
		end,
		IsCurrent = C_Item.IsCurrentItem,
		IsEquipped = function(itemId) return C_Item.IsEquippedItem(itemId) end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
	},
	Fallback = {
		GetCooldown = function(_) return -1, 0, true end,
		GetCount = function(_) return 0 end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
		IsUsable = function(_) return false, false end,
		IsInRange = function(_, _) return nil end,
		IsCurrent = function(_) return false end,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
   },
	Unknown = {
		GetCooldown = function(_) return -1, 0, true end,
		GetCount = function(_) return 0 end,
		GetCharges = function(_) return 0, 0, -1, 0, 1 end, -- charges, maxCharges, chargeStart, chargeDuration, chargeModRate
		IsUsable = function(_) return true, false end,
		IsInRange = function(_, _) return nil end,
		IsCurrent = function(_) return false end,
		IsEquipped = function(_) return false end,
		IsAutoRepeat = function(_) return false end,
		IsLocked = function(_) return false end,
		GetLossOfControlCooldown = function(_) return -1, 0 end,
		IsOverlayed = function(_) return false end
	}
}
