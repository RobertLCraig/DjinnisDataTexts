-- Djinni's Data Texts - Settings
-- Blizzard Settings API integration, widget helpers, and per-module subcategories.
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

local function AddCheckboxPair(content, y, label1, getter1, setter1, label2, getter2, setter2, refreshList)
    local cb1 = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb1:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    local text1 = cb1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text1:SetPoint("LEFT", cb1, "RIGHT", 2, 0)
    text1:SetText(label1)
    cb1:SetChecked(getter1())
    cb1:SetScript("OnClick", function(self) setter1(self:GetChecked()) end)

    local cb2 = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb2:SetPoint("TOPLEFT", content, "TOPLEFT", 270, y)
    local text2 = cb2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text2:SetPoint("LEFT", cb2, "RIGHT", 2, 0)
    text2:SetText(label2)
    cb2:SetChecked(getter2())
    cb2:SetScript("OnClick", function(self) setter2(self:GetChecked()) end)

    if refreshList then
        table.insert(refreshList, function()
            cb1:SetChecked(getter1())
            cb2:SetChecked(getter2())
        end)
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

--- Two compact sliders side by side.
--- @param spec1 table  { label, min, max, step, get, set }
--- @param spec2 table  { label, min, max, step, get, set }
local function AddSliderPair(content, y, spec1, spec2, refreshList)
    local specs = {spec1, spec2}
    local xBases = {18, 280}
    local SLIDER_W = 155

    for i = 1, 2 do
        local spec = specs[i]
        if not spec then break end
        local xBase = xBases[i]
        local stp = spec.step

        local function FormatVal(v)
            if stp < 1 then return string.format("%.2f", v)
            else return tostring(math.floor(v + 0.5)) end
        end

        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", content, "TOPLEFT", xBase, y)
        lbl:SetText(spec.label)

        local slider = CreateFrame("Slider", nil, content)
        slider:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
        slider:SetMinMaxValues(spec.min, spec.max)
        slider:SetValueStep(stp)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(SLIDER_W)
        slider:SetHeight(16)
        slider:SetOrientation("HORIZONTAL")
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local bg = slider:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
        bg:SetAllPoints()
        bg:SetTexCoord(0, 1, 0, 1)

        local input = CreateFrame("EditBox", nil, content, "BackdropTemplate")
        input:SetPoint("LEFT", slider, "RIGHT", 8, 0)
        input:SetSize(48, 20)
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

        local valText = input:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valText:SetPoint("CENTER")
        valText:SetJustifyH("CENTER")
        valText:SetText(FormatVal(spec.get()))

        input:SetScript("OnEditFocusGained", function(self)
            valText:Hide()
            self:SetText(FormatVal(spec.get()))
            self:HighlightText()
        end)
        input:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            valText:SetText(FormatVal(spec.get()))
            valText:Show()
        end)
        input:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end)
        input:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        end)

        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / stp + 0.5) * stp
            spec.set(value)
            valText:SetText(FormatVal(value))
            input:SetText(FormatVal(value))
        end)
        slider:SetValue(spec.get())

        input:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val then
                val = math.max(spec.min, math.min(spec.max, val))
                val = math.floor(val / stp + 0.5) * stp
                spec.set(val)
                slider:SetValue(val)
            else
                self:SetText(FormatVal(spec.get()))
            end
            self:ClearFocus()
        end)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        if refreshList then
            local s, v = slider, valText
            table.insert(refreshList, function()
                s:SetValue(spec.get())
                v:SetText(FormatVal(spec.get()))
            end)
        end
    end

    return y - 48
end

--- Add a small gray note/hint text
local function AddNote(content, y, text)
    local note = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    note:SetPoint("RIGHT", content, "RIGHT", -18, 0)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    local h = math.max(14, note:GetStringHeight() + 2)
    return y - h
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

