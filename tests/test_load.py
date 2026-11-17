"""The addon loads cleanly and every tab of the guild panel can be built and refreshed."""
from harness import Guild


def test_loads_without_errors():
    guild = Guild([("Gm", 0), ("Alice", 1), ("Bob", 3)])
    guild["Bob"].login()
    guild.run(15)
    for c in guild.clients.values():
        assert c.errors() == []
    assert any("loaded" in line for line in guild["Bob"].said())


def test_every_tab_builds_and_refreshes():
    # Officers see every tab, so open the panel as one.
    guild = Guild([("Alice", 1), ("Bob", 3)])
    alice = guild["Alice"]
    for tab in ("roster", "raids", "dkp", "kills", "wanted", "settings", "officers", "addon"):
        alice.ns.OpenPanel(tab)
        alice.ns.RefreshPanel()
        guild.run(1)
    assert alice.errors() == []
