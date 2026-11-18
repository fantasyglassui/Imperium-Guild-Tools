"""New guilds: the welcome and guild setup, DKP on or off, and the help window."""
from harness import Guild

MEMBERS = [("Alice", 0), ("Bob", 3)]   # Alice is the Guild Master


def ready(guild):
    for c in guild.clients.values():
        c.login()
    guild.run(15)


def shown(client, frame):
    f = client.lua.eval(frame)
    return f is not None and f.IsShown(f)


def test_welcome_shows_once_for_a_new_install():
    guild = Guild(MEMBERS)
    ready(guild)
    assert shown(guild["Bob"], "WarcrestWelcome")
    assert guild["Bob"].ns.db.welcomed
    assert not guild["Bob"].errors()


def test_no_welcome_for_players_who_already_had_it():
    guild = Guild(MEMBERS, setup=lambda c: c.run('WarcrestDB = { minimap = {} }'))
    for c in guild.clients.values():
        c.ns.cfg.stamp = 5                      # the guild was set up already
    ready(guild)
    assert not shown(guild["Bob"], "WarcrestWelcome")


def test_guild_without_dkp():
    guild = Guild(MEMBERS, raid=["Alice", "Bob"])
    ready(guild)
    alice, bob = guild["Alice"], guild["Bob"]
    types = alice.lua.table_from({})
    for k, v in alice.ns.cfg.types.items():
        types[k] = v
    assert alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1, "dkp": False}))
    guild.run(3)
    assert not bob.ns.UsesDKP()
    # The DKP tab is hidden; auctions are refused; raid nights give no DKP.
    bob.ns.OpenPanel("roster")
    tabs = list(bob.lua.eval("""function(UI)
      local out, panel = {}, WarcrestPanel
      for i, t in ipairs(UI.tabs) do if panel.navButtons[i]:IsShown() then out[#out + 1] = t.id end end
      return out end""")(bob.ns.UI).values())
    assert "dkp" not in tabs and "raids" in tabs
    alice.ns.StartAuction("|cffa335ee|Hitem:1:|h[Thing]|h|r", 5, 20)
    assert alice.said("DKP is turned off")
    alice.ns.StartRaidSession("", "Hyjal Summit", 10, 10, 15)
    guild.run(3)
    assert bob.ns.Balance("Bob") == 0
    assert alice.said("Attendance recorded")
    # Turned back on later.
    assert alice.ns.PushConfig(alice.lua.table_from({"enabled": True, "types": types, "officerRank": 1, "dkp": True}))
    guild.run(3)
    assert bob.ns.UsesDKP()


def test_help_window_every_topic():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    for i in range(1, 10):
        bob.ns.ShowHelp(i)
    bob.ns.ShowHelp("wishlists")
    bob.run('SlashCmdList.WARCREST("help")')
    assert shown(bob, "WarcrestHelp")
    assert not bob.errors()
