"""Boss fights and PvP matches lock addon chat: Warcrest holds what it has to
say and sends it when the lockdown ends, instead of losing it."""
from harness import Guild

MEMBERS = [("Gm", 0), ("Alice", 1), ("Bob", 3), ("Cara", 3)]
RAID = ["Alice", "Bob", "Cara"]
LEGS = "|cffa335ee|Hitem:2::::::::60:::::::|h[Stormrage Legguards]|h|r"


def lock(guild, on, who=None, mode=True):
    for name in (who or guild.clients):
        guild[name].lua.globals().chatLockdown = mode if on else False


def raid_night():
    guild = Guild(MEMBERS, raid=RAID)
    guild["Alice"].ns.StartRaidSession("", "Molten Core", 10, 10, 15)
    guild.run(3)
    return guild


def bal(guild, name, who="Gm"):
    return guild[who].ns.Balance(name)


def test_messages_wait_for_the_fight_to_end():
    guild = raid_night()
    alice = guild["Alice"]
    lock(guild, True, RAID)
    alice.said()
    alice.ns.AwardDKP(alice.lua.table_from(["Bob"]), 7, "Pulled well")
    guild.run(60)
    assert bal(guild, "Bob") == 10          # nothing got out during the fight
    assert alice.ns.QueueSize() > 0         # but it wasn't thrown away
    assert len(alice.said("when this one ends")) == 1   # told once, not every tick
    lock(guild, False)
    guild.run(3)
    assert bal(guild, "Bob") == 17
    assert alice.ns.QueueSize() == 0


def test_a_refused_send_is_kept_even_without_the_lockdown_flag():
    # Some restrictions only show in SendAddonMessage's answer.
    guild = raid_night()
    alice = guild["Alice"]
    lock(guild, True, ["Alice"], mode="result")
    alice.ns.AwardDKP(alice.lua.table_from(["Cara"]), 4, "Soaked")
    guild.run(120)                          # well past the old five tries
    assert bal(guild, "Cara") == 10
    lock(guild, False)
    guild.run(8)
    assert bal(guild, "Cara") == 14


def test_chat_lines_are_held_too():
    guild = raid_night()
    alice = guild["Alice"]
    lock(guild, True, ["Alice"])
    ok, why = alice.ns.SendChat("Grats on the kill!", "GUILD")
    assert ok and why == "held"
    assert len(alice.lua.eval("chatSent")) == 0
    guild.run(10)
    lock(guild, False)
    guild.run(3)
    sent = alice.lua.eval("chatSent")
    assert len(sent) == 1 and sent[1][1] == "Grats on the kill!"


def test_an_auction_waits_out_the_fight():
    guild = raid_night()
    a = guild["Alice"].ns
    lock(guild, True, RAID)
    guild["Alice"].said()
    assert not a.StartAuction(LEGS, 5, 20)
    assert guild["Alice"].said("Wait for the fight to end")
    lock(guild, False)
    a.StartAuction(LEGS, 5, 20)
    guild.run(3)
    lock(guild, True, RAID)                 # the next boss is pulled mid-auction
    guild["Bob"].ns.PlaceBid(8)             # held until the fight ends
    guild.run(90)
    assert not guild["Bob"].ns.auction.done
    assert not guild["Bob"].ns.auction.rolling
    lock(guild, False)
    guild.run(30)
    assert guild["Bob"].ns.auction.done
    assert bal(guild, "Bob") == 2           # his bid counted
    for c in guild.clients.values():
        assert c.errors() == []


def test_secret_values_are_ignored():
    guild = raid_night()
    bob = guild["Bob"]
    bob.run('issecretvalue = function(v) return v == "SECRET" end')
    bob.fire("CHAT_MSG_ADDON", "TheImperium", "K^x", "GUILD", "SECRET")
    bob.fire("CHAT_MSG_ADDON", "TheImperium", "SECRET", "GUILD", "Alice-Realm")
    bob.fire("CHAT_MSG_WHISPER", "SECRET", "Stranger-Realm")
    bob.fire("ENCOUNTER_START", 672, "SECRET", 9, 40)
    bob.fire("CHAT_MSG_SYSTEM", "SECRET")
    assert bob.errors() == []
    assert bob.ns.RemindAssignment("SECRET") is None
