"""Each guild's look: The Imperium keeps its own, every other guild gets Warcrest's."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3)]


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
