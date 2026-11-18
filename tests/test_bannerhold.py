"""The rename to Bannerhold: data handed over from The Imperium, and each guild's look."""
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
            client.run('OLD_ADDON_META = { ["X-Bannerhold-Handover"] = "1" }')
    return setup


def test_data_from_the_imperium_is_handed_over_once():
    guild = Guild(MEMBERS, setup=old_install(True))
    bob = guild["Bob"]
    db = bob.lua.eval("BannerholdDB")
    assert db.minimap.hide
    assert len(bob.ns.db.killLog) == 1
    assert not bob.ns.isNewInstall
    old = bob.lua.eval("TheImperiumDB")
    assert old.movedToBannerhold and old.killLog is None      # the old file is emptied


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
    assert o.ns.BRAND == "Bannerhold" and o.ns.PORTRAIT.endswith("Media\\Portrait")
    o.ns.OpenPanel("roster")
    panel = o.lua.eval("BannerholdPanel")
    assert panel.brand.GetText(panel.brand) == "Bannerhold"
    assert panel.brandSub.GetText(panel.brandSub) == "Night Watch"
    o.ns.Say("hello")
    assert o.said("[Bannerhold]")
    assert not o.errors()
