"""The Wanted list: three kills put a ganker on it, and killing him takes him off."""
from harness import Guild


def death(client, who, ago):
    client.ns.MergeDeath(client.lua.eval(
        '{ t = %d, who = "%s", kind = "pvp", sub = "world", zone = "STV", killer = "Ganker-Stormrage" }'
        % (int(client.guild.clock) - ago, who)))


def wanted(client):
    w = client.ns.WantedList()
    return [(w[i].name, w[i].count) for i in range(1, len(w) + 1)]


def test_wanted_and_claimed():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    bob = guild["Bob"]
    for i, who in enumerate(["Bob", "Alice", "Bob"]):
        death(bob, who, 3000 - i * 100)
    assert [n for n, _ in wanted(bob)] == ["Ganker"]
    assert wanted(bob)[0][1] == 3

    # Alice kills him: he comes off the list for everyone.
    guild["Alice"].ns.Send("K", "kill_world", "Ganker-Stormrage", "STV", int(guild.clock))
    guild.run(3)
    assert wanted(bob) == []

    guild.jump(1000)
    death(bob, "Bob", 900)
    death(bob, "Alice", 800)
    assert wanted(bob) == []          # two kills since: below the threshold
    death(bob, "Bob", 100)
    assert [n for n, _ in wanted(bob)] == ["Ganker"]

    # With the option off, old kills count again.
    bob.ns.SetWantedRemoveOnKill(False)
    assert wanted(bob)[0][1] == 6
    assert bob.errors() == []


def test_your_own_sighting_shows_once_when_the_game_echoes_it_with_a_realm():
    """WoW: Forever sends your own guild messages back with your realm on the
    name, and may not say which realm is yours: it must still count as you."""
    guild = Guild([("Sathryus", 1), ("Bob", 3)], echo=True)
    me = guild["Sathryus"]
    me.run('GetNormalizedRealmName = function() return nil end')
    me.ns.Send("S", "Xbalanque", "Feralas", 2, "", "", "", int(guild.clock))
    guild.run(2)
    lines = me.said("Xbalanque")
    assert len(lines) == 1 and lines[0].endswith("by Sathryus")


def test_two_reports_of_the_same_enemy_show_once():
    guild = Guild([("Alice", 1), ("Bob", 3), ("Cara", 3)])
    for who in ("Alice", "Bob"):
        guild[who].ns.Send("S", "Xbalanque", "Feralas", 2, "", "", "", int(guild.clock))
    guild.run(2)
    assert len(guild["Cara"].said("Xbalanque")) == 1


def test_your_own_messages_count_as_yours_whatever_realm_the_game_adds():
    guild = Guild([("Sathryus", 1), ("Bob", 3)], echo=True)
    me = guild["Sathryus"]
    me.run('GetNormalizedRealmName = function() return "SomethingElse" end')
    assert me.ns.IsMe("Sathryus-Wraithblade") and me.ns.IsMe("sathryus") and not me.ns.IsMe("Bob-Realm")
    # Every kind of message, not only sightings: handled once.
    me.run('zzCount = 0')
    me.lua.eval('function(ns) ns.OnMessage("ZZ", function() zzCount = zzCount + 1 end) end')(me.ns)
    me.ns.Send("ZZ", "x")
    guild.run(2)
    assert me.lua.eval("zzCount") == 1
