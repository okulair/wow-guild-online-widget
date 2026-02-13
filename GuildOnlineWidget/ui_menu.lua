local GOW = _G.GuildOnlineWidget

local dropdown

local function EnsureDropdown()
  if dropdown then return dropdown end
  dropdown = CreateFrame("Frame", "GuildOnlineWidgetDropDown", UIParent, "UIDropDownMenuTemplate")
  return dropdown
end

local function DoWhisper(member)
  if not member then return end
  if ChatFrame_SendTell then
    ChatFrame_SendTell(Ambiguate(member.name or "", "short"))
  end
end

local function DoInvite(member)
  if not member then return end
  InviteUnit(Ambiguate(member.name or "", "none"))
end

local function DoTarget(member)
  if not member or not member.name then return end
  pcall(TargetUnit, member.name)
end

local function DoWho(member)
  if not member then return end
  SendWho("n-\"" .. (Ambiguate(member.name or "", "short")) .. "\"")
end

local function MemberMenuData(member)
  local short = Ambiguate(member.name or "", "short")
  return {
    { text = short, isTitle = true, notCheckable = true },
    { text = "Whisper", func = function() DoWhisper(member) end, notCheckable = true },
    { text = "Invite", func = function() DoInvite(member) end, notCheckable = true },
    { text = "Target", func = function() DoTarget(member) end, notCheckable = true },
    { text = "Who", func = function() DoWho(member) end, notCheckable = true },
    { text = "Close", func = function() CloseDropDownMenus() end, notCheckable = true },
  }
end

local function ShowMemberMenuModern(anchor, member)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end

  local ok = pcall(function()
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      root:CreateTitle(Ambiguate(member.name or "", "short"))
      root:CreateButton("Whisper", function() DoWhisper(member) end)
      root:CreateButton("Invite", function() DoInvite(member) end)
      root:CreateButton("Target", function() DoTarget(member) end)
      root:CreateButton("Who", function() DoWho(member) end)
    end)
  end)

  return ok
end

local function ShowWidgetMenuModern(anchor)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end

  local ok = pcall(function()
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      root:CreateTitle("Guild Online Widget")

      root:CreateButton(GOW.db.locked and "Unlock" or "Lock", function()
        GOW.db.locked = not GOW.db.locked
        GOW:PersistDB()
        if GOW.widget then GOW.widget:ApplyMovableState() end
      end)

      root:CreateButton(GOW.db.showTotal and "Hide Total" or "Show Total", function()
        GOW.db.showTotal = not GOW.db.showTotal
        GOW:PersistDB()
        if GOW.widget then GOW.widget:UpdateText() end
      end)

      root:CreateButton(GOW.db.showMythicPlusScore and "Hide Mythic+ Score" or "Show Mythic+ Score", function()
        GOW.db.showMythicPlusScore = not GOW.db.showMythicPlusScore
        GOW:PersistDB()
        if GOW.db.showMythicPlusScore and GOW.core and GOW.core.ScanMythicPlusScores then
          GOW.core:ScanMythicPlusScores(true)
        end
        if GOW.tooltip and GOW.tooltip:IsShown() then GOW.tooltip:RefreshRows() end
      end)

      local function IsSortSelected(sortValue)
        return GOW.db.sort == sortValue
      end

      local function SetSortSelected(sortValue)
        GOW.db.sort = sortValue
        GOW:PersistDB()
        GOW.core:OnRosterUpdate()
      end

      local sort = root:CreateButton("Sort")
      sort:CreateRadio("Name", IsSortSelected, SetSortSelected, "name")
      sort:CreateRadio("Level", IsSortSelected, SetSortSelected, "level")
      sort:CreateRadio("Zone", IsSortSelected, SetSortSelected, "zone")

      root:CreateButton("Scale +", function()
        GOW.db.scale = math.min((GOW.db.scale or 1) + 0.05, 2)
        GOW:PersistDB()
        if GOW.widget then GOW.widget:SetScale(GOW.db.scale) end
      end)

      root:CreateButton("Scale -", function()
        GOW.db.scale = math.max((GOW.db.scale or 1) - 0.05, 0.6)
        GOW:PersistDB()
        if GOW.widget then GOW.widget:SetScale(GOW.db.scale) end
      end)

      root:CreateButton("Reset Position", function()
        GOW.db.point, GOW.db.relPoint, GOW.db.x, GOW.db.y = "CENTER", "CENTER", 0, 0
        GOW:PersistDB()
        if GOW.widget then GOW.widget:RestorePosition() end
      end)

      root:CreateButton("Refresh Roster", function()
        GOW.core:RequestRoster(true)
      end)

      if EditModeManagerFrame and EditModeManagerFrame.CanEnterEditMode then
        root:CreateButton(HUD_EDIT_MODE_MENU or "Edit Mode", function()
          if EditModeManagerFrame:CanEnterEditMode() then
            ShowUIPanel(EditModeManagerFrame)
          end
        end)
      end
    end)
  end)

  return ok
