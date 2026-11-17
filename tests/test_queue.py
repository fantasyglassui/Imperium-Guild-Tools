"""The send queue stays under the game's limits and sends urgent messages first."""
from harness import Guild


def test_burst_is_throttled_not_refused():
    guild = Guild([("Alice", 1), ("Bob", 3)], throttle=True)
    alice = guild["Alice"]
    alice.ns.db.addonUsers.bob = alice.lua.eval('{ name = "Bob", version = "2.6.0" }')
    for i in range(120):
        alice.ns.QueueTo("Bob", "KX", i)
    for i in range(40):
        alice.ns.QueueTo("Old", "HK", i)
    guild.run(3)
    burst = guild.clock
    for i in range(5):
        alice.ns.Send("K", "kill_world", "Ganker%d" % i, "STV", 1)
    guild.run(200, step=0.5)

    mine = [m for m in guild.sent if m[0] == "Alice"]
    assert guild.refused == 0
    assert len([m for m in mine if m[3].startswith("KX^")]) == 120
    assert len([m for m in mine if m[3].startswith("HK^")]) == 40
    assert alice.ns.QueueSize() == 0
    # Catch-up for Bob (2.6.0+) goes on the bulk prefix, leaving the main one free for alerts.
    assert {m[1] for m in mine if m[3].startswith("KX^")} == {"TheImperiumB"}
    assert {m[1] for m in mine if m[3].startswith("HK^")} == {"TheImperium"}
    # Kill alerts jump the queue.
    kills = [i for i, m in enumerate(mine) if m[3].startswith("K^")]
    old = [i for i, m in enumerate(mine) if m[3].startswith("HK^")]
    assert len(kills) == 5 and max(kills) < max(old)
