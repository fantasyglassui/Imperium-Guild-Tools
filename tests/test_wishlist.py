"""Loot wishlists: shared between guildmates, Need before Want, won items drop off."""
from harness import Guild
from test_dkp import LEGS, CHEST, MEMBERS, RAID, raid_night


def ids(rows):
    return [r.id for r in rows.values()]


def test_wishes_are_shared_and_sorted():
    guild = Guild(MEMBERS)
    guild["Bob"].ns.WishlistAdd(LEGS, "want")
    guild["Cara"].ns.WishlistAdd(LEGS, "need")
    guild["Cara"].ns.WishlistAdd(CHEST, "want")
    guild.run(3)
    dan = guild["Dan"].ns
    rows = list(dan.GuildWishlist().values())
    assert [r.name for r in rows] == ["Stormrage Legguards", "Plate Chest"]
    legs = rows[0]
    assert (legs.need, legs.want) == (1, 1)
    assert [w.name for w in legs.wishers.values()] == ["Cara", "Bob"]   # Need first
    assert [w.name for w in dan.WishersFor(LEGS).values()] == ["Cara", "Bob"]


def test_change_and_remove():
    guild = Guild(MEMBERS)
    bob = guild["Bob"].ns
    bob.WishlistAdd(LEGS, "want")
    guild.run(1)
    guild.jump(5)
    bob.WishlistAdd(LEGS, "need")
    guild.run(2)
    assert [w.prio for w in guild["Dan"].ns.Wishes("Bob").values()] == ["need"]
    guild.jump(5)
    bob.WishlistRemove("2")
    guild.run(2)
    assert len(guild["Dan"].ns.Wishes("Bob")) == 0


def test_nobody_can_wish_in_someone_elses_name():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    # Bob passes along a wish claiming to be Cara's.
    bob.lua.globals().fake = bob.ns
    bob.run('fake.Send("X", "Cara:1:9", tostring(GetServerTime()), "Cara", "WL", "2", "Stormrage Legguards", "need")')
    guild.run(2)
    assert len(guild["Dan"].ns.Wishes("Cara")) == 0


def test_won_items_leave_the_wishers_but_stay_on_your_list():
    guild = raid_night()
    guild["Bob"].ns.WishlistAdd(LEGS, "need")
    guild["Cara"].ns.WishlistAdd(LEGS, "want")
    guild.run(3)
    guild.jump(10)
    a = guild["Alice"].ns
    a.StartAuction(LEGS, 5, 20)
    guild.run(2)
    assert guild["Bob"].said("on your wishlist")
    assert guild["Alice"].said("On wishlists: Bob (Need")
    guild["Bob"].ns.PlaceBid(8)
    guild.run(25)
    dan = guild["Dan"].ns
    assert [w.name for w in dan.WishersFor(LEGS).values()] == ["Cara"]
    mine = list(guild["Bob"].ns.Wishes("Bob").values())
    assert mine[0].won
    assert not guild["Bob"].errors() and not guild["Alice"].errors()
