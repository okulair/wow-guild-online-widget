local GOW = _G.GuildOnlineWidget
local U = GOW.util

GOW.tooltip = GOW.tooltip or nil

local ROW_HEIGHT = 18
local MAX_ROWS = 30

local COL_NAME_X = 4
local COL_LEVEL_X = 104
local COL_SCORE_X = 132
local COL_ZONE_WITH_SCORE_X = 176
local COL_ZONE_NO_SCORE_X = 132

local TOOLTIP_WIDTH_EMPTY = 272
local TOOLTIP_WIDTH_NO_SCORE = 316
local TOOLTIP_WIDTH_WITH_SCORE = 364

local ZONE_CHAR_MIN = 24
local ZONE_CHAR_MAX = 52
local ZONE_PX_PER_CHAR = 5.8
local TOOLTIP_ROSTER_REFRESH_INTERVAL = 90

function GOW:CreateTooltip()
  if self.tooltip then return self.tooltip end

  local t = CreateFrame("Frame", "GuildOnlineWidgetTooltip", UIParent, "BackdropTemplate")
  self.tooltip = t
  t:SetFrameStrata("TOOLTIP")
  t:SetClampedToScreen(true)
  t:Hide()

  t.pinned = false
  t.hoverPreview = false

  t:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  t:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
  t:SetBackdropBorderColor(0.4, 0.6, 0.85, 1)

  t.header = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t.header:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -8)
  t.header:SetText("Guild Online")

  t.rows = {}
  t.owner = nil

  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, t)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", t, "TOPLEFT", 8, -8 - (i * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", t, "TOPRIGHT", -8, -8 - (i * ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(true)
    row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.07)

    row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameFS:SetPoint("LEFT", row, "LEFT", COL_NAME_X, 0)
    row.nameFS:SetJustifyH("LEFT")

    row.levelFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.levelFS:SetPoint("LEFT", row, "LEFT", COL_LEVEL_X, 0)
    row.levelFS:SetWidth(22)
    row.levelFS:SetJustifyH("RIGHT")

    row.scoreFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.scoreFS:SetPoint("LEFT", row, "LEFT", COL_SCORE_X, 0)
    row.scoreFS:SetWidth(38)
    row.scoreFS:SetJustifyH("RIGHT")

    row.zoneFS = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.zoneFS:SetPoint("LEFT", row, "LEFT", COL_ZONE_WITH_SCORE_X, 0)
    row.zoneFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.zoneFS:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(selfRow, button)
      if not selfRow.member then return end
      if button == "RightButton" and GOW.ShowMemberMenu then
        GOW:ShowMemberMenu(selfRow.member, selfRow)
      elseif button == "LeftButton" then
        local who = U.SafeAmbiguate(selfRow.member.name)
        if ChatFrame_SendTell then
          ChatFrame_SendTell(who)
        end
      end
    end)

    row:SetScript("OnEnter", function(selfRow)
      selfRow.bg:SetColorTexture(1, 1, 1, 0.12)
    end)

    row:SetScript("OnLeave", function(selfRow)
      selfRow.bg:SetColorTexture(1, 1, 1, (selfRow.index % 2 == 0) and 0.03 or 0.07)
    end)

    row:Hide()
    t.rows[i] = row
  end

  function t:UpdateAnchor(widget)
    widget = widget or self.owner
    if not widget then return end

    self:ClearAllPoints()

    local parentW, parentH = UIParent:GetWidth(), UIParent:GetHeight()
    local x, y = widget:GetCenter()

    local nearBottom = y and y < (parentH * 0.35)
    local nearTop = y and y > (parentH * 0.65)
    local nearRight = x and x > (parentW * 0.75)
    local nearLeft = x and x < (parentW * 0.25)

    local openUp = nearBottom and true or false
    if nearTop then
      openUp = false
    end

    local hAlign = "LEFT"
    if nearRight and not nearLeft then
      hAlign = "RIGHT"
    end

    if openUp then
      self:SetPoint("BOTTOM" .. hAlign, widget, "TOP" .. hAlign, 0, 4)
    else
      self:SetPoint("TOP" .. hAlign, widget, "BOTTOM" .. hAlign, 0, -4)
    end
  end

  function t:ShowForWidget(widget, pinned)
    self.owner = widget
    self.pinned = pinned and true or false
    self.hoverPreview = not self.pinned
    self.rosterRefreshElapsed = 0
    self:RefreshRows()
    self:UpdateAnchor(widget)
    self:Show()
  end

  function t:ShowPreview(widget)
    if self.pinned then return end
    self:ShowForWidget(widget, false)
  end

  function t:TogglePinned(widget)
    if self:IsShown() and self.pinned then
      self.pinned = false
      self.hoverPreview = false
      self:Hide()
      return
    end

    self:ShowForWidget(widget or self.owner, true)
  end

  function t:GetZoneMaxChars(row, zoneLeftX)
    if not row then return ZONE_CHAR_MIN end
    local width = row:GetWidth() or 0
    local zoneWidth = width - zoneLeftX - 6
    if zoneWidth <= 0 then
      return ZONE_CHAR_MIN
    end

    local byWidth = math.floor(zoneWidth / ZONE_PX_PER_CHAR)
    if byWidth < ZONE_CHAR_MIN then return ZONE_CHAR_MIN end
    if byWidth > ZONE_CHAR_MAX then return ZONE_CHAR_MAX end
    return byWidth
  end

  function t:RefreshRows()
    local s = GOW.state
    local list = s.sorted

    if not IsInGuild() then
      self.header:SetText("Not in a guild")
      for i = 1, MAX_ROWS do self.rows[i]:Hide() end
      self:SetSize(TOOLTIP_WIDTH_EMPTY, 36)
      self:UpdateAnchor(self.owner)
      return
    end

    self.header:SetText(("Guild Online (%d)"):format(s.onlineCount or 0))

    local shown = 0
    local total = math.min(#list, MAX_ROWS)
    local showMPlus = GOW.db and GOW.db.showMythicPlusScore
    local tooltipWidth = showMPlus and TOOLTIP_WIDTH_WITH_SCORE or TOOLTIP_WIDTH_NO_SCORE
    self:SetWidth(tooltipWidth)

    for i = 1, total do
      local m = list[i]
      local row = self.rows[i]
      row.index = i
      row.member = m

      row.nameFS:SetText(U.ClassColoredName(m.name, m.classFile))
      row.levelFS:SetText(m.level and tostring(m.level) or "--")

      row.zoneFS:ClearAllPoints()
      row.zoneFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)

      local zoneLeftX = COL_ZONE_NO_SCORE_X
      if showMPlus and GOW.core and GOW.core.GetMemberMythicPlusScore then
        local score, color = GOW.core:GetMemberMythicPlusScore(m)
        local scoreText = score and tostring(math.floor(score + 0.5)) or "--"
        if color and score then
          scoreText = color:WrapTextInColorCode(scoreText)
        end
        row.scoreFS:SetText(scoreText)
        row.scoreFS:Show()
        zoneLeftX = COL_ZONE_WITH_SCORE_X
      else
        row.scoreFS:SetText("")
        row.scoreFS:Hide()
      end

      row.zoneFS:SetPoint("LEFT", row, "LEFT", zoneLeftX, 0)
      local zoneMaxChars = self:GetZoneMaxChars(row, zoneLeftX)
      row.zoneFS:SetText(U.Truncate((m.isMobile and "Mobile") or m.zone or "", zoneMaxChars))
      row:Show()
      shown = shown + 1
    end

    for i = shown + 1, MAX_ROWS do
      self.rows[i]:Hide()
      self.rows[i].member = nil
    end

    local height = 12 + ROW_HEIGHT + (shown * ROW_HEIGHT)
    if shown == 0 then
      self:SetSize(TOOLTIP_WIDTH_EMPTY, 40)
    else
      self:SetSize(tooltipWidth, height)
    end

    self:UpdateAnchor(self.owner)
  end

  t:SetScript("OnUpdate", function(selfFrame, elapsed)
    if not selfFrame:IsShown() then return end

    selfFrame.rosterRefreshElapsed = (selfFrame.rosterRefreshElapsed or 0) + (elapsed or 0)
    if selfFrame.rosterRefreshElapsed >= TOOLTIP_ROSTER_REFRESH_INTERVAL then
      selfFrame.rosterRefreshElapsed = 0
      if GOW.core and GOW.core.RequestRoster then
        GOW.core:RequestRoster(false)
      end
    end

    if selfFrame.pinned then return end

    -- Retail: GetMouseFocus() may be unavailable. Use IsMouseOver checks instead.
    if selfFrame:IsMouseOver() then return end
    if selfFrame.owner and selfFrame.owner.IsMouseOver and selfFrame.owner:IsMouseOver() then return end

    for i = 1, MAX_ROWS do
      local row = selfFrame.rows[i]
      if row and row:IsShown() and row:IsMouseOver() then
        return
      end
    end

    selfFrame.hoverPreview = false
    selfFrame:Hide()
  end)

  return t
end
