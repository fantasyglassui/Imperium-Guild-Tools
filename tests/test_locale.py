"""Translations: the game's language picks German, French or Spanish text, and
a choice in Settings overrides it."""
from harness import Guild


def german(c):
    c.run('gameLocale = "deDE"')


def test_game_language_is_used():
    guild = Guild([("Thorne", 1)], setup=german)
    ns = guild["Thorne"].ns
    assert ns.T("Raids") == "Schlachtzüge"
    assert ns.T("Something not translated") == "Something not translated"


def test_labels_and_buttons_translate():
    guild = Guild([("Thorne", 1)], setup=german)
    me = guild["Thorne"]
    me.ns.OpenPanel("settings", "general")
    label = me.lua.eval("function(ns) local l = ns.UI.Label(UIParent, 'Save'); return l:GetText() end")(me.ns)
    assert label == "Speichern"
    button = me.lua.eval("function(ns) local b = ns.UI.Button(UIParent, 'Cancel'); b:SetText('Wishlist'); return b:GetText() end")(me.ns)
    assert button == "Wunschliste"


def test_setting_overrides_game_language():
    guild = Guild([("Thorne", 1)], setup=lambda c: c.run('gameLocale = "deDE"; WarcrestDB = { locale = "frFR" }'))
    assert guild["Thorne"].ns.T("Raids") == "Raids"
    assert guild["Thorne"].ns.T("Loot council") == "Conseil de butin"
    guild = Guild([("Thorne", 1)], setup=lambda c: c.run('gameLocale = "esMX"'))
    assert guild["Thorne"].ns.T("Loot council") == "Consejo de botín"


def test_every_translation_keeps_format_codes():
    guild = Guild([("Thorne", 1)])
    ns = guild["Thorne"].ns
    import re
    for code in ("deDE", "frFR", "esES"):
        for en, tr in ns.LOCALES[code].items():
            assert re.findall(r"%[sd]", en) == re.findall(r"%[sd]", tr), (code, en)
            assert tr.strip(), (code, en)
