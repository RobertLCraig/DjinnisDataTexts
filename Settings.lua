local addonName, ns = ...
local DDT = ns.addon

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------

local function AddHeader(content, y, text)
    y = y - 8
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    header:SetText(text)

    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return y - 22
end

local function AddCheckbox(content, y, label, getter, setter, refreshList)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    text:SetText(label)

    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    if refreshList then
        table.insert(refreshList, function() cb:SetChecked(getter()) end)
    end
    return y - 26
end

local function AddSlider(content, y, label, min, max, step, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local slider = CreateFrame("Slider", nil, content)
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(240)
    slider:SetHeight(16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    bg:SetAllPoints()
    bg:SetTexCoord(0, 1, 0, 1)

    local function FormatVal(v)
        if step < 1 then
            return string.format("%.2f", v)
        else
            return tostring(math.floor(v + 0.5))
        end
    end

    local input = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    input:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    input:SetSize(54, 22)
    input:SetAutoFocus(false)
    input:SetFontObject(GameFontHighlightSmall)
    input:SetJustifyH("CENTER")
    input:SetMaxLetters(8)
    input:SetTextInsets(4, 4, 0, 0)
    input:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, edgeSize = 1, tileSize = 5,
    })
    input:SetBackdropColor(0, 0, 0, 0.5)
    input:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    -- FontString overlay -- always shows the current value
    local valText = input:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("CENTER", input, "CENTER", 0, 0)
    valText:SetJustifyH("CENTER")
    valText:SetText(FormatVal(getter()))

    input:SetScript("OnEditFocusGained", function(self)
        valText:Hide()
        self:SetText(FormatVal(getter()))
        self:HighlightText()
    end)
    input:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        valText:SetText(FormatVal(getter()))
        valText:Show()
    end)
    input:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    input:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        setter(value)
        valText:SetText(FormatVal(value))
        input:SetText(FormatVal(value))
    end)
    slider:SetValue(getter())

    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(min, math.min(max, val))
            val = math.floor(val / step + 0.5) * step
            setter(val)
            slider:SetValue(val)
        else
            self:SetText(FormatVal(getter()))
        end
        self:ClearFocus()
    end)

    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    if refreshList then
        table.insert(refreshList, function()
            slider:SetValue(getter())
            valText:SetText(FormatVal(getter()))
        end)
    end
    return y - 48
end

local function AddDropdown(content, y, label, values, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    dropdown:SetWidth(200)

    dropdown:SetupMenu(function(owner, rootDescription)
        local sorted = {}
        for value, displayText in pairs(values) do
            table.insert(sorted, { value = value, text = displayText })
        end
        table.sort(sorted, function(a, b)
            -- "none" always first
            if a.value == "none" and b.value ~= "none" then return true end
            if b.value == "none" and a.value ~= "none" then return false end
            return a.text < b.text
        end)

        for _, item in ipairs(sorted) do
            rootDescription:CreateButton(item.text, function()
                setter(item.value)
            end):SetIsSelected(function() return getter() == item.value end)
        end
    end)

    if refreshList then
        table.insert(refreshList, function()
            dropdown:GenerateMenu()
        end)
    end
    return y - 54
end

local function AddEditBox(content, y, label, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    local editbox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    editbox:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 4, -4)
    editbox:SetSize(380, 20)
    editbox:SetAutoFocus(false)
    editbox:SetText(getter())
    editbox:SetTextColor(0, 0, 0, 0) -- hide native text; valText overlay renders instead

    -- FontString overlay -- always renders reliably inside scroll children
    local valText = editbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", editbox, "LEFT", 6, 0)
    valText:SetPoint("RIGHT", editbox, "RIGHT", -6, 0)
    valText:SetJustifyH("LEFT")
    valText:SetText(getter())

    editbox:SetScript("OnEditFocusGained", function(self)
        valText:Hide()
        self:SetTextColor(1, 1, 1, 1)
        self:SetText(getter())
        self:HighlightText()
    end)
    editbox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetTextColor(0, 0, 0, 0)
        valText:SetText(getter())
        valText:Show()
    end)
    editbox:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        valText:SetText(self:GetText())
        self:ClearFocus()
    end)
    editbox:SetScript("OnEscapePressed", function(self)
        self:SetText(getter())
        valText:SetText(getter())
        self:ClearFocus()
    end)

    if refreshList then
        table.insert(refreshList, function()
            editbox:SetText(getter())
            valText:SetText(getter())
        end)
    end
    return y - 44
