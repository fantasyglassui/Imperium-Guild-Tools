"""Settings > Accessibility: text size, colour-blind colours, high contrast, banner timing and motion."""
from harness import Guild


def one():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    return guild, guild["Bob"]


def font_size(c, key):
    return c.lua.eval('function(UI, k) local _, size = UI.Fonts[k]:GetFont(); return size end')(c.ns.UI, key)


def test_off_by_default():
    _, bob = one()
    a = bob.ns.Access()
    assert (a.textSize, a.colorblind, a.contrast, a.bannerHold, a.reduceMotion) == (100, False, False, "normal", False)
    assert font_size(bob, "Body") == 12


def test_text_size_changes_every_font_at_once():
    _, bob = one()
    bob.ns.SetAccess("textSize", 120)
    assert font_size(bob, "Body") == 14 and font_size(bob, "Title") == 20
    bob.ns.SetAccess("textSize", 100)
    assert font_size(bob, "Body") == 12


def test_colours_and_contrast():
    _, bob = one()
    C = bob.ns.UI.C
    green, muted = (C.good[1], C.good[2], C.good[3]), C.muted[1]
    bob.ns.SetAccess("colorblind", True)
    assert round(C.good[3], 2) == round(0xe9 / 255, 2)           # good news is blue
    assert bob.ns.AccessKindColor("raid") is not None
    assert bob.ns.AccessChatColor("kill") == "|cff56b4e9"
    assert bob.said("/reload")
    bob.ns.SetAccess("contrast", True)
    assert C.muted[1] > muted
    bob.ns.SetAccess("colorblind", False)
    bob.ns.SetAccess("contrast", False)
    assert (C.good[1], C.good[2], C.good[3]) == green and C.muted[1] == muted
    assert bob.ns.AccessKindColor("raid") is None


def test_saved_colours_apply_before_windows_are_built():
    guild = Guild([("Alice", 1), ("Bob", 3)],
                  setup=lambda c: c.run('WarcrestDB = { access = { colorblind = true, textSize = 120 } }'))
    bob = guild["Bob"]
    assert round(bob.ns.UI.C.bad[1], 2) == round(0xf0 / 255, 2)
    assert font_size(bob, "Body") == 14


def test_banners_can_stay_until_dismissed_and_skip_motion():
    guild, bob = one()
    bob.ns.SetAccess("bannerHold", "sticky")
    bob.ns.SetAccess("reduceMotion", True)
    b = bob.ns.ShowBanner("kill", "Bob killed a ganker")
    assert b.GetAlpha(b) == 1                       # no fade in
    guild.run(60)
    assert len(bob.ns.ShownBanners()) == 1          # still there
    b.GetScript(b, "OnClick")(b, "RightButton")
    guild.run(0.2)
    assert len(bob.ns.ShownBanners()) == 0          # gone at once, no fade
    bob.ns.SetAccess("bannerHold", "long")
    bob.ns.ShowBanner("kill", "again")
    guild.run(8)
    assert len(bob.ns.ShownBanners()) == 1          # 10 seconds instead of 5
    guild.run(3)
    assert len(bob.ns.ShownBanners()) == 0


def test_the_settings_view():
    _, bob = one()
    bob.run('SlashCmdList.WARCREST("access")')
    tab = bob.lua.eval('function(UI) for _, t in ipairs(UI.tabs) do if t.id == "settings" then return t end end end')(bob.ns.UI)
    assert tab.view.value == "access"
    assert not bob.errors()
