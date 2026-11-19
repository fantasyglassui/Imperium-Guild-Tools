"""Warcrest's history survives: achievements are recorded with the guild, the
saved data is cleaned before the game writes it, and if it ever comes back
empty, the guild sends it back."""
from harness import Guild, Client

M = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3)]
DUMP = r"""
local function dump(v)
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" then return "nil" end
  local out = {}
  for k, x in pairs(v) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(x) end
  return "{" .. table.concat(out, ",") .. "}"
end
return dump(WarcrestDB), dump(WarcrestState)
"""


def relog(guild, name, lose_data=False):
    old = guild[name]
    old.fire("PLAYER_LOGOUT")
    db, state = old.lua.execute(DUMP)
    code = "WarcrestState = %s; WarcrestDB = %s" % (state, "nil" if lose_data else db)
    new = Client(guild, name, setup=lambda c: c.run(code))
    guild.clients[name] = new
    new.set_raid(guild.raid if name in guild.raid else [])
    new.login()
    return new


def earn(guild):
    for c in guild.clients.values():
        c.login()
    guild.run(12)
    for c in guild.clients.values():
        c.run('INSTANCE = { "Hyjal Summit", "raid" }')
    for n in ("Alice", "Bob", "Cara"):
        guild[n].fire("ENCOUNTER_END", 2001, "Rage Winterchill", 9, 20, 1)
    guild["Bob"].ns.Send("K", "kill_world", "Ganker", "STV", int(guild.clock), "0.5", "60", "1")
    guild.run(30)


def test_achievements_are_recorded_with_the_guild():
    guild = Guild(M, raid=[m[0] for m in M])
    earn(guild)
    recorded = [(e.a, e.ach) for e in guild["Alice"].ns.LedgerEntries("AE").values()]
    assert ("Bob", "kill1") in recorded and ("Bob", "pioneer") in recorded
    assert ("Alice", "pioneer") in recorded


def test_a_relog_keeps_everything():
    guild = Guild(M, raid=[m[0] for m in M])
    earn(guild)
    bob = relog(guild, "Bob")
    guild.run(5)
    assert bob.ns.HasAchievement("Bob", "kill1")
    assert bob.ns.HasAchievement("Bob", "pioneer")
    assert not bob.said("didn't load")


def test_lost_saved_data_comes_back_from_the_guild():
    guild = Guild(M, raid=[m[0] for m in M])
    earn(guild)
    bob = relog(guild, "Bob", lose_data=True)
    assert bob.ns.dataWasLost
    guild.run(240)
    assert bob.said("didn't load")
    # Kills (from a guildmate) and achievements (from the guild record) are back.
    assert len(list(bob.ns.db.killLog.values())) == 1
    assert bob.ns.HasAchievement("Bob", "kill1")
    assert bob.ns.HasAchievement("Bob", "pioneer")


def test_secret_values_are_taken_out_before_saving():
    guild = Guild([("Alice", 1)])
    a = guild["Alice"]
    a.run("""
      SECRET = setmetatable({}, { __tostring = function() return "secret" end })
      function issecretvalue(v) return v == SECRET end
    """)
    a.run("WarcrestDB.killLog[1] = { t = 1, victim = SECRET, zone = 'STV', killers = { 'Alice' } }")
    a.fire("PLAYER_LOGOUT")
    assert a.lua.eval("WarcrestDB.killLog[1].victim") is None
    assert a.lua.eval("WarcrestDB.killLog[1].zone") == "STV"
    assert a.lua.eval("WarcrestState.kills") == 1


def test_officers_put_back_achievements_a_member_lost():
    # From before achievements were kept with the guild: Bob's achievements are
    # only remembered by guildmates' addons, and his kills are gone everywhere.
    guild = Guild(M, raid=[m[0] for m in M])
    earn(guild)
    assert guild["Alice"].ns.db.achievements["bob"]["kill1"]
    for c in guild.clients.values():
        c.run('for id, e in pairs(WarcrestDB.ledger) do if e.k == "AE" then WarcrestDB.ledger[id] = nil end end '
              'wipe(WarcrestDB.killLog)'); c.ns.ReindexLedger()
    for c in guild.clients.values():
        if c.name != "Alice":
            c.run('wipe(WarcrestDB.achievements)')
    bob = relog(guild, "Bob", lose_data=True)
    guild.run(400)
    assert bob.ns.MemberAchievements("Bob")["kill1"]["t"]
    put_back = [e for e in bob.ns.LedgerEntries("AG").values()]
    assert put_back and all(e.a == "Alice" for e in put_back)
    assert bob.errors() == [] and guild["Alice"].errors() == []


def test_guildmates_vouch_for_lost_achievements_when_no_officer_can():
    # No officer remembers Bob's achievements; two guildmates do. One alone isn't enough.
    guild = Guild(M, raid=[m[0] for m in M])
    earn(guild)
    for c in guild.clients.values():
        c.run('for id, e in pairs(WarcrestDB.ledger) do if e.k == "AE" then WarcrestDB.ledger[id] = nil end end '
              'wipe(WarcrestDB.killLog)')
        c.ns.ReindexLedger()
    for c in guild.clients.values():
        if c.name not in ("Cara", "Dan"):
            c.run('wipe(WarcrestDB.achievements)')
    bob = relog(guild, "Bob", lose_data=True)
    guild["Cara"].ns.RestoreGuildAchievements()
    guild.run(30)
    assert bob.ns.MemberAchievements("Bob")["kill1"]["t"] is None    # one guildmate: not yet
    guild["Dan"].ns.RestoreGuildAchievements()
    guild.run(30)
    assert bob.ns.MemberAchievements("Bob")["kill1"]["t"]                # two agree: it's back
    vouched = {(e.a, e.who) for e in bob.ns.LedgerEntries("AW").values()}
    assert ("Cara", "Bob") in vouched and ("Dan", "Bob") in vouched
    assert all(c.errors() == [] for c in guild.clients.values())
