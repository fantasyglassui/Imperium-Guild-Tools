"""Some game clients write a player's realm after a space ("Name Realm")."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def test_a_solo_kill_has_no_assist_when_the_realm_comes_after_a_space():
    guild = Guild(M)
    t = int(guild.clock)
    text = "K^kill_world^Enemy^STV^%d^0.5^58^1" % t
    for c in guild.clients.values():
        if c.name == "Bob":
            c.ns.HandleAddonMessage("TheImperium", text, "GUILD", "Bob-Realm")      # handled as it's sent
            c.fire("CHAT_MSG_ADDON", "TheImperium", text, "GUILD", "Bob Wraithblade")  # and the game's copy
        else:
            c.fire("CHAT_MSG_ADDON", "TheImperium", text, "GUILD", "Bob Wraithblade")
    guild.run(5)
    for c in guild.clients.values():
        k = c.ns.db.killLog[1]
        assert list(k.killers.values()) == ["Bob"], c.name
    assert not guild["Cara"].said("assist")


def test_stored_kills_are_tidied():
    guild = Guild(M)
    a = guild["Alice"]
    k = a.lua.eval('{ t = 100, kind = "kill_world", victim = "Enemy", zone = "STV", killers = { "Bob", "Bob Wraithblade" },'
                   ' gaps = { Bob = 2, ["Bob Wraithblade"] = 0.5 } }')
    a.ns.TidyKillers(k)
    assert list(k.killers.values()) == ["Bob"]
    assert k.gaps["Bob"] == 0.5
    assert a.ns.Ambiguate("Bob Wraithblade", "short") == "Bob"
    assert a.ns.Ambiguate("Bob (Wraithblade)", "short") == "Bob"
    assert a.ns.IsMe("Alice Wraithblade")


def test_whispers_go_to_a_name_the_server_knows():
    guild = Guild(M)
    a = guild["Alice"]
    assert a.ns.WhisperName("Bob Wraithblade") in ("Bob", "Bob-Realm")      # the roster's own name for Bob
    assert a.ns.WhisperName("Stranger Wraithblade") == "Stranger-Wraithblade"
    assert a.ns.WhisperName("Stranger (Argent Dawn)") == "Stranger-ArgentDawn"
    assert a.ns.WhisperName("Stranger-Realm") == "Stranger-Realm"


def test_no_whispers_to_guildmates_who_are_offline():
    guild = Guild(M)
    guild.set_online("Cara", False)
    a = guild["Alice"]
    assert a.ns.WhisperName("Cara") is None
    assert a.ns.WhisperName("Bob") is not None
