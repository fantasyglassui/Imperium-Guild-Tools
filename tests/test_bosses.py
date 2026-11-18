"""Boss kills: recorded once for the guild, progress per raid, guild firsts and boss achievements."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3)]
RAID = ["Alice", "Bob", "Cara", "Dan", "Eve", "Finn"]


def in_raid_instance(guild, name="Hyjal Summit"):
    for c in guild.clients.values():
        c.run('INSTANCE = { "%s", "raid" }' % name)


def kill(guild, boss_id, boss, who=("Alice", "Bob", "Cara")):
    for n in who:                               # several guildmates see the kill
        guild[n].fire("ENCOUNTER_END", boss_id, boss, 9, 20, 1)
    guild.run(8)


def test_a_kill_is_recorded_once_with_everyone_there():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild)
    kill(guild, 2001, "Rage Winterchill")
    for c in guild.clients.values():
        kills = list(c.ns.BossKills().values())
        assert len(kills) == 1
        assert kills[0].name == "Rage Winterchill" and kills[0].raid == "Hyjal Summit"
        assert sorted(kills[0].names.values()) == sorted(RAID)
    # Entries in the ledger: one guildmate sent it, the others saw it and stayed quiet.
    assert len(guild["Dan"].ns.LedgerEntries("BK")) == 1


def test_wipes_pugs_and_dungeons_dont_count():
    guild = Guild(MEMBERS, raid=["Alice", "Bob", "Cara", "Dan"] + ["Pug%d" % i for i in range(6)])
    in_raid_instance(guild)
    kill(guild, 2001, "Rage Winterchill")           # only 4 guild members: not a guild kill
    guild.set_raid(RAID)
    guild["Alice"].fire("ENCOUNTER_END", 2001, "Rage Winterchill", 9, 20, 0)   # a wipe
    guild.run(8)
    for c in guild.clients.values():
        c.run('INSTANCE = { "Blackrock Depths", "party" }')
    kill(guild, 227, "Emperor Dagran Thaurissan")
    assert len(guild["Bob"].ns.BossKills()) == 0


def test_progress_and_guild_first():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild)
    for c in guild.clients.values():
        c.login()
    guild.run(12)
    bob = guild["Bob"]
    bob.said(clear=True)
    kill(guild, 2001, "Rage Winterchill")
    assert bob.said("Guild first! Rage Winterchill is down in Hyjal Summit")
    guild.jump(7 * 86400)
    kill(guild, 2001, "Rage Winterchill")
    kill(guild, 2002, "Anetheron")
    assert not bob.said("Guild first! Rage Winterchill", clear=False)   # only the first time
    progress = list(bob.ns.RaidProgress().values())
    assert len(progress) == 1
    hyjal = progress[0]
    assert (hyjal.raid, hyjal.killed, hyjal.total) == ("Hyjal Summit", 2, 13)
    rage = [b for b in hyjal.bosses.values() if b.name == "Rage Winterchill"][0]
    assert rage.kills == 2


def test_boss_achievements():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild)
    kill(guild, 2001, "Rage Winterchill")
    guild.run(3)
    got = {k for k, e in guild["Eve"].ns.MemberAchievements("Finn").items() if e.t is not None}
    assert {"boss1", "pioneer"} <= got
    assert guild["Eve"].ns.MemberAchievements("Finn")["boss25"].progress == 1


def test_boss_checks_say_why_a_kill_did_or_didnt_count():
    guild = Guild(MEMBERS, raid=["Alice", "Bob", "Cara", "Dan"] + ["Pug%d" % i for i in range(6)])
    in_raid_instance(guild)
    alice = guild["Alice"]
    alice.fire("ENCOUNTER_END", 2001, "Rage Winterchill", 9, 20, 1)
    guild.run(8)
    alice.ns.ShowBossChecks()
    assert alice.said("Not counted: fewer than 5 guild members")
    # With debug on, it shows in chat right away; BOSS_KILL works too, and a kill counts once.
    alice.run('SlashCmdList.WARCREST("debug")')
    guild.set_raid(RAID)
    alice.fire("BOSS_KILL", 2002, "Anetheron")
    alice.fire("ENCOUNTER_END", 2002, "Anetheron", 9, 20, 1)
    guild.run(8)
    assert alice.said("Boss check: Boss kill: Anetheron")
    assert len(alice.ns.LedgerEntries("BK")) == 1


def test_a_boss_with_no_id_still_counts():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild)
    guild["Alice"].fire("ENCOUNTER_END", None, "Mystery Boss", 9, 20, 1)
    guild.run(8)
    kills = list(guild["Bob"].ns.BossKills().values())
    assert len(kills) == 1 and kills[0].name == "Mystery Boss" and kills[0].boss > 0
