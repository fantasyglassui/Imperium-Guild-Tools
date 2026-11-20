"""Guild polls: officers (and members, if the guild allows) ask a question,
everyone votes once, results are shared."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def answers(c, *a):
    return c.lua.table_from(list(a))


def test_officers_start_polls_and_everyone_votes_once():
    guild = Guild(M)
    alice, bob, cara = guild["Alice"], guild["Bob"], guild["Cara"]
    assert bob.ns.StartPoll("Members?", answers(bob, "a", "b"), 3) is None          # off by default
    e = alice.ns.StartPoll("Raid on Thursday or Friday?", answers(alice, "Thursday", "Friday", ""), 3)
    assert e
    guild.run(3)
    p = cara.ns.Poll(e.id)
    assert p.open and list(p.opts.values()) == ["Thursday", "Friday"]
    bob.ns.VotePoll(e.id, 1)
    cara.ns.VotePoll(e.id, 2)
    cara.ns.VotePoll(e.id, 1)                                                     # changes her vote
    guild.run(3)
    p = alice.ns.Poll(e.id)
    assert p.total == 2 and p.counts[1] == 2 and p.counts[2] == 0
    assert cara.ns.MyVote(cara.ns.Poll(e.id)) == 1


def test_closing_and_votes_after_it_dont_count():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    e = alice.ns.StartPoll("Onyxia this week?", answers(alice, "Yes", "No"), 1)
    guild.run(2)
    assert bob.ns.ClosePoll(e.id) is None                      # not his poll
    assert alice.ns.ClosePoll(e.id)
    guild.run(2)
    assert not bob.ns.Poll(e.id).open
    assert bob.ns.VotePoll(e.id, 1) is None


def test_members_can_start_one_each_when_allowed():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    types = alice.ns.cfg.types
    assert alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1,
                                                     "memberPolls": True}))
    guild.run(3)
    assert bob.ns.MembersCanPoll()
    assert bob.ns.StartPoll("Dungeon tonight?", answers(bob, "Strat", "Scholo"), 2)
    assert bob.ns.StartPoll("Another?", answers(bob, "a", "b"), 2) is None        # one open each
    guild.run(3)
    assert guild["Cara"].said("Bob asks the guild: ")


def test_the_polls_view():
    guild = Guild(M)
    alice, bob = guild["Alice"], guild["Bob"]
    alice.ns.StartPoll("Raid time?", answers(alice, "19:00", "20:00", "21:00"), 7)
    guild.run(2)
    for c in (alice, bob):
        c.ns.OpenPanel("events", "polls")
        guild.run(1)
        assert not c.errors()
