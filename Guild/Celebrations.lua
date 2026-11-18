--[[
  Warcrest
  Celebrations: tells the guild when a member levels up.
  Members choose between every level, or only every 10 levels and max level.
]]

local _, ns = ...

local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"
local CHEER_COLOR = "|cffffd200"

local function maxLevel()
  local ok, n = pcall(function() return GetMaxPlayerLevel and GetMaxPlayerLevel() end)
  n = ok and ns.Usable(n)
  return (type(n) == "number" and n > 0) and n or (MAX_PLAYER_LEVEL or 60)
end

-- Which alert type a level counts as.
local function kindFor(level)
  if level == maxLevel() or level % 10 == 0 then return "level_ten" end
  return "level_all"
end

ns.OnEvent("PLAYER_LEVEL_UP", function(level)
  level = tonumber(ns.Usable(level))
  if not level then return end
  local c = ns.cfg
  local kind = kindFor(level)
  -- "Every level up" includes the milestones, so send if either is on.
  if not (c.enabled and (c.types[kind] or c.types.level_all)) then return end
  ns.Send("L", level, GetServerTime())
end)

function ns.DescribeLevel(who, level)
  if level == maxLevel() then
    return ("%s has reached level %d! %s salutes you!"):format(who, level, ns.GuildName() or "The guild")
  end
  return ("%s reached level %d!"):format(who, level)
end

function ns.ShowLevel(who, level, force)
  local kind = kindFor(level)
  if not force then
    local c, show = ns.cfg, ns.db.show
    if not c.enabled then return end
    -- Milestones show if either option is on; other levels only for "every level".
    local wanted = (kind == "level_ten" and ((c.types.level_ten and show.level_ten) or (c.types.level_all and show.level_all)))
      or (kind == "level_all" and c.types.level_all and show.level_all)
    if not wanted then return end
  end
  local text = CHEER_COLOR .. ns.DescribeLevel(who, level) .. "|r"
  local sound = SOUNDKIT and (level == maxLevel() and (SOUNDKIT.LEVELUP or SOUNDKIT.UI_LEVELUP) or SOUNDKIT.RAID_WARNING)
  ns.Notify(STAR .. " " .. text, STAR .. " " .. text .. " " .. STAR, sound, force, "celebrate",
    level == maxLevel() and "Max level" or "Level up")
end

ns.OnMessage("L", function(p, sender)
  local level = tonumber(p[2])
  if not level or level < 2 then return end
  ns.ShowLevel(Ambiguate(sender, "short"), level)
end)

ns.MaxLevel = maxLevel
