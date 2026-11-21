"""Wipe tracking (pulls, wipes, best kill times) and the officers' list of
inactive members."""
from harness import Guild
from test_bosses import MEMBERS, RAID, in_raid_instance


def pull(guild, boss, secs, ok, who=("Alice", "Bob")):
    for n in who:
        guild[n].fire("ENCOUNTER_START", 663, boss, 9, 20)
    guild.run(secs)
    for n in who:
        guild[n].fire("ENCOUNTER_END", 663, boss, 9, 20, 1 if ok else 0)
    guild.run(8)


def test_pulls_wipes_and_best_kill_time():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild, "Molten Core")
    pull(guild, "Lucifron", 40, False)
    pull(guild, "Lucifron", 3, False)            # a reset, not an attempt
    pull(guild, "Lucifron", 95, True)
    cara = guild["Cara"]
    p = cara.ns.BossPulls("Molten Core", "Lucifron")
    assert p.pulls == 2 and p.wipes == 1 and p.kills == 1 and 94 <= p.best <= 97
    assert p.wipesBeforeFirst == 1
    pull(guild, "Lucifron", 70, True)
    assert 69 <= cara.ns.BossPulls("Molten Core", "Lucifron").best <= 72
    assert cara.said("New best kill time on")
    assert cara.ns.FightTime(272) == "4:32"
    # Only wiped so far: the boss and raid still show on Progress.
    pull(guild, "Magmadar", 60, False)
    cara.ns.OpenPanel("raids", "progress")
    guild.run(1)
    assert not cara.errors()


def test_pulls_outside_a_guild_raid_dont_count():
    guild = Guild(MEMBERS, raid=["Alice", "Bob", "Cara"])        # too few guild members
    in_raid_instance(guild, "Molten Core")
    pull(guild, "Lucifron", 40, False)
    assert guild["Alice"].ns.BossPulls("Molten Core", "Lucifron") is None


def test_inactive_members():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]
    guild.set_online("Dan", False)
    guild.set_online("Eve", False)
    alice.run("""GetGuildRosterLastOnline = function(i)
      local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
      if online then return nil end
      if name:find("^Dan") then return 0, 2, 5, 0 end           -- 65 days
      return 0, 0, 3, 0                                          -- 3 days
    end""")
    alice.ns.RosterChanged()
    away = list(alice.ns.InactiveMembers(30).values())
    assert [m.name for m in away] == ["Dan"]
    assert len(list(alice.ns.InactiveMembers(1).values())) == 2
    alice.ns.OpenPanel("officers", "inactive")
    guild.run(1)
    assert not alice.errors()
