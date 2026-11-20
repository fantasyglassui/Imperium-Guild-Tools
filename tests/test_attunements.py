"""Attunements: worked out from the quests each member has finished, shared,
shown in their own window and on raid sign-ups."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def finish(c, *ids):
    c.run("; ".join("questsDone[%d] = true" % i for i in ids))


def test_attunements_are_found_and_shared():
    guild = Guild(M)
    bob = guild["Bob"]
    finish(bob, 7848, 6602, 4743)           # MC, Onyxia (Horde), UBRS key
    bob.ns.CheckAttunements(True)
    guild.run(2)
    cara = guild["Cara"]
    assert cara.ns.IsAttuned("Bob", "mc") and cara.ns.IsAttuned("Bob", "ony") and cara.ns.IsAttuned("Bob", "ubrs")
    assert not cara.ns.IsAttuned("Bob", "bwl")
    assert cara.ns.AttunementsOf("Alice") is None              # nothing shared yet
    # Nothing changed: nothing new is written.
    before = len(bob.ns.LedgerEntries("AN"))
    bob.ns.CheckAttunements(True)
    assert len(bob.ns.LedgerEntries("AN")) == before


def test_a_new_attunement_is_announced():
    guild = Guild(M)
    bob = guild["Bob"]
    bob.ns.CheckAttunements(True)
    guild.run(2)
    finish(bob, 7761)
    bob.fire("QUEST_TURNED_IN", 7761)
    guild.run(5)
    assert bob.said("You're now attuned: Blackwing Lair.")
    assert guild["Cara"].said("Bob is now attuned: Blackwing Lair.")


def test_the_window_and_raid_signups():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    finish(alice, 7848)
    for c in (alice, bob):
        c.ns.CheckAttunements(True)
    guild.run(2)
    assert alice.ns.AttunementForRaid("Molten Core").key == "mc"
    assert alice.ns.AttunementForRaid("MC run Friday").key == "mc"
    assert alice.ns.AttunementForRaid("Zul'Gurub") is None
    alice.run('SlashCmdList.WARCREST("attune")')
    assert alice.lua.eval("WarcrestAttunements and WarcrestAttunements:IsShown()")
    counts, known = alice.ns.AttunementCounts(False)
    assert counts["mc"] == 1 and known == 2
    assert not alice.errors()
