"""Every rank with officer chat counts as an officer, without the Guild Master
changing anything. The Guild Master can turn that off (and back on)."""
from harness import Guild

M = [("Gwen", 0), ("Alice", 1), ("Cara", 2), ("Dan", 3)]


def flags(guild, ranks):
    """Ranks (0 = Guild Master) that can read officer chat, as the game's guild control says."""
    for c in guild.clients.values():
        c.run("C_GuildInfo.GuildControlGetRankFlags = function(order) "
              "local on = ({ %s })[order - 1] return { true, true, on or false, on or false } end"
              % ", ".join("[%d] = true" % r for r in ranks))


def push(c, **features):
    types = c.lua.table_from({})
    for k, v in c.ns.cfg.types.items():
        types[k] = v
    cfg = {"enabled": True, "types": types, "officerRank": c.ns.cfg.officerRank}
    cfg.update(features)
    return c.ns.PushConfig(c.lua.table_from(cfg))


def test_ranks_with_officer_chat_are_officers():
    guild = Guild(M)
    flags(guild, [0, 1, 2])
    cara, dan = guild["Cara"], guild["Dan"]
    assert cara.ns.IsAddonOfficer() and not dan.ns.IsAddonOfficer()
    assert guild["Gwen"].ns.IsOfficerName("Cara")
    # What Cara does as an officer counts for everyone.
    cara.ns.SetRecruit("thrall", cara.lua.eval('{ class = "SHAMAN", level = 58 }'))
    guild.run(2)
    assert guild["Alice"].ns.Recruit("Thrall") is not None


def test_only_the_guild_master_turns_it_off():
    guild = Guild(M)
    flags(guild, [0, 1, 2])
    assert not push(guild["Alice"], chatOfficers=False)
    assert guild["Alice"].said("Only the Guild Master")
    assert push(guild["Gwen"], chatOfficers=False)
    guild.run(3)
    assert not guild["Cara"].ns.IsAddonOfficer()
    assert guild["Alice"].ns.IsAddonOfficer()            # rank 1: picked by rank
    assert push(guild["Gwen"], chatOfficers=True)
    guild.run(3)
    assert guild["Cara"].ns.IsAddonOfficer()


def test_without_the_game_saying_only_the_picked_ranks_count():
    guild = Guild(M)
    assert guild["Alice"].ns.IsAddonOfficer()
    assert not guild["Cara"].ns.IsAddonOfficer()
