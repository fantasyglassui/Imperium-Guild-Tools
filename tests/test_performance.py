"""A big guild: 500 members and full logs stay quick, and lists only make the rows on screen."""
import time
from harness import Guild

CLASSES = ["WARRIOR", "MAGE", "PRIEST", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "PALADIN", "SHAMAN"]


def big_guild():
    guild = Guild([("Alice", 0), ("Bob", 3)])
    for i in range(500):
        guild.members.append(("Member%03d" % i, 3 + i % 4, i % 3 == 0, CLASSES[i % len(CLASSES)], 50 + i % 11))
    for c in guild.clients.values():
        c.set_roster()
    bob = guild["Bob"]
    bob.lua.eval("""function(ns, now)
      local kl, dl = ns.db.killLog, ns.db.deathLog
      for i = 1, 2000 do
        table.insert(kl, 1, { t = now - 2000 * 600 + i * 600, victim = "Enemy" .. (i % 97),
          killers = { "Member" .. string.format("%03d", i % 500) }, zone = "Stranglethorn Vale",
          kind = "kill_world", level = 60 })
      end
      for i = 1, 500 do
        table.insert(dl, 1, { t = now - 500 * 2000 + i * 2000, who = "Member" .. string.format("%03d", (i * 7) % 500),
          kind = "pvp", sub = "world", zone = "Duskwood", killer = "Enemy" .. (i % 97) .. "-Realm" })
      end
      ns.OnHistoryChanged()
    end""")(bob.ns, int(guild.clock))
    guild.run(3)
    return guild, bob


def test_every_tab_refreshes_quickly_in_a_big_guild():
    guild, bob = big_guild()
    slowest = 0
    for tab in ("roster", "raids", "dkp", "wishlist", "kills", "wanted", "achievements", "settings", "addon"):
        bob.ns.OpenPanel(tab)
        start = time.perf_counter()
        bob.ns.RefreshPanel()
        slowest = max(slowest, time.perf_counter() - start)
    assert slowest < 1.0, slowest
    assert not bob.errors()


def test_lists_only_make_the_rows_on_screen():
    guild, bob = big_guild()
    bob.ns.OpenPanel("kills")
    bob.ns.RefreshPanel()
    # Every list frame in the window has at most a screenful of rows.
    lists = bob.lua.eval("""function()
      local most = 0
      local function walk(f)
        for _, k in ipairs(rawget(f, "_kids") or {}) do
          local n = 0
          for _, c in ipairs(rawget(k, "_kids") or {}) do n = n + 1 end
          most = math.max(most, n)
          walk(k)
        end
      end
      walk(WarcrestPanel)
      return most
    end""")()
    assert lists < 120, lists     # 2000 kills shown, but no frame holds anywhere near 2000 rows


def test_achievements_for_the_whole_guild_are_quick():
    guild, bob = big_guild()
    start = time.perf_counter()
    feed = bob.ns.GuildAchievements()
    leaders = bob.ns.AchievementLeaders(8)
    took = time.perf_counter() - start
    assert len(feed) > 0 and len(leaders) == 8
    assert took < 2.0, took
