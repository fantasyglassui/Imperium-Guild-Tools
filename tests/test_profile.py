"""Player cards: one guild member's history in one place."""
from harness import Guild
from render import Renderer, demo_guild
from test_render import sticking_out, walk_text
from test_streaks import live_death, live_kill

MEMBERS = [("Alice", 1), ("Bob", 3), ("Mira", 3, "PRIEST")]


def test_profile_counts_kills_deaths_nemesis_and_streaks():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for victim in ("Grim", "Grim", "Vex"):
        live_kill(guild, "Alice", victim)
        guild.jump(300)
    live_death(guild, "Alice", "Ganker-Stormrage")
    guild.jump(600)
    live_death(guild, "Alice", "Ganker-Stormrage")
    guild.jump(600)
    live_death(guild, "Alice", "Other-Stormrage")
    guild.jump(600)
    live_kill(guild, "Alice", "Vex")
    p = bob.ns.PlayerProfile("Alice")
    assert (p.kills, p.monthKills, p.deaths) == (4, 4, 3)
    assert (p.favorite, p.favoriteCount) == ("Grim", 2) or (p.favorite, p.favoriteCount) == ("Vex", 2)
    assert (p.nemesis, p.nemesisCount) == ("Ganker", 2)
    assert (p.streak, p.bestStreak) == (1, 3)


def test_empty_profile():
    guild = Guild(MEMBERS)
    p = guild["Bob"].ns.PlayerProfile("Mira")
    assert p.member.classFile == "PRIEST"
    assert (p.kills, p.deaths, p.streak, p.bestStreak, p.itemsWon) == (0, 0, 0, 0, 0)
    assert p.nemesis is None


def test_card_shows_and_fits(tmp_path):
    guild, me = demo_guild()
    me.ns.ShowPlayerCard("Lyra")
    card = me.lua.eval("WarcrestPlayerCard")
    assert card.IsShown(card)
    rd = Renderer(me)
    rd.render(card, str(tmp_path / "card.png"))
    text = " ".join(str(fs["_GetText"] or "") for fs in walk_text(rd, card))
    assert "Lyra" in text and "Nemesis: " in text and "Ganker" in text
    found = []
    sticking_out(rd, card, rd.rect(card), found)
    assert not found, found
    assert not me.errors()


def test_clicking_a_roster_name_opens_the_card():
    guild, me = demo_guild()
    me.run('SlashCmdList.WARCREST("card Mira")')
    card = me.lua.eval("WarcrestPlayerCard")
    assert card.IsShown(card)
    assert "Mira" in card.name.GetText(card.name)
    assert not me.errors()


def test_clicking_names_on_tabs_opens_the_card():
    guild, me = demo_guild()
    rd = Renderer(me)
    card = lambda: me.lua.eval("WarcrestPlayerCard")
    for tab, name in (("kills", "Lyra"), ("dkp", "Mira"), ("raids", "Brakk")):
        me.ns.OpenPanel(tab)
        me.ns.RefreshPanel()
        panel = me.lua.eval("WarcrestPanel")
        hits = [fs for fs in walk_text(rd, panel) if fs["_GetText"] == name and fs["_parent"]["script_OnClick"]]
        assert hits, tab
        row = hits[0]["_parent"]
        row["script_OnClick"](row, "LeftButton")
        assert card().IsShown(card()), tab
        assert card().name.GetText(card().name) == name, tab
        card().Hide(card())
    assert not me.errors()
