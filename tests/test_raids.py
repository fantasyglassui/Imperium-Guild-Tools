"""Raid nights: sign-ups, reminders, standby, hourly DKP, attendance, decay, invites and seasons."""
from harness import Guild

DAY = 86400
MEMBERS = [("Gm", 0), ("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3)]


def bal(guild, name, who="Gm"):
    return guild[who].ns.Balance(name)


def test_raid_night():
    guild = Guild(MEMBERS)
    a = guild["Alice"].ns
    ev = a.CreateRaid("Molten Core", int(guild.clock) + 600, "")
    guild.run(2)
    for n in ("Bob", "Cara", "Dan"):
        guild[n].ns.SignUp(ev.id, "accept", "dps")
        guild.run(1)

    guild.jump(600)
    guild.set_raid(["Alice", "Bob", "Cara"])
    guild["Dan"].said()
    a.StartRaidSession(ev.id, "Molten Core", 10, 10)
    guild.run(3)
    assert guild["Dan"].said("raid has started")       # signed up but not there
    assert not guild["Eve"].said("raid has started")   # never signed up

    a.AddStandby("Eve")
    guild.run(3)
    assert list(a.StandbyList(a.ActiveSession().id).values()) == ["Eve"]

    for _ in range(37):
        guild.jump(100)
        guild.run(0.3)
    guild.run(10)
    assert [bal(guild, n) for n in ("Alice", "Bob", "Cara")] == [20, 20, 20]
    assert bal(guild, "Eve") > 0     # standby is paid
    assert bal(guild, "Dan") == 0

    a.EndRaidSession()
    guild.run(3)
    gm = guild["Gm"].ns
    att, total, _ = gm.Attendance("Bob")
    assert (att, total) == (1, 1)
    att, total, noshow = gm.Attendance("Dan")
    assert att == 0 and len(noshow) == 1
    assert list(gm.NoShows(ev.id)[0].values()) == ["Dan"]

    # Decay: 10%, once a week however many officers press it.
    a.ApplyDecay(10)
    guild.run(5)
    assert bal(guild, "Cara") == 18
    guild["Alice"].said()
    a.ApplyDecay(10)
    guild.run(2)
    assert guild["Alice"].said("already been decayed")
    assert bal(guild, "Cara") == 18

    # Weekly decay applies itself after the weekly reset.
    a.SetDKPRules(10, True, False)
    guild.run(3)
    guild["Alice"].login()
    guild.run(20)
    assert bal(guild, "Cara") == 18
    guild.jump(8 * DAY)
    guild["Alice"].login()
    guild.run(20)
    assert bal(guild, "Cara") < 18
    for c in guild.clients.values():
        assert c.errors() == []


def test_invites_signups_then_converts_to_raid():
    members = [("Alice", 1)] + [("P%d" % i, 3) for i in range(1, 9)]
    guild = Guild(members)
    a = guild["Alice"].ns
    ev = a.CreateRaid("Onyxia", int(guild.clock) + 600, "")
    guild.run(2)
    for i in range(1, 9):
        guild["P%d" % i].ns.SignUp(ev.id, "decline" if i == 8 else "accept", "dps")
        guild.run(1)
    guild.set_online("P7", False)
    guild["Alice"].run("invited = {}")
    a.InviteSignups(ev.id)
    guild.run(1)
    first = list(guild["Alice"].lua.eval("invited").values())
    assert len(first) == 4                  # a party holds 5, so 4 invites first
    # They accept and join Alice's party; she turns it into a raid and invites the rest.
    guild["Alice"].run('raidMembers = { "Alice", "P1", "P2", "P3", "P4" }; partyOnly = true')
    guild["Alice"].fire("GROUP_ROSTER_UPDATE")
    guild["Alice"].fire("GROUP_ROSTER_UPDATE")
    guild.run(1)
    assert guild["Alice"].lua.eval("convertedToRaid")
    everyone = list(guild["Alice"].lua.eval("invited").values())
    assert sorted(everyone) == ["P1", "P2", "P3", "P4", "P5", "P6"]   # declined and offline skipped


def test_new_season_keeps_balances_and_trims_history():
    guild = Guild([("Gm", 0), ("Alice", 1), ("Bob", 3), ("Cara", 3)], raid=["Alice", "Bob", "Cara"])
    a = guild["Alice"].ns
    trio = guild["Alice"].lua.table_from(["Alice", "Bob", "Cara"])
    cara = guild["Alice"].lua.table_from(["Cara"])
    for night in range(17):
        a.StartRaidSession("", "Molten Core", 10, 0, 0)
        guild.run(1)
        for h in range(3):
            a.AwardDKP(trio, 10, "Hour %d" % (h + 1))
            guild.run(0.5)
        a.AwardDKP(cara, -15, "Won [Item %d]" % night)
        guild.run(0.5)
        a.EndRaidSession()
        guild.run(1)
        guild.jump(3.5 * DAY)
    guild.run(60)

    def size(c):
        return sum(1 for _ in c.ns.db.ledger.items())

    before = {n: bal(guild, n) for n in ("Alice", "Bob", "Cara")}
    big = size(guild["Gm"])
    old = [c.entry for c in a.DKPChanges().values()][-1]
    guild.set_online("Bob", False)
    a.StartSeason("Season 2")
    guild.run(60)
    after = {n: bal(guild, n) for n in before}
    assert after == before
    assert size(guild["Gm"]) < big / 2
    assert guild["Gm"].ns.CurrentSeason().name == "Season 2"
    guild["Alice"].said()
    a.UndoDKP(old, "")
    assert guild["Alice"].said("before this season")

    # Bob was offline: he catches up and ends with the same balances and a trimmed ledger.
    guild.set_online("Bob", True)
    guild["Bob"].ns.RequestLedger()
    guild.run(120)
    assert {n: bal(guild, n, "Bob") for n in before} == before
    assert guild["Bob"].ns.CurrentSeason().name == "Season 2"
    assert size(guild["Bob"]) < big / 2
