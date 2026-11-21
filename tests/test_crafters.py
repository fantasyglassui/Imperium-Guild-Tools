"""The crafters directory: recipes noted from profession windows, shared with
the guild, searched, and a whisper to the crafter."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]

TAILOR = ('{ name = "Tailoring", rank = 280, max = 300, recipes = {'
          '{ "Cloth", "header" },'
          '{ "Mooncloth Bag", "optimal", "|cff1eff00|Hitem:14155::::::::60:::::|h[Mooncloth Bag]|h|r" },'
          '{ "Runecloth Robe", "medium", "|cff1eff00|Hitem:13858::::::::60:::::|h[Runecloth Robe]|h|r" } } }')
ENCHANT = ('{ name = "Enchanting", rank = 300, max = 300, recipes = {'
           '{ "Enchant Weapon - Crusader", "optimal", "|cffffffff|Henchant:20034|h[Enchant Weapon - Crusader]|h|r" } } }')


def search(c, query, prof=None):
    return c.ns.CraftSearch(query, prof)[0]


def open_window(c, table, event):
    if c.guild.forever:
        # WoW: Forever has one profession window for everything, enchanting too.
        table = table.replace("craftSkill", "tradeSkill")
        event = "TRADE_SKILL_SHOW"
    c.run(table)
    c.fire(event)
    c.guild.run(2)


def test_recipes_are_shared_and_searchable():
    guild = Guild(M)
    bob = guild["Bob"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    open_window(bob, "craftSkill = " + ENCHANT, "CRAFT_SHOW")
    guild.run(35)                                   # sent after a short wait
    cara = guild["Cara"]
    cara.run('itemNames[14155] = "Mooncloth Bag"; itemNames[13858] = "Runecloth Robe"')
    found = search(cara, "moon")
    assert len(found) == 1
    assert found[1].name == "Mooncloth Bag" and found[1].crafters[1].name == "Bob"
    profs = list(cara.ns.CraftProfessions().values())
    assert profs == ["Enchanting", "Tailoring"]
    # Bob's own names came with the window; Cara needs the game to know the names.
    assert search(bob, "crusader")[1].id == "e20034"
    assert all(c.errors() == [] for c in guild.clients.values())


def test_a_new_recipe_sends_an_update_and_nothing_is_lost():
    guild = Guild(M)
    bob = guild["Bob"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    # The window collapsed to one recipe: the others are still known.
    bob.run('tradeSkill.recipes = { tradeSkill.recipes[2] }')
    bob.fire("TRADE_SKILL_LIST_UPDATE" if guild.forever else "TRADE_SKILL_UPDATE")
    guild.run(35)
    assert len(search(guild["Cara"], "", "Tailoring")) == 2
    bob.run('table.insert(tradeSkill.recipes, { "Felcloth Bag", "optimal", "|Hitem:14156|h[Felcloth Bag]|h" })')
    bob.fire("TRADE_SKILL_LIST_UPDATE" if guild.forever else "TRADE_SKILL_UPDATE")
    guild.run(35)
    assert len(search(guild["Cara"], "", "Tailoring")) == 3


def test_lists_only_come_from_the_crafter():
    guild = Guild(M)
    cara = guild["Cara"]
    # Alice tries to send a list in Bob's name.
    cara.ns.HandleAddonMessage("TheImperium", "CR^Bob^Alchemy^300^300^5^1^1^13442", "GUILD", "Alice-Realm")
    assert len(cara.ns.CraftProfessions()) == 0


def test_logging_in_asks_for_lists():
    guild = Guild(M)
    bob = guild["Bob"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    alice = guild["Alice"]
    for k in list(alice.ns.db.crafters.keys()):
        alice.ns.db.crafters[k] = None
    alice.ns.Send("CQ")
    guild.run(5)
    assert len(search(alice, "", "Tailoring")) == 2


def test_the_window_and_whispers():
    guild = Guild(M)
    bob = guild["Bob"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    cara = guild["Cara"]
    cara.run('itemNames[13858] = "Runecloth Robe"')
    cara.ns.ShowCrafters("robe")
    assert cara.errors() == []
    cara.ns.AskCrafter("Bob", "13858")
    opened = list(cara.lua.eval("openedChat").values())
    assert opened and opened[0].split(" ", 2)[1].split("-")[0] == "Bob" and "Hi! Could you craft" in opened[0] and "Runecloth Robe" in opened[0]


def test_crafters_and_profiles_are_guild_views():
    guild = Guild(M)
    bob = guild["Bob"]
    open_window(bob, "tradeSkill = " + TAILOR, "TRADE_SKILL_SHOW")
    guild.run(35)
    cara = guild["Cara"]
    cara.ns.ShowCrafters("moon")
    assert tuple(cara.ns.PanelSection()) == ("guild", "crafters")
    cara.ns.ShowCrafters(None, "orders")
    assert tuple(cara.ns.PanelSection()) == ("guild", "crafters")
    cara.ns.ShowProfiles()
    assert tuple(cara.ns.PanelSection()) == ("guild", "profiles")
    cara.ns.OpenPanel("roster")
    cara.ns.RefreshCrafters()      # not showing: does nothing
    cara.ns.RefreshProfiles()
    assert cara.errors() == []
