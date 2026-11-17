"""DKP: awards, undo, boss kills, imports, alts, auctions and free rolls."""
from harness import Guild

MEMBERS = [("Gm", 0), ("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Bobalt", 3)]
RAID = ["Alice", "Bob", "Cara"]
CHEST = "|cffa335ee|Hitem:1::::::::60:::::::|h[Plate Chest]|h|r"
LEGS = "|cffa335ee|Hitem:2::::::::60:::::::|h[Stormrage Legguards]|h|r"


def raid_night():
    guild = Guild(MEMBERS, raid=RAID)
    guild["Alice"].ns.StartRaidSession("", "Molten Core", 10, 10, 15)
    guild.run(3)
    return guild


def bal(guild, name, who="Gm"):
    return guild[who].ns.Balance(name)


def names(client, *who):
    return client.lua.table_from(list(who))


def test_on_time_bonus_reaches_everyone():
    guild = raid_night()
    for viewer in ("Gm", "Bob", "Dan"):
        assert [bal(guild, n, viewer) for n in RAID] == [10, 10, 10]
    assert bal(guild, "Dan") == 0


def test_boss_kill_counts_once_and_not_on_a_wipe():
    guild = raid_night()
    alice = guild["Alice"]
    alice.fire("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 0)  # wipe
    guild.run(3)
    assert bal(guild, "Bob") == 10
    alice.fire("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)  # kill
    guild.run(3)
    assert bal(guild, "Bob") == 25
    alice.fire("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)  # same boss again
    guild.run(3)
    assert bal(guild, "Bob") == 25


def test_undo():
    guild = raid_night()
    a = guild["Alice"].ns
    a.AwardDKP(names(guild["Alice"], "Cara"), 100, "Oops, meant 10")
    guild.run(3)
    assert bal(guild, "Cara") == 110
    oops = [c.entry for c in a.DKPChanges().values() if c.entry.reason == "Oops, meant 10"][0]
    a.UndoDKP(oops, "")
    guild.run(3)
    assert bal(guild, "Cara") == 10
    guild["Alice"].said()
    a.UndoDKP(oops, "")
    guild.run(3)
    assert bal(guild, "Cara") == 10
    assert guild["Alice"].said("already undone")


def test_members_cannot_award():
    guild = raid_night()
    guild["Bob"].ns.AwardDKP(names(guild["Bob"], "Bob"), 500, "Free DKP")
    guild.run(3)
    assert bal(guild, "Bob") == 10


def test_import():
    guild = raid_night()
    a = guild["Alice"].ns
    rows, bad = a.ParseImport("Name, DKP\nBob, 120\nCara 50\nDan\t75\nthis line is junk")
    assert len(rows) == 3
    assert list(bad.values()) == ["this line is junk"]
    a.ImportBalances(rows)
    guild.run(5)
    assert [bal(guild, n) for n in ("Bob", "Cara", "Dan")] == [120, 50, 75]


def test_alt_needs_the_mains_confirmation():
    guild = raid_night()
    a = guild["Alice"].ns
    a.AwardDKP(names(guild["Alice"], "Bobalt"), 30, "Played the alt")
    guild.run(3)

    guild["Cara"].ns.RequestAltLink("Bob")
    guild.run(3)
    assert guild["Gm"].ns.MainOf("Cara") != "Bob"

    # Cara forges Bob's confirmation: whispers from her can't speak for Bob.
    forged = "X^Bob:1:1^%d^Bob^AL^Cara^Bob^ok" % int(guild.clock)
    for c in guild.clients.values():
        if c.name != "Cara":
            c.fire("CHAT_MSG_ADDON", "TheImperium", forged, "WHISPER", "Cara-Realm")
    guild.run(2)
    assert guild["Gm"].ns.MainOf("Cara") != "Bob"

    guild["Bobalt"].ns.RequestAltLink("Bob")
    guild.run(3)
    assert "Bobalt" in list(guild["Bob"].ns.PendingAltRequests().values())
    guild["Bob"].ns.ConfirmAlt("Bobalt")
    guild.run(3)
    assert guild["Gm"].ns.MainOf("Bobalt") == "Bob"
    assert bal(guild, "Bob") == 40       # 10 + the alt's 30
    assert bal(guild, "Bobalt") == 40    # the alt spends the main's DKP


def test_class_check():
    a = raid_night()["Alice"].ns
    assert not a.CanUseItem("[Plate Chest]", "MAGE")
    assert a.CanUseItem("[Plate Chest]", "WARRIOR")
    assert a.CanUseItem("[Ring]", "MAGE") is None   # jewelry: can't tell, so allowed


def test_free_roll_when_nobody_bids():
    guild = raid_night()
    alice = guild["Alice"]
    alice.ns.StartAuction(CHEST, 5, 20)
    guild.run(25)
    assert guild["Bob"].ns.auction.rolling
    # Only a raider's first roll counts; outsiders are ignored.
    for who, v in [("Bob", 40), ("Cara", 60), ("Stranger", 99), ("Bob", 100)]:
        alice.fire("CHAT_MSG_SYSTEM", "%s rolls %d (1-100)" % (who, v))
    guild.run(25)
    lh = guild["Gm"].ns.LootHistory()
    won = [lh[i] for i in range(1, len(lh) + 1) if "Plate Chest" in lh[i].item][0]
    assert won.winner == "Cara" and won.roll    # Bob's second roll of 100 didn't count
    assert bal(guild, "Cara") == 10             # a free roll costs nothing


def test_open_auction_and_reassign():
    guild = raid_night()
    a = guild["Alice"].ns
    a.StartAuction(LEGS, 5, 20)
    guild.run(2)
    guild["Bob"].ns.PlaceBid(8)
    guild.run(25)
    assert bal(guild, "Bob") == 2
    won = [l for l in a.LootHistory().values() if "Legguards" in l.item][0]
    a.ReassignLoot(won, "Cara")
    guild.run(5)
    assert (bal(guild, "Bob"), bal(guild, "Cara")) == (10, 2)


def test_hidden_bids_pay_second_price_plus_one():
    guild = raid_night()
    a = guild["Alice"].ns
    a.SetDKPRules(10, False, True)   # decay %, weekly decay, hidden bids
    guild.run(3)
    a.AwardDKP(names(guild["Alice"], "Bob", "Cara"), 10, "Bonus")
    guild.run(3)
    a.StartAuction(LEGS, 5, 20)
    guild.run(2)
    assert guild["Bob"].ns.auction.hidden
    guild["Bob"].ns.PlaceBid(18)
    guild["Cara"].ns.PlaceBid(12)
    guild.run(3)
    assert guild["Bob"].ns.auction.myBid == 18
    assert not guild["Cara"].ns.auction.leader   # nobody sees the others' bids
    guild.run(25)
    assert bal(guild, "Bob") == 20 - 13
    assert bal(guild, "Cara") == 20
    for c in guild.clients.values():
        assert c.errors() == []
