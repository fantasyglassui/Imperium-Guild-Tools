"""Achievements and titles: worked out from shared history, announced when earned."""
from harness import Guild
from test_streaks import live_death, live_kill

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def earned(client, name):
    return {k for k, e in client.ns.MemberAchievements(name).items() if e.t is not None}


def test_kills_streaks_and_announcement():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.login()
    guild.run(12)                      # the guild is ready: what's earned so far is the baseline
    bob = guild["Bob"]
    bob.said(clear=True)
    for victim in ("Grim", "Vex", "Skarn"):
        live_kill(guild, "Alice", victim)
        guild.jump(60)
    guild.run(3)
    got = earned(bob, "Alice")
    assert {"kill1", "streak3"} <= got
    assert "streak5" not in got
    assert bob.said("Alice earned First Blood", clear=False)
    assert bob.said("Alice earned Killing Spree")
    progress = bob.ns.MemberAchievements("Alice")["kill25"].progress
    assert progress == 3


def test_revenge_bounty_and_nemesis():
    guild = Guild(MEMBERS)
    # Ganker kills Alice three times, then Bob kills him right after the third: revenge and a bounty.
    for _ in range(3):
        live_death(guild, "Alice", "Ganker-Stormrage")
        guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(3)
    cara = guild["Cara"]
    assert {"revenge1", "bounty"} <= earned(cara, "Bob")
    assert "nemesis" not in earned(cara, "Bob")
    # Alice gets her own back: her nemesis.
    guild.jump(3600)
    live_kill(guild, "Alice", "Ganker")
    guild.run(3)
    assert "nemesis" in earned(cara, "Alice")


def test_titles_only_show_when_earned_and_only_from_their_owner():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for _ in range(3):
        live_death(guild, "Alice", "Ganker-Stormrage")
        guild.jump(600)
    live_kill(guild, "Bob", "Ganker")
    guild.run(3)
    assert bob.ns.SetTitle("bounty")
    guild.run(3)
    assert guild["Cara"].ns.TitledName("Bob") == "Bob the Bounty Hunter"
    # A title you haven't earned can't be picked...
    assert not guild["Cara"].ns.SetTitle("kill250")
    # ...and one sent anyway (or sent in someone else's name) doesn't show.
    cara = guild["Cara"]
    cara.lua.globals().cns = cara.ns
    cara.run('cns.Send("X", "Cara:1:1", tostring(GetServerTime()), "Cara", "TI", "kill250")')
    cara.run('cns.Send("X", "Bob:1:1", tostring(GetServerTime() + 5), "Bob", "TI", "")')
    guild.run(3)
    assert guild["Alice"].ns.TitledName("Cara") == "Cara"
    assert guild["Alice"].ns.TitledName("Bob") == "Bob the Bounty Hunter"
    assert not any(c.errors() for c in guild.clients.values())


def test_earned_achievements_stay_after_the_log_is_cleared():
    guild = Guild(MEMBERS)
    live_kill(guild, "Alice", "Grim")
    guild.run(3)
    bob = guild["Bob"]
    assert "kill1" in earned(bob, "Alice")
    bob.run("WarcrestDB_killLog_backup = nil")
    bob.lua.eval("function(ns) wipe(ns.db.killLog); ns.OnHistoryChanged() end")(bob.ns)
    guild.run(3)
    assert "kill1" in earned(bob, "Alice")


def test_achievements_tab_and_settings_title_card():
    from render import Renderer, demo_guild
    guild, me = demo_guild()
    for view in ("pvp", "hunt", "raid", "loot", "social", "guild"):
        me.ns.OpenPanel("achievements", view)
    me.ns.ShowAchievements("Lyra")
    me.ns.OpenPanel("settings", "general")
    me.ns.ShowPlayerCard("Lyra")
    assert not me.errors()