end

local function ShowMenuDropdown(anchor, entries)
  local dd = EnsureDropdown()
  EasyMenu(entries, dd, "cursor", 0, 0, "MENU", 2)
end

function GOW:ShowMemberMenu(member, anchor)
  if not member then return end
  local owner = anchor or self.widget
  if not ShowMemberMenuModern(owner, member) then
    ShowMenuDropdown(owner, MemberMenuData(member))
  end
end

function GOW:ShowWidgetMenu()
  local entries = {
    { text = "Guild Online Widget", isTitle = true, notCheckable = true },
    {
      text = self.db.locked and "Unlock" or "Lock",
      notCheckable = true,
      func = function()
        self.db.locked = not self.db.locked
        self:PersistDB()
        if self.widget then self.widget:ApplyMovableState() end
      end,
    },
    {
      text = self.db.showTotal and "Hide Total" or "Show Total",
      notCheckable = true,
      func = function()
        self.db.showTotal = not self.db.showTotal
        self:PersistDB()
        if self.widget then self.widget:UpdateText() end
      end,
    },
    {
      text = self.db.showMythicPlusScore and "Hide Mythic+ Score" or "Show Mythic+ Score",
      notCheckable = true,
      func = function()
        self.db.showMythicPlusScore = not self.db.showMythicPlusScore
        self:PersistDB()
        if self.db.showMythicPlusScore and self.core and self.core.ScanMythicPlusScores then
          self.core:ScanMythicPlusScores(true)
        end
        if self.tooltip and self.tooltip:IsShown() then self.tooltip:RefreshRows() end
      end,
    },
    {
      text = "Sort",
      notCheckable = true,
      hasArrow = true,
      menuList = {
        { text = "Name", checked = self.db.sort == "name", isNotRadio = false, keepShownOnClick = false, func = function() self.db.sort = "name"; self:PersistDB(); self.core:OnRosterUpdate() end },
        { text = "Level", checked = self.db.sort == "level", isNotRadio = false, keepShownOnClick = false, func = function() self.db.sort = "level"; self:PersistDB(); self.core:OnRosterUpdate() end },
        { text = "Zone", checked = self.db.sort == "zone", isNotRadio = false, keepShownOnClick = false, func = function() self.db.sort = "zone"; self:PersistDB(); self.core:OnRosterUpdate() end },
      },
    },
    { text = "Scale +", notCheckable = true, func = function() self.db.scale = math.min((self.db.scale or 1) + 0.05, 2); self:PersistDB(); self.widget:SetScale(self.db.scale) end },
    { text = "Scale -", notCheckable = true, func = function() self.db.scale = math.max((self.db.scale or 1) - 0.05, 0.6); self:PersistDB(); self.widget:SetScale(self.db.scale) end },
    { text = "Reset Position", notCheckable = true, func = function() self.db.point, self.db.relPoint, self.db.x, self.db.y = "CENTER", "CENTER", 0, 0; self:PersistDB(); if self.widget then self.widget:RestorePosition() end end },
    { text = "Refresh Roster", notCheckable = true, func = function() self.core:RequestRoster(true) end },
  }

  if not ShowWidgetMenuModern(self.widget) then
    ShowMenuDropdown(self.widget, entries)
  end
end
