--[[
  Bannerhold
  Officer Log: records guild changes seen while you're online.
  Promotions, demotions, removals, joins and leaves come from the game's own
  system messages, so they're logged no matter how they were done.
  Note, MOTD and settings changes made through the addon are shared by the
  addon itself (without the note text).
]]

local _, ns = ...
local MAX_ENTRIES = 300

ns.OnLoad(function()
  ns.db.audit = ns.db.audit or {}
end)

local function add(actor, action, target, detail)
  if ns.IsWiped and ns.IsWiped("audit", time()) then return end
  local log = ns.db.audit
  table.insert(log, 1, { t = time(), actor = actor or "", action = action,
    target = target or "", detail = detail or "" })
  while #log > MAX_ENTRIES do table.remove(log) end
  if ns.RefreshPanel then ns.RefreshPanel() end
end

local ADDON_ACTIONS = { note = true, onote = true, motd = true, settings = true }

function ns.LogAction(action, target, detail)
  ns.Send("A", action, target or "", detail or "")
end

ns.OnMessage("A", function(parts, sender)
  if not ADDON_ACTIONS[parts[2]] then return end
  add(Ambiguate(sender, "short"), parts[2], parts[3], parts[4])
end)

local SYSTEM = {
  { global = "ERR_GUILD_PROMOTE_SSS", action = "promote", map = function(a, b, c) return a, b, c end },
  { global = "ERR_GUILD_DEMOTE_SSS",  action = "demote",  map = function(a, b, c) return a, b, c end },
  { global = "ERR_GUILD_REMOVE_SS",   action = "remove",  map = function(target, by) return by, target end },
  { global = "ERR_GUILD_JOIN_S",      action = "join",    map = function(a) return a, a end },
  { global = "ERR_GUILD_LEAVE_S",     action = "leave",   map = function(a) return a, a end },
}

ns.OnLoad(function()
  for _, s in ipairs(SYSTEM) do s.pattern = ns.FormatToPattern(_G[s.global]) end
end)

ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
  text = ns.Usable(text)
  if type(text) ~= "string" then return end
  text = text:gsub("|H.-|h%[?(.-)%]?|h", "%1")
  for _, s in ipairs(SYSTEM) do
    if s.pattern then
      local caps = { text:match(s.pattern) }
      if caps[1] then
        local actor, target, detail = s.map(unpack(caps))
        add(actor, s.action, target, detail)
        return
      end
    end
  end
end)

local DESCRIBE = {
  promote  = function(e) return ("%s promoted %s to %s"):format(e.actor, e.target, e.detail) end,
  demote   = function(e) return ("%s demoted %s to %s"):format(e.actor, e.target, e.detail) end,
  remove   = function(e) return ("%s removed %s from the guild"):format(e.actor, e.target) end,
  join     = function(e) return ("%s joined the guild"):format(e.target) end,
  leave    = function(e) return ("%s left the guild"):format(e.target) end,
  note     = function(e) return ("%s edited %s's public note"):format(e.actor, e.target) end,
  onote    = function(e) return ("%s edited %s's officer note"):format(e.actor, e.target) end,
  motd     = function(e) return ("%s changed the Message of the Day"):format(e.actor) end,
  settings = function(e) return ("%s changed the guild alert settings"):format(e.actor) end,
}

function ns.DescribeAction(e)
  local f = DESCRIBE[e.action]
  return f and f(e) or (e.actor .. " " .. tostring(e.action))
end

function ns.ClearAudit() ns.WipeLog("audit") end
