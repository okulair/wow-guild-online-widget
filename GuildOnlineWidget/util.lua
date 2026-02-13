local GOW = _G.GuildOnlineWidget

GOW.util = GOW.util or {}
local U = GOW.util

function U.SafeAmbiguate(name)
  if not name or name == "" then return "" end
  local ok, result = pcall(Ambiguate, name, "short")
  if ok and result and result ~= "" then
    return result
  end
  return name
end

function U.ClassColoredName(name, classFile)
  name = U.SafeAmbiguate(name)
  if not classFile then return name end

  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not c then return name end
  return ("|c%s%s|r"):format(c.colorStr or "ffffffff", name)
end

function U.Truncate(text, maxLen)
  if not text then return "" end
  text = tostring(text)
  maxLen = maxLen or 28
  if #text <= maxLen then return text end
  return text:sub(1, maxLen - 1) .. "…"
end

function U.GetNameKey(name, guid)
  if guid and guid ~= "" then return guid end
  return (name and name:lower()) or tostring(math.random())
end

function U.SortMembers(members, sortBy)
  table.sort(members, function(a, b)
    if sortBy == "level" then
      if (a.level or 0) ~= (b.level or 0) then
        return (a.level or 0) > (b.level or 0)
      end
      return (a.name or "") < (b.name or "")
    elseif sortBy == "zone" then
      if (a.zone or "") ~= (b.zone or "") then
        return (a.zone or "") < (b.zone or "")
      end
      return (a.name or "") < (b.name or "")
    end
    return (a.name or "") < (b.name or "")
  end)
end
