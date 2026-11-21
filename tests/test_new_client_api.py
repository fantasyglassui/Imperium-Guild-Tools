"""Newer game clients (WoW: Forever) have no global GetItemInfo or GetSpellInfo:
only C_Item.GetItemInfo and C_Spell.GetSpellInfo, which returns a table."""
from harness import Guild
from test_members import gear

M = [("Alice", 1), ("Bob", 3, "PRIEST"), ("Cara", 3)]


def newer_client(c):
    c.run('C_Item.GetItemInfo = C_Item.GetItemInfo or GetItemInfo; GetItemInfo = nil '
          'local names = spellNames '
          'C_Spell.GetSpellInfo = function(id) if names[id] then return { name = names[id], spellID = id } end end '
          'GetSpellInfo = nil')


def test_profile_editor_and_item_level_work_without_the_old_globals():
    guild = Guild(M)
    bob = guild["Bob"]
    newer_client(bob)
    gear(bob, 60)
    assert bob.ns.MyItemLevel() == 60
    bob.ns.ShowProfileEditor()
    assert bob.lua.eval("WarcrestProfile:IsShown()")
    assert "60" in bob.lua.eval("WarcrestProfile").ilvl.GetText(bob.lua.eval("WarcrestProfile").ilvl)


def test_crafters_work_without_the_old_globals():
    guild = Guild(M)
    cara = guild["Cara"]
    newer_client(cara)
    cara.run('itemNames[13858] = "Runecloth Robe"; spellNames[20025] = "Enchant Chest - Greater Stats"')
    assert cara.ns.RecipeName("13858") == "Runecloth Robe"
    assert cara.ns.RecipeName("e20025") == "Enchant Chest - Greater Stats"
    assert "Runecloth Robe" in cara.ns.RecipeLink("13858")
    cara.ns.ShowCrafters("robe")
    assert tuple(cara.ns.PanelSection()) == ("guild", "crafters")
