"""The new layout: Home, the side menu's sections and the views along the top."""
from harness import Guild
from render import Renderer
from test_render import walk_text

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def ready(**kw):
    guild = Guild(MEMBERS, raid=["Alice", "Bob"], **kw)
    for c in guild.clients.values():
        c.ns.db.welcomed = True
        c.login()
    guild.run(15)
    return guild


def shown(c, expr):
    return c.lua.eval("function(ns) local f = %s; return f ~= nil and f:IsShown() end" % expr)(c.ns)


def nav(c):
    return list(c.lua.eval("""function(ns)
      local out = {}
      for _, b in ipairs(WarcrestPanel.navButtons) do if b:IsShown() then out[#out + 1] = b.section.id end end
      return out end""")(c.ns).values())


def test_opens_on_home_for_new_players():
    guild = ready()
    bob = guild["Bob"]
    bob.ns.OpenPanel()
    assert bob.ns.PanelSection() == ("home", "home")
    panel = bob.lua.eval("WarcrestPanel")
    assert "Bob" in panel.heading.GetText(panel.heading)
    assert not bob.errors()


def test_members_and_officers_see_their_sections():
    guild = ready()
    guild["Bob"].ns.OpenPanel("home")
    guild["Alice"].ns.OpenPanel("home")
    assert nav(guild["Bob"]) == ["home", "guild", "events", "raids", "loot", "pvp", "achievements"]
    assert nav(guild["Alice"])[-1] == "officers"


def test_old_tab_names_open_the_right_section_and_view():
    guild = ready()
    a = guild["Alice"].ns
    for tab, view, want in [("dkp", "loot", ("loot", "dkp")), ("wishlist", None, ("loot", "wishlist")),
                            ("kills", None, ("pvp", "kills")), ("wanted", "guilds", ("pvp", "wanted")),
                            ("calendar", None, ("events", "calendar")), ("events", "polls", ("events", "events")),
                            ("recruit", None, ("officers", "recruit")), ("addon", None, ("guild", "addon")),
                            ("raids", "progress", ("raids", "raids")), ("settings", "access", ("settings", "settings"))]:
        a.OpenPanel(tab, view)
        assert a.PanelSection() == want, (tab, view)
    a.OpenPanel("wanted", "guilds")
    tab = guild["Alice"].lua.eval('function(UI) for _, t in ipairs(UI.tabs) do if t.id == "wanted" then return t end end end')(a.UI)
    assert tab.view.value == "guilds" and not tab.view.IsShown(tab.view)   # the section's switch replaces it
    assert guild["Alice"].ns.db.lastSection == "pvp"


def test_reopens_where_you_left_off():
    guild = ready()
    a = guild["Alice"]
    a.ns.OpenPanel("dkp", "changes")
    assert a.ns.db.lastSection == "loot" and a.ns.db.lastItem == 3


def test_home_cards():
    guild = ready()
    alice, bob = guild["Alice"], guild["Bob"]
    ev = alice.ns.CreateRaid("Molten Core", alice.lua.eval("time()") + 3600, "")
    guild.run(3)
    bob.ns.SignUp(ev.id, "accept", "healer")
    alice.ns.StartPoll("Which night?", alice.lua.table_from(["Wed", "Sat"]), 3)
    guild.run(3)
    bob.ns.OpenPanel("home")
    rd = Renderer(bob)
    texts = "\n".join(str(fs["_GetText"] or "") for fs in walk_text(rd, bob.lua.eval("WarcrestPanel")))
    assert "Molten Core" in texts and "Healer" in texts
    assert "Which night?" in texts
    assert "Next step" in texts                       # Getting started isn't finished
    assert not bob.errors()
