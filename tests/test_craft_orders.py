"""Crafting orders: ask a guild crafter for something; they accept, decline or
mark it done; you can cancel. Both sides hear about it."""
from harness import Guild
from test_crafters import TAILOR, open_window

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def test_an_order_from_start_to_finish():
    guild = Guild(M)
    bob, cara = guild["Bob"], guild["Cara"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    cara.run('itemNames[13858] = "Runecloth Robe"')
    bob.run('itemNames[13858] = "Runecloth Robe"')
    e = cara.ns.PlaceCraftOrder("Bob", "13858", True, "for my alt")
    assert e
    assert cara.ns.PlaceCraftOrder("Bob", "13858", True, "") is None          # not twice
    guild.run(5)
    assert bob.said("Cara asks you to craft")
    forMe = list(bob.ns.MyCraftOrders()[0].values())
    assert len(forMe) == 1 and forMe[0].status == "open" and forMe[0].mats and forMe[0].note == "for my alt"
    assert cara.ns.UpdateCraftOrder(e.id, "accepted") is None                 # only Bob can
    assert bob.ns.UpdateCraftOrder(e.id, "accepted")
    guild.run(5)
    assert cara.said("Bob will craft")
    bob.ns.UpdateCraftOrder(e.id, "done")
    guild.run(5)
    assert cara.said("Bob has made")
    assert cara.ns.CraftOrder(e.id).status == "done"
    assert cara.ns.UpdateCraftOrder(e.id, "cancelled") is None or cara.ns.CraftOrder(e.id).status == "done"


def test_cancelling_and_the_window():
    guild = Guild(M)
    bob, cara = guild["Bob"], guild["Cara"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    e = cara.ns.PlaceCraftOrder("Bob", "14155", False, "")
    guild.run(3)
    assert cara.ns.UpdateCraftOrder(e.id, "cancelled")
    guild.run(3)
    assert bob.ns.CraftOrder(e.id).status == "cancelled"
    assert bob.ns.UpdateCraftOrder(e.id, "accepted") is None or bob.ns.CraftOrder(e.id).status == "cancelled"
    for c in (bob, cara):
        c.ns.ShowCrafters(None, "orders")
        c.ns.ShowCrafters("moon", "recipes")
        assert not c.errors()
