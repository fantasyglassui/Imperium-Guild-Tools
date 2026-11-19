"""Grey kills (victims far below the killer's level) are never reported or logged."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Twink", 3, "ROGUE", 45)]


def victims(client):
    L = client.ns.db.killLog
    return sorted(L[i].victim for i in range(1, len(L) + 1))


def attack_and_kill(client, victim, level, honor_message=True):
    """Fireball an enemy player, then they die (with or without the game's honor message)."""
    client.run('units.target = { name = "%s", player = true, hostile = true, level = %d }' % (victim, level))
    client.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
    client.run('units.target.dead = true')
    if honor_message:
        client.fire("CHAT_MSG_COMBAT_HONOR_GAIN", "%s dies, honorable kill Rank: Private (10 Honor Points)" % victim)


def test_my_grey_kill_is_not_reported_even_with_honor():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]   # level 60: level 47 and below is grey
    attack_and_kill(alice, "Lowbie", 40)
    guild.run(10)
    attack_and_kill(alice, "Peer", 55)
    guild.run(10)
    kills = [m for m in guild.sent if m[3].startswith("K^")]
    assert len(kills) == 1 and "Peer" in kills[0][3]
    assert victims(guild["Bob"]) == ["Peer"]
    assert guild["Bob"].said("Lowbie") == []


def test_unknown_level_goes_by_the_honor_message():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]
    alice.run('units.target = { name = "Hidden", player = true, hostile = true }')
    alice.run('UnitLevel = function(u) if u == "target" then return nil end return 60 end')
    alice.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
    alice.run('units.target.dead = true')
    alice.fire("CHAT_MSG_COMBAT_HONOR_GAIN", "Hidden dies, honorable kill Rank: Private (10 Honor Points)")
    guild.run(10)
    assert victims(guild["Bob"]) == ["Hidden"]


def test_older_versions_grey_reports_are_dropped():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    t = int(guild.clock)
    # An older version reports a level 40 kill as honorable. From a level 60 it's grey...
    bob.fire("CHAT_MSG_ADDON", "TheImperium", "K^kill_world^Lowbie^STV^%d^0.5^40^1" % t, "GUILD", "Alice-Realm")
    # ...but from a level 45 it isn't (grey for 45 is 35 and below).
    bob.fire("CHAT_MSG_ADDON", "TheImperium", "K^kill_world^Fair^STV^%d^0.5^40^1" % t, "GUILD", "Twink-Realm")
    # Through kill-log sync, too.
    bob.fire("CHAT_MSG_ADDON", "TheImperiumB", "KX^%d^kill_world^Synced^STV^Alice^0.5^41^1" % (t - 3600), "WHISPER", "Alice-Realm")
    guild.run(5)
    assert victims(bob) == ["Fair"]
    assert bob.said("Lowbie") == []


def test_older_kills_stay_after_the_killer_levels_up():
    # A kill that gave honor at the time isn't removed or hidden because the
    # killer has levelled since: their level now says nothing about then.
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    t = int(guild.clock) - 86400
    for i, (victim, level, killer, honor) in enumerate([
        ("Earlier", 30, "Alice", "true"),      # honorable when Alice was lower; she's 60 now
        ("NoHonor", None, "Alice", "false"),   # level unknown, and no honor: left out
        ("Fine", 58, "Alice", "true"),
        ("Unknown", None, "Bob", "nil"),       # from before honor was recorded: kept
    ]):
        bob.run('table.insert(WarcrestDB.killLog, 1, { t = %d, kind = "kill_world", victim = "%s", zone = "STV", killers = { "%s" }, level = %s, honor = %s })'
                % (t - i * 60, victim, killer, level or "nil", honor))
    bob.login()
    guild.run(40)
    assert victims(bob) == ["Earlier", "Fine", "NoHonor", "Unknown"]   # nothing deleted
    L = bob.ns.db.killLog
    shown = sorted(L[i].victim for i in range(1, len(L) + 1) if not bob.ns.KillHidden(L[i]))
    assert shown == ["Earlier", "Fine", "Unknown"]
    # Older history from a guildmate is taken as recorded, too.
    bob.fire("CHAT_MSG_ADDON", "TheImperiumB", "KX^%d^kill_world^Synced^STV^Alice^0.5^41^1" % (t - 7200), "WHISPER", "Alice-Realm")
    guild.run(5)
    assert "Synced" in victims(bob)
    assert bob.errors() == []
