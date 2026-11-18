"""Raid groups planner: officers place sign-ups into groups or the bench; invites and arranging follow it."""
from harness import Guild

NAMES = ["Alice", "Tank1", "Tank2", "Heal1", "Heal2", "Heal3"] + ["Dps%d" % i for i in range(1, 9)] + ["Maybe"]
MEMBERS = [(n, 1 if n == "Alice" else 3) for n in NAMES]


def raid_with_signups(guild):
    alice = guild["Alice"]
    ev = alice.ns.CreateRaid("Hyjal Summit", int(guild.clock) + 86400, "")
    guild.run(3)
    for n in NAMES[1:]:
        role = "tank" if n.startswith("Tank") else ("healer" if n.startswith("Heal") else "dps")
        guild[n].ns.SignUp(ev.id, "tentative" if n == "Maybe" else "accept", role)
    guild.run(5)
    return ev


def test_auto_plan_puts_tanks_healers_and_dps_in_groups():
    guild = Guild(MEMBERS)
    ev = raid_with_signups(guild)
    alice = guild["Alice"]
    assert alice.ns.AutoPlan(ev.id, 10)
    guild.run(20)
    groups, bench, unplaced = guild["Dps1"].ns.RaidPlanGroups(ev.id)
    g1 = [p.name for p in groups[1].values()]
    g2 = [p.name for p in groups[2].values()]
    assert len(g1) == 5 and len(g2) == 5
    assert "Tank1" in g1 and "Tank2" in g1                # tanks together in group 1
    assert any(n.startswith("Heal") for n in g2)          # a healer in each group
    bench_names = [p.name for p in bench.values()]
    assert "Maybe" in bench_names and len(bench_names) == 4   # tentative and the overflow sit out
    assert len(unplaced) == 0


def test_moving_people_and_full_groups():
    guild = Guild(MEMBERS)
    ev = raid_with_signups(guild)
    alice = guild["Alice"]
    for n in ["Dps1", "Dps2", "Dps3", "Dps4", "Dps5"]:
        alice.ns.SetPlanGroup(ev.id, n, 3)
    guild.run(3)
    assert not alice.ns.SetPlanGroup(ev.id, "Dps6", 3)
    assert alice.said("Group 3 is full")
    alice.ns.SetPlanGroup(ev.id, "Dps1", 0)       # to the bench
    guild.jump(2)
    alice.ns.SetPlanGroup(ev.id, "Dps2", -1)      # out of the plan
    guild.run(3)
    groups, bench, unplaced = guild["Heal1"].ns.RaidPlanGroups(ev.id)
    assert sorted(p.name for p in groups[3].values()) == ["Dps3", "Dps4", "Dps5"]
    assert [p.name for p in bench.values()] == ["Dps1"]
    assert "Dps2" in [p.name for p in unplaced.values()]
    # Members can't change the plan.
    assert not guild["Dps1"].ns.SetPlanGroup(ev.id, "Dps1", 1)


def test_invites_skip_the_bench_and_arrange_moves_people():
    guild = Guild(MEMBERS, raid=["Alice"])
    ev = raid_with_signups(guild)
    alice = guild["Alice"]
    alice.ns.AutoPlan(ev.id, 10)
    guild.run(5)
    for n in NAMES:
        guild.set_online(n, True)
    invited = []
    alice.lua.globals().C_PartyInfo = alice.lua.table_from({"InviteUnit": lambda name: invited.append(name)})
    alice.ns.InviteSignups(ev.id)
    guild.run(15)
    bench = {p.name for p in alice.ns.RaidPlanGroups(ev.id)[1].values()}
    assert invited and not (set(invited) & bench)
    # Everyone's in the raid, in join order; arrange moves them to their planned groups.
    guild.set_raid(["Alice"] + [n for n in NAMES[1:] if n not in bench])
    alice.ns.ArrangeRaid(ev.id)
    guild.run(10)
    plan = alice.ns.RaidPlan(ev.id)
    for i, n in enumerate(alice.lua.eval("raidMembers").values(), start=1):
        p = plan[alice.ns.Key(n)] if alice.ns.Key(n) in plan else None
        if p and p.group >= 1:
            assert alice.lua.eval("function(i) local _, _, g = GetRaidRosterInfo(i) return g end")(i) == p.group, n
    assert alice.said("Arranged the raid")
