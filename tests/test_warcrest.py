"""The rename to Warcrest: data handed over from The Imperium, and each guild's look."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3)]


def old_install(handover):
    def setup(client):
        client.run('''
          TheImperiumDB = { minimap = { hide = true }, releaseReset = "2.1.0",
                            killLog = { { t = 1800000000 - 60, victim = "Grim", killers = { "Alice" }, zone = "STV",
                                          kind = "kill_world", level = 60 } } }
        ''')
        if handover:
            client.run('OLD_ADDON_META = { ["X-Warcrest-Handover"] = "1" }')
    return setup


def test_data_from_the_imperium_is_handed_over_once():
    guild = Guild(MEMBERS, setup=old_install(True))
    bob = guild["Bob"]
    db = bob.lua.eval("WarcrestDB")
    assert db.minimap.hide
    assert len(bob.ns.db.killLog) == 1
    assert not bob.ns.isNewInstall
    old = bob.lua.eval("TheImperiumDB")
    assert old.movedToWarcrest and old.killLog is None      # the old file is emptied


def test_an_old_full_copy_keeps_its_data():
    # Someone still has the old The Imperium folder (not the hand-over one): don't empty it.
    guild = Guild(MEMBERS, setup=old_install(False))
    bob = guild["Bob"]
    assert len(bob.ns.db.killLog) == 1
    assert bob.lua.eval("TheImperiumDB").killLog is not None


def test_each_guild_gets_its_look():
    imperium = Guild(MEMBERS)
    ns = imperium["Bob"].ns
    imperium["Bob"].fire("GUILD_ROSTER_UPDATE")
    assert ns.BRAND == "The Imperium" and "Imperium\\Portrait" in ns.PORTRAIT
    other = Guild(MEMBERS, setup=lambda c: c.run('GUILD_NAME = "Night Watch"'))
    o = other["Bob"]
    o.fire("GUILD_ROSTER_UPDATE")
    assert o.ns.BRAND == "Warcrest" and o.ns.PORTRAIT.endswith("Media\\Portrait")
    o.ns.OpenPanel("roster")
    panel = o.lua.eval("WarcrestPanel")
    assert panel.brand.GetText(panel.brand) == "Warcrest"
    assert panel.brandSub.GetText(panel.brandSub) == "Night Watch"
    o.ns.Say("hello")
    assert o.said("[Warcrest]")
    assert not o.errors()


def test_history_saved_as_bannerhold_is_added_back():
    # For a short while the addon was called Bannerhold. That history (and an
    # emptied The Imperium file) is found and added to Warcrest's, once.
    def setup(client):
        client.run('''
          TheImperiumDB = { movedToBannerhold = 1799990000 }
          WarcrestDB = { releaseReset = "2.1.0", killLog = { { t = 1800000000 - 30, victim = "New", killers = { "Bob" },
                         zone = "STV", kind = "kill_world", level = 60 } } }
          BannerholdDB = { releaseReset = "2.1.0", minimap = { hide = true },
                           achievements = { bob = { kill1 = 1799999000 } },
                           killLog = { { t = 1800000000 - 60, victim = "Grim", killers = { "Bob" }, zone = "STV",
                                         kind = "kill_world", level = 60 },
                                       { t = 1800000000 - 30, victim = "New", killers = { "Bob" }, zone = "STV",
                                         kind = "kill_world", level = 60 } } }
          OLD_ADDON_META = { ["X-Warcrest-Handover"] = "1" }
        ''')
    guild = Guild(MEMBERS, setup=setup)
    bob = guild["Bob"]
    guild.run(15)
    log = bob.ns.db.killLog
    assert sorted(log[i].victim for i in range(1, len(log) + 1)) == ["Grim", "New"]
    assert bob.ns.db.minimap.hide
    assert bob.ns.MemberAchievements("Bob")["kill1"]["t"]
    assert bob.lua.eval("BannerholdDB").movedToWarcrest and bob.lua.eval("BannerholdDB").killLog is None
    assert bob.said("older name")
    assert bob.errors() == []
