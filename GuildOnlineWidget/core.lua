local GOW = _G.GuildOnlineWidget
local U = GOW.util

GOW.core = GOW.core or {}
local Core = GOW.core

Core.lastGuildRosterRequest = 0
Core.refreshThrottle = 12
Core.mythicPlusTTL = 300
Core.mythicPlusScanThrottle = 10
Core.lastMythicPlusScan = 0

local function RequestGuildRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
    return true
  end

  if GuildRoster then
    GuildRoster()
    return true
  end

  return false
end

local function GetMPlusColor(score)
  if not score or score <= 0 then
    return nil
  end

  if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
    return C_ChallengeMode.GetDungeonScoreRarityColor(score)
  end

  return nil
end

function Core:RequestRoster(force)
  if not IsInGuild() then
    GOW.state.loading = false
    GOW.state.online = {}
    GOW.state.sorted = {}
    GOW.state.onlineCount = 0
    GOW.state.totalCount = 0
    if GOW.widget then GOW.widget:UpdateText() end
    if GOW.tooltip and GOW.tooltip:IsShown() then GOW.tooltip:RefreshRows() end
    return
  end

  local now = GetTime()
  if not force and (now - self.lastGuildRosterRequest) < self.refreshThrottle then
    return
  end
  self.lastGuildRosterRequest = now

  GOW.state.loading = true
  local ok = RequestGuildRoster()
  if not ok then
    -- If we can't request, don't leave the UI stuck in loading.
    GOW.state.loading = false
    if GOW.widget then GOW.widget:UpdateText() end
  end
end

