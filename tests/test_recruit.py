"""Recruiting: officers share one list of recruits, post the recruiting
message, see whispers about joining, and hear when a trial is over."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Olga", 1)]


def test_officers_share_the_recruit_list():
    guild = Guild(M)
    alice = guild["Alice"]
    alice.ns.SetRecruit("thrall", alice.lua.eval('{ class = "SHAMAN", level = 58, note = "Resto, raided before" }'))
    guild.run(2)
    r = guild["Olga"].ns.Recruit("Thrall")
    assert (r.name, r["class"], r.level, r.status) == ("Thrall", "SHAMAN", 58, "new")
    guild["Olga"].ns.SetRecruit("Thrall", guild["Olga"].lua.eval('{ status = "contacted" }'))
    guild.run(2)
    r = alice.ns.Recruit("Thrall")
    assert r.status == "contacted" and r.note == "Resto, raided before"   # the rest stays
    alice.ns.RemoveRecruit("Thrall")
    guild.run(2)
    assert len(guild["Olga"].ns.Recruits()) == 0


def test_members_cant_manage_recruits():
    guild = Guild(M)
    assert guild["Bob"].ns.SetRecruit("Thrall") is None
    assert guild["Bob"].said("Only officers")


def test_trial_progress_and_the_end_of_a_trial():
    guild = Guild(M)
    alice = guild["Alice"]
    alice.ns.SetRecruit("Bob", alice.lua.eval('{ status = "trial" }'))     # Bob joined on trial
    guild.run(2)
    p = alice.ns.TrialProgress(alice.ns.Recruit("Bob"))
    assert (p.days, p.length, p.over) == (0, 14, False)
    guild.clock += 15 * 86400
    alice.login()
    guild.run(60)
    assert alice.said("Bob's trial is over (15 days)")
    assert guild["Bob"].said("trial") == []                # members don't hear it


def test_recruiting_message_and_posting():
    guild = Guild(M)
    alice = guild["Alice"]
    assert "is recruiting" in alice.ns.RecruitMessage()
    alice.ns.SetRecruitMessage("<The Imperium> wants healers! /w Alice")
    guild.run(2)
    assert guild["Olga"].ns.RecruitMessage() == "<The Imperium> wants healers! /w Alice"
    channels = alice.ns.ChatChannels()
    assert [channels[i].name for i in range(1, len(channels) + 1)] == ["General", "Trade"]
    assert alice.ns.PostRecruitMessage(2)
    sent = alice.lua.eval("chatSent")
    assert sent[1][1] == "<The Imperium> wants healers! /w Alice" and sent[1][2] == "CHANNEL" and sent[1][3] == 2


def test_whispers_about_joining_are_noted_for_officers():
    guild = Guild(M)
    alice = guild["Alice"]
    alice.fire("CHAT_MSG_WHISPER", "hey can i get a guild invite?", "Jaina-Realm")
    alice.fire("CHAT_MSG_WHISPER", "wanna duel?", "Arthas-Realm")
    alice.fire("CHAT_MSG_WHISPER", "join pls", "Bob-Realm")      # already in the guild
    assert [w.name for w in alice.ns.recruitWhispers.values()] == ["Jaina"]
    assert alice.said("Jaina whispered about joining")
    guild["Bob"].fire("CHAT_MSG_WHISPER", "guild invite?", "Jaina-Realm")
    assert len(guild["Bob"].ns.recruitWhispers) == 0               # only officers
    alice.ns.InviteRecruit("Jaina")
    assert alice.lua.eval("guildInvites[1]") == "Jaina"
    assert all(c.errors() == [] for c in guild.clients.values())
