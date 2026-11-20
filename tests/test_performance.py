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


def test_a_big_catch_up_is_quick():
    """Thousands of ledger entries arriving (a catch-up after a week away) are
    added one by one without sorting the whole record again each time."""
    guild = Guild([("Alice", 0), ("Bob", 3)])
    alice = guild["Alice"]
    start = time.perf_counter()
    made = alice.lua.eval("""function(ns)
      for i = 1, 4000 do ns.LedgerAdd("DK", { amount = 1, names = "Bob", reason = "Test " .. i }) end
      return #ns.LedgerEntries("DK")
    end""")(alice.ns)
    took = time.perf_counter() - start
    assert made == 4000
    assert took < 3.0, took
    guild.run(1)
    assert alice.ns.Balance("Bob") == 4000


def test_a_dkp_award_doesnt_rebuild_boss_kills():
    guild = Guild([("Alice", 0), ("Bob", 3)])
    lua = guild["Alice"].lua
    ns = guild["Alice"].ns
    lua.execute("FIRST_KILLS = nil")
    lua.eval("function(ns) FIRST_KILLS = ns.BossKills() end")(ns)
    ns.AwardDKP(lua.table_from(["Bob"]), 5, "Test")
    guild.run(1)
    assert lua.eval("function(ns) return rawequal(ns.BossKills(), FIRST_KILLS) end")(ns)  # the same cached list
    assert ns.Balance("Bob") == 5        # while the balances did catch up


def fill_new_features(client, now):
    """60 events with 100 answers each, 300 profiles, 200 recruits and 150 titles."""
    client.lua.eval("""function(ns, now)
      local L, n = ns.db.ledger, 0
      local function add(k, a, t, fields)
        n = n + 1
        local e = { k = k, a = a, t = t, id = a .. ":" .. t .. ":" .. n }
        for key, v in pairs(fields) do e[key] = v end
        L[e.id] = e
        return e
      end
      local types = { "pvp", "worldboss", "dungeon", "meeting", "social", "other" }
      for i = 1, 60 do
        local ev = add("GE", "Member" .. string.format("%03d", i), now - 86400 * 20 + i * 3600 * 10,
          { title = "Event " .. i, start = now - 86400 * 10 + i * 3600 * 8, etype = types[i % 6 + 1], notes = "", mins = 120 })
        for j = 1, 100 do
          add("GS", "Member" .. string.format("%03d", (i * 7 + j) % 500), ev.t + j,
            { ref = ev.id, status = ({ "going", "maybe", "no" })[j % 3 + 1] })
        end
        add("GT", ev.a, ev.t + 500, { ref = ev.id, names = "Member001,Member002,Member003,Member004" })
      end
      for i = 0, 299 do
        add("PF", "Member" .. string.format("%03d", i), now - 1000 + i,
          { spec = "Holy", role = ({ "tank", "healer", "dps" })[i % 3 + 1], days = "1111100", hours = "19:00-23:00",
            bday = "", ilvl = 50 + i % 15, note = "" })
      end
      for i = 1, 200 do
        add("RC", "Alice", now - 5000 + i, { name = "Recruit" .. i, class = "MAGE", level = 60, note = "",
          status = ({ "new", "contacted", "trial", "joined", "declined" })[i % 5 + 1] })
      end
      for i = 0, 149 do
        add("TI", "Member" .. string.format("%03d", i), now - 100 + i, { title = "kill1" })
      end
      ns.ReindexLedger()
    end""")(client.ns, now)


def test_events_profiles_and_recruiting_stay_quick_in_a_big_guild():
    guild, bob = big_guild()
    alice = guild["Alice"]
    now = int(guild.clock)
    for c in (alice, bob):
        fill_new_features(c, now)
    guild.run(3)
    slowest = 0
    for client, tab in ((bob, "events"), (alice, "recruit"), (bob, "raids")):
        client.ns.OpenPanel(tab)
        for _ in range(3):   # the first refresh builds the caches; later ones should be quicker still
            start = time.perf_counter()
            client.ns.RefreshPanel()
            slowest = max(slowest, time.perf_counter() - start)
    bob.ns.ShowProfiles()
    start = time.perf_counter()
    bob.ns.RefreshProfiles()
    slowest = max(slowest, time.perf_counter() - start)
    assert slowest < 1.0, slowest
    assert not bob.errors() and not alice.errors()


def test_titles_in_chat_cost_next_to_nothing():
    guild, bob = big_guild()
    fill_new_features(bob, int(guild.clock))
    show = bob.lua.eval("ShowChat")
    show("CHAT_MSG_GUILD", "warm up", "Member001-Realm")
    start = time.perf_counter()
    bob.lua.eval("""function()
      for i = 1, 5000 do
        ShowChat("CHAT_MSG_CHANNEL", "WTS stuff " .. i, "Member" .. string.format("%03d", i % 500) .. "-Realm")
      end
    end""")()
    took = time.perf_counter() - start
    assert took < 1.0, took
    assert not bob.errors()