-- Font preview dropdown: shows each font name rendered in its own typeface.
-- Blizzard's menu system blocks SetFont inside initializers, so we build
-- a custom popup list instead of using WowStyle1DropdownTemplate.
local function AddFontDropdown(content, y, label, values, getter, setter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText(label)

    -- Sort font entries once
    local sorted = {}
    for path, displayName in pairs(values) do
        sorted[#sorted + 1] = { path = path, name = displayName }
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    -- Clickable selection button (styled like WoW dropdown)
    local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    btn:SetSize(240, 24)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, edgeSize = 1, tileSize = 5,
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")

    local function UpdateSelection()
        local v = getter()
        btnText:SetText(values[v] or "Unknown")
        btnText:SetFont(v, 13, "")
    end
    UpdateSelection()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end)

    -- Popup list frame
    local popup = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    popup:SetSize(280, 10)
    popup:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    popup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    popup:SetFrameStrata("DIALOG")
    popup:Hide()

    -- Build font rows
    local fontRows = {}
    local ry = -6
    local PREVIEW_SIZE = 14
    local PREVIEW_ROW_H = 22
    for _, item in ipairs(sorted) do
        local row = CreateFrame("Button", nil, popup)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 6, ry)
        row:SetPoint("RIGHT", popup, "RIGHT", -6, 0)
        row:SetHeight(PREVIEW_ROW_H)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.1)

        local fs = row:CreateFontString(nil, "OVERLAY")
        fs:SetFont(item.path, PREVIEW_SIZE, "")
        fs:SetPoint("LEFT", row, "LEFT", 4, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -20, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText(item.name)

        local fontPath = item.path
        row:SetScript("OnClick", function()
            setter(fontPath)
            UpdateSelection()
            popup:Hide()
        end)

        fontRows[#fontRows + 1] = { row = row, fs = fs, path = fontPath }
        ry = ry - PREVIEW_ROW_H
    end
    popup:SetHeight(math.abs(ry) + 6)

    -- Refresh active markers when popup opens
    local function RefreshActive()
        local active = getter()
        for _, entry in ipairs(fontRows) do
            if entry.path == active then
                entry.fs:SetTextColor(0.2, 1.0, 0.2)
            else
                entry.fs:SetTextColor(0.85, 0.85, 0.85)
            end
        end
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
        else
            RefreshActive()
            popup:Show()
        end
    end)

    if refreshList then
        table.insert(refreshList, function() UpdateSelection() end)
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
    editbox:SetTextColor(0, 0, 0, 0)

    -- FontString overlay - EditBox text doesn't render in scroll children;
    -- the overlay provides reliable display when unfocused.
    local valText = editbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", editbox, "LEFT", 6, 0)
    valText:SetPoint("RIGHT", editbox, "RIGHT", -6, 0)
    valText:SetJustifyH("LEFT")
    valText:SetText(getter())

    editbox:HookScript("OnEditFocusGained", function(self)
        -- Sync buffer and make text visible; delay hiding overlay by one
        -- frame so editbox text rendering has time to initialise.
        self:SetText(getter())
        self:SetTextColor(1, 1, 1, 1)
        C_Timer.After(0, function()
            if self:HasFocus() then
                valText:Hide()
                self:HighlightText(0, 0)
                self:SetCursorPosition(#self:GetText())
            end
        end)
    end)
    editbox:HookScript("OnEditFocusLost", function(self)
        local newVal = self:GetText()
        setter(newVal)
        self:SetTextColor(0, 0, 0, 0)
        valText:SetText(newVal)
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
    editbox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            setter(self:GetText())
        end
    end)

    if refreshList then
        table.insert(refreshList, function()
            if not editbox:HasFocus() then
                editbox:SetText(getter())
                valText:SetText(getter())
            end
        end)
    end
    return y - 44
end

--- Build a label template editor in a panel's fixed header (above scroll frame).
--- Editbox lives outside the scroll child so text renders reliably.
--- @param panel table  Panel created by CreateScrollPanel
--- @param tags string  Space-separated tag names e.g. "fps latency world memory cpu"
--- @param getter function  Returns current template string
--- @param setter function  Called with new template string
--- @param refreshList table  Refresh callbacks
--- @param suggestions table|nil  Optional list of { label, template } preset buttons
local function AddLabelEditBox(panel, tags, getter, setter, refreshList, suggestions)
    -- Container frame parented to panel (outside scroll child)
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -5)
    header:SetPoint("RIGHT", panel, "RIGHT", -24, 0)

    local titleStr = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleStr:SetPoint("TOPLEFT", 8, 0)
    titleStr:SetText("Label Template")

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", titleStr, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", header, "TOPLEFT", 18, -24)
    text:SetText("Template")

    local editbox = CreateFrame("EditBox", nil, header, "InputBoxTemplate")
    editbox:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 4, -4)
    editbox:SetSize(380, 20)
    editbox:SetAutoFocus(false)
    editbox:SetText(getter())

    -- Track cursor position so tag buttons can insert at the right spot
    -- (clicking a tag button causes focus loss before OnClick fires)
    local lastCursorPos = nil
    local lastText = nil

    editbox:HookScript("OnEditFocusLost", function(self)
        lastCursorPos = self:GetCursorPosition()
        lastText = self:GetText()
        setter(lastText)
    end)
    editbox:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
    end)
    editbox:SetScript("OnEscapePressed", function(self)
        self:SetText(getter())
        self:ClearFocus()
    end)
    editbox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            setter(self:GetText())
        end
    end)

    if refreshList then
        table.insert(refreshList, function()
            if not editbox:HasFocus() then
                editbox:SetText(getter())
            end
        end)
    end

    -- Tag insert buttons row
    local tagY = -68
    local tagList = {}
    for tag in tags:gmatch("%S+") do
        table.insert(tagList, tag)
    end

    local TAG_BTN_HEIGHT = 20
    local TAG_BTN_PAD = 4
    local xOffset = 22
    local maxRowWidth = 380

    for _, tag in ipairs(tagList) do
        local tagStr = "<" .. tag .. ">"
        local btn = CreateFrame("Button", nil, header)
        btn:SetHeight(TAG_BTN_HEIGHT)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("CENTER")
        btnText:SetText(tagStr)
        btnText:SetTextColor(0.4, 0.78, 1.0)
        local btnWidth = math.max(btnText:GetStringWidth() + 12, 40)
        btn:SetWidth(btnWidth)

        -- Background
        local bbg = btn:CreateTexture(nil, "BACKGROUND")
        bbg:SetAllPoints()
        bbg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

        -- Border
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.3, 0.3, 0.3, 0.6)

        -- Wrap to next row if exceeds width
        if xOffset + btnWidth > maxRowWidth + 22 then
            xOffset = 22
            tagY = tagY - TAG_BTN_HEIGHT - TAG_BTN_PAD
        end

        btn:SetPoint("TOPLEFT", header, "TOPLEFT", xOffset, tagY)
        xOffset = xOffset + btnWidth + TAG_BTN_PAD

        -- Hover effect
        btn:SetScript("OnEnter", function(self)
            bbg:SetColorTexture(0.25, 0.35, 0.45, 0.9)
            btnText:SetTextColor(1, 1, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            bbg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            btnText:SetTextColor(0.4, 0.78, 1.0)
        end)

        btn:SetScript("OnClick", function()
            local cur = lastText or getter()
            local pos = lastCursorPos or #cur
            lastCursorPos = nil
            lastText = nil
            local before = cur:sub(1, pos)
            local after  = cur:sub(pos + 1)
            local newVal = before .. tagStr .. after
            setter(newVal)
            editbox:SetText(newVal)
            editbox:SetFocus()
            editbox:SetCursorPosition(pos + #tagStr)
        end)
    end

    tagY = tagY - TAG_BTN_HEIGHT - 6

    -- Preset suggestion buttons (click to replace template)
    if suggestions and #suggestions > 0 then
        tagY = tagY - 2
        local sugLabel = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sugLabel:SetPoint("TOPLEFT", header, "TOPLEFT", 22, tagY)
        sugLabel:SetText("Presets:")
        tagY = tagY - 14

        for _, sug in ipairs(suggestions) do
            local btn = CreateFrame("Button", nil, header)
            btn:SetHeight(18)
            btn:SetPoint("TOPLEFT", header, "TOPLEFT", 22, tagY)
            btn:SetPoint("RIGHT", header, "RIGHT", -22, 0)

            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("LEFT", 6, 0)
            btnText:SetJustifyH("LEFT")
            btnText:SetText("|cff888888" .. sug[1] .. ":|r  " .. sug[2])

            local sbg = btn:CreateTexture(nil, "BACKGROUND")
            sbg:SetAllPoints()
            sbg:SetColorTexture(0, 0, 0, 0)

            btn:SetScript("OnEnter", function()
                sbg:SetColorTexture(0.2, 0.3, 0.4, 0.5)
            end)
            btn:SetScript("OnLeave", function()
                sbg:SetColorTexture(0, 0, 0, 0)
            end)
            btn:SetScript("OnClick", function()
                setter(sug[2])
                editbox:SetText(sug[2])
            end)

            tagY = tagY - 20
        end
    end

    -- Size header and push scroll frame down
    local headerHeight = math.abs(tagY) + 4
    header:SetHeight(headerHeight)
    panel.scroll:SetPoint("TOPLEFT", 0, -(headerHeight + 5))

    panel.labelHeader = header
    panel.labelEditBox = editbox
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

---------------------------------------------------------------------------
-- Collapsible section infrastructure
---------------------------------------------------------------------------

--- Create a collapsible section in a sectioned panel.
--- Widgets are added to the returned body frame using standard y-offset calls.
--- Call EndSection(panel, y) when done adding widgets.
--- @param panel table  Panel created by CreateScrollPanel
--- @param title string  Section header text
--- @param defaultCollapsed boolean|nil  Start collapsed (default false)
--- @return Frame body  The body frame to add widgets into
local function AddSection(panel, title, defaultCollapsed)
    local sections = panel.sections
    local content = panel.content

    local section = CreateFrame("Frame", nil, content)
    section:SetPoint("RIGHT", content, "RIGHT")
    if #sections == 0 then
        section:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -6)
    else
        section:SetPoint("TOPLEFT", sections[#sections], "BOTTOMLEFT", 0, -2)
    end

    -- Header button
    local headerBtn = CreateFrame("Button", nil, section)
    headerBtn:SetHeight(24)
    headerBtn:SetPoint("TOPLEFT", 0, 0)
    headerBtn:SetPoint("RIGHT", 0, 0)

    local arrow = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("LEFT", 8, 0)
    arrow:SetTextColor(0.6, 0.6, 0.6)

    local titleStr = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleStr:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    titleStr:SetText(title)

    -- Separator line extends from end of title to right edge
    local line = section:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", titleStr, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", section, "RIGHT", -10, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    -- Hover highlight on header
    headerBtn:SetScript("OnEnter", function()
        arrow:SetTextColor(1, 0.82, 0)
    end)
    headerBtn:SetScript("OnLeave", function()
        arrow:SetTextColor(0.6, 0.6, 0.6)
    end)

    -- Body container
    local body = CreateFrame("Frame", nil, section)
    body:SetPoint("TOPLEFT", headerBtn, "BOTTOMLEFT", 0, -4)
    body:SetPoint("RIGHT")

    local HEADER_H = 28
    section.body = body
    section.headerHeight = HEADER_H
    section.bodyHeight = 0
    section.isCollapsed = defaultCollapsed or false

    function section:UpdateLayout()
        if self.isCollapsed then
            arrow:SetText("+")
            body:Hide()
            self:SetHeight(self.headerHeight)
        else
            arrow:SetText("-")
            body:Show()
            self:SetHeight(self.headerHeight + self.bodyHeight)
        end
        panel:RecalcHeight()
    end

    headerBtn:SetScript("OnClick", function()
        section.isCollapsed = not section.isCollapsed
        section:UpdateLayout()
    end)

    table.insert(sections, section)
    panel.currentSection = section

    return body
end

--- Finalize a section after adding widgets. Sets body height from final y offset.
--- @param panel table  The panel
--- @param y number  Final y offset (negative) from widget building
local function EndSection(panel, y)
    local section = panel.currentSection
    if not section then return end
    section.bodyHeight = math.abs(y) + 8
    section.body:SetHeight(section.bodyHeight)
    section:UpdateLayout()
    panel.currentSection = nil
end

---------------------------------------------------------------------------
-- "Copy Tooltip From" dropdown - copies tooltipScale/Width/MaxHeight
-- from another module's saved settings into the current module.
---------------------------------------------------------------------------

local TOOLTIP_COPY_KEYS = { "tooltipScale", "tooltipWidth", "tooltipMaxHeight", "tooltipGrowDirection" }

local TOOLTIP_GROW_VALUES = {
    auto = "Auto (detect from position)",
    up   = "Up (above DataText)",
    down = "Down (below DataText)",
}

local function AddTooltipGrowDirection(content, y, dbGetter, refreshList)
    return AddDropdown(content, y, "Tooltip Grow Direction", TOOLTIP_GROW_VALUES,
        function() return dbGetter().tooltipGrowDirection or "auto" end,
        function(v) dbGetter().tooltipGrowDirection = v end, refreshList)
end

local function AddTooltipCopyFrom(content, y, currentKey, dbGetter, refreshList)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    text:SetText("Copy Tooltip Settings From")

    local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    dropdown:SetWidth(200)

    dropdown:SetupMenu(function(owner, rootDescription)
        local sorted = {}
        for key, mod in pairs(ns.modules) do
            if key ~= currentKey then
                local label = mod.settingsLabel or key
                sorted[#sorted + 1] = { key = key, label = label }
            end
        end
        table.sort(sorted, function(a, b) return a.label < b.label end)

        for _, entry in ipairs(sorted) do
            rootDescription:CreateButton(entry.label, function()
                local srcDB = ns.db[entry.key]
                if not srcDB then return end
                local destDB = dbGetter()
                if not destDB then return end
                for _, k in ipairs(TOOLTIP_COPY_KEYS) do
                    if srcDB[k] ~= nil then destDB[k] = srcDB[k] end
                end
                -- Refresh all sliders in this panel
                if refreshList then
                    for _, fn in ipairs(refreshList) do fn() end
                end
            end)
        end
    end)

    return y - 54
end

-- Expose widget helpers for use by module settings panels
ns.SettingsWidgets = {
    AddHeader       = AddHeader,
    AddCheckbox     = AddCheckbox,
    AddCheckboxPair = AddCheckboxPair,
    AddSlider       = AddSlider,
    AddSliderPair   = AddSliderPair,
    AddDropdown     = AddDropdown,
    AddEditBox      = AddEditBox,
    AddLabelEditBox = AddLabelEditBox,
    AddButton       = AddButton,
    AddDescription  = AddDescription,
    AddNote         = AddNote,
    AddSection      = AddSection,
    EndSection      = EndSection,
    AddTooltipCopyFrom = AddTooltipCopyFrom,
    AddTooltipGrowDirection = AddTooltipGrowDirection,
}

---------------------------------------------------------------------------
-- Panel builder
---------------------------------------------------------------------------

local function CreateScrollPanel()
    local panel = CreateFrame("Frame")
    panel:Hide()  -- start hidden so OnShow fires when Blizzard Settings displays it

    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -5)
    scroll:SetPoint("BOTTOMRIGHT", -24, 5)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(560)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.refreshCallbacks = {}
    panel.sections = {}

    function panel:RecalcHeight()
        local totalH = 6
        for i, sec in ipairs(self.sections) do
            totalH = totalH + sec:GetHeight()
            if i < #self.sections then
                totalH = totalH + 2
            end
        end
        self.content:SetHeight(math.max(totalH + 20, 100))
    end

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
    { key = "middleClick",     label = "Middle Click" },
    { key = "shiftLeftClick",  label = "Shift + Left Click" },
    { key = "shiftRightClick", label = "Shift + Right Click" },
    { key = "ctrlLeftClick",   label = "Ctrl + Left Click" },
    { key = "ctrlRightClick",  label = "Ctrl + Right Click" },
    { key = "altLeftClick",    label = "Alt + Left Click" },
    { key = "altRightClick",   label = "Alt + Right Click" },
}

--- Build row click-action settings for social modules (tooltip row clicks).
--- Creates a collapsed section automatically.
--- @param panel table  Sectioned panel
--- @param r table  Refresh callbacks list
--- @param dbKey string  Module db key
local function AddClickActionsSection(panel, r, dbKey)
    local body = AddSection(panel, "Row Click Actions", true)
    local y = 0
    y = AddDescription(body, y, "Configure what happens when you click on a player row in the tooltip.")
    for _, entry in ipairs(CLICK_ACTION_KEYS) do
        y = AddDropdown(body, y, entry.label, ns.ACTION_VALUES,
            function() return ns.db[dbKey].rowClickActions[entry.key] end,
            function(v) ns.db[dbKey].rowClickActions[entry.key] = v end, r)
    end
    EndSection(panel, y)
end

ns.AddClickActionsSection = AddClickActionsSection

--- Build click-action settings for standalone (non-social) modules.
--- Creates a collapsed section automatically.
--- @param panel table  Sectioned panel
--- @param r table  Refresh callbacks list
--- @param dbKey string  Module db key
--- @param actionValues table  Module-specific { key = "Display Name" } table
--- @param extraDesc string|nil  Optional description appended after dropdowns
local function AddModuleClickActionsSection(panel, r, dbKey, actionValues, extraDesc)
    local body = AddSection(panel, "Click Actions", true)
    local y = 0
    y = AddDescription(body, y, "Configure what happens when you click the DataText.")
    for _, entry in ipairs(CLICK_ACTION_KEYS) do
        y = AddDropdown(body, y, entry.label, actionValues,
            function() return ns.db[dbKey].clickActions[entry.key] end,
            function(v) ns.db[dbKey].clickActions[entry.key] = v end, r)
    end
    if extraDesc then
        y = AddDescription(body, y, extraDesc)
    end
    EndSection(panel, y)
end

ns.AddModuleClickActionsSection = AddModuleClickActionsSection

--- Build row click-action settings for modules with interactive tooltip rows.
--- Creates a collapsed section automatically.
--- @param panel table  Sectioned panel
--- @param r table  Refresh callbacks list
--- @param dbKey string  Module db key
--- @param actionValues table  Module-specific row action { key = "Display Name" } table
local function AddRowClickActionsSection(panel, r, dbKey, actionValues)
    local body = AddSection(panel, "Row Click Actions", true)
    local y = 0
    y = AddDescription(body, y, "Configure what happens when you click a row in the tooltip.")
    for _, entry in ipairs(CLICK_ACTION_KEYS) do
        y = AddDropdown(body, y, entry.label, actionValues,
            function() return ns.db[dbKey].rowClickActions[entry.key] end,
            function(v) ns.db[dbKey].rowClickActions[entry.key] = v end, r)
    end
    EndSection(panel, y)
end

ns.AddRowClickActionsSection = AddRowClickActionsSection

---------------------------------------------------------------------------
-- General panel
---------------------------------------------------------------------------

local FONT_OPTIONS = {
    ["Fonts\\FRIZQT__.TTF"]  = "Friz Quadrata (Default)",
    ["Fonts\\ARIALN.TTF"]    = "Arial Narrow",
    ["Fonts\\MORPHEUS.TTF"]  = "Morpheus",
    ["Fonts\\skurri.TTF"]    = "Skurri",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\AtkinsonHyperlegible-Regular.ttf"]     = "Atkinson Hyperlegible",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\AtkinsonHyperlegibleNext-Regular.ttf"] = "Atkinson Hyperlegible Next",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\IBMPlexSans-Regular.ttf"]              = "IBM Plex Sans",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\Montserrat-Regular.ttf"]               = "Montserrat",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\OpenSans-Regular.ttf"]                 = "Open Sans",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\OpenSans-Medium.ttf"]                  = "Open Sans Medium",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\Saira-Regular.ttf"]                    = "Saira",
    ["Interface\\AddOns\\DjinnisDataTexts\\Fonts\\SpaceGrotesk-Regular.ttf"]             = "Space Grotesk",
}

