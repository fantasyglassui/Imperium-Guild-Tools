"""Guild events: any member makes one, guildmates answer, get reminded, and
whoever made it can invite, take attendance and cancel."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3)]
HOUR = 3600


def make(guild, who="Bob", etype="pvp", title="Tarren Mill raid", in_hours=2, mins=90):
    c = guild[who]
    e = c.ns.CreateGuildEvent(etype, title, int(guild.clock) + int(in_hours * HOUR), "Bring pots", mins)
    guild.run(2)
    return e


def test_any_member_makes_an_event_and_guildmates_answer():
    guild = Guild(M)
    e = make(guild)
    assert e is not None
    alice, cara = guild["Alice"], guild["Cara"]
    assert [x.title for x in alice.ns.GuildEvents().values()] == ["Tarren Mill raid"]
    assert alice.said("New guild event from Bob")         # guildmates hear about it
    assert guild["Bob"].said("New guild event") == []      # not the one who made it
    alice.ns.EventSignUp(e.id, "going")
    cara.ns.EventSignUp(e.id, "maybe")
    guild["Dan"].ns.EventSignUp(e.id, "no")
    guild.run(2)
    counts = guild["Bob"].ns.EventCounts(e.id)
    assert (counts.going, counts.maybe, counts.no) == (1, 1, 1)
    cara.ns.EventSignUp(e.id, "going")                     # changing your answer: the latest counts
    guild.run(2)
    assert guild["Bob"].ns.EventCounts(e.id).going == 2


def test_only_the_maker_or_an_officer_can_cancel():
    guild = Guild(M)
    e = make(guild)
    guild["Cara"].ns.CancelGuildEvent(e.id)               # not hers
    guild.run(2)
    assert len(guild["Dan"].ns.GuildEvents()) == 1
    assert guild["Cara"].said("Only whoever made the event")
    # Even sent by hand, a cancel from someone else doesn't count.
    guild["Cara"].ns.LedgerAdd("GX", guild["Cara"].lua.eval('{ ref = "%s" }' % e.id))
    guild.run(2)
    assert len(guild["Dan"].ns.GuildEvents()) == 1
    guild["Alice"].ns.CancelGuildEvent(e.id)              # an officer can
    guild.run(2)
    assert len(guild["Dan"].ns.GuildEvents()) == 0


def test_reminder_before_it_starts_for_those_going():
    guild = Guild(M)
    e = make(guild, in_hours=0.5)
    guild["Alice"].ns.EventSignUp(e.id, "going")
    guild["Dan"].ns.EventSignUp(e.id, "no")
    guild.run(20 * 60)
    assert guild["Alice"].said("Tarren Mill raid starts at")
    assert guild["Dan"].said("starts at") == []
    assert guild["Cara"].said("starts at") == []


def test_attendance_is_the_makers_group_and_counts_for_members():
    guild = Guild(M)
    e = make(guild)
    bob = guild["Bob"]
    assert bob.ns.TakeEventAttendance(e.id) is None       # not in a group yet
    assert bob.said("Group up with everyone")
    bob.set_raid(["Bob", "Alice", "Cara"])
    assert bob.ns.TakeEventAttendance(e.id) == 3
    guild.run(2)
    came = guild["Dan"].ns.EventAttended(e.id)
    assert sorted(came.keys()) == ["alice", "bob", "cara"]
    assert guild["Dan"].ns.EventsAttended("Alice") == 1
    assert guild["Dan"].ns.EventsAttended("Dan") == 0
    # Someone else can't take attendance for it.
    guild["Dan"].set_raid(["Dan"])
    assert guild["Dan"].ns.TakeEventAttendance(e.id) is None


def test_invite_everyone_going():
    guild = Guild(M)
    e = make(guild)
    for n in ("Alice", "Cara"):
        guild[n].ns.EventSignUp(e.id, "going")
    guild["Dan"].ns.EventSignUp(e.id, "no")
    guild.run(2)
    assert guild["Bob"].ns.InviteEventGoing(e.id) == 2
    assert guild["Bob"].said("Inviting 2 members going to Tarren Mill raid")


def test_events_show_on_the_calendar_and_errors_stay_away():
    guild = Guild(M)
    make(guild, etype="worldboss", title="Kazzak")
    for c in guild.clients.values():
        assert c.errors() == []
