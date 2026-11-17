"""Raid makeup: sign-ups counted by role and class, with the gaps pointed out."""
from harness import Guild

MEMBERS = [
    ("Alice", 1, "WARRIOR"),
    ("Tank", 3, "WARRIOR"), ("Tank2", 3, "PALADIN"),
    ("Heals", 3, "PRIEST"), ("Heals2", 3, "DRUID"),
    ("Mage1", 3, "MAGE"), ("Mage2", 3, "MAGE"), ("Mage3", 3, "MAGE"),
    ("Rogue1", 3, "ROGUE"), ("Rogue2", 3, "ROGUE"),
    ("Hunter", 3, "HUNTER"), ("Lock1", 3, "WARLOCK"), ("Lock2", 3, "WARLOCK"),
    ("Shammy", 3, "SHAMAN"),          # never signs up
    ("Lowbie", 3, "DEATHKNIGHT", 30),  # not max level: not expected at raids
]
DPS = ["Mage1", "Mage2", "Mage3", "Rogue1", "Rogue2", "Hunter", "Lock1", "Lock2"]


def schedule(guild, minutes=600):
    ev = guild["Alice"].ns.CreateRaid("Molten Core", int(guild.clock) + minutes * 60, "")
    guild.run(2)
    return ev


def sign(guild, ev, name, role, status="accept"):
    guild[name].ns.SignUp(ev.id, status, role)
    guild.run(0.5)


def warnings(mk):
    return [mk.warnings[i] for i in range(1, len(mk.warnings) + 1)]


def test_small_group_is_covered():
    guild = Guild(MEMBERS)
    ev = schedule(guild)
    for name, role in [("Tank", "tank"), ("Heals", "healer"), ("Mage1", "dps"), ("Rogue1", "dps")]:
        sign(guild, ev, name, role)
    mk = guild["Mage2"].ns.RaidMakeup(ev.id)
    assert mk.accept == 4
    assert (mk.roles.tank, mk.roles.healer, mk.roles.dps) == (1, 1, 2)
    assert warnings(mk) == []     # 1 tank and 1 healer is enough for 4, and classes aren't checked yet


def test_gaps_in_a_full_raid():
    guild = Guild(MEMBERS)
    ev = schedule(guild)
    sign(guild, ev, "Tank", "tank")
    sign(guild, ev, "Heals", "healer")
    for name in DPS:
        sign(guild, ev, name, "dps")
    sign(guild, ev, "Tank2", "tank", "tentative")
    sign(guild, ev, "Heals2", "healer", "decline")

    mk = guild["Shammy"].ns.RaidMakeup(ev.id)
    assert (mk.accept, mk.tentative) == (10, 1)
    classes = [(mk.classes[i].name, mk.classes[i].count) for i in range(1, len(mk.classes) + 1)]
    assert classes == [("Mage", 3), ("Rogue", 2), ("Warlock", 2), ("Hunter", 1), ("Priest", 1), ("Warrior", 1)]
    assert warnings(mk) == [
        "Only 1 tank (2 wanted for 10 players), 1 tentative",
        "Only 1 healer (2 wanted for 10 players)",
        # Paladin (tentative), Druid (declined) and Shaman have nobody accepted; the level 30 Death Knight isn't counted.
        "No Druid, Paladin or Shaman signed up",
    ]

    # Filling the gaps clears the warnings.
    sign(guild, ev, "Tank2", "tank")
    sign(guild, ev, "Heals2", "healer")
    sign(guild, ev, "Shammy", "healer")
    mk = guild["Alice"].ns.RaidMakeup(ev.id)
    assert mk.accept == 13
    assert warnings(mk) == []


def test_officer_hears_about_gaps_an_hour_before():
    guild = Guild(MEMBERS)
    ev = schedule(guild, minutes=90)
    sign(guild, ev, "Mage1", "dps")
    sign(guild, ev, "Mage2", "dps")
    for c in guild.clients.values():
        c.said()
    guild.run(60, step=1)
    assert guild["Alice"].said("Molten Core in") == []      # still 90 minutes away
    guild.jump(31 * 60)
    guild.run(31, step=1)
    lines = guild["Alice"].said("Molten Core in")
    assert len(lines) == 1 and "No tanks" in lines[0] and "No healers" in lines[0]
    assert guild["Mage1"].said("Molten Core in") == []      # members aren't told
    guild.run(61, step=1)
    assert guild["Alice"].said("Molten Core in") == []      # only once


def test_raids_tab_shows_makeup():
    guild = Guild(MEMBERS)
    ev = schedule(guild)
    sign(guild, ev, "Tank", "tank")
    alice = guild["Alice"]
    alice.ns.OpenPanel("raids")
    alice.ns.RefreshPanel()
    guild.run(1)
    assert alice.errors() == []
