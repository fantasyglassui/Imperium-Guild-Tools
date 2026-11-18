"""Loot council: the raid answers, officers vote, the loot master awards it for 0 DKP."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Olly", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3)]
RAID = ["Alice", "Olly", "Bob", "Cara", "Dan"]
LEGS = "|cffa335ee|Hitem:16901::::::::60:::::::|h[Stormrage Legguards]|h|r"


def test_a_vote_from_start_to_award():
    guild = Guild(MEMBERS, raid=RAID)
    alice, olly, bob, cara, dan = (guild[n] for n in RAID)
    cara.ns.WishlistAdd(LEGS, "need")
    guild.run(3)
    assert alice.ns.StartCouncil(LEGS, 60)
    guild.run(2)
    for c in (bob, cara, dan):
        assert c.ns.council is not None and c.lua.eval("WarcrestCouncil").IsShown(c.lua.eval("WarcrestCouncil"))
    assert cara.said("It's on your wishlist")
    bob.ns.CouncilAnswer("greed")
    cara.ns.CouncilAnswer("need")
    dan.ns.CouncilAnswer("pass")
    guild.run(2)
    cands = list(alice.ns.CouncilCandidates().values())
    assert [(c.name, c.choice, c.wish) for c in cands] == [("Cara", "need", "need"), ("Bob", "greed", None)]
    # Officers vote; members' votes don't count.
    olly.ns.CouncilVote("Cara")
    alice.ns.CouncilVote("Cara")
    bob.run('TheBob = true')
    bob.ns.SendRaid("L3", bob.ns.council.id, "Bob")
    guild.run(2)
    votes = {c.name: c.votes for c in alice.ns.CouncilCandidates().values()}
    assert votes == {"Cara": 2, "Bob": 0}
    # Only the loot master awards it.
    olly.ns.CouncilAward("Bob")
    guild.run(2)
    assert not dan.ns.council.done
    alice.ns.CouncilAward("Cara")
    guild.run(3)
    assert dan.ns.council.done and dan.ns.council.winner == "Cara"
    assert dan.said("Cara gets")
    loot = list(dan.ns.LootHistory().values())
    assert loot[0].winner == "Cara" and loot[0].council and loot[0].amount == 0
    assert dan.ns.Balance("Cara") == 0
    # Won from her wishlist: no longer wanted.
    assert [w.name for w in dan.ns.WishersFor(LEGS).values()] == []
    assert not any(c.errors() for c in guild.clients.values())


def test_members_cant_start_and_late_answers_dont_count():
    guild = Guild(MEMBERS, raid=RAID)
    bob, alice = guild["Bob"], guild["Alice"]
    assert not bob.ns.StartCouncil(LEGS, 60)
    assert bob.said("Only officers")
    alice.ns.StartCouncil(LEGS, 15)
    guild.run(30)
    bob.ns.CouncilAnswer("need")
    guild.run(2)
    assert len(alice.ns.CouncilCandidates()) == 0


def test_works_without_dkp():
    guild = Guild(MEMBERS, raid=RAID)
    alice = guild["Alice"]
    types = alice.lua.table_from({})
    for k, v in alice.ns.cfg.types.items():
        types[k] = v
    alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1, "dkp": False}))
    guild.run(3)
    assert alice.ns.StartCouncil(LEGS, 60)
    guild.run(2)
    guild["Bob"].ns.CouncilAnswer("need")
    guild.run(2)
    alice.ns.CouncilAward("Bob")
    guild.run(3)
    assert guild["Cara"].ns.council.winner == "Bob"


def test_council_window_renders(tmp_path):
    from render import Renderer, demo_guild
    guild, me = demo_guild()
    me.ns.StartCouncil(LEGS, 60)
    guild.run(2)
    for n in ("Lyra", "Mira", "Brakk"):
        guild[n].ns.CouncilAnswer("need" if n != "Brakk" else "greed")
    guild.run(2)
    me.ns.CouncilVote("Lyra")
    guild.run(2)
    rd = Renderer(me)
    rd.render(me.lua.eval("WarcrestCouncil"), str(tmp_path / "council.png"))
    me.ns.OpenPanel("wishlist")
    assert not me.errors()
