-- BetterMacro window controller
--
-- Storage, parsing, icon evaluation, and action-bar behavior intentionally
-- keep their legacy MegaMacro API names. This module owns only window state
-- and UI events, so it can be rebuilt without migrating saved variables.

local RENDERING = {
	MacrosPerRow = 12,
	CharacterLimitFormat = "%s/%s Characters Used",
	BrowserColumns = 10,
	BrowserRows = 10,
	BrowserButtonSize = 41,
	BrowserPollSeconds = 0.15,
}

local POPUP_MODE = { New = 1, Edit = 2 }
local PLUS_TEXTURE = 3192688
local NO_ICON_TEXTURE = MegaMacroTexture

local State = {
	isOpen = false,
	scope = MegaMacroScopes.Global,
	tabIndex = 1,
	items = {},
	buttonsByMacroId = {},
	selectedMacro = nil,
	selectedButton = nil,
	popupMode = nil,
	selectedIcon = nil,
	createdSlotCount = 0,
	refreshingSlots = false,
	browser = {
		initialized = false,
		items = {},
		firstIndex = 1,
		dirty = true,
		lastRevision = -1,
		ticker = nil,
	},
}

NUM_ICONS_PER_ROW = RENDERING.BrowserColumns
NUM_ICON_ROWS = RENDERING.BrowserRows
NUM_MACRO_ICONS_SHOWN = NUM_ICONS_PER_ROW * NUM_ICON_ROWS
MACRO_ICON_ROW_HEIGHT = 44
MegaMacroWindowTogglingMode = false

local function SetEnabled(control, enabled)
	if not control then return end
	if enabled then control:Enable() else control:Disable() end
end

local function GetScopeFromTabIndex(tabIndex)
	local scopes = {
		MegaMacroScopes.Global,
		MegaMacroScopes.Class,
		MegaMacroScopes.Specialization,
		MegaMacroScopes.Character,
		MegaMacroScopes.Inactive,
	}
	return scopes[tabIndex]
end

local function GetMacroButtonUI(index)
	local button = _G["MegaMacro_MacroButton" .. index]
	if not button then return nil, nil, nil end
	return button, button.Name or _G[button:GetName() .. "Name"], button.Icon or _G[button:GetName() .. "Icon"]
end

local function AnchorMacroButton(button, index)
	button:ClearAllPoints()
	if index == 1 then
		button:SetPoint("TOPLEFT", MegaMacro_ButtonContainer, "TOPLEFT", 6, -6)
	elseif mod(index, RENDERING.MacrosPerRow) == 1 then
		button:SetPoint("TOP", _G["MegaMacro_MacroButton" .. (index - RENDERING.MacrosPerRow)], "BOTTOM", 0, -10)
	else
		button:SetPoint("LEFT", _G["MegaMacro_MacroButton" .. (index - 1)], "RIGHT", 13, 0)
	end
end

-- Create slots one page at a time instead of allocating the maximum 192 at
-- XML load. More slots are created only when the plus control requests them.
local function EnsureMacroSlotFrames(count)
	count = math.max(0, math.min(tonumber(count) or 0, HighestMaxMacroCount or 0))
	for index = State.createdSlotCount + 1, count do
		local button = CreateFrame(
			"CheckButton", "MegaMacro_MacroButton" .. index,
			MegaMacro_ButtonContainer, "MegaMacro_ButtonTemplate"
		)
		button:SetID(index)
		AnchorMacroButton(button, index)
		State.createdSlotCount = index
	end
end

