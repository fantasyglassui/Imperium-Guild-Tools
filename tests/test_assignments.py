"""Raid assignments: officers write who does what per boss; everyone sees the
plan and their own job, reminded at the pull; officers post it to raid chat."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]
PLAN = "Tanks: Alice on the boss, Bob on adds\nHealers: Cara on tanks\nInterrupts: Bob and Cara"


def test_officers_write_plans_everyone_reads_them():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    assert bob.ns.SaveAssignment("Molten Core", "Lucifron", "x") is None      # members can't
    assert alice.ns.SaveAssignment("Molten Core", "Lucifron", PLAN)
    guild.run(3)
    plan = bob.ns.Assignment("Molten Core", "Lucifron")
    assert plan.text == PLAN
    assert list(bob.ns.JobsIn(plan.text, "Bob").values()) == ["Tanks: Alice on the boss, Bob on adds",
                                                              "Interrupts: Bob and Cara"]
    assert list(bob.ns.JobsIn(plan.text, "Bo").values()) == []                # whole names only
    bosses = list(bob.ns.AssignmentBosses("Molten Core").values())
    assert bosses[0] == "Whole raid" and bosses[1] == "Lucifron" and len(bosses) == 11


def test_long_plans_are_sent_in_parts_and_the_newest_counts():
    guild = Guild(M)
    alice, cara = guild["Alice"], guild["Cara"]
    long = "\n".join("Group %d: Cara heals, Bob tanks the pack by the lava" % i for i in range(1, 15))
    assert alice.ns.SaveAssignment("Naxxramas", "Patchwerk", long)
    guild.run(5)
    assert cara.ns.Assignment("Naxxramas", "Patchwerk").text == long[:1200].strip()
    alice.ns.SaveAssignment("Naxxramas", "Patchwerk", "Tanks: Alice")
    guild.run(3)
    assert cara.ns.Assignment("Naxxramas", "Patchwerk").text == "Tanks: Alice"


def test_your_job_at_the_pull_and_posting_to_raid_chat():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    alice.ns.SaveAssignment("Molten Core", "Lucifron", PLAN)
    guild.run(3)
    bob.run("IsInRaid = function() return true end")
    bob.fire("ENCOUNTER_START", 663, "Lucifron", 9, 40)
    assert bob.said("Your job on")
    alice.run("IsInRaid = function() return true end; chatSent = {}")
    assert alice.ns.PostAssignment("Molten Core", "Lucifron")
    guild.run(3)
    sent = [m for m in alice.lua.eval("chatSent").values()]
    assert len(sent) == 4
    alice.ns.ShowAssignments("Molten Core")
    bob.ns.ShowAssignments("Molten Core")
    assert not alice.errors() and not bob.errors()
