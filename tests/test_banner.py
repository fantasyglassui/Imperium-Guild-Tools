"""Alert banners: guild alerts show as a themed card at the top of the screen,
one look per kind of alert, and fade after a few seconds."""
from harness import Guild


def test_kill_alert_shows_a_banner_that_fades():
    guild = Guild([("Thorne", 1), ("Lyra", 3)])
    me = guild["Thorne"]
    me.ns.ShowKill(me.lua.eval('{ killers = { "Lyra" }, victim = "Ganker", kind = "kill_world", zone = "Duskwood" }'), True)
    shown = me.ns.ShownBanners()
    assert len(shown) == 1
    b = shown[1]
    assert "Ganker" in b.text.GetText(b.text)
    assert "|T" not in b.text.GetText(b.text)          # the little chat icons are dropped
    assert b.kicker.GetText(b.kicker) == "GUILD KILL"
    guild.run(10)
    assert len(me.ns.ShownBanners()) == 0


def test_banners_stack_three_at_most():
    guild = Guild([("Thorne", 1)])
    ns = guild["Thorne"].ns
    for i in range(5):
        ns.ShowBanner("boss", "Boss %d is down" % i)
    shown = ns.ShownBanners()
    assert len(shown) == 3
    assert shown[1].text.GetText(shown[1].text) == "Boss 4 is down"   # newest on top


def test_raid_warning_and_chat_only_styles():
    guild = Guild([("Thorne", 1)])
    me = guild["Thorne"]
    me.ns.db.alertStyle = "warning"
    me.ns.Notify("Hello", None, None, True, "kill")
    assert len(me.ns.ShownBanners()) == 0
    me.ns.db.alertStyle = "off"
    me.ns.Notify("Hello", None, None, True, "kill")
    assert len(me.ns.ShownBanners()) == 0


def test_old_setting_carries_over():
    guild = Guild([("Thorne", 1)], setup=lambda c: c.run("WarcrestDB = { warning = false }"))
    assert guild["Thorne"].ns.AlertStyle() == "off"
    guild = Guild([("Thorne", 1)])
    assert guild["Thorne"].ns.AlertStyle() == "banner"


def test_translated_heading():
    guild = Guild([("Thorne", 1)], setup=lambda c: c.run('gameLocale = "deDE"'))
    ns = guild["Thorne"].ns
    b = ns.ShowBanner("boss", "Onyxia")
    assert b.kicker.GetText(b.kicker) == "BOSS BESIEGT"
