--[[
  Warcrest
  Bounties: officers put a reward on an enemy player's head, and the guild
  member who lands the killing blow claims it.

  Off until the Guild Master or an officer turns it on for the guild
  (Settings > Alerts > Bounties). With DKP on, the reward is DKP, paid
  automatically; with DKP off, a bounty is for the glory.

  Ledger entries (officers only):
    BO  a bounty: target, amount (DKP), note
    BX  a bounty withdrawn: ref
    BC  a bounty claimed: ref, killer, when (the kill's time)
  A bounty lasts 30 days. One officer's addon pays each claim: the one who
  placed the bounty if they're online, otherwise the first online officer
  with Warcrest (by name), after a short random wait, so it's paid once.
]]

local _, ns = ...

local LASTS = 30 * 86400
local MAX_AMOUNT = 1000
local PAY_WAIT = 3

local BOUNTY_COLOR = "|cffffb347"

function ns.BountiesOn()
  return ns.cfg ~= nil and ns.cfg.bounties == true
end

------------------------------------------------------------------------
-- Reading bounties
------------------------------------------------------------------------
-- Every bounty, newest first: { id, target, amount, note, by, t, expires,
-- state = "open" | "claimed" | "withdrawn" | "expired", killer, claimedAt }.
function ns.Bounties()
  local withdrawn, claims = {}, {}
  for _, e in ipairs(ns.LedgerEntries("BX")) do withdrawn[e.ref] = e end
  for _, e in ipairs(ns.LedgerEntries("BC")) do
    if not claims[e.ref] or e.t < claims[e.ref].t then claims[e.ref] = e end -- the first claim stands
  end
  local now, out = GetServerTime(), {}
  for _, e in ipairs(ns.LedgerEntries("BO")) do
    local b = { id = e.id, target = e.target, amount = e.amount or 0, note = e.note or "", by = Ambiguate(e.a, "short"),
      t = e.t, expires = e.t + LASTS }
    local c = claims[e.id]
    if c then
      b.state, b.killer, b.claimedAt = "claimed", c.killer, tonumber(c.when) or c.t
    elseif withdrawn[e.id] then
      b.state = "withdrawn"
    elseif now >= b.expires then
      b.state = "expired"
    else
      b.state = "open"
    end
    out[#out + 1] = b
  end
  table.sort(out, function(a, b) return a.t > b.t end)
  return out
end

-- The open bounty on an enemy player, if any (the biggest, if several).
function ns.BountyOn(target)
  local key, best = ns.Key(target or ""), nil
  for _, b in ipairs(ns.Bounties()) do
    if b.state == "open" and ns.Key(b.target) == key and (not best or b.amount > best.amount) then best = b end
  end
  return best
end

-- Bounties a guild member has claimed (sorted times), for achievements.
function ns.BountyClaimTimes(name)
  local key, out = ns.Key(name), {}
  for _, b in ipairs(ns.Bounties()) do
    if b.state == "claimed" and ns.Key(b.killer) == key then out[#out + 1] = b.claimedAt end
  end
  table.sort(out)
  return out
end

------------------------------------------------------------------------
-- Placing and withdrawing (officers)
------------------------------------------------------------------------
function ns.PlaceBounty(target, amount, note)
  if not ns.BountiesOn() then ns.Say("Bounties are off for the guild. An officer can turn them on in Settings.") return end
  if not ns.IsAddonOfficer() then ns.Say("Only officers can place bounties.") return end
  target = target and Ambiguate(strtrim(target), "short") or ""
  if target == "" or target:find("[%s%d]") then ns.Say("Type the enemy player's name.") return end
  if ns.Member(target) then ns.Say(target .. " is in the guild.") return end
  amount = ns.UsesDKP() and math.floor(tonumber(amount) or 0) or 0
  if amount < 0 or amount > MAX_AMOUNT then ns.Say(ns.TF("The reward must be between 0 and %d DKP.", MAX_AMOUNT)) return end
  if ns.BountyOn(target) then ns.Say("There's already a bounty on " .. target .. ".") return end
  local e = ns.LedgerAdd("BO", { target = target, amount = amount, note = note or "" })
  return e
end

function ns.WithdrawBounty(id)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can withdraw bounties.") return end
  return ns.LedgerAdd("BX", { ref = id })
end

------------------------------------------------------------------------
-- Claiming and paying
------------------------------------------------------------------------
local function onlineOfficers()
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    if m.online and ns.IsOfficerName(m.name)
        and (ns.IsMe(m.name) or (ns.versions[ns.fullName(m.name)] and ns.CompareVersions(ns.versions[ns.fullName(m.name)], "3.2.0") >= 0)) then
      out[#out + 1] = Ambiguate(m.name, "short")
    end
  end
  table.sort(out)
  return out
end

-- Whether this addon pays a bounty's claim.
local function iPay(b)
  local officers = onlineOfficers()
  local payer
  for _, n in ipairs(officers) do
    if ns.Key(n) == ns.Key(b.by) then payer = n end
  end
  payer = payer or officers[1]
  return payer ~= nil and ns.IsMe(payer)
end

-- The first killing blow on the target while the bounty was open.
local function claimingKill(b)
  local best
  for _, k in ipairs(ns.db.killLog or {}) do
    if k.t >= b.t and k.t < b.expires and ns.Key(k.victim) == ns.Key(b.target) and not ns.KillHidden(k) then
      local kb = ns.KillingBlow(k)
      if kb and (not best or k.t < best.t) then best = { t = k.t, killer = kb } end
    end
  end
  return best
end

local function payClaims()
  if not (ns.BountiesOn() and ns.IsAddonOfficer()) then return end
  for _, b in ipairs(ns.Bounties()) do
    if b.state == "open" then
      local kill = claimingKill(b)
      if kill and iPay(b) then
        ns.LedgerAdd("BC", { ref = b.id, killer = kill.killer, when = kill.t })
        if ns.UsesDKP() and b.amount > 0 then
          ns.AwardDKP({ kill.killer }, b.amount, "Bounty: " .. b.target)
        end
      end
    end
  end
end

local pending = false
local function check()
  if pending then return end
  pending = true
  C_Timer.After(PAY_WAIT + math.random() * 3, function()
    pending = false
    payClaims()
  end)
end

local previousHook = ns.OnHistoryChanged
function ns.OnHistoryChanged()
  check()
  if previousHook then previousHook() end
end

------------------------------------------------------------------------
-- Announcements
------------------------------------------------------------------------
local seen = {}       -- ledger ids already announced (or there at login)
local ready = false

local function wanted()
  local c, show = ns.cfg, ns.db.show
  return ns.BountiesOn() and c.enabled and c.types.bounty and show.bounty
end

-- quiet: just note what's there (at login), without announcing it.
local function announce(quiet)
  local fresh = GetServerTime() - 15 * 60
  for _, b in ipairs(ns.Bounties()) do
    local key = b.id .. ":" .. b.state
    if not seen[key] then
      seen[key] = true
      if ready and not quiet and wanted() then
        if b.state == "open" and b.t >= fresh then
          local text = b.amount > 0 and ns.TF("Bounty placed: %d DKP on %s's head, by %s.", b.amount, b.target, b.by)
            or ns.TF("Bounty placed on %s's head, by %s.", b.target, b.by)
          if b.note ~= "" then text = text .. " \"" .. b.note .. "\"" end
          ns.Notify(ns.KILL_ICON .. " " .. BOUNTY_COLOR .. text .. "|r", BOUNTY_COLOR .. text .. "|r", nil, nil, "bounty")
        elseif b.state == "claimed" and (b.claimedAt or 0) >= fresh then
          local text = (b.amount > 0 and ns.UsesDKP()) and ns.TF("%s claimed the bounty on %s for %d DKP!", b.killer, b.target, b.amount)
            or ns.TF("%s claimed the bounty on %s!", b.killer, b.target)
          ns.Notify(ns.KILL_ICON .. " " .. BOUNTY_COLOR .. text .. "|r", BOUNTY_COLOR .. text .. "|r", nil, nil, "bounty")
        end
      end
    end
  end
end

table.insert(ns.OnGuildReady, function()
  announce(true)
  ready = true
end)

ns.OnLoad(function()
  ns.OnLedgerChanged(function()
    announce()
    check()
  end)
end)
