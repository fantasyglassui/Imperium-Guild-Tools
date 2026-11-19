"""Member profiles: shared with the guild, item level kept up to date,
birthdays and anniversaries celebrated."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3, "PRIEST"), ("Cara", 3)]


def profile(c, **kw):
    fields = dict(spec="Holy", role="healer", hours="19:00-23:00", bday="", note="Raid healer, loves PvP")
    fields.update(kw)
    days = kw.pop("days", [True, True, True, True, True, False, False])
    t = c.lua.eval("{}")
    for k, v in fields.items():
        if k != "days":
            t[k] = v
    t["days"] = c.lua.table_from(days)
    return c.ns.SaveMyProfile(t)


def gear(c, level):
    c.run('equipped = {} itemLevels = {} for slot = 1, 18 do if slot ~= 4 then '
          'equipped[slot] = "item" .. slot itemLevels["item" .. slot] = { %d } end end' % level)


def test_a_profile_is_shared_and_the_latest_counts():
    guild = Guild(M)
    bob = guild["Bob"]
    gear(bob, 60)
    assert profile(bob) is not None
    guild.run(2)
    p = guild["Alice"].ns.MemberProfile("Bob")
    assert (p.spec, p.role, p.hours, p.ilvl) == ("Holy", "healer", "19:00-23:00", 60)
    assert guild["Alice"].ns.AvailabilityText(p) == "Mon-Fri, 19:00-23:00"
    profile(bob, spec="Shadow", role="dps")
    guild.run(2)
    assert guild["Alice"].ns.MemberProfile("Bob").spec == "Shadow"
    assert guild["Alice"].ns.MemberProfile("Cara") is None


def test_times_must_look_like_times():
    guild = Guild(M)
    assert profile(guild["Bob"], hours="evenings") is None
    assert guild["Bob"].said("19:00-23:00")


def test_days_in_words():
    guild = Guild(M)
    ns = guild["Bob"].ns
    L = guild["Bob"].lua
    def words(days):
        return ns.DaysText(L.table_from(days))
    assert words([True] * 7) == "Every day"
    assert words([False, False, False, False, False, True, True]) == "Sat, Sun"
    assert words([True, False, True, False, True, False, False]) == "Mon, Wed, Fri"
    assert words([False] * 7) == ""


def test_item_level_follows_your_gear():
    guild = Guild(M)
    bob = guild["Bob"]
    gear(bob, 55)
    profile(bob)
    guild.run(2)
    gear(bob, 62)
    bob.run('WarcrestDB.ilvlSharedAt = 0')
    bob.fire("PLAYER_EQUIPMENT_CHANGED", 5, True)
    guild.run(30)
    assert guild["Alice"].ns.MemberProfile("Bob").ilvl == 62


def test_birthdays_are_celebrated_once():
    guild = Guild(M)
    bob = guild["Bob"]
    today = bob.lua.eval('date("%m-%d")')
    profile(bob, bday=today)
    guild.run(2)
    for c in guild.clients.values():
        c.login()
    guild.run(30)
    assert guild["Alice"].said("It's Bob's birthday today!")
    assert bob.said("Happy birthday from your guild!")
    guild.run(600)
    assert guild["Alice"].said("birthday") == []          # once


def test_anniversaries():
    guild = Guild(M)
    alice = guild["Alice"]
    alice.login()
    guild.run(30)
    alice.run('WarcrestDB.firstSeen.cara = time() - 365 * 86400')
    guild.run(310)
    assert alice.said("Cara has been in the guild for a year!")
    assert all(c.errors() == [] for c in guild.clients.values())
