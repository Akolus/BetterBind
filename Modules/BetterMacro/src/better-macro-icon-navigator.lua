local FetchesPerFrame = 1000
local DefaultFetchesPerFrame = 250
local MaxTargetedSpellId = 1000000

local IconLoadingStarted = false
local ActiveSearch = nil
local IconCacheRevision = 0

local IconCache = {}
IconCacheKeys = {}
local DefaultIconProvider = nil
local DefaultProviderIconList = nil
local DefaultIconCatalogue = nil
local DefaultIconCataloguePresent = nil
local DefaultScanNextSpellId = 1
local DefaultScanFinished = false

local function AddRange(self, otherTable)
    local selfLength = #self
    for i=1, #otherTable do
        self[selfLength + i] = otherTable[i]
    end
end

local function GetSpellData(identifier)
    if identifier == nil then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local resolvedIdentifier = identifier
        if type(identifier) == "string" and C_Spell.GetSpellIDForSpellIdentifier then
            local ok, spellId = pcall(C_Spell.GetSpellIDForSpellIdentifier, identifier)
            if ok and spellId then
                resolvedIdentifier = spellId
            end
        end

        local spellInfo
        if type(resolvedIdentifier) == "number" then
            spellInfo = C_Spell.GetSpellInfo(resolvedIdentifier)
        else
            local ok, result = pcall(C_Spell.GetSpellInfo, resolvedIdentifier)
            if ok then spellInfo = result end
        end

        if spellInfo and spellInfo.name and spellInfo.iconID then
            return spellInfo.name, spellInfo.spellID or tonumber(identifier), spellInfo.iconID
        end
    end

    -- Keep the navigator usable on clients where the compatibility global is
    -- still present, without making the modern C_Spell API a hard dependency.
    if GetSpellInfo then
        local ok, name, _, icon, _, _, _, spellId = pcall(GetSpellInfo, identifier)
        if ok and name and icon then
            return name, spellId or tonumber(identifier), icon
        end
    end

    return nil
end

local function CacheSpellData(name,spellId,icon)
    if not name or name == "" or not icon or icon == 136243 then
        return nil
    end

    local key = string.lower(name)
    local cachedIconList = IconCache[key]
    if not cachedIconList then
        table.insert(IconCacheKeys, key)
        cachedIconList = {}
        IconCache[key] = cachedIconList
    end

    for i=1, #cachedIconList do
        local cached = cachedIconList[i]
        if cached.Icon == icon then
            return cached
        end
    end

    local item = { SpellId = spellId, Icon = icon }
    table.insert(cachedIconList, item)
    IconCacheRevision = IconCacheRevision + 1
    return item
end

local function CacheSpell(identifier)
    return CacheSpellData(GetSpellData(identifier))
end

local function BeginTargetedSearch(query)
    if ActiveSearch and ActiveSearch.query == query then return end
    ActiveSearch = {
        query = query,
        nextSpellId = 1,
        finished = false,
    }
end

