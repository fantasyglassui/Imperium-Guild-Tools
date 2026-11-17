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
