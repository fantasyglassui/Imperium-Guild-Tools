"""Shared kill log: everyone ends up with the same kills, and only officers can remove them."""
from harness import Guild, START

T = START - 86400


def add(client, t, victim, killers):
    client.ns.MergeKill(client.lua.eval('{ t = %d, kind = "kill_world", victim = "%s", zone = "STV", killers = { %s } }'
                                        % (t, victim, ",".join('"%s"' % k for k in killers))))


def log(client):
    L = client.ns.db.killLog
    return sorted((L[i].victim, tuple(sorted(L[i].killers.values()))) for i in range(1, len(L) + 1))


def board(client):
    top = client.ns.KillStats(client.ns.db.killLog, 10)
    return [(top[i].name, top[i].count) for i in range(1, len(top) + 1)]


def synced_guild():
    guild = Guild([("Alice", 1), ("Bob", 3), ("Cara", 3)])
    a, b, c = guild["Alice"], guild["Bob"], guild["Cara"]
    for x in (a, b, c):
        add(x, T, "Ganker", ["Alice"])
    add(a, T + 600, "Sneaky", ["Alice", "Bob"])
    add(c, T + 600, "Sneaky", ["Alice"])
    add(a, T - 3 * 86400, "Rogue", ["Bob"])
    add(c, T - 5 * 86400, "OldGanker", ["Cara"])
    add(b, T - 2 * 86400 + 8, "Camper", ["Bob"])     # the same kill, reported
    add(a, T - 2 * 86400 + 2, "Camper", ["Alice"])   # a few seconds apart
    for _ in range(3):
        for x in (a, b, c):
            x.ns.SyncKills()
            guild.run(30, step=0.5)
    return guild


def test_logs_converge():
    guild = synced_guild()
    a, b, c = guild["Alice"], guild["Bob"], guild["Cara"]
    assert log(a) == log(b) == log(c)
    victims = [v for v, _ in log(a)]
    assert sorted(victims) == ["Camper", "Ganker", "OldGanker", "Rogue", "Sneaky"]
    assert dict(log(a))["Sneaky"] == ("Alice", "Bob")
    assert dict(log(a))["Camper"] == ("Alice", "Bob")
    # Every client picks the same killing blow, so the boards match too.
    assert board(a) == board(b) == board(c)


def test_officer_removal_spreads_member_cannot_remove():
    guild = synced_guild()
    a, b, c = guild["Alice"], guild["Bob"], guild["Cara"]
    guild.set_online("Bob", False)
    rogue = [k for k in a.ns.db.killLog.values() if k.victim == "Rogue"][0]
    a.ns.RemoveKill(rogue)
    guild.run(3)
    assert not any(k.victim == "Rogue" for k in c.ns.db.killLog.values())
    assert any(k.victim == "Rogue" for k in b.ns.db.killLog.values())

    # Bob comes back with the old copy: his sync must not bring it back.
    guild.set_online("Bob", True)
    b.ns.SyncKills()
    guild.run(30, step=0.5)
    b.ns.RequestLedger()
    guild.run(30, step=0.5)
    for x in (a, b, c):
        assert not any(k.victim == "Rogue" for k in x.ns.db.killLog.values())

    before = [len(x.ns.db.killLog) for x in (a, b, c)]
    b.said()
    b.ns.RemoveKill(b.ns.db.killLog[1])
    guild.run(3)
    assert [len(x.ns.db.killLog) for x in (a, b, c)] == before
    assert b.said("officers")


def test_month_ranges_and_champion_announcement():
    # 2027-03-03 12:00 UTC
    guild = Guild([("Alice", 1), ("Bob", 3)], start=1804075200)
    a = guild["Alice"]
    fromT, toT, name, key = a.ns.MonthRange(0)
    assert (name, key) == ("March", "2027-03")
    assert fromT == 1803859200  # 2027-03-01 00:00 UTC
    fromT, toT, name, key = a.ns.MonthRange(-1)
    assert (name, key, (toT - fromT) // 86400) == ("February", "2027-02", 28)
    fromT, toT, name, key = a.ns.MonthRange(-13)
    assert (name, key, (toT - fromT) // 86400) == ("February", "2026-02", 28)
    # Leap year: February 2028 has 29 days.
    guild.jump(365 * 86400)
    fromT, toT, name, key = a.ns.MonthRange(-1)
    assert (name, key, (toT - fromT) // 86400) == ("February", "2028-02", 29)
    guild.jump(-365 * 86400)

    feb_from, feb_to, _, _ = a.ns.MonthRange(-1)
    for i in range(3):
        add(a, feb_from + 3600 * (i + 1), "Victim%d" % i, ["Bob"])
    add(a, feb_from + 86400, "Other", ["Alice"])
    a.said()
    a.ns.AnnounceChampion()
    lines = a.said("Top Head Hunters of February")
    assert len(lines) == 1 and "Bob" in lines[0]
    a.ns.AnnounceChampion()
    assert a.said("Top Head Hunters") == []  # only once per month