end

local function AddButton(content, y, label, onClick)
    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    btn:SetSize(160, 24)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return y - 30
end

local function AddDescription(content, y, text)
    y = y - 6
    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    desc:SetPoint("RIGHT", content, "RIGHT", -18, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetSpacing(2)
    desc:SetText(text)
    local cw = content:GetWidth()
    if cw and cw > 50 then
        desc:SetWidth(cw - 36)
    end
    local h = desc:GetStringHeight() or 14
    return y - h - 12
end

-- Expose widget helpers for use by module settings panels
ns.SettingsWidgets = {
    AddHeader      = AddHeader,
    AddCheckbox    = AddCheckbox,
    AddSlider      = AddSlider,
    AddDropdown    = AddDropdown,
    AddEditBox     = AddEditBox,
    AddButton      = AddButton,
    AddDescription = AddDescription,
}

---------------------------------------------------------------------------
-- Panel builder
---------------------------------------------------------------------------

local function CreateScrollPanel()
    local panel = CreateFrame("Frame")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -5)
    scroll:SetPoint("BOTTOMRIGHT", -24, 5)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(560)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.refreshCallbacks = {}

    panel:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(math.max(w - 30, 400))
    end)

    panel:SetScript("OnShow", function(self)
        for _, cb in ipairs(self.refreshCallbacks) do
            cb()
        end
    end)

    return panel
end

ns.CreateScrollPanel = CreateScrollPanel

---------------------------------------------------------------------------
-- Shared section builders
---------------------------------------------------------------------------

local CLICK_ACTION_KEYS = {
    { key = "leftClick",       label = "Left Click" },
    { key = "rightClick",      label = "Right Click" },
    { key = "shiftLeftClick",  label = "Shift + Left Click" },
    { key = "shiftRightClick", label = "Shift + Right Click" },
    { key = "middleClick",     label = "Middle Click" },
}

local function AddClickActionsSection(c, r, y, dbKey)
    y = AddHeader(c, y, "Click Actions")
    y = AddDescription(c, y, "Configure what happens when you click on a row in the tooltip.")
    for _, entry in ipairs(CLICK_ACTION_KEYS) do
        y = AddDropdown(c, y, entry.label, ns.ACTION_VALUES,
            function() return ns.db[dbKey].clickActions[entry.key] end,
            function(v) ns.db[dbKey].clickActions[entry.key] = v end, r)
    end
    return y
end

ns.AddClickActionsSection = AddClickActionsSection

---------------------------------------------------------------------------
-- General panel
---------------------------------------------------------------------------

--- Build a tooltip-appearance section (scale, width, spacing, max height, label format).
local function AddTooltipSection(c, r, y, header, labelTokens, dbKey, broker, copyFrom)
    local db = function() return ns.db[dbKey] end
    local refresh = function() if broker() then broker():UpdateData() end end

    y = AddHeader(c, y, header)
    y = AddEditBox(c, y, "Panel Text  (tokens: " .. labelTokens .. ")",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r)
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return db().rowSpacing end,
        function(v) db().rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)
    if copyFrom then
        y = AddButton(c, y, "Copy from " .. copyFrom.label, function()
            DDT:CopyDisplaySettings(copyFrom.key, dbKey)
            refresh()
            for _, cb in ipairs(r) do cb() end
        end)
    end
    return y
end

