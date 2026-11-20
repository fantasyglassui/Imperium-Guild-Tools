"""The war board: enemy guilds learned from what guildmates see, kills and
deaths tallied by guild, rivals marked by officers, and rival sightings."""
from harness import Guild

M = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def kill(client, victim, guild, level=58):
    client.run('units.target = { name = "%s", player = true, hostile = true, level = %d, guild = "%s" }'
               % (victim, level, guild))
    client.guild.run(1.5)        # the scanner sees their guild on the target
    client.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
    client.run('units.target.dead = true')
    client.fire("CHAT_MSG_COMBAT_HONOR_GAIN", "%s dies, honorable kill Rank: Private (10 Honor Points)" % victim)
    client.guild.run(6)
    client.run('units.target = nil')


def died_to(guild, who, killer, killer_guild):
    """The death message a guildmate sends, with the killer's guild (3.7)."""
    t = int(guild.clock)
    text = "D2^pvp^world^STV^%s^60^^^^%d^%s" % (killer, t, killer_guild)
    for c in guild.clients.values():
        c.ns.HandleAddonMessage("TheImperium", text, "GUILD", who + "-Realm")
    guild.run(1)


def test_kills_and_deaths_are_tallied_by_enemy_guild():
    guild = Guild(M)
    bob, cara = guild["Bob"], guild["Cara"]
    kill(bob, "Grim", "Bloodfang")
    kill(bob, "Thrak", "Bloodfang")
    kill(cara, "Zul", "Shadow Pact")
    # Guildmates learn the guilds from the reports, without seeing them.
    assert guild["Alice"].ns.EnemyGuild("Grim") == "Bloodfang"
    war = guild["Alice"].ns.GuildWar()
    rows = {war[i].guild: (war[i].kills, war[i].deaths) for i in range(1, len(war) + 1)}
    assert rows["Bloodfang"] == (2, 0) and rows["Shadow Pact"] == (1, 0)
    assert all(c.errors() == [] for c in guild.clients.values())


def test_officers_mark_rivals_and_they_come_first():
    guild = Guild(M)
    kill(guild["Bob"], "Grim", "Bloodfang")
    kill(guild["Bob"], "Zul", "Shadow Pact")
    kill(guild["Bob"], "Zed", "Shadow Pact")
    assert guild["Bob"].ns.SetRival("Bloodfang", True) is None        # members can't
    assert guild["Alice"].ns.SetRival("Bloodfang", True)
    guild.run(2)
    war = guild["Cara"].ns.GuildWar()
    assert war[1].guild == "Bloodfang" and war[1].rival
    assert guild["Alice"].ns.SetRival("Iron Horde", True)              # before anyone met them
    guild.run(2)
    names = [r.guild for r in guild["Cara"].ns.GuildWar().values()]
    assert "Iron Horde" in names


def test_a_group_of_rivals_is_reported_to_the_guild():
    guild = Guild(M)
    guild["Alice"].ns.SetRival("Bloodfang", True)
    guild.run(2)
    bob = guild["Bob"]
    plates = ", ".join('["nameplate%d"] = { name = "Orc%d", player = true, hostile = true, guild = "Bloodfang" }' % (i, i)
                       for i in range(1, 5))
    bob.run('units = { %s }' % plates)
    bob.run('C_NamePlate = { GetNamePlates = function() local t = {} for i = 1, 4 do '
            't[i] = { namePlateUnitToken = "nameplate" .. i } end return t end }')
    guild.run(3)
    assert guild["Cara"].said("Rival guild <Bloodfang> spotted: 4 players")
    guild.run(60)
    assert guild["Cara"].said("Rival guild") == []                     # not again straight away


def test_the_weekly_recap_says_how_the_war_went():
    guild = Guild(M)
    guild["Alice"].ns.SetRival("Bloodfang", True)
    guild.run(2)
    kill(guild["Bob"], "Grim", "Bloodfang")
    kill(guild["Bob"], "Thrak", "Bloodfang")
    lines = guild["Alice"].ns.WarRecapLines(0, 2 ** 31)
    assert lines[1] == "War with <Bloodfang>: we killed 2, they killed 0 (won)."


def test_deaths_count_against_the_killers_guild():
    guild = Guild(M)
    died_to(guild, "Bob", "Grim", "Bloodfang")
    d = guild["Alice"].ns.db.deathLog
    assert d[1].killer == "Grim"
    war = guild["Alice"].ns.GuildWar()
    assert (war[1].guild, war[1].deaths) == ("Bloodfang", 1)