local function BuildGeneralPanel(panel)
    local r = panel.refreshCallbacks

    -- Number Formatting
    local body = AddSection(panel, "Number Formatting")
    local y = 0
    y = AddDescription(body, y,
        "Controls how numbers, gold, and quantities are displayed across\n" ..
        "all modules. Choose a preset or use Custom for full control.")
    y = AddDropdown(body, y, "Format Preset", ns.FORMAT_PRESET_LABELS,
        function() return ns.db.global.numberFormat end,
        function(v)
            ns.db.global.numberFormat = v
            if v ~= "custom" then
                local preset = ns.FORMAT_PRESETS[v]
                if preset then
                    ns.db.global.numberSep = preset.sep
                    ns.db.global.numberDec = preset.dec
                    ns.db.global.numberAbbr = preset.abbr
                end
            end
            for _, cb in ipairs(r) do cb() end
            for _, mod in pairs(ns.modules) do
                if mod.UpdateData then mod:UpdateData() end
            end
        end, r)

    -- Preview
    local previewLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y)
    previewLabel:SetText("Preview:")
    local previewValue = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewValue:SetPoint("LEFT", previewLabel, "RIGHT", 8, 0)

    local function UpdatePreview()
        local examples = {
            ns.FormatNumber(1234),
            ns.FormatNumber(1234567),
            ns.FormatGold(12345670000, false),
        }
        previewValue:SetText("|cff66c7ff" .. table.concat(examples, "  |  ") .. "|r")
    end
    UpdatePreview()
    table.insert(r, UpdatePreview)
    y = y - 20

    -- Custom separators (only shown when preset == custom)
    local customWidgets = {}

    local function ShowCustomWidgets()
        local isCustom = ns.db.global.numberFormat == "custom"
        for _, w in ipairs(customWidgets) do
            if isCustom then w:Show() else w:Hide() end
        end
    end

    -- Thousands separator
    local sepLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sepLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y)
    sepLabel:SetText("Thousands Separator")
    table.insert(customWidgets, sepLabel)

    local sepBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    sepBox:SetPoint("TOPLEFT", sepLabel, "BOTTOMLEFT", 4, -4)
    sepBox:SetSize(60, 20)
    sepBox:SetAutoFocus(false)
    sepBox:SetText(ns.db.global.numberSep or ",")
    sepBox:SetScript("OnEnterPressed", function(self)
        ns.db.global.numberSep = self:GetText()
        UpdatePreview()
        self:ClearFocus()
    end)
    sepBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    table.insert(customWidgets, sepBox)
    table.insert(r, function() sepBox:SetText(ns.db.global.numberSep or ",") end)

    -- Decimal separator
    local decLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    decLabel:SetPoint("LEFT", sepLabel, "RIGHT", 100, 0)
    decLabel:SetText("Decimal Separator")
    table.insert(customWidgets, decLabel)

    local decBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    decBox:SetPoint("TOPLEFT", decLabel, "BOTTOMLEFT", 4, -4)
    decBox:SetSize(60, 20)
    decBox:SetAutoFocus(false)
    decBox:SetText(ns.db.global.numberDec or ".")
    decBox:SetScript("OnEnterPressed", function(self)
        ns.db.global.numberDec = self:GetText()
        UpdatePreview()
        self:ClearFocus()
    end)
    decBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    table.insert(customWidgets, decBox)
    table.insert(r, function() decBox:SetText(ns.db.global.numberDec or ".") end)

    y = y - 44

    -- Abbreviate checkbox
    local abbrCb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
    abbrCb:SetPoint("TOPLEFT", body, "TOPLEFT", 14, y)
    local abbrText = abbrCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    abbrText:SetPoint("LEFT", abbrCb, "RIGHT", 2, 0)
    abbrText:SetText("Abbreviate large numbers (K / M / B)")
    abbrCb:SetChecked(ns.db.global.numberAbbr ~= false)
    abbrCb:SetScript("OnClick", function(self)
        ns.db.global.numberAbbr = self:GetChecked()
        UpdatePreview()
    end)
    table.insert(customWidgets, abbrCb)
    table.insert(customWidgets, abbrText)
    table.insert(r, function()
        abbrCb:SetChecked(ns.db.global.numberAbbr ~= false)
        ShowCustomWidgets()
    end)
    y = y - 26

    ShowCustomWidgets()
    EndSection(panel, y)

    -- Gold Display
    body = AddSection(panel, "Gold Display")
    y = 0
    y = AddDescription(body, y,
        "Controls how gold amounts appear in all module tooltips.\n" ..
        "Number formatting (separators, abbreviation) is inherited from above.")
    local function OnGoldSettingChanged()
        for _, cb in ipairs(r) do cb() end
        -- Notify all modules so labels using gold formatting refresh
        for _, mod in pairs(ns.modules) do
            if mod.UpdateData then mod:UpdateData() end
        end
    end
    y = AddCheckbox(body, y, "Colorize gold (|cffe6cc80g|r |cffc0c0c0s|r |cffcc7722c|r)",
        function() return ns.db.global.goldColorize ~= false end,
        function(v) ns.db.global.goldColorize = v; OnGoldSettingChanged() end, r)
    y = AddCheckboxPair(body, y,
        "Show silver",
        function() return ns.db.global.goldShowSilver ~= false end,
        function(v) ns.db.global.goldShowSilver = v; OnGoldSettingChanged() end,
        "Show copper",
        function() return ns.db.global.goldShowCopper ~= false end,
        function(v) ns.db.global.goldShowCopper = v; OnGoldSettingChanged() end, r)

    -- Gold preview
    local goldPreviewLabel = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldPreviewLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 18, y)
    goldPreviewLabel:SetText("Preview:")
    local goldPreviewValue = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldPreviewValue:SetPoint("LEFT", goldPreviewLabel, "RIGHT", 8, 0)

    local function UpdateGoldPreview()
        -- Show examples at different amounts
        local examples = {
            ns.FormatGold(12345678, nil),   -- ~1234g
            ns.FormatGold(1234567890, nil), -- ~123456g
        }
        goldPreviewValue:SetText(table.concat(examples, "   "))
    end
    UpdateGoldPreview()
    table.insert(r, UpdateGoldPreview)
    y = y - 20

    EndSection(panel, y)

    -- Tooltip Font
    body = AddSection(panel, "Tooltip Font")
    y = 0
    y = AddDescription(body, y, "Global font used by all module tooltips.")
    y = AddFontDropdown(body, y, "Font Face", FONT_OPTIONS,
        function() return ns.db.global.tooltipFont end,
        function(v) ns.db.global.tooltipFont = v; ns:UpdateFonts() end, r)
    local fontSizeTimer
    y = AddSlider(body, y, "Font Size", 8, 50, 1,
        function() return ns.db.global.tooltipFontSize end,
        function(v)
            ns.db.global.tooltipFontSize = v
            if fontSizeTimer then fontSizeTimer:Cancel() end
            fontSizeTimer = C_Timer.NewTimer(0.15, function() ns:UpdateFonts() end)
        end, r)
    EndSection(panel, y)
