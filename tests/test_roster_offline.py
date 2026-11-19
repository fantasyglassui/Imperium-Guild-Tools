"""Offline guild members count, even when "Show offline members" is unticked
in the guild window (Classic-style clients then list only who's online)."""
from harness import Guild


def test_offline_members_are_still_guild_members():
    guild = Guild([("Alice", 1), ("Bob", 3), ("Sathryus", 3)])
    guild.set_online("Sathryus", False)
    alice = guild["Alice"]
    alice.run("guildShowOffline = false")
    alice.set_roster()
    m = alice.ns.Member("Sathryus")
    assert m is not None and m.online is False
    assert alice.ns.RankOf("Sathryus") == 3
    assert len(alice.ns.GetRoster()) == 3


def test_player_card_names_the_guild():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    alice = guild["Alice"]
    alice.ns.ShowPlayerCard("Bob")
    info = alice.lua.eval("WarcrestPlayerCard").info
    assert "<The Imperium>" in info.GetText(info)
    alice.ns.ShowPlayerCard("Stranger")
    assert "Not in your guild" in info.GetText(info)