local function GetVisibleSlotBounds()
	local slotCount = tonumber(MegaMacro.GetSlotCount(State.scope)) or 0
	if slotCount < 1 then return 0, 0 end
	local pageSize = MegaMacroSlotPageSize or 48
	local maximum = math.ceil(slotCount / pageSize) * pageSize
	local items = MegaMacro.GetMacrosInScope(State.scope) or {}
	local minimum = math.max(pageSize, math.ceil(#items / pageSize) * pageSize)
	return math.min(minimum, maximum), maximum
end

local function GetVisibleSlotCount()
	local minimum, maximum = GetVisibleSlotBounds()
	if maximum == 0 then return 0 end
	MegaMacroConfig = type(MegaMacroConfig) == "table" and MegaMacroConfig or {}
	MegaMacroConfig.VisibleSlotCounts = type(MegaMacroConfig.VisibleSlotCounts) == "table"
		and MegaMacroConfig.VisibleSlotCounts or {}
	local pageSize = MegaMacroSlotPageSize or 48
	local key = tostring(State.tabIndex)
	local visible = tonumber(MegaMacroConfig.VisibleSlotCounts[key]) or pageSize
	visible = math.floor((visible + pageSize / 2) / pageSize) * pageSize
	visible = math.max(minimum, math.min(maximum, visible))
	MegaMacroConfig.VisibleSlotCounts[key] = visible
	return visible
end

local function ShowVisibleMacroSlots()
	local visible = GetVisibleSlotCount()
	EnsureMacroSlotFrames(visible)
	for index = 1, State.createdSlotCount do
		local button = _G["MegaMacro_MacroButton" .. index]
		if button then
			if index <= visible then button:Show() else button:Hide() end
		end
	end
	return visible
end

local function SetButtonEmpty(button, name, icon)
	button.Macro = nil
	button.IsNewButton = false
	button:SetChecked(false)
	name:SetText("")
	icon:SetTexture(nil)
	icon:SetDesaturated(false)
	icon:SetTexCoord(0, 1, 0, 1)
	icon:SetAlpha(1)
end

local function SetButtonNew(button, name, icon)
	button.Macro = nil
	button.IsNewButton = true
	button:SetChecked(false)
	name:SetText("")
	icon:SetTexture(PLUS_TEXTURE)
	icon:SetDesaturated(true)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetAlpha(0.5)
end

local function SetButtonMacro(button, name, icon, macro)
	button.Macro = macro
	button.IsNewButton = false
	button:SetChecked(false)
	name:SetText(macro.DisplayName or "")
	MegaMacroIconEvaluator.UpdateMacro(macro)
	local data = MegaMacroIconEvaluator.GetCachedData(macro.Id)
	icon:SetTexture(data and data.Icon or NO_ICON_TEXTURE)
	icon:SetDesaturated(false)
	icon:SetTexCoord(0, 1, 0, 1)
	icon:SetAlpha(1)
	if not MegaMacroEngine.GetMacroIndexFromId(macro.Id) then
		icon:SetAlpha(0.5)
		icon:SetDesaturated(true)
	end
end

local function SaveMacro()
	local macro = State.selectedMacro
	if macro and MegaMacro_FrameText then
		local code = MegaMacro_FrameText:GetText() or ""
		if macro.Code ~= code then MegaMacro.UpdateCode(macro, code) end
	end
	SetEnabled(MegaMacro_SaveButton, false)
	SetEnabled(MegaMacro_CancelButton, false)
end

local function RefreshSelectedMacroIcon()
	local texture
	local macro = State.selectedMacro
	if macro then
		if State.selectedIcon == NO_ICON_TEXTURE then
			local data = MegaMacroIconEvaluator.GetCachedData(macro.Id)
			texture = data and data.Icon or NO_ICON_TEXTURE
		else
			local fallback = MegaMacro_FallbackTextureCheckBox and MegaMacro_FallbackTextureCheckBox:GetChecked()
			texture = select(4, MegaMacroIconEvaluator.ComputeMacroIcon(macro, State.selectedIcon, fallback))
		end
	end
	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(texture)
end

local function RefreshBrowserChecks()
	if not State.browser.initialized then return end
	for index = 1, NUM_MACRO_ICONS_SHOWN do
		local button = _G["MegaMacro_PopupButton" .. index]
		local icon = _G["MegaMacro_PopupButton" .. index .. "Icon"]
		if button and icon then
			button:SetChecked(State.selectedIcon == icon:GetTexture())
			if button.__BetterAppearanceRefreshSelection then
				button:__BetterAppearanceRefreshSelection()
			end
		end
	end
end

local function SelectIcon(texture)
	State.selectedIcon = texture or NO_ICON_TEXTURE
	RefreshSelectedMacroIcon()
	RefreshBrowserChecks()
end

local function ClearSelectedMacroUI()
	if State.selectedButton then State.selectedButton:SetChecked(false) end
	State.selectedMacro = nil
	State.selectedButton = nil
	MegaMacro_FrameSelectedMacroName:SetText("")
	MegaMacro_FrameSelectedMacroButtonIcon:SetTexture(nil)
	MegaMacro_FrameText:SetText("")
	SetEnabled(MegaMacro_EditButton, false)
	SetEnabled(MegaMacro_DeleteButton, false)
	SetEnabled(MegaMacro_SaveButton, false)
	SetEnabled(MegaMacro_CancelButton, false)
	MegaMacro_FrameText:Disable()
end

local function SelectMacro(macro, skipSave)
	if not skipSave then SaveMacro() end
	if MegaMacro_PopupFrame then MegaMacro_PopupFrame:Hide() end
	ClearSelectedMacroUI()
	if macro then
		local button = State.buttonsByMacroId[macro.Id]
		State.selectedMacro = macro
		State.selectedButton = button
		if button then button:SetChecked(true) end
		MegaMacro_FrameSelectedMacroName:SetText(macro.DisplayName or "")
		MegaMacro_FrameText:SetText(macro.Code or "")
		MegaMacro_FrameText:Enable()
		SetEnabled(MegaMacro_EditButton, true)
		SetEnabled(MegaMacro_DeleteButton, true)
	end
	SelectIcon(macro and macro.StaticTexture or NO_ICON_TEXTURE)
	if _G.BPMM74 and _G.BPMM74.SetSelected then _G.BPMM74.SetSelected(State.selectedMacro) end
end

local function RefreshMacroItems(preferredMacro)
	if State.refreshingSlots then return end
	State.refreshingSlots = true
	local visible = ShowVisibleMacroSlots()
	local scopeLimit = tonumber(MegaMacro.GetSlotCount(State.scope)) or 0
	State.items = MegaMacro.GetMacrosInScope(State.scope) or {}
	table.sort(State.items, function(left, right)
		return (left.DisplayName or "") < (right.DisplayName or "")
	end)
	wipe(State.buttonsByMacroId)
	local newButtonCreated = false
	for index = 1, visible do
		local button, name, icon = GetMacroButtonUI(index)
		if button and name and icon then
			local macro = State.items[index]
			if macro then
				SetButtonMacro(button, name, icon, macro)
				State.buttonsByMacroId[macro.Id] = button
			elseif index <= scopeLimit and not newButtonCreated and State.scope ~= MegaMacroScopes.Inactive then
				SetButtonNew(button, name, icon)
				newButtonCreated = true
			else
				SetButtonEmpty(button, name, icon)
			end
		end
	end
	State.refreshingSlots = false
	local candidate = preferredMacro
	if not candidate or not State.buttonsByMacroId[candidate.Id] then candidate = State.items[1] end
	SelectMacro(candidate, true)
end

local function UpdateSearchPlaceholder()
	if not MegaMacro_IconSearchPlaceholder or not MegaMacro_IconSearchBox then return end
	MegaMacro_IconSearchPlaceholder:SetAlpha(MegaMacro_IconSearchBox:GetText() == "" and 0.4 or 0)
end

local function MarkBrowserDirty()
	State.browser.dirty = true
end

local function UpdateIconList(resetPage)
	local search = MegaMacro_IconSearchBox and MegaMacro_IconSearchBox:GetText() or ""
	local results = MegaMacroIconNavigator.Search(search) or {}
	local items = { { Name = "No Icon", Icon = NO_ICON_TEXTURE } }
	for index = 1, #results do items[index + 1] = results[index] end
	State.browser.items = items
	local lastStart = math.max(1, #items - NUM_MACRO_ICONS_SHOWN + 1)
	if resetPage ~= false then
		State.browser.firstIndex = 1
	else
		State.browser.firstIndex = math.max(1, math.min(lastStart, State.browser.firstIndex))
	end
	MarkBrowserDirty()
end

local function BuildIconButtons()
	if State.browser.initialized then return end
	local container = _G.MegaMacro_PopupScrollFrameScrollChildFrame or MegaMacro_PopupFrame
	local appearance = BetterBindAppearance_Get and BetterBindAppearance_Get("browser") or nil
	local spacing = appearance and appearance.spacing or 4
	for index = 1, NUM_MACRO_ICONS_SHOWN do
		local name = "MegaMacro_PopupButton" .. index
		local button = _G[name] or CreateFrame("CheckButton", name, container, "MegaMacro_PopupButtonTemplate")
		button:SetParent(container)
		button:SetID(index)
		button:SetSize(RENDERING.BrowserButtonSize, RENDERING.BrowserButtonSize)
		button:ClearAllPoints()
		local column = (index - 1) % NUM_ICONS_PER_ROW
		local row = math.floor((index - 1) / NUM_ICONS_PER_ROW)
		button:SetPoint(
			"TOPLEFT", container, "TOPLEFT",
			5 + column * (RENDERING.BrowserButtonSize + spacing),
			-5 - row * (RENDERING.BrowserButtonSize + spacing)
		)
	end
	State.browser.initialized = true
	MarkBrowserDirty()
end

local function RenderIconPage(force)
	if not State.browser.initialized or (not force and not State.browser.dirty) then return end
	State.browser.dirty = false
	local itemCount = #State.browser.items
	local lastStart = math.max(1, itemCount - NUM_MACRO_ICONS_SHOWN + 1)
	State.browser.firstIndex = math.max(1, math.min(lastStart, State.browser.firstIndex))
	for buttonIndex = 1, NUM_MACRO_ICONS_SHOWN do
		local button = _G["MegaMacro_PopupButton" .. buttonIndex]
		local icon = _G["MegaMacro_PopupButton" .. buttonIndex .. "Icon"]
		local item = State.browser.items[State.browser.firstIndex + buttonIndex - 1]
		if button and icon then
			if item then
				icon:SetTexture(item.Icon)
				button.SpellId = item.SpellId
				button:Show()
			else
				icon:SetTexture(nil)
				button.SpellId = nil
				button:Hide()
			end
			button:SetChecked(item and State.selectedIcon == item.Icon or false)
			if button.__BetterAppearanceRefreshSelection then button:__BetterAppearanceRefreshSelection() end
		end
	end
end

local function PollBrowserResults()
	if not MegaMacro_PopupFrame or not MegaMacro_PopupFrame:IsShown() then return end
	if not MegaMacroIconNavigator.GetRevision then return end
	local revision = MegaMacroIconNavigator.GetRevision()
	if revision ~= State.browser.lastRevision then
		State.browser.lastRevision = revision
		UpdateIconList(false)
		RenderIconPage()
	end
end

local function StartBrowserTicker()
	if State.browser.ticker or not C_Timer or not C_Timer.NewTicker then return end
	State.browser.ticker = C_Timer.NewTicker(RENDERING.BrowserPollSeconds, PollBrowserResults)
end

local function StopBrowserTicker()
	if State.browser.ticker then
		State.browser.ticker:Cancel()
		State.browser.ticker = nil
	end
end

local function OpenMacroDetails(mode)
	if mode == POPUP_MODE.Edit and not State.selectedMacro then return end
	State.popupMode = mode
	BuildIconButtons()
	if mode == POPUP_MODE.Edit then
		MegaMacro_PopupEditBox:SetText(State.selectedMacro.DisplayName or "")
		MegaMacro_FallbackTextureCheckBox:SetChecked(State.selectedMacro.IsStaticTextureFallback)
		MegaMacro_DisplayNameLabel:SetText("Name")
		if _G.BetterBindAppearance_SetBrowserMacroMetadata then
			BetterBindAppearance_SetBrowserMacroMetadata(State.selectedMacro.Id)
		end
		SelectIcon(State.selectedMacro.StaticTexture)
	else
		MegaMacro_PopupEditBox:SetText("")
		MegaMacro_FallbackTextureCheckBox:SetChecked(true)
		MegaMacro_DisplayNameLabel:SetText("Name")
		if _G.BetterBindAppearance_SetBrowserMacroMetadata then
			BetterBindAppearance_SetBrowserMacroMetadata(nil, true)
		end
		SelectIcon(NO_ICON_TEXTURE)
	end
	MegaMacro_IconSearchBox:SetText("")
	UpdateIconList(true)
	MegaMacro_PopupFrame:Show()
	RenderIconPage(true)
	if MegaMacro_PopupFrame.Raise then MegaMacro_PopupFrame:Raise() end
	MegaMacro_PopupEditBox:SetFocus()
end

local function NewMacro()
	SaveMacro()
	SelectMacro(nil, true)
	local button = _G["MegaMacro_MacroButton" .. (#State.items + 1)]
	if button then button:SetChecked(true) end
	OpenMacroDetails(POPUP_MODE.New)
end

local function DeleteSelectedMacro()
	if not State.selectedMacro then return end
	MegaMacro.Delete(State.selectedMacro)
	RefreshMacroItems()
end

local function UpdateTooltipIfButtonIsHovered(macroId)
	local mouseFocus
	if GetMouseFoci then
		local foci = GetMouseFoci()
		mouseFocus = foci and foci[1]
	elseif GetMouseFocus then
		mouseFocus = GetMouseFocus()
	end
	if not mouseFocus or not mouseFocus.GetName then return end
	local name = mouseFocus:GetName()
	if not name then return end
	if string.find(name, "^MegaMacro_MacroButton%d+$") then
		local macro = _G[name].Macro
		if macro and macro.Id == macroId then ShowToolTipForMegaMacro(macro.Id) end
	elseif name == "MegaMacro_FrameSelectedMacroButton"
		and State.selectedMacro and State.selectedMacro.Id == macroId
	then
		ShowToolTipForMegaMacro(State.selectedMacro.Id)
	end
end

local function PickupMegaMacro(macro)
	if not macro then return end
	for index = 1, 5 do
		if index ~= State.tabIndex then
			local tab = _G["MegaMacro_FrameTab" .. index]
			if tab then tab:LockHighlight() end
		end
	end
	local macroIndex = MegaMacroEngine.GetMacroIndexFromId(macro.Id)
	if macroIndex then PickupMacro(macroIndex) end
end

local function HandleReceiveDrag(targetScope)
	if not targetScope then return false end
	local cursorType, macroIndex = GetCursorInfo()
	if cursorType ~= "macro" then return cursorType ~= nil end
	local macroId = MegaMacroEngine.GetMacroIdFromIndex(macroIndex)
	if macroId then
		local macro = MegaMacro.GetById(macroId)
		ClearCursor()
		if not macro then return true end
		if IsControlKeyDown() then
			local displayName = macro.Scope == targetScope and (macro.DisplayName .. " copy") or macro.DisplayName
			local created = MegaMacro.Create(
				displayName, targetScope, macro.StaticTexture,
				macro.IsStaticTextureFallback, macro.Code
			)
			if not created then
				print("BetterMacro: The target scope is full.")
			elseif targetScope == State.scope then
				RefreshMacroItems(created)
			end
		elseif targetScope ~= macro.Scope then
			local oldScope = macro.Scope
			local moved = MegaMacro.Move(macro, targetScope)
			if not moved then
				print("BetterMacro: The target scope is full.")
			elseif targetScope == State.scope then
				RefreshMacroItems(moved)
			elseif oldScope == State.scope then
				RefreshMacroItems()
			end
		end
		return true
	end

	-- Import a native macro. Protected action-bar replacement is skipped in combat.
	ClearCursor()
	local name, _, body = GetMacroInfo(macroIndex)
	local created = MegaMacro.Create(name, targetScope, NO_ICON_TEXTURE, false, body)
	if not created then
		print("BetterMacro: The target scope is full; the original macro was not changed.")
		return true
	end
	if targetScope == State.scope then RefreshMacroItems(created) end
	if not InCombatLockdown() then
		local newIndex = MegaMacroEngine.GetMacroIndexFromId(created.Id)
		if newIndex then
			for action = 1, 120 do
				local actionType, actionArg = GetActionInfo(action)
				local secret = type(_G.issecretvalue) == "function"
					and (issecretvalue(actionType) or issecretvalue(actionArg))
				if not secret and actionType == "macro" and actionArg == macroIndex then
					PickupMacro(newIndex)
					PlaceAction(action)
					ClearCursor()
				end
			end
		end
		DeleteMacro(macroIndex)
		if MacroFrame and MacroFrame:IsVisible() and MacroFrame_Update then MacroFrame_Update() end
	end
	return true
end

local function InitializeTabs()
	MegaMacro_FrameTab2:SetText(MegaMacroCachedClass or "Class")
	MegaMacro_FrameTab4:SetText(UnitName("player") or "Character")
	MegaMacro_FrameTab5:SetText("Inactive")
	if MegaMacroCachedSpecialization == "" then
		MegaMacro_FrameTab3:SetText("Locked")
		MegaMacro_FrameTab3:Disable()
	else
		MegaMacro_FrameTab3:SetText(MegaMacroCachedSpecialization or "Specialization")
		MegaMacro_FrameTab3:Enable()
	end
end

local function ConfigureCharacterLimitTooltip()
	if not MegaMacro_FrameCharLimitText or MegaMacro_FrameCharLimitText.__BetterMacroTooltip then return end
	MegaMacro_FrameCharLimitText.__BetterMacroTooltip = true
	MegaMacro_FrameCharLimitText:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine("BetterMacro: Character Limit", 1, 1, 1)
		GameTooltip:AddLine(
			"\nMacros over 250 characters rely on BetterMacro's extended macro engine.",
			1, 1, 1, true
		)
		GameTooltip:Show()
	end)
	MegaMacro_FrameCharLimitText:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

StaticPopupDialogs["CONFIRM_DELETE_SELECTED_MEGA_MACRO"] = {
	text = CONFIRM_DELETE_MACRO,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = DeleteSelectedMacro,
	timeout = 0,
	whileDead = 1,
	showAlert = 1,
}

MegaMacroWindow = {
	Show = function()
		if MegaMacroConfig_IsWindowDialog() then
			MegaMacro_Frame:SetMovable(false)
			if MegaMacro_ToggleWindowModeButton then MegaMacro_ToggleWindowModeButton:SetText("Unlock") end
			ShowUIPanel(MegaMacro_Frame)
		else
			local relativePoint, x, y = MegaMacroConfig_GetWindowPosition()
			MegaMacro_Frame:SetMovable(true)
			MegaMacro_Frame:SetSize(722, 696)
			MegaMacro_Frame:ClearAllPoints()
			MegaMacro_Frame:SetPoint(relativePoint, UIParent, relativePoint, x, y)
			if MegaMacro_ToggleWindowModeButton then MegaMacro_ToggleWindowModeButton:SetText("Lock") end
			MegaMacro_Frame:Show()
		end
	end,
	IsOpen = function() return State.isOpen end,
	SaveMacro = SaveMacro,
	OnSpecializationChanged = function()
		InitializeTabs()
		RefreshMacroItems(State.selectedMacro)
	end,
}

function BetterMacro_GetSelectedTabIndex()
	return State.tabIndex
end

function BetterMacro_GetSelectedMacro()
	return State.selectedMacro
end

function BetterMacro_GetVisibleSlotCount()
	return GetVisibleSlotCount()
end

function BetterMacro_GetVisibleSlotBounds()
	return GetVisibleSlotBounds()
end

function BetterMacro_AdjustVisibleSlots(direction)
	local minimum, maximum = GetVisibleSlotBounds()
	local current = GetVisibleSlotCount()
	local pageSize = MegaMacroSlotPageSize or 48
	local nextVisible = math.max(minimum, math.min(maximum, current + (direction < 0 and -pageSize or pageSize)))
	if nextVisible == current then return false end
	MegaMacroConfig.VisibleSlotCounts[tostring(State.tabIndex)] = nextVisible
	RefreshMacroItems(State.selectedMacro)
	if _G.BPMMGoalLayout and _G.BPMMGoalLayout.ApplyMegaMacroGrid then
		_G.BPMMGoalLayout.ApplyMegaMacroGrid()
	end
	-- Stage 8 owns the custom cell border. Apply it to frames that were just
	-- created for this page so lazy allocation never exposes Blizzard chrome.
	if _G.BPMM84 and type(_G.BPMM84.Apply) == "function" and C_Timer then
		C_Timer.After(0, _G.BPMM84.Apply)
	end
	return true
end

function BetterMacro_IconBrowserScroll(delta)
	if not delta or delta == 0 then return end
	local lastStart = math.max(1, #State.browser.items - NUM_MACRO_ICONS_SHOWN + 1)
	local step = delta < 0 and NUM_ICONS_PER_ROW or -NUM_ICONS_PER_ROW
	State.browser.firstIndex = math.max(1, math.min(lastStart, State.browser.firstIndex + step))
	MarkBrowserDirty()
	RenderIconPage()
end

function BetterMacro_GetIconBrowserPageState()
	return State.browser.firstIndex, #State.browser.items
end

function BetterMacro_RefreshIconBrowser(resetPage)
	BuildIconButtons()
	UpdateIconList(resetPage ~= false)
	State.browser.lastRevision = MegaMacroIconNavigator.GetRevision and MegaMacroIconNavigator.GetRevision() or -1
	RenderIconPage()
end

function MegaMacro_OnIconUpdated(macroId, texture)
	if not State.isOpen then return end
	if State.selectedMacro and State.selectedMacro.Id == macroId then RefreshSelectedMacroIcon() end
	local button = State.buttonsByMacroId[macroId]
	if button then
		local _, _, icon = GetMacroButtonUI(button:GetID())
		if icon then icon:SetTexture(texture) end
	end
	UpdateTooltipIfButtonIsHovered(macroId)
end

function MegaMacro_Window_OnLoad()
	PanelTemplates_SetNumTabs(MegaMacro_Frame, 5)
	PanelTemplates_SetTab(MegaMacro_Frame, 1)
	ConfigureCharacterLimitTooltip()
	MegaMacroIconEvaluator.OnIconUpdated(MegaMacro_OnIconUpdated)
end

function MegaMacro_Window_OnShow()
	State.isOpen = true
	InitializeTabs()
	ConfigureCharacterLimitTooltip()
	UpdateSearchPlaceholder()
	if MegaMacro_FallbackTextureDescription then MegaMacro_FallbackTextureDescription:SetAlpha(0.6) end
	RefreshMacroItems(State.selectedMacro)
end

function MegaMacro_Window_OnHide()
	SaveMacro()
	State.isOpen = false
	if MegaMacro_PopupFrame then MegaMacro_PopupFrame:Hide() end
end

function MegaMacro_Window_OnDragStop()
	local _, _, relativePoint, x, y = MegaMacro_Frame:GetPoint()
	MegaMacroGlobalData.WindowInfo.RelativePoint = relativePoint
	MegaMacroGlobalData.WindowInfo.X = x
	MegaMacroGlobalData.WindowInfo.Y = y
end

function MegaMacro_FrameTab_OnClick(self)
	local tabIndex = self:GetID()
	local scope = GetScopeFromTabIndex(tabIndex)
	if HandleReceiveDrag(scope) then return end
	SaveMacro()
	PanelTemplates_SetTab(MegaMacro_Frame, tabIndex)
	if MegaMacro_ButtonScrollFrame then MegaMacro_ButtonScrollFrame:SetVerticalScroll(0) end
	if MegaMacro_ConfigContainer then MegaMacro_ConfigContainer:Hide() end
	State.scope = scope
	State.tabIndex = tabIndex
	InitializeTabs()
	RefreshMacroItems()
end

-- Compatibility entry point for old hooks. The Config tab no longer exists.
function MegaMacro_FrameTab_ShowConfig()
	if MegaMacro_ConfigContainer then MegaMacro_ConfigContainer:Hide() end
end

function MegaMacro_FrameTab_OnReceiveDrag(self)
	HandleReceiveDrag(GetScopeFromTabIndex(self:GetID()))
end

function MegaMacro_ButtonContainer_OnLoad()
	EnsureMacroSlotFrames(MegaMacroSlotPageSize or 48)
end

function MegaMacro_ButtonContainer_OnShow()
	ShowVisibleMacroSlots()
end

function MegaMacro_ButtonContainer_OnReceiveDrag()
	HandleReceiveDrag(State.scope)
end

function MegaMacro_MacroButton_OnClick(self, mouseButton)
	if HandleReceiveDrag(State.scope) then return end
	if self.Macro then
		SelectMacro(self.Macro)
		if mouseButton == "RightButton" then OpenMacroDetails(POPUP_MODE.Edit) end
	elseif self.IsNewButton then
		NewMacro()
	else
		self:SetChecked(false)
	end
end

function MegaMacro_MacroButton_OnEnter(self)
	if self.Macro then ShowToolTipForMegaMacro(self.Macro.Id) end
end

function MegaMacro_MacroButton_OnLeave()
	GameTooltip:Hide()
end

function MegaMacro_MacroButton_OnDragStart(self)
	PickupMegaMacro(self.Macro)
end

function MegaMacro_MacroButton_OnDragStop()
	for index = 1, 5 do
		local tab = _G["MegaMacro_FrameTab" .. index]
		if tab then tab:UnlockHighlight() end
	end
end

function MegaMacro_MacroButton_OnReceiveDrag()
	HandleReceiveDrag(State.scope)
end

function MegaMacro_FrameSelectedMacroButton_OnEnter()
	if State.selectedMacro then ShowToolTipForMegaMacro(State.selectedMacro.Id) end
end

function MegaMacro_FrameSelectedMacroButton_OnLeave()
	GameTooltip:Hide()
end

function MegaMacro_FrameSelectedMacroButton_OnDragStart()
	PickupMegaMacro(State.selectedMacro)
end

function MegaMacro_FrameTextButton_OnClick()
	if State.selectedMacro then MegaMacro_FrameText:SetFocus() end
end

function MegaMacro_TextBox_OnKeyDown(_, key)
	if State.selectedMacro and key == "S" and IsControlKeyDown() then
		MegaMacro_SaveButton_OnClick()
		MegaMacro_FrameText:SetFocus()
	end
end

function MegaMacro_TextBox_TextChanged(self)
	local text = self:GetText() or ""
	local changed = State.selectedMacro and State.selectedMacro.Code ~= text
	SetEnabled(MegaMacro_SaveButton, changed)
	SetEnabled(MegaMacro_CancelButton, changed)
	local length = self:GetNumLetters()
	MegaMacro_FrameCharLimitText:SetFormattedText(RENDERING.CharacterLimitFormat, length, MegaMacroCodeMaxLength)
	if length > MegaMacroCodeMaxLength then
		MegaMacro_FrameCharLimitText:SetTextColor(1, 0.267, 0.267)
	elseif length > MegaMacroCodeMaxLengthForNative then
		MegaMacro_FrameCharLimitText:SetTextColor(1, 0.85, 0)
	else
		MegaMacro_FrameCharLimitText:SetTextColor(1, 1, 1)
	end
	if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, self:GetParent()) end
	if MegaMacro_FormattedFrameText then
		local ok, formatted = pcall(MegaMacroParser.Parse, text)
		MegaMacro_FormattedFrameText:SetText(ok and formatted or text)
		if ScrollingEdit_OnTextChanged then
			ScrollingEdit_OnTextChanged(MegaMacro_FormattedFrameText, MegaMacro_FormattedFrameText:GetParent())
		end
	end
end

function MegaMacro_CancelButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if State.selectedMacro then MegaMacro_FrameText:SetText(State.selectedMacro.Code or "") end
	MegaMacro_FrameText:ClearFocus()
	SetEnabled(MegaMacro_CancelButton, false)
end

function MegaMacro_SaveButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	SaveMacro()
	MegaMacro_FrameText:ClearFocus()
end

function MegaMacro_EditButton_OnClick()
	OpenMacroDetails(POPUP_MODE.Edit)
end

function MegaMacro_BlizMacro_Toggle()
	MegaMacroEngine.SafeInitialize()
	MegaMacro_InitialiseConfig()
	MegaMacro_FrameCharLimitText:SetFormattedText(
		RENDERING.CharacterLimitFormat,
		MegaMacro_FrameText:GetNumLetters(),
		MegaMacroCodeMaxLength
	)
end

function MegaMacro_EditOkButton_OnClick()
	local displayName = MegaMacro_PopupEditBox:GetText() or ""
	local fallback = MegaMacro_FallbackTextureCheckBox:GetChecked()
	if State.popupMode == POPUP_MODE.Edit and State.selectedMacro then
		local macro = State.selectedMacro
		MegaMacro.UpdateDetails(macro, displayName, State.selectedIcon, fallback)
		RefreshMacroItems(macro)
	elseif State.popupMode == POPUP_MODE.New then
		local macro = MegaMacro.Create(displayName, State.scope, State.selectedIcon, fallback)
		RefreshMacroItems(macro)
		if macro then MegaMacro_FrameText:SetFocus() end
	end
	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditOkButton_OnClick_Wrapper()
	MegaMacro_EditOkButton_OnClick()
end

function MegaMacro_EditCancelButton_OnClick()
	SelectIcon(State.selectedMacro and State.selectedMacro.StaticTexture or NO_ICON_TEXTURE)
	MegaMacro_PopupFrame:Hide()
end

function MegaMacro_EditCancelButton_OnClick_Wrapper()
	MegaMacro_EditCancelButton_OnClick()
end

function MegaMacro_PopupFrame_OnShow()
	BuildIconButtons()
	UpdateIconList(false)
	State.browser.lastRevision = MegaMacroIconNavigator.GetRevision and MegaMacroIconNavigator.GetRevision() or -1
	RenderIconPage(true)
	StartBrowserTicker()
end

function MegaMacro_PopupFrame_OnHide()
	StopBrowserTicker()
end

-- Compatibility entry point. It no longer redraws 100 buttons every frame.
function MegaMacro_PopupFrame_OnUpdate()
	PollBrowserResults()
	RenderIconPage()
end

function MegaMacro_PopupButton_OnClick(self)
	local icon = _G[self:GetName() .. "Icon"]
	if icon then SelectIcon(icon:GetTexture()) end
end

function MegaMacro_PopupButton_OnEnter(self)
	if not self.SpellId then return end
	GameTooltip:Hide()
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetSpellByID(self.SpellId)
	GameTooltip:Show()
end

function MegaMacro_PopupButton_OnLeave()
	GameTooltip:Hide()
end

function MegaMacro_ToggleWindowModeButton_OnClick()
	if MegaMacroConfig_IsWindowDialog() then
		local _, _, relativePoint, x, y = MegaMacro_Frame:GetPoint()
		MegaMacroGlobalData.WindowInfo = { IsDialog = false, RelativePoint = relativePoint, X = x, Y = y }
	else
		MegaMacroGlobalData.WindowInfo = nil
	end
	MegaMacroWindowTogglingMode = true
	HideUIPanel(MegaMacro_Frame)
	MegaMacroWindow.Show()
	MegaMacroWindowTogglingMode = false
end

function MegaMacro_FallbackTextureCheckBox_OnClick()
	RefreshSelectedMacroIcon()
end

function MegaMacro_IconSearchBox_TextChanged()
	UpdateSearchPlaceholder()
	UpdateIconList(true)
	State.browser.lastRevision = MegaMacroIconNavigator.GetRevision and MegaMacroIconNavigator.GetRevision() or -1
	RenderIconPage()
end

function MegaMacro_RegisterShiftClicks()
	local function ShiftClickSpell(self)
		if not MegaMacro_FrameText or not MegaMacro_FrameText:HasFocus() then return end
		if not IsModifiedClick("CHATLINK") or not SpellBook_GetSpellBookSlot then return end
		local slot = SpellBook_GetSpellBookSlot(self)
		if not slot or (MAX_SPELLS and slot > MAX_SPELLS) then return end
		local spellName, subSpellName = GetSpellBookItemName(slot, SpellBookFrame.bookType)
		if spellName and not IsPassiveSpell(slot, SpellBookFrame.bookType) then
			if subSpellName and subSpellName ~= "" then
				MegaMacro_FrameText:Insert(spellName .. "(" .. subSpellName .. ")")
			else
				MegaMacro_FrameText:Insert(spellName)
			end
		end
	end
	for index = 1, 120 do
		local button = _G["SpellButton" .. index]
		if button and button.OnModifiedClick then hooksecurefunc(button, "OnModifiedClick", ShiftClickSpell) end
	end
end

-- The removed Config-tab constructors remain as no-ops for old hooks.
function MecaMacro_GenerateConfig() end
function MecaMacroConfig_GenerateCheckbox() return nil end
function MecaMacroConfig_GenerateButton() return nil end
