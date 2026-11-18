"""The weekly recap after the Tuesday reset."""
from harness import Guild

DAY = 86400
LEGS = "|cffa335ee|Hitem:2::::::::60:::::::|h[Stormrage Legguards]|h|r"


def busy_week():
    # Starts Friday; the week turns over on Tuesday at 15:00 UTC.
    guild = Guild([("Gm", 0), ("Alice", 1), ("Bob", 3), ("Cara", 3)], raid=["Alice", "Bob", "Cara"])
    cara = guild["Cara"]
    for c in guild.clients.values():
        c.login()
    guild.run(200, step=1)
    assert cara.said("Last week") == []   # just installed: no recap yet

    t = int(guild.clock)
    for i, (victim, killers) in enumerate([("Ganker", ["Bob"]), ("Sneaky", ["Bob", "Alice"]), ("Rogue", ["Alice"])]):
        cara.ns.MergeKill(cara.lua.eval('{ t = %d, kind = "kill_world", victim = "%s", zone = "STV", killers = { %s } }'
                                        % (t + i * 600, victim, ",".join('"%s"' % k for k in killers))))
    for i, who in enumerate(["Cara", "Bob", "Cara"]):
        cara.ns.MergeDeath(cara.lua.eval('{ t = %d, who = "%s", kind = "pvp", sub = "world", zone = "STV", killer = "Ganker-Stormrage" }'
                                         % (t + 3000 + i * 600, who)))

    a = guild["Alice"].ns
    a.StartRaidSession("", "Molten Core", 10, 0, 15)
    guild.run(3)
    guild["Alice"].fire("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)
    guild.run(3)
    a.StartAuction(LEGS, 5, 20)
    guild.run(2)
    guild["Bob"].ns.PlaceBid(12)
    guild.run(25)
    a.EndRaidSession()
    guild.run(3)
    return guild


def test_this_week_so_far():
    guild = busy_week()
    r = guild["Cara"].ns.WeeklyRecap(0)
    assert (r.kills, r.deaths, r.raidNights, r["items"]) == (3, 3, 1, 1)
    top = [(r.hunters[i].name, r.hunters[i].count) for i in range(1, len(r.hunters) + 1)]
    assert sorted(n for n, _ in top) == ["Alice", "Bob"] and top[0][1] == 2
    assert r.nemesis.name == "Ganker" and r.nemesis.count == 3
    assert list(r.bosses.values()) == ["Ragnaros"]
    assert r.biggest.winner == "Bob" and r.biggest.amount == 12


def test_recap_after_the_reset():
    guild = busy_week()
    cara = guild["Cara"]
    cara.said()
    guild.jump(5 * DAY)
    cara.login()
    guild.run(200, step=1)
    out = cara.said()
    start = [i for i, line in enumerate(out) if "Last week in the guild" in line]
    assert len(start) == 1
    body = "\n".join(out[start[0]:])
    assert "PvP: 3 enemy players killed." in body
    assert "Top Head Hunters: 1." in body
    assert "Guild members killed by enemy players: 3.  Most kills on us: Ganker (3)." in body
    assert "Raids: 1 raid night (Molten Core), 1 boss killed." in body
    assert "Loot: 1 item handed out.  Biggest buy: Bob, " in body and "for 12 DKP." in body

    # Once a week: logging in again doesn't repeat it.
    cara.login()
    guild.run(200, step=1)
    assert cara.said("Last week in the guild") == []
    # But it can be shown on demand.
    cara.run('SlashCmdList.WARCREST("recap")')
    assert cara.said("Last week in the guild")
    for c in guild.clients.values():
        assert c.errors() == []


def test_recap_can_be_turned_off_and_quiet_weeks_say_nothing():
    guild = busy_week()
    bob, gm = guild["Bob"], guild["Gm"]
    bob.ns.db.weeklyRecap = False
    guild.jump(5 * DAY)
    for c in (bob, gm):
        c.said()
        c.login()
    guild.run(200, step=1)
    assert bob.said("Last week") == []
    assert gm.said("Last week in the guild")   # raid and loot are shared, so Gm has a recap too

    # The week after had nothing in it: no recap.
    guild.jump(7 * DAY)
    gm.login()
    guild.run(200, step=1)
    assert gm.said("Last week") == []
