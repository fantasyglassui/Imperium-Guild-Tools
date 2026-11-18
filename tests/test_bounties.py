"""Bounties: off until an officer turns them on; the first killing blow claims it, paid once."""
from harness import Guild
from test_streaks import live_kill

MEMBERS = [("Alice", 0), ("Olly", 1), ("Bob", 3), ("Cara", 3)]   # Alice: Guild Master, Olly: officer


def ready(guild):
    for c in guild.clients.values():
        c.login()
    guild.run(15)


def set_guild(guild, officer="Alice", **features):
    alice = guild[officer]
    types = alice.lua.table_from({})
    for k, v in alice.ns.cfg.types.items():
        types[k] = v
    cfg = {"enabled": True, "types": types, "officerRank": 1}
    cfg.update(features)
    assert alice.ns.PushConfig(alice.lua.table_from(cfg))
    guild.run(3)


def test_bounties_are_off_until_an_officer_turns_them_on():
    guild = Guild(MEMBERS)
    ready(guild)
    olly = guild["Olly"]
    assert not olly.ns.BountiesOn()
    assert not olly.ns.PlaceBounty("Ganker", 50, "")
    assert olly.said("Bounties are off for the guild")
    set_guild(guild, bounties=True)
    for c in guild.clients.values():
        assert c.ns.BountiesOn()


def test_the_first_killing_blow_claims_it_and_is_paid_once():
    guild = Guild(MEMBERS)
    ready(guild)
    set_guild(guild, bounties=True)
    olly, bob, cara = guild["Olly"], guild["Bob"], guild["Cara"]
    bob.said(clear=True)
    assert olly.ns.PlaceBounty("Ganker", 50, "He camps the flight master")
    guild.run(3)
    assert bob.said("Bounty placed: 50 DKP on Ganker's head, by Olly.")
    guild.jump(600)
    live_kill(guild, "Cara", "Ganker")
    guild.run(20)
    b = list(bob.ns.Bounties().values())[0]
    assert (b.state, b.killer) == ("claimed", "Cara")
    assert bob.said("Cara claimed the bounty on Ganker for 50 DKP!")
    # Paid once, though two officers were online.
    assert bob.ns.Balance("Cara") == 50
    assert len(bob.ns.LedgerEntries("BC")) == 1
    # A later kill of Ganker doesn't pay again.
    guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(20)
    assert bob.ns.Balance("Bob") == 0
    got = {k for k, e in bob.ns.MemberAchievements("Cara").items() if e.t is not None}
    assert "claim1" in got
    assert not any(c.errors() for c in guild.clients.values())


def test_kills_before_a_bounty_and_withdrawn_bounties_dont_pay():
    guild = Guild(MEMBERS)
    ready(guild)
    set_guild(guild, bounties=True)
    olly, bob = guild["Olly"], guild["Bob"]
    live_kill(guild, "Bob", "Ganker")         # before the bounty
    guild.jump(600)
    b = olly.ns.PlaceBounty("Ganker", 30, "")
    guild.run(15)
    assert bob.ns.BountyOn("Ganker") is not None
    olly.ns.WithdrawBounty(b.id)
    guild.run(3)
    guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(20)
    assert bob.ns.Balance("Bob") == 0
    assert list(bob.ns.Bounties().values())[0].state == "withdrawn"


def test_members_cant_place_bounties_and_guild_without_dkp_pays_glory():
    guild = Guild(MEMBERS)
    ready(guild)
    set_guild(guild, bounties=True, dkp=False)
    bob, olly = guild["Bob"], guild["Olly"]
    assert not bob.ns.PlaceBounty("Ganker", 50, "")
    assert bob.said("Only officers can place bounties")
    olly.ns.PlaceBounty("Ganker", 50, "")
    guild.run(3)
    b = list(bob.ns.Bounties().values())[0]
    assert b.amount == 0
    guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(20)
    assert list(bob.ns.Bounties().values())[0].state == "claimed"
    assert bob.ns.Balance("Bob") == 0


def test_bounties_view_renders(tmp_path):
    from render import Renderer, demo_guild
    guild, me = demo_guild()
    set_guild(guild, "Thorne", bounties=True)
    me.ns.PlaceBounty("Shadowfang", 40, "Camps Booty Bay")
    guild.run(3)
    me.ns.OpenPanel("wanted", "bounties")
    rd = Renderer(me)
    rd.render(me.lua.eval("WarcrestPanel"), str(tmp_path / "bounties.png"))
    assert not me.errors()
