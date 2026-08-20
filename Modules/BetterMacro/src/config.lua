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
        bindpad = { style = "crop", zoom = 0, spacing = 11 },
        profiles = { style = "crop", zoom = 0, spacing = 12 },
        bettermacro = { style = "crop", zoom = 0, spacing = 7 },
        browser = { style = "crop", zoom = 0, spacing = 4 },
    }

    MegaMacroConfig.Appearance = type(MegaMacroConfig.Appearance) == "table"
        and MegaMacroConfig.Appearance or {}

    for group, values in pairs(defaults) do
        local saved = MegaMacroConfig.Appearance[group]
        if type(saved) ~= "table" then
            saved = {}
            MegaMacroConfig.Appearance[group] = saved
        end

        if saved.style ~= "full" and saved.style ~= "crop" and saved.style ~= "rounded" then
            saved.style = values.style
        end
        saved.zoom = tonumber(saved.zoom) or values.zoom
        saved.spacing = tonumber(saved.spacing) or values.spacing
    end
end

local appearanceDefaults = {
    bindpad = { style = "crop", zoom = 0, spacing = 11 },
    profiles = { style = "crop", zoom = 0, spacing = 12 },
    bettermacro = { style = "crop", zoom = 0, spacing = 7 },
    browser = { style = "crop", zoom = 0, spacing = 4 },
}

local appearanceLimits = {
    bindpad = { zoom = 40, spacing = 11 },
    profiles = { zoom = 40, spacing = 18 },
    bettermacro = { zoom = 40, spacing = 9 },
    browser = { zoom = 40, spacing = 8 },
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
    local style = saved.style
    if style ~= "full" and style ~= "crop" and style ~= "rounded" then
        style = defaults.style
    end
    return {
        style = style,
        zoom = Clamp(saved.zoom, 0, limits.zoom),
        spacing = Clamp(saved.spacing, 0, limits.spacing),
    }
end

function BetterBindAppearance_Set(group, key, value)
    if not appearanceDefaults[group] then return false end
    MegaMacro_InitialiseConfig()

    if key == "style" then
        if value ~= "full" and value ~= "crop" and value ~= "rounded" then
            return false
        end
    elseif key == "zoom" then
        value = Clamp(value, 0, appearanceLimits[group].zoom)
    elseif key == "spacing" then
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
