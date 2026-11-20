"""WoW: Forever writes senders as "Name Realm", which can't be whispered. Catch-up
(which whispers) has to work anyway, or guildmates who were offline never see changes."""
from harness import Guild
from test_members import profile, gear

M = [("Alice", 1), ("Bob", 3, "PRIEST"), ("Cara", 3)]


def test_a_profile_changed_while_you_were_offline_reaches_you():
    guild = Guild(M, realm_space=True)
    bob, cara = guild["Bob"], guild["Cara"]
    gear(bob, 60)
    profile(bob, spec="Holy")
    guild.run(3)
    assert cara.ns.MemberProfile("Bob").spec == "Holy"
    guild.set_online("Cara", False)
    profile(bob, spec="Shadow", role="dps")
    guild.run(3)
    guild.set_online("Cara", True)
    cara.login()
    guild.run(120)
    assert cara.ns.MemberProfile("Bob").spec == "Shadow"
    assert guild.bad_whispers == 0
