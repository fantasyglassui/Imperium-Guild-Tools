"""Kill streaks and revenge."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Mira", 3, "PRIEST")]


def live_kill(guild, killer, victim, ago=0):
    """A guildmate reports a kill (as the game would, through the addon's message)."""
    t = int(guild.clock) - ago
    for c in guild.clients.values():
        c.fire("CHAT_MSG_ADDON", "TheImperium", "K^kill_world^%s^STV^%d^0.5^58^1" % (victim, t), "GUILD",
               killer + "-Realm")
    guild.run(5)


def live_death(guild, who, killer, ago=0):
    t = int(guild.clock) - ago
    for c in guild.clients.values():
        e = c.lua.eval('{ t = %d, who = "%s", kind = "pvp", sub = "world", zone = "STV", killer = "%s" }'
                       % (t, who, killer))
        if c.ns.MergeDeath(e):
            c.ns.OnLiveDeath(e)


def test_streak_alerts_at_three_and_five():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    bob.said()
    for i in range(5):
        live_kill(guild, "Alice", "Enemy%d" % i)
        guild.jump(300)
    lines = bob.said("kill streak")
    assert len(lines) == 2
    assert "Alice is on a 3-kill streak!" in lines[0] and "Alice is on a 5-kill streak!" in lines[1]
    assert bob.ns.CurrentStreak("Alice") == 5


def test_dying_or_a_long_gap_ends_a_streak():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for i in range(5):
        live_kill(guild, "Alice", "Enemy%d" % i)
        guild.jump(300)
    bob.said()
    live_death(guild, "Alice", "Ganker-Stormrage")
    assert bob.ns.CurrentStreak("Alice") == 0
    guild.jump(60)
    live_kill(guild, "Alice", "Next")
    assert bob.ns.CurrentStreak("Alice") == 1
    guild.jump(2 * 3600)               # more than an hour later: a new streak
    live_kill(guild, "Alice", "Later")
    assert bob.ns.CurrentStreak("Alice") == 1
    best = bob.ns.BestStreaks(None, None, 3)
    assert (best[1].name, best[1].count) == ("Alice", 5)


def test_streak_end_is_announced():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for i in range(6):
        live_kill(guild, "Alice", "Enemy%d" % i)
        guild.jump(300)
    bob.said()
    live_death(guild, "Alice", "Ganker-Stormrage")
    lines = bob.said("streak was ended")
    assert len(lines) == 1 and "Alice's 6-kill streak was ended by Ganker" in lines[0]


def test_revenge():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    live_death(guild, "Mira", "Ganker-Stormrage", ago=240)
    bob.said()
    live_kill(guild, "Alice", "Ganker")
    lines = bob.said("Revenge")
    assert len(lines) == 1 and "Alice killed Ganker, who killed Mira 4 minutes ago" in lines[0]
    guild.jump(60)
    live_kill(guild, "Bob", "Ganker")          # the same death is only avenged once
    assert bob.said("Revenge") == []


def test_revenge_on_your_own_killer_and_old_deaths():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    live_death(guild, "Alice", "Sneaky", ago=120)
    live_death(guild, "Mira", "Slowpoke", ago=3600)   # too long ago to count
    bob.said()
    live_kill(guild, "Alice", "Sneaky")
    live_kill(guild, "Alice", "Slowpoke")
    lines = bob.said("Revenge")
    assert len(lines) == 1 and "Alice paid Sneaky back for killing them 2 minutes ago" in lines[0]


def test_streak_and_revenge_can_be_turned_off():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    bob.ns.db.show.kill_streak = False
    bob.ns.db.show.kill_revenge = False
    live_death(guild, "Mira", "Ganker-Stormrage", ago=60)
    bob.said()
    for i in range(3):
        live_kill(guild, "Alice", "Ganker" if i == 0 else "Enemy%d" % i)
    assert bob.said("streak") == [] and bob.said("Revenge") == []
    assert guild["Alice"].said("Revenge")       # others still see them


def test_older_officer_settings_leave_streaks_on():
    guild = Guild([("Gm", 0), ("Bob", 3)])
    bob = guild["Bob"]
    stamp = int(guild.clock) + 100
    # An officer on an older version sends only the older settings message.
    bob.fire("CHAT_MSG_ADDON", "TheImperium", "C5^%d^1^pvp,kill_world,wanted^1^Gm" % stamp, "GUILD", "Gm-Realm")
    guild.run(1)
    assert bob.ns.cfg.types.kill_world and not bob.ns.cfg.types.kill_bg
    assert bob.ns.cfg.types.kill_streak and bob.ns.cfg.types.kill_revenge
