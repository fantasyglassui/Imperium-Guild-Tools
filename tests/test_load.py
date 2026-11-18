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


def test_panel_remembers_last_tab_and_tooltips_work():
    guild = Guild([("Alice", 1), ("Bob", 3)])
    alice = guild["Alice"]
    alice.ns.OpenPanel("dkp")
    assert alice.ns.db.lastTab == "dkp"
    alice.ns.OpenPanel("kills")
    assert alice.ns.db.lastTab == "kills"

    # Hover every control in every tab: no tooltip may raise an error.
    for tab in ("roster", "raids", "dkp", "kills", "wanted", "settings", "officers", "addon"):
        alice.ns.OpenPanel(tab)
    hovered = alice.run("""
      local n = 0
      for _, f in ipairs(frames) do
        local enter = rawget(f, "script_OnEnter")
        if enter and rawget(f, "hasTooltip") then enter(f); n = n + 1 end
      end
      return n
    """)
    assert hovered >= 30, hovered
    assert alice.errors() == []
