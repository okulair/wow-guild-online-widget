local ADDON_NAME, ns = ...

_G.GuildOnlineWidget = _G.GuildOnlineWidget or {}
local GOW = _G.GuildOnlineWidget

GOW.name = ADDON_NAME or "GuildOnlineWidget"
GOW.ns = ns
GOW.state = {
  online = {},
  sorted = {},
  onlineCount = 0,
  totalCount = 0,
  loading = true,
  mythicPlusCache = {},
}

GOW.defaults = {
  version = 1,
  locked = false,
  scale = 1,
  alpha = 0.75,
  showTotal = false,
  showMythicPlusScore = false,
  sort = "name", -- name|level|zone
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = 0,
}

function GOW:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff58c6ffGOW|r " .. tostring(msg))
end

local function CopyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function GOW:InitDB()
  GuildOnlineWidgetDB = CopyDefaults(GuildOnlineWidgetDB, self.defaults)
  self.db = GuildOnlineWidgetDB
end

-- Explicitly re-assign the global SavedVariables reference. This is normally
-- unnecessary (tables are by reference), but it helps avoid edge cases where a
-- consumer accidentally swaps GOW.db.
function GOW:PersistDB()
  GuildOnlineWidgetDB = self.db
end
