"""Guild goals: officers set targets for the week or month, everyone sees the
guild's progress, and the guild hears when a goal is reached."""
from harness import Guild
from test_war import kill

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def test_officers_set_goals_and_everyone_sees_progress():
    guild = Guild(M)
    assert guild["Bob"].ns.AddGoal("kills", 3, "week") is None       # members can't
    assert guild["Alice"].ns.AddGoal("kills", 3, "week")
    guild.run(2)
    goals = guild["Cara"].ns.Goals()
    assert len(goals) == 1
    g = goals[1]
    assert guild["Cara"].ns.GoalText(g) == "Kill 3 enemy players"
    kill(guild["Bob"], "Grim", "Bloodfang")
    p = guild["Cara"].ns.GoalProgress(g, 0)
    assert p.count == 1 and not p.done
    assert all(c.errors() == [] for c in guild.clients.values())


def test_reaching_a_goal_is_announced_once():
    guild = Guild(M)
    guild["Alice"].ns.AddGoal("kills", 2, "month")
    guild.run(2)
    kill(guild["Bob"], "Grim", "Bloodfang")
    guild.run(25)
    assert guild["Cara"].said("Guild goal reached") == []
    kill(guild["Bob"], "Thrak", "Bloodfang")
    guild.run(25)
    assert guild["Cara"].said("Guild goal reached: Kill 2 enemy players (this month).")
    guild.run(60)
    assert guild["Cara"].said("Guild goal reached") == []
    assert len(guild["Cara"].ns.GoalCompletions()) == 1


def test_goals_can_be_removed_and_are_capped():
    guild = Guild(M)
    alice = guild["Alice"]
    for n in range(1, 5):
        assert alice.ns.AddGoal("bosses", n, "week")
    assert alice.ns.AddGoal("bosses", 9, "week") is None             # four at most
    guild.run(2)
    goals = guild["Bob"].ns.Goals()
    assert len(goals) == 4
    assert alice.ns.RemoveGoal(goals[1].id)
    guild.run(2)
    assert len(guild["Bob"].ns.Goals()) == 3


def test_the_goals_card_renders():
    guild = Guild(M)
    alice = guild["Alice"]
    alice.ns.AddGoal("kills", 5, "week")
    alice.ns.AddGoal("raidnights", 8, "month")
    guild.run(2)
    for c in (alice, guild["Bob"]):
        c.ns.OpenPanel("achievements", "guild")
        guild.run(1)
        assert c.errors() == []