end

---------------------------------------------------------------------------
-- Social settings (shared across Friends/Guild/Communities)
---------------------------------------------------------------------------

--- Build shared social settings as a collapsed section.
local function AddSocialSettingsSection(panel, r)
    local body = AddSection(panel, "Social Settings", true)
    local y = 0
    y = AddHeader(body, y, "Custom URL Templates")
    y = AddDescription(body, y, "Shared across Friends, Guild, and Communities. Use <name>, <realm>, <region> as placeholders.")
    y = AddEditBox(body, y, "Custom URL 1",
        function() return ns.db.global.customUrl1 end,
        function(v) ns.db.global.customUrl1 = v end, r)
    y = AddEditBox(body, y, "Custom URL 2",
        function() return ns.db.global.customUrl2 end,
        function(v) ns.db.global.customUrl2 = v end, r)

    y = AddHeader(body, y, "Tag Grouping")
    y = AddDescription(body, y, "Tags in player notes are used for note-based grouping.")
    y = AddEditBox(body, y, "Tag Separator Character",
        function() return ns.db.global.tagSeparator end,
        function(v) if v ~= "" then ns.db.global.tagSeparator = v end end, r)
    y = AddCheckbox(body, y, "Show Members in All Matching Tag Groups",
        function() return ns.db.global.noteShowInAllGroups end,
        function(v) ns.db.global.noteShowInAllGroups = v end, r)
    EndSection(panel, y)
end
ns.AddSocialSettingsSection = AddSocialSettingsSection

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function DDT:SetupOptions()
    local generalPanel = CreateScrollPanel()
    BuildGeneralPanel(generalPanel)

    -- Register with Blizzard Settings
    local mainCategory = Settings.RegisterCanvasLayoutCategory(generalPanel, "Djinni's Data Texts")

    -- Collect all subcategories from registered modules, sort alphabetically
    local subcats = {}
    for key, mod in pairs(ns.modules) do
        if mod.BuildSettingsPanel then
            local modPanel = CreateScrollPanel()
            mod:BuildSettingsPanel(modPanel)
            local label = mod.settingsLabel or key
            table.insert(subcats, { label = label, panel = modPanel })
        end
    end
    table.sort(subcats, function(a, b) return a.label < b.label end)
    for _, entry in ipairs(subcats) do
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, entry.panel, entry.label)
    end

    Settings.RegisterAddOnCategory(mainCategory)

    self.settingsCategoryID = mainCategory:GetID()
end
