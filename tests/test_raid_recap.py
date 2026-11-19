"""Raid night recap: when the raid night ends, everyone gets a summary of the
bosses, loot, attendance and their own DKP."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3), ("Gus", 3)]
RAID = ["Alice", "Bob", "Cara", "Dan", "Eve", "Finn"]


def raid_night(guild):
    for c in guild.clients.values():
        c.login()
    guild.run(10)
    a = guild["Alice"].ns
    a.StartRaidSession("", "Hyjal Summit", 10, 0, 15)
    guild.run(3)
    for c in guild.clients.values():
        c.run('INSTANCE = { "Hyjal Summit", "raid" }')
    for n in ("Alice", "Bob", "Cara"):
        guild[n].fire("ENCOUNTER_END", 2001, "Rage Winterchill", 9, 20, 1)
    guild.run(8)
    a.AwardDKP(guild["Alice"].lua.table_from(["Bob"]), -30, "Won [Thunderfury]")
    guild.run(3)
    guild.jump(3600)
    for n in guild.clients:
        guild[n].said()
    a.EndRaidSession()
    guild.run(15)
    return a


def test_everyone_gets_the_recap():
    guild = Guild(MEMBERS, raid=RAID)
    raid_night(guild)
    for n in ("Bob", "Gus"):     # in the raid, or not
        c = guild[n]
        assert c.said("Raid night recap: Hyjal Summit", clear=False)
        assert c.said("Rage Winterchill", clear=False)
        assert c.said("guild first!", clear=False)
        assert c.said("[Thunderfury] to Bob (30 DKP)", clear=False)
        assert c.said("Raiders: 6 attended", clear=False)
    assert guild["Bob"].said("You earned 25 DKP.")      # 10 on time + 15 for the boss
    assert not guild["Gus"].said("You earned")
    banners = guild["Gus"].ns.ShownBanners()
    assert len(banners) >= 1
    text = banners[1].text.GetText(banners[1].text)
    assert text == "Hyjal Summit: 1 boss, 1 item, 6 raiders"


def test_command_shows_the_last_one_again():
    guild = Guild(MEMBERS, raid=RAID)
    raid_night(guild)
    guild["Cara"].said()
    guild["Cara"].ns.ShowLastRaidNight()
    assert guild["Cara"].said("Raid night recap: Hyjal Summit")


def test_can_be_turned_off_and_older_settings_leave_it_on():
    guild = Guild(MEMBERS, raid=RAID)
    a = guild["Alice"].ns
    assert guild["Bob"].ns.cfg.types.raid_recap
    types = guild["Alice"].lua.table_from({})
    for k, v in a.cfg.types.items():
        types[k] = v
    types["raid_recap"] = False
    assert a.PushConfig(guild["Alice"].lua.table_from({"enabled": True, "officerRank": 1, "types": types}))
    guild.run(5)
    assert not guild["Bob"].ns.cfg.types.raid_recap
    raid_night(guild)
    assert not guild["Bob"].said("Raid night recap")
