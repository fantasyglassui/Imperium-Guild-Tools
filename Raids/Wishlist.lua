--[[
  Warcrest
  Loot wishlists: each guild member marks the items they want from raids,
  as Need (a big upgrade) or Want (nice to have).

  Wishes are entries in the shared ledger (kind WL), written by each member
  for themselves only, so every guildmate sees the same lists. An item someone
  has won since they wished for it counts as received: it stays on their own
  list, marked Won, but no longer counts them as wanting it.

  When an auction starts, everyone who wished for the item hears about it,
  and the auction window shows who has it on their wishlist.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local MAX_WISHES = 40
local PRIOS = { need = true, want = true }
ns.WISH_PRIO_ORDER = { need = 1, want = 2 }

-- The item ID in an item link (or a bare ID), as a string.
function ns.ItemID(link)
  if not link then return end
  link = tostring(link)
  return link:match("item:(%d+)") or link:match("^%s*(%d+)%s*$")
end

-- An item's name from its link.
local function linkName(link)
  return link and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]"))
end

------------------------------------------------------------------------
-- Reading the wishlists
------------------------------------------------------------------------
local cache

ns.OnLedgerChanged(function() cache = nil end)

-- When each member last won each item: key -> itemID -> time.
local function wonTimes()
  local won = {}
  for _, l in ipairs(ns.LootHistory()) do
    local id = ns.ItemID(l.item)
    if id then
      local k = ns.Key(l.winner)
      won[k] = won[k] or {}
      won[k][id] = math.max(won[k][id] or 0, l.t)
    end
  end
  return won
end

local function build()
  local byPlayer = {} -- key -> itemID -> wish
  for _, e in ipairs(ns.LedgerEntries("WL")) do
    local k = ns.Key(e.a)
    byPlayer[k] = byPlayer[k] or {}
    if PRIOS[e.prio] then
      byPlayer[k][e.item] = { id = e.item, name = e.name, prio = e.prio, t = e.t, who = Ambiguate(e.a, "short") }
    else
      byPlayer[k][e.item] = nil -- removed
    end
  end
  local won = wonTimes()
  for k, items in pairs(byPlayer) do
    for id, w in pairs(items) do
      local t = won[k] and won[k][id]
      w.won = t ~= nil and t >= w.t
    end
  end
  cache = { byPlayer = byPlayer }
  return cache
end

local function sortWishes(list)
  table.sort(list, function(a, b)
    if (a.won or false) ~= (b.won or false) then return not a.won end
    if a.prio ~= b.prio then return ns.WISH_PRIO_ORDER[a.prio] < ns.WISH_PRIO_ORDER[b.prio] end
    return a.name < b.name
  end)
  return list
end

-- One member's wishlist: { { id, name, prio, t, won }, ... }, wanted first.
function ns.Wishes(name)
  local items = (cache or build()).byPlayer[ns.Key(name)] or {}
  local list = {}
  for _, w in pairs(items) do list[#list + 1] = w end
  return sortWishes(list)
end

-- Is this item on a member's wishlist (and not yet won)? Returns the wish.
function ns.WishFor(name, link)
  local id = ns.ItemID(link)
  local items = id and (cache or build()).byPlayer[ns.Key(name)]
  local w = items and items[id]
  if w and not w.won then return w end
end

-- Everyone who wants an item and hasn't won it: { { name, prio, dkp }, ... },
-- Need before Want, then most DKP first.
function ns.WishersFor(link)
  local id = ns.ItemID(link)
  local out = {}
  if not id then return out end
  for _, items in pairs((cache or build()).byPlayer) do
    local w = items[id]
    if w and not w.won then
      out[#out + 1] = { name = w.who, prio = w.prio, dkp = ns.Balance(w.who), t = w.t }
    end
  end
  table.sort(out, function(a, b)
    if a.prio ~= b.prio then return ns.WISH_PRIO_ORDER[a.prio] < ns.WISH_PRIO_ORDER[b.prio] end
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  return out
end

-- The guild's wishlist, one row per item: { id, name, wishers = {...}, need, want }.
-- only: if given, a set of keys; only those members' wishes count.
function ns.GuildWishlist(only)
  local items = {}
  for k, list in pairs((cache or build()).byPlayer) do
    if not only or only[k] then
      for id, w in pairs(list) do
        if not w.won then
          local it = items[id]
          if not it then
            it = { id = id, name = w.name, wishers = {}, need = 0, want = 0 }
            items[id] = it
          end
          it[w.prio] = it[w.prio] + 1
          it.wishers[#it.wishers + 1] = { name = w.who, prio = w.prio, dkp = ns.Balance(w.who) }
        end
      end
    end
  end
  local out = {}
  for _, it in pairs(items) do
    table.sort(it.wishers, function(a, b)
      if a.prio ~= b.prio then return ns.WISH_PRIO_ORDER[a.prio] < ns.WISH_PRIO_ORDER[b.prio] end
      if a.dkp ~= b.dkp then return a.dkp > b.dkp end
      return a.name < b.name
    end)
    out[#out + 1] = it
  end
  table.sort(out, function(a, b)
    local na, nb = #a.wishers, #b.wishers
    if a.need ~= b.need then return a.need > b.need end
    if na ~= nb then return na > nb end
    return a.name < b.name
  end)
  return out
end

------------------------------------------------------------------------
-- Changing your own wishlist
------------------------------------------------------------------------
-- Add an item (or change how much you want it). prio: "need" or "want".
function ns.WishlistAdd(link, prio)
  local id = ns.ItemID(link)
  local name = linkName(link)
  if not id or not name then
    ns.Say("Put an item in first: Shift-click it into the item box.")
    return
  end
  prio = PRIOS[prio] and prio or "want"
  local mine = ns.Wishes(UnitName("player"))
  local already = ns.WishFor(UnitName("player"), id)
  if not already and #mine >= MAX_WISHES then
    ns.Say(ns.TF("Your wishlist is full (%d items). Remove something first.", MAX_WISHES))
    return
  end
  return ns.LedgerAdd("WL", { item = id, name = name, prio = prio })
end

function ns.WishlistRemove(id)
  for _, w in ipairs(ns.Wishes(UnitName("player"))) do
    if w.id == id then return ns.LedgerAdd("WL", { item = id, name = w.name, prio = "off" }) end
  end
end

------------------------------------------------------------------------
-- Auctions
------------------------------------------------------------------------
-- Called when an auction window opens: tell wishers, and give the officer the list.
function ns.OnAuctionStarted(a)
  local me = UnitName("player")
  local mine = ns.WishFor(me, a.link)
  if mine then
    ns.Say(ns.TF("%s is up for bids, and it's on your wishlist (%s).", a.link, ns.T(mine.prio == "need" and "Need" or "Want")))
  end
  if ns.Key(a.by or "") == ns.Key(me) then
    local wishers = ns.WishersFor(a.link)
    if #wishers > 0 then
      local parts = {}
      for _, w in ipairs(wishers) do
        parts[#parts + 1] = ("%s (%s, %d DKP)"):format(w.name, w.prio == "need" and "Need" or "Want", w.dkp)
      end
      ns.Say("On wishlists: " .. table.concat(parts, ", "))
    end
  end
end