local function GetDefaultIconList()
    -- Use Blizzard's indexed provider when available.  Besides matching the
    -- current Macro UI, this deliberately preserves the provider's complete
    -- ordering (including repeated textures) instead of deduplicating the
    -- catalogue down to the roughly 80 entries seen in the broken browser.
    if DefaultProviderIconList then
        return DefaultProviderIconList
    end
    if DefaultIconProvider == nil
        and type(CreateAndInitFromMixin) == "function"
        and IconDataProviderMixin
        and IconDataProviderExtraType
    then
        local ok, provider = pcall(
            CreateAndInitFromMixin,
            IconDataProviderMixin,
            IconDataProviderExtraType.Spellbook
        )
        DefaultIconProvider = ok and provider or false
    end
    if DefaultIconProvider then
        local ok, count = pcall(DefaultIconProvider.GetNumIcons, DefaultIconProvider)
        if ok and type(count) == "number" and count > 1 then
            local providerIcons = {}
            -- Index 1 is Blizzard's question-mark entry. BetterMacro already
            -- inserts its own explicit "No Icon" entry before this list.
            for index = 2, count do
                local icon = DefaultIconProvider:GetIconByIndex(index)
                if icon then
                    providerIcons[#providerIcons + 1] = { Icon = icon, SpellId = nil }
                end
            end
            if #providerIcons > 0 then
                DefaultProviderIconList = providerIcons
                return DefaultProviderIconList
            end
        end
    end

    local icons = {}
    local presentIcons = {}

    local function AddIcon(icon)
        if not icon then return end
        if type(icon) ~= "number" then
            icon = "INTERFACE\\ICONS\\"..icon
        end
        if presentIcons[icon] then return end
        presentIcons[icon] = true
        icons[#icons + 1] = { Icon = icon, SpellId = nil }
    end

	-- We need to avoid adding duplicate spellIDs from the spellbook tabs for your other specs.
	local activeIcons = {};

	for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLine = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local tab = skillLine.name
        local tabTex = skillLine.iconID
        local offset = skillLine.itemIndexOffset
        local numSpells = skillLine.numSpellBookItems
		offset = offset + 1;
		local tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			--to get spell info by slot, you have to pass in a pet argument
			local spellType, ID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player);
			if (spellType ~= "FUTURESPELL") then
				if (ID) then
					CacheSpell(ID)
				end
				local fileID = C_SpellBook.GetSpellBookItemTexture(j, Enum.SpellBookSpellBank.Player);
				if (fileID) then
					activeIcons[fileID] = true;
				end
			end
			if (spellType == "FLYOUT") then
				local _, _, numSlots, isKnown = GetFlyoutInfo(ID);
				if (isKnown and numSlots > 0) then
					for k = 1, numSlots do
						local spellID
						spellID, _, isKnown = GetFlyoutSlotInfo(ID, k)
						if (isKnown) then
							CacheSpell(spellID)
							local fileID = GetSpellTexture(spellID);
							if (fileID) then
								activeIcons[fileID] = true;
							end
						end
					end
				end
			end
		end
	end

	for fileDataID in pairs(activeIcons) do AddIcon(fileDataID) end

    -- Match Blizzard's current IconDataProvider: spell and item sources are
    -- populated into separate arrays before they are read.  Feeding all four
    -- APIs the same destination can leave only the tail of the catalogue on
    -- some clients.
    local spellIcons = {}
    local itemIcons = {}
	GetLooseMacroIcons(spellIcons)
	GetMacroIcons(spellIcons)
	GetLooseMacroItemIcons(itemIcons)
	GetMacroItemIcons(itemIcons)

    for _,icon in ipairs(spellIcons) do AddIcon(icon) end
    for _,icon in ipairs(itemIcons) do AddIcon(icon) end

    return icons
end

local function EnsureDefaultIconCatalogue()
    if DefaultIconCatalogue then return DefaultIconCatalogue end
    DefaultIconCatalogue = {}
    DefaultIconCataloguePresent = {}
    for _,item in ipairs(GetDefaultIconList()) do
        if item and item.Icon and not DefaultIconCataloguePresent[item.Icon] then
            DefaultIconCataloguePresent[item.Icon] = true
            DefaultIconCatalogue[#DefaultIconCatalogue + 1] = item
        end
    end
    return DefaultIconCatalogue
end

local function AddDefaultSpellIcon(spellId,icon)
    if not icon or icon == 136243 then return false end
    EnsureDefaultIconCatalogue()
    if DefaultIconCataloguePresent[icon] then return false end
    DefaultIconCataloguePresent[icon] = true
    DefaultIconCatalogue[#DefaultIconCatalogue + 1] = {
        SpellId = spellId,
        Icon = icon,
    }
    IconCacheRevision = IconCacheRevision + 1
    return true
end

local function ScanDefaultSpellIcons(fetchLimit,targetCount)
    EnsureDefaultIconCatalogue()
    for _=1, fetchLimit do
        if targetCount and #DefaultIconCatalogue >= targetCount then break end
        local spellId = DefaultScanNextSpellId
        if spellId > MaxTargetedSpellId then
            DefaultScanFinished = true
            break
        end
        DefaultScanNextSpellId = spellId + 1
        local name,resolvedSpellId,icon = GetSpellData(spellId)
        if name and icon then
            CacheSpellData(name,resolvedSpellId,icon)
            AddDefaultSpellIcon(resolvedSpellId,icon)
        end
    end
    return DefaultIconCatalogue
end

MegaMacroIconNavigator = {}

function MegaMacroIconNavigator.BeginLoadingIcons()
    IconLoadingStarted = true
end

function MegaMacroIconNavigator.OnUpdate()
    if not IconLoadingStarted then
        return
    end
    if _G.MegaMacro_PopupFrame and not MegaMacro_PopupFrame:IsShown() then
        return
    end

    if not ActiveSearch then
        local searchText = _G.MegaMacro_IconSearchBox
            and tostring(MegaMacro_IconSearchBox:GetText() or "") or ""
        searchText = searchText:match("^%s*(.-)%s*$") or ""
        if #searchText > 2 or DefaultScanFinished then return end

        ScanDefaultSpellIcons(DefaultFetchesPerFrame)
        return
    end

    if ActiveSearch.finished then return end

    for _=1, FetchesPerFrame do
        local spellId=ActiveSearch.nextSpellId
        if spellId > MaxTargetedSpellId then
            ActiveSearch.finished=true
            table.sort(IconCacheKeys)
            break
        end

        ActiveSearch.nextSpellId=spellId+1
        local name,resolvedSpellId,icon=GetSpellData(spellId)
        if name and icon
            and string.find(string.lower(name),ActiveSearch.query,1,true)
        then
            CacheSpellData(name,resolvedSpellId,icon)
        end
    end
end

function MegaMacroIconNavigator.GetRevision()
    return IconCacheRevision
end

function MegaMacroIconNavigator.Search(searchText)
    local priorityResults = {}
    local otherResults = {}
    local resultCount = 0
    local presentIcons = {}

    local function AddResult(target,item)
        if not item or not item.Icon or presentIcons[item.Icon] then
            return false
        end
        presentIcons[item.Icon] = true
        table.insert(target,item)
        resultCount = resultCount + 1
        return true
    end

    local rawSearch = tostring(searchText or ""):match("^%s*(.-)%s*$")
    local numericId = tonumber(rawSearch)

    if numericId then
        ActiveSearch=nil
        numericId = math.floor(numericId)
        if numericId > 0 then
            local exact = CacheSpell(numericId)
            AddResult(priorityResults,exact)

            -- A numeric query may be either a spell ID or a texture file ID.
            -- Search both the spell cache and the browser's native icon pool.
            for _,key in ipairs(IconCacheKeys) do
                for _,item in ipairs(IconCache[key]) do
                    if item.SpellId == numericId or item.Icon == numericId then
                        AddResult(priorityResults,item)
                    end
                end
            end
            for _,item in ipairs(GetDefaultIconList()) do
                if item.SpellId == numericId or item.Icon == numericId then
                    AddResult(priorityResults,item)
                end
            end

            -- Some spell records are streamed. Ask the client for the data,
            -- then also accept the number directly as a texture file ID. A
            -- valid file ID will render immediately in the browser.
            if resultCount == 0 and C_Spell and C_Spell.RequestLoadSpellData then
                pcall(C_Spell.RequestLoadSpellData, numericId)
            end
            if resultCount == 0 then
                AddResult(priorityResults,{ SpellId = nil, Icon = numericId })
            end
        end
        return priorityResults
    end

    if #rawSearch <= 2 then
        ActiveSearch=nil
        local catalogue = EnsureDefaultIconCatalogue()
        if #catalogue < 100 and not DefaultScanFinished then
            catalogue = ScanDefaultSpellIcons(1000,100)
        end
        return catalogue
    end

    -- Seed the cache from the player's spellbook and retain the native icon
    -- identifiers so texture path/name searches work as well.
    local defaultIcons = GetDefaultIconList()

    -- Resolve a complete localized spell name immediately.  This avoids
    -- making exact-name searches depend on the background spell-ID scan.
    local exact = CacheSpell(rawSearch)
    if exact then
        AddResult(priorityResults,exact)
    end

    local loweredSearch = string.lower(rawSearch)
    BeginTargetedSearch(loweredSearch)

    for _, key in ipairs(IconCacheKeys) do
        local index = string.find(key, loweredSearch, 1, true)

        if index then
            local itemList = IconCache[key]
            for _, item in ipairs(itemList) do
                if not presentIcons[item.Icon] then
                    if index == 1 then
                        AddResult(priorityResults,item)
                    else
                        AddResult(otherResults,item)
                    end

                    if resultCount >= 300 then
                        break
                    end
                end
            end
        end

        if resultCount >= 300 then
            break
        end
    end

    if resultCount < 300 then
        for _,item in ipairs(defaultIcons) do
            local iconText=string.lower(tostring(item.Icon or ""))
            if string.find(iconText,loweredSearch,1,true) then
                AddResult(otherResults,item)
                if resultCount >= 300 then break end
            end
        end
    end

    AddRange(priorityResults, otherResults)
    return priorityResults

end
