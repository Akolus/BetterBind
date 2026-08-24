function MegaMacro_InitialiseConfig()
    MegaMacroGlobalData = type(MegaMacroGlobalData) == "table" and MegaMacroGlobalData or {}
    if MegaMacroGlobalData.Activated == nil then MegaMacroGlobalData.Activated = false end
    if type(MegaMacroGlobalData.Macros) ~= "table" then MegaMacroGlobalData.Macros = {} end
    if type(MegaMacroGlobalData.InactiveMacros) ~= "table" then MegaMacroGlobalData.InactiveMacros = {} end
    -- Older BetterBind builds accidentally left MegaMacroScopes.Inactive nil.
    -- Preserve those records and normalize their scope now that the inactive
    -- tab has a real, non-nil identifier.
    for _, macro in ipairs(MegaMacroGlobalData.InactiveMacros) do
        if type(macro) == "table" then macro.Scope = MegaMacroScopes.Inactive end
    end
    if type(MegaMacroGlobalData.Classes) ~= "table" then MegaMacroGlobalData.Classes = {} end

    MegaMacroCharacterData = type(MegaMacroCharacterData) == "table" and MegaMacroCharacterData or {}
    if MegaMacroCharacterData.Activated == nil then MegaMacroCharacterData.Activated = false end
    if type(MegaMacroCharacterData.Macros) ~= "table" then MegaMacroCharacterData.Macros = {} end
    if type(MegaMacroCharacterData.Specializations) ~= "table" then MegaMacroCharacterData.Specializations = {} end

    MegaMacroConfig = type(MegaMacroConfig) == "table" and MegaMacroConfig or {}

-- Always use Blizzard's native action-bar handling. This also migrates older
-- BetterMacro configurations that saved UseNativeActionBar as false.
MegaMacroConfig.UseNativeActionBar = true

    local defaults = {
        bindpad = 11,
        profiles = 12,
        bettermacro = 7,
        browser = 4,
    }

    MegaMacroConfig.Appearance = type(MegaMacroConfig.Appearance) == "table"
        and MegaMacroConfig.Appearance or {}

    for group, defaultSpacing in pairs(defaults) do
        local saved = MegaMacroConfig.Appearance[group]
        if type(saved) ~= "table" then
            saved = {}
            MegaMacroConfig.Appearance[group] = saved
        end

        -- Retain old style/zoom keys in SavedVariables for compatibility, but
        -- the fixed HUI visual preset now exposes spacing only.
        saved.spacing = tonumber(saved.spacing) or defaultSpacing
    end
end

local appearanceDefaults = {
    bindpad = { spacing = 11 },
    profiles = { spacing = 12 },
    bettermacro = { spacing = 7 },
    browser = { spacing = 4 },
}

local appearanceLimits = {
    bindpad = { spacing = 11 },
    profiles = { spacing = 18 },
    bettermacro = { spacing = 9 },
    browser = { spacing = 8 },
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function BetterBindAppearance_Get(group)
    MegaMacro_InitialiseConfig()
    local defaults = appearanceDefaults[group] or appearanceDefaults.bindpad
    local limits = appearanceLimits[group] or appearanceLimits.bindpad
    local saved = MegaMacroConfig.Appearance[group] or {}
    return {
        spacing = Clamp(saved.spacing, 0, limits.spacing),
    }
end

function BetterBindAppearance_Set(group, key, value)
    if not appearanceDefaults[group] then return false end
    MegaMacro_InitialiseConfig()

    if key == "spacing" then
        value = Clamp(value, 0, appearanceLimits[group].spacing)
    else
        return false
    end

    MegaMacroConfig.Appearance[group][key] = value
    return true
end

function MegaMacroConfig_IsWindowDialog()
    return not MegaMacroGlobalData.WindowInfo and true or MegaMacroGlobalData.WindowInfo.IsDialog
end

function MegaMacroConfig_GetWindowPosition()
    if MegaMacroGlobalData.WindowInfo then
        return MegaMacroGlobalData.WindowInfo.RelativePoint, MegaMacroGlobalData.WindowInfo.X, MegaMacroGlobalData.WindowInfo.Y
    end
end