function Core:BuildSnapshot()
  local state = GOW.state
  wipe(state.online)
  wipe(state.sorted)

  if not IsInGuild() then
    state.loading = false
    state.onlineCount = 0
    state.totalCount = 0
    return
  end

  local total, online = GetNumGuildMembers()
  state.totalCount = tonumber(total) or 0
  state.onlineCount = tonumber(online) or 0
  state.loading = false

  for i = 1, state.totalCount do
    -- Return mapping currently used by Blizzard codepaths:
    -- name, rank, rankIndex, level, class, zone, note, officerNote,
    -- isOnline, status, classFileName, achievementPoints, achievementRank,
    -- isMobile, canSoR, reputation, guid
    local name, _, _, level, _, zone, _, _, isOnline, status, classFileName, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
    if isOnline then
      local fullName = name or "Unknown"
      local key = U.GetNameKey(fullName, guid)
      local row = {
        name = fullName,
        level = tonumber(level) or 0,
        zone = zone or "",
        classFile = classFileName,
        isMobile = isMobile and true or false,
        status = status,
        guid = guid,
        lastSeen = GetTime(),
        mplusKey = key,
      }
      state.online[key] = row
      state.sorted[#state.sorted + 1] = row
    end
  end

  U.SortMembers(state.sorted, GOW.db.sort)
end

function Core:ScanMythicPlusScores(force)
  if not (GOW.db and GOW.db.showMythicPlusScore) then return end
  if not IsInGuild() then return end
  if not (C_Club and C_Club.GetGuildClubId and C_Club.GetClubMembers and C_Club.GetMemberInfo) then return end

  local now = GetTime()
  if not force and (now - self.lastMythicPlusScan) < self.mythicPlusScanThrottle then
    return
  end
  self.lastMythicPlusScan = now

  local clubId = C_Club.GetGuildClubId()
  if not clubId then return end

  local members = C_Club.GetClubMembers(clubId)
  if not members then return end

  local state = GOW.state
  state.mythicPlusCache = state.mythicPlusCache or {}

  local changed = false
  for i = 1, #members do
    local info = C_Club.GetMemberInfo(clubId, members[i])
    if info then
      local key = U.GetNameKey(info.name, info.guid)
      local old = state.mythicPlusCache[key]
      local score = tonumber(info.overallDungeonScore)
      if not old or old.score ~= score then
        changed = true
      end
      state.mythicPlusCache[key] = {
        score = score,
        updated = now,
        color = GetMPlusColor(score),
      }
    end
  end

  if changed and GOW.tooltip and GOW.tooltip:IsShown() then
    GOW.tooltip:RefreshRows()
  end
end

function Core:GetMemberMythicPlusScore(member)
  if not member then return nil, nil end
  if not (GOW.db and GOW.db.showMythicPlusScore) then return nil, nil end

  local state = GOW.state
  state.mythicPlusCache = state.mythicPlusCache or {}

  local key = member.mplusKey or U.GetNameKey(member.name, member.guid)
  local now = GetTime()
  local entry = state.mythicPlusCache[key]

  if not entry or (now - (entry.updated or 0)) > self.mythicPlusTTL then
    self:ScanMythicPlusScores(false)
    entry = state.mythicPlusCache[key]
  end

  if not entry then
    return nil, nil
  end

  return entry.score, entry.color or GetMPlusColor(entry.score)
end

function Core:OnRosterUpdate()
  self:BuildSnapshot()
  self:ScanMythicPlusScores(false)
  if GOW.widget then GOW.widget:UpdateText() end
  if GOW.tooltip and GOW.tooltip:IsShown() then GOW.tooltip:RefreshRows() end
end

local function HandleSlash(msg)
  msg = strtrim((msg or ""):lower())

  if msg == "" or msg == "help" then
    GOW:Print("/gow lock | unlock | reset | scale <n> | sort name|level|zone")
    return
  end

  local cmd, arg = msg:match("^(%S+)%s*(.-)$")
  if cmd == "lock" then
    GOW.db.locked = true
    GOW:PersistDB()
    if GOW.widget then GOW.widget:ApplyMovableState() end
    GOW:Print("Widget locked")
  elseif cmd == "unlock" then
    GOW.db.locked = false
    GOW:PersistDB()
    if GOW.widget then GOW.widget:ApplyMovableState() end
    GOW:Print("Widget unlocked")
  elseif cmd == "reset" then
    GOW.db.point, GOW.db.relPoint, GOW.db.x, GOW.db.y = "CENTER", "CENTER", 0, 0
    GOW:PersistDB()
    if GOW.widget then GOW.widget:RestorePosition() end
    GOW:Print("Position reset")
  elseif cmd == "scale" then
    local n = tonumber(arg)
    if n and n >= 0.6 and n <= 2 then
      GOW.db.scale = n
      GOW:PersistDB()
      if GOW.widget then GOW.widget:SetScale(n) end
      GOW:Print(("Scale set to %.2f"):format(n))
    else
      GOW:Print("Scale must be between 0.6 and 2.0")
    end
  elseif cmd == "sort" then
    if arg == "name" or arg == "level" or arg == "zone" then
      GOW.db.sort = arg
      GOW:PersistDB()
      U.SortMembers(GOW.state.sorted, GOW.db.sort)
      if GOW.tooltip and GOW.tooltip:IsShown() then GOW.tooltip:RefreshRows() end
      GOW:Print("Sort set to " .. arg)
    else
      GOW:Print("Sort must be name, level, or zone")
    end
  else
    GOW:Print("Unknown command. /gow help")
  end
end

function Core:Initialize()
  if self.initialized then return end
  self.initialized = true

  -- SavedVariables are guaranteed to be loaded by the time ADDON_LOADED fires.
  GOW:InitDB()

  if GOW.CreateWidget then GOW:CreateWidget() end
  if GOW.CreateTooltip then GOW:CreateTooltip() end

  SLASH_GUILDONLINEWIDGET1 = "/gow"
  SlashCmdList.GUILDONLINEWIDGET = HandleSlash

  local ev = CreateFrame("Frame")
  self.eventFrame = ev

  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_GUILD_UPDATE")
  ev:RegisterEvent("GUILD_ROSTER_UPDATE")
  ev:RegisterEvent("CLUB_MEMBERS_UPDATED")
  ev:RegisterEvent("CLUB_MEMBER_UPDATED")

  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
      self:RequestRoster(true)
      C_Timer.After(1, function() self:RequestRoster(true) end)
      -- Fallback: roster update events sometimes lag; build snapshot from whatever data we have.
      C_Timer.After(2, function() self:OnRosterUpdate() end)
      C_Timer.After(2, function() self:ScanMythicPlusScores(true) end)
    elseif event == "PLAYER_GUILD_UPDATE" then
      self:RequestRoster(true)
    elseif event == "GUILD_ROSTER_UPDATE" then
      self:OnRosterUpdate()
    elseif event == "CLUB_MEMBERS_UPDATED" or event == "CLUB_MEMBER_UPDATED" then
      self:ScanMythicPlusScores(true)
    end
  end)
end

-- Defer initialization until SavedVariables are available.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
  if addonName == GOW.name then
    Core:Initialize()
    loader:UnregisterEvent("ADDON_LOADED")
  end
end)
