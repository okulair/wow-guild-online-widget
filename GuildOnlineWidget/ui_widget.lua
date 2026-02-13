local GOW = _G.GuildOnlineWidget

GOW.widget = GOW.widget or nil

function GOW:SavePosition(frame)
  local point, _, relPoint, x, y = frame:GetPoint(1)
  self.db.point = point
  self.db.relPoint = relPoint
  self.db.x = x
  self.db.y = y
end

function GOW:CreateWidget()
  if self.widget then return self.widget end

  local f = CreateFrame("Button", "GuildOnlineWidgetFrame", UIParent, "BackdropTemplate")
  self.widget = f
  f:SetSize(132, 24)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  f:RegisterForDrag("LeftButton")

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0.05, 0.05, 0.08, 0.75)
  f:SetBackdropBorderColor(0.3, 0.45, 0.65, 0.9)

  function f:SetPinnedVisual(isPinned)
    if isPinned then
      self:SetBackdropColor(0.05, 0.08, 0.10, 0.92)
      self:SetBackdropBorderColor(0.35, 0.85, 1.00, 1.00)
    else
      self:SetBackdropColor(0.05, 0.05, 0.08, 0.75)
      self:SetBackdropBorderColor(0.3, 0.45, 0.65, 0.9)
    end
  end

  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.text = text
  text:SetPoint("CENTER", f, "CENTER", 0, 0)
  text:SetText("Online: --")

  function f:RestorePosition()
    self:ClearAllPoints()
    self:SetPoint(GOW.db.point, UIParent, GOW.db.relPoint, GOW.db.x, GOW.db.y)
  end

  function f:ApplyMovableState()
    self:SetMovable(not GOW.db.locked)
    if GOW.db.locked then
      self:RegisterForDrag()
    else
      self:RegisterForDrag("LeftButton")
    end
  end

  function f:UpdateText()
    local s = GOW.state
    local label
    if not IsInGuild() then
      label = "No guild"
    elseif s.loading then
      label = "Loading..."
    elseif GOW.db.showTotal then
      label = ("Online: %d/%d"):format(s.onlineCount or 0, s.totalCount or 0)
    else
      label = ("Online: %d"):format(s.onlineCount or 0)
    end
    self.text:SetText(label)
  end

  f:SetScript("OnDragStart", function(selfBtn)
    local editModeActive = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
    if not GOW.db.locked and not editModeActive then
      selfBtn:StartMoving()
    end
  end)

  f:SetScript("OnDragStop", function(selfBtn)
    selfBtn:StopMovingOrSizing()
    GOW:SavePosition(selfBtn)
  end)

  f:SetScript("OnEnter", function(selfBtn)
    if GOW.tooltip then GOW.tooltip:ShowPreview(selfBtn) end
  end)

  f:SetScript("OnLeave", function()
    -- Tooltip handles delayed self-hide to allow row interactions.
  end)

  f:SetScript("OnClick", function(selfBtn, button)
    if button == "LeftButton" and GOW.tooltip then
      GOW.tooltip:TogglePinned(selfBtn)
      selfBtn:SetPinnedVisual(GOW.tooltip and GOW.tooltip.pinned)
    elseif button == "RightButton" and GOW.ShowWidgetMenu then
      GOW:ShowWidgetMenu()
    end
  end)

  f:RestorePosition()
  f:SetScale(self.db.scale or 1)
  f:ApplyMovableState()
  f:UpdateText()
  f:SetPinnedVisual(GOW.tooltip and GOW.tooltip.pinned)

  return f
end