local FONT_OPTIONS = {
    ["Fonts\\FRIZQT__.TTF"]  = "Friz Quadrata (Default)",
    ["Fonts\\ARIALN.TTF"]    = "Arial Narrow",
    ["Fonts\\MORPHEUS.TTF"]  = "Morpheus",
    ["Fonts\\skurri.TTF"]    = "Skurri",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\AtkinsonHyperlegibleNext.ttf"] = "Atkinson Hyperlegible Next",
}

local function BuildGeneralPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10

    y = AddHeader(c, y, "Tooltip Font")
    y = AddDescription(c, y, "Global font used by all module tooltips. Individual modules can override this in their own settings.")
    y = AddDropdown(c, y, "Font Face", FONT_OPTIONS,
        function() return ns.db.global.tooltipFont end,
        function(v) ns.db.global.tooltipFont = v; ns:UpdateFonts() end, r)
    y = AddSlider(c, y, "Font Size", 8, 20, 1,
        function() return ns.db.global.tooltipFontSize end,
        function(v) ns.db.global.tooltipFontSize = v; ns:UpdateFonts() end, r)

    c:SetHeight(math.abs(y) + 20)
end

-- Shared social settings section (URL templates, tag grouping)
local function AddSocialSettingsSection(c, r, y)
    y = AddHeader(c, y, "Custom URL Templates")
    y = AddDescription(c, y, "Shared across Friends, Guild, and Communities. Use <name>, <realm>, <region> as placeholders.")
    y = AddEditBox(c, y, "Custom URL 1",
        function() return ns.db.global.customUrl1 end,
        function(v) ns.db.global.customUrl1 = v end, r)
    y = AddEditBox(c, y, "Custom URL 2",
        function() return ns.db.global.customUrl2 end,
        function(v) ns.db.global.customUrl2 = v end, r)

    y = AddHeader(c, y, "Tag Grouping")
    y = AddDescription(c, y, "Tags in player notes are used for note-based grouping.")
    y = AddEditBox(c, y, "Tag Separator Character",
        function() return ns.db.global.tagSeparator end,
        function(v) if v ~= "" then ns.db.global.tagSeparator = v end end, r)
    y = AddCheckbox(c, y, "Show Members in All Matching Tag Groups",
        function() return ns.db.global.noteShowInAllGroups end,
        function(v) ns.db.global.noteShowInAllGroups = v end, r)
    return y
end

---------------------------------------------------------------------------
-- Friends panel
---------------------------------------------------------------------------

local function BuildFriendsPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.friends end
    local refresh = function() if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end

    y = AddHeader(c, y, "Label Template")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online> <total> <offline>)",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r)

    y = AddHeader(c, y, "Tooltip")
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return db().rowSpacing end,
        function(v) db().rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)

    y = AddHeader(c, y, "Display Filters")
    y = AddCheckbox(c, y, "Show Character Friends",
        function() return ns.db.friends.showWoWFriends end,
        function(v) ns.db.friends.showWoWFriends = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Show Battle.net Friends",
        function() return ns.db.friends.showBNetFriends end,
        function(v) ns.db.friends.showBNetFriends = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.friends.classColorNames end,
        function(v) ns.db.friends.classColorNames = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Show Hint Bar",
        function() return ns.db.friends.showHintBar end,
        function(v) ns.db.friends.showHintBar = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Grouping")
    y = AddDropdown(c, y, "Group By", ns.FRIENDS_GROUP_VALUES,
        function() return ns.db.friends.groupBy end,
        function(v) ns.db.friends.groupBy = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddDropdown(c, y, "Then By", ns.FRIENDS_GROUP_VALUES,
        function() return ns.db.friends.groupBy2 end,
        function(v) ns.db.friends.groupBy2 = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", status = "Status" },
        function() return ns.db.friends.sortBy end,
        function(v) ns.db.friends.sortBy = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.friends.sortAscending end,
        function(v) ns.db.friends.sortAscending = v; if ns.FriendsBroker then ns.FriendsBroker:UpdateData() end end, r)

    y = AddClickActionsSection(c, r, y, "friends")

    y = AddSocialSettingsSection(c, r, y)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Guild panel
---------------------------------------------------------------------------

local function BuildGuildPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.guild end
    local refresh = function() if ns.GuildBroker then ns.GuildBroker:UpdateData() end end

    y = AddHeader(c, y, "Label Template")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online> <total> <offline> <guildname>)",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r)

    y = AddHeader(c, y, "Tooltip")
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return db().rowSpacing end,
        function(v) db().rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)

    y = AddHeader(c, y, "Display Options")
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.guild.classColorNames end,
        function(v) ns.db.guild.classColorNames = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Show Officer Notes (inline)",
        function() return ns.db.guild.showOfficerNotes end,
        function(v) ns.db.guild.showOfficerNotes = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddDescription(c, y, "Requires guild rank permission to view officer notes.")
    y = AddCheckbox(c, y, "Show Hint Bar",
        function() return ns.db.guild.showHintBar end,
        function(v) ns.db.guild.showHintBar = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Grouping")
    y = AddDropdown(c, y, "Group By", ns.GUILD_GROUP_VALUES,
        function() return ns.db.guild.groupBy end,
        function(v) ns.db.guild.groupBy = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddDropdown(c, y, "Then By", ns.GUILD_GROUP_VALUES,
        function() return ns.db.guild.groupBy2 end,
        function(v) ns.db.guild.groupBy2 = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", rank = "Rank", status = "Status" },
        function() return ns.db.guild.sortBy end,
        function(v) ns.db.guild.sortBy = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.guild.sortAscending end,
        function(v) ns.db.guild.sortAscending = v; if ns.GuildBroker then ns.GuildBroker:UpdateData() end end, r)

    y = AddClickActionsSection(c, r, y, "guild")

    y = AddSocialSettingsSection(c, r, y)

    c:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- Communities panel
---------------------------------------------------------------------------

local function BuildCommunitiesPanel(panel)
    local c = panel.content
    local r = panel.refreshCallbacks
    local y = -10
    local db = function() return ns.db.communities end
    local refresh = function() if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end

    y = AddHeader(c, y, "Label Template")
    y = AddEditBox(c, y, "Panel Text  (tokens: <online>)",
        function() return db().labelFormat end,
        function(v) db().labelFormat = v; refresh() end, r)

    y = AddHeader(c, y, "Tooltip")
    y = AddSlider(c, y, "Scale", 0.5, 2.0, 0.05,
        function() return db().tooltipScale end,
        function(v) db().tooltipScale = v end, r)
    y = AddSlider(c, y, "Width", 300, 800, 10,
        function() return db().tooltipWidth end,
        function(v) db().tooltipWidth = v end, r)
    y = AddSlider(c, y, "Row Spacing", 0, 16, 1,
        function() return db().rowSpacing end,
        function(v) db().rowSpacing = v end, r)
    y = AddSlider(c, y, "Max Height", 100, 1000, 10,
        function() return db().tooltipMaxHeight end,
        function(v) db().tooltipMaxHeight = v end, r)

    y = AddHeader(c, y, "Display Options")
    y = AddCheckbox(c, y, "Class-Colored Names",
        function() return ns.db.communities.classColorNames end,
        function(v) ns.db.communities.classColorNames = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Show Hint Bar",
        function() return ns.db.communities.showHintBar end,
        function(v) ns.db.communities.showHintBar = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Grouping")
    y = AddDropdown(c, y, "Group By", ns.COMMUNITIES_GROUP_VALUES,
        function() return ns.db.communities.groupBy end,
        function(v) ns.db.communities.groupBy = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)
    y = AddDropdown(c, y, "Then By", ns.COMMUNITIES_GROUP_VALUES,
        function() return ns.db.communities.groupBy2 end,
        function(v) ns.db.communities.groupBy2 = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)

    y = AddHeader(c, y, "Sorting")
    y = AddDropdown(c, y, "Sort By", { name = "Name", class = "Class", level = "Level", zone = "Zone", status = "Status" },
        function() return ns.db.communities.sortBy end,
        function(v) ns.db.communities.sortBy = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)
    y = AddCheckbox(c, y, "Ascending Order",
        function() return ns.db.communities.sortAscending end,
        function(v) ns.db.communities.sortAscending = v; if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end end, r)

    y = AddClickActionsSection(c, r, y, "communities")

    y = AddSocialSettingsSection(c, r, y)

    -- Dynamic section: community checkboxes
    y = AddHeader(c, y, "Enabled Communities")
    y = AddDescription(c, y, "Uncheck a community to hide it from the tooltip. New communities are shown by default.")

    local dynamicStart = y
    local dynamicWidgets = {}

    local function RebuildClubList()
        for _, widget in ipairs(dynamicWidgets) do
            widget:Hide()
            widget:SetParent(nil)
        end
        wipe(dynamicWidgets)

        local dy = dynamicStart
        local clubs = C_Club.GetSubscribedClubs()
        if type(clubs) ~= "table" then clubs = {} end

        local communityClubs = {}
        for _, clubInfo in ipairs(clubs) do
            if type(clubInfo.name) == "string"
               and (clubInfo.clubType == Enum.ClubType.Character or clubInfo.clubType == Enum.ClubType.BattleNet) then
                table.insert(communityClubs, clubInfo)
            end
        end
        table.sort(communityClubs, function(a, b) return (a.name or "") < (b.name or "") end)

        if #communityClubs == 0 then
            local noClubs = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            noClubs:SetPoint("TOPLEFT", c, "TOPLEFT", 18, dy)
            noClubs:SetText("No communities found.")
            table.insert(dynamicWidgets, noClubs)
            dy = dy - 20
        else
            for _, clubInfo in ipairs(communityClubs) do
                local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", c, "TOPLEFT", 14, dy)

                local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                text:SetText(clubInfo.name)

                local clubId = clubInfo.clubId
                cb:SetChecked(not ns.db.communities.disabledClubs[clubId])
                cb:SetScript("OnClick", function(self)
                    if self:GetChecked() then
                        ns.db.communities.disabledClubs[clubId] = nil
                    else
                        ns.db.communities.disabledClubs[clubId] = true
                    end
                    if ns.CommunitiesBroker then ns.CommunitiesBroker:UpdateData() end
                end)

                table.insert(dynamicWidgets, cb)
                table.insert(dynamicWidgets, text)
                dy = dy - 26
            end
        end

        c:SetHeight(math.abs(dy) + 20)
    end

    RebuildClubList()

    panel:HookScript("OnShow", function()
        RebuildClubList()
    end)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function DDT:SetupOptions()
    local generalPanel = CreateScrollPanel()
    BuildGeneralPanel(generalPanel)

    local friendsPanel = CreateScrollPanel()
    BuildFriendsPanel(friendsPanel)

    local guildPanel = CreateScrollPanel()
    BuildGuildPanel(guildPanel)

    local commPanel = CreateScrollPanel()
    BuildCommunitiesPanel(commPanel)

    -- Register with Blizzard Settings
    local mainCategory = Settings.RegisterCanvasLayoutCategory(generalPanel, "Djinni's Data Texts")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, friendsPanel, "Friends")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, guildPanel, "Guild")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, commPanel, "Communities")

    -- Let registered modules add their own subcategories
    for key, mod in pairs(ns.modules) do
        if mod.BuildSettingsPanel then
            local modPanel = CreateScrollPanel()
            mod:BuildSettingsPanel(modPanel)
            local label = mod.settingsLabel or key
            Settings.RegisterCanvasLayoutSubcategory(mainCategory, modPanel, label)
        end
    end

    Settings.RegisterAddOnCategory(mainCategory)

    self.settingsCategoryID = mainCategory:GetID()
end
