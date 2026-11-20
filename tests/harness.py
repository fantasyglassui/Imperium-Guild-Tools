"""
Runs the addon outside the game: each simulated player gets their own Lua 5.1
(the version WoW uses) with a stand-in for the WoW API (tests/wow.lua), loads
the addon's files in TOC order, and exchanges addon messages with the others.

    guild = Guild(members=[("Alice", 1), ("Bob", 3, "PRIEST")])  # name, rank (0 = GM)[, class[, level]]
    alice = guild["Alice"]
    alice.ns.AwardDKP(alice.table(["Bob"]), 10, "Bonus")
    guild.run(5)                                          # let 5 seconds pass
    assert guild["Bob"].ns.Balance("Bob") == 10
"""
import os
import re
from lupa.lua51 import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STUB = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wow.lua")).read()

# 2027-01-15 08:00 UTC: comfortably after the addon's release cutoff.
START = 1800000000


def addon_files():
    """The addon's Lua files and version, in the order the TOC loads them."""
    files, version = [], None
    for line in open(os.path.join(ROOT, "Warcrest.toc")):
        line = line.strip()
        m = re.match(r"## Version:\s*(\S+)", line)
        if m:
            version = m.group(1)
        if line and not line.startswith("#") and line.endswith(".lua"):
            files.append(line.replace("\\", "/"))
    return files, version


FILES, VERSION = addon_files()
SOURCES = {f: open(os.path.join(ROOT, f)).read() for f in FILES}


class Client:
    """One player running the addon."""

    def __init__(self, guild, name, setup=None):
        self.guild, self.name, self.online = guild, name, True
        self.in_raid = False
        L = self.lua = LuaRuntime(unpack_returned_tuples=True)
        g = L.globals()
        g.now_py = lambda: guild.clock
        g.send_py = lambda prefix, text, channel, target: guild._send(self, prefix, text, channel, target)
        g.PLAYER = name
        g.ADDON_VERSION = VERSION
        L.execute(STUB)
        self.set_roster()
        if setup:
            setup(self)          # e.g. saved data from before, as the game would load it
        self.ns = L.eval("{}")
        load = L.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
        for f in FILES:
            # The same as the game: each file gets the addon's name and its shared table.
            load(SOURCES[f], f)("Warcrest", self.ns)
        self.fire("ADDON_LOADED", "Warcrest")

    # --- helpers -----------------------------------------------------------
    def set_roster(self):
        rows = ",".join('{"%s", %d, %s, "%s", %d}' % (n, r, "true" if on else "false", cls, lvl)
                        for n, r, on, cls, lvl in self.guild.roster())
        self.lua.execute("guildRoster = { %s }" % rows)
        ns = getattr(self, "ns", None)
        if ns is not None and ns.RosterChanged:
            ns.RosterChanged()        # as GUILD_ROSTER_UPDATE would in the game

    def set_raid(self, names):
        self.lua.execute("raidMembers = { %s }" % ",".join('"%s"' % n for n in names))

    def fire(self, event, *args):
        self.lua.globals().fire(event, *args)

    def run(self, code):
        return self.lua.execute(code)

    def table(self, value):
        """A Python list or dict as a Lua table."""
        return self.lua.table_from(value) if not isinstance(value, dict) else self.lua.table_from(value)

    def said(self, contains=None, clear=True):
        """Chat lines the addon printed (optionally only those containing a word)."""
        lines = [str(x) for x in self.lua.eval("printed").values()]
        if clear:
            self.lua.execute("printed = {}")
        if contains:
            lines = [x for x in lines if contains in x]
        return [re.sub(r"\|c[0-9a-fA-F]{8}|\|r|\|T.*?\|t ?", "", x) for x in lines]

    def errors(self):
        errs = self.ns.loadErrors
        return [errs[i] for i in range(1, len(errs) + 1)] if errs else []

    def login(self):
        """Simulate logging in (runs the addon's login catch-up)."""
        self.online = True
        self.fire("PLAYER_ENTERING_WORLD", True, False)


class Guild:
    """Several players, the messages between them, and a shared clock."""

    def __init__(self, members, raid=(), start=START, throttle=False, setup=None, echo=False, realm_space=None):
        self.echo = echo  # True: the game sends your own guild/raid messages back to you (retail does)
        # True: like WoW: Forever, senders come as "Name Realm", and a whisper to a
        # name with a space in it doesn't arrive ("No player named ...").
        if realm_space is None:
            realm_space = os.environ.get("WARCREST_REALM_SPACE") == "1"
        self.realm_space = realm_space
        self.bad_whispers = 0
        self.clock = float(start)
        # (name, guild rank[, class[, level]])
        self.members = [(m[0], m[1], True, m[2] if len(m) > 2 else "WARRIOR", m[3] if len(m) > 3 else 60)
                        for m in members]
        self.raid = list(raid)
        self.throttle = throttle
        self.outbox = []
        self.sent = []          # every message delivered: (sender, prefix, channel, text)
        self.refused = 0        # messages the simulated game refused for being too fast
        self._allowance = {}
        self.clients = {}
        for m in members:
            self.clients[m[0]] = Client(self, m[0], setup)
        self.set_raid(self.raid)

    def __getitem__(self, name):
        return self.clients[name]

    def roster(self):
        return [(n, r, self.clients[n].online if n in self.clients else on, cls, lvl)
                for n, r, on, cls, lvl in self.members]

    def set_raid(self, names):
        self.raid = list(names)
        for c in self.clients.values():
            c.in_raid = c.name in self.raid
            c.set_raid(self.raid if c.in_raid else [])

    def set_online(self, name, online):
        self.clients[name].online = online
        for c in self.clients.values():
            c.set_roster()

    # --- messages ------------------------------------------------------------
    def _send(self, client, prefix, text, channel, target):
        if self.throttle:
            # The game's limit: about 10 messages per prefix, refilling 1 per second.
            key = (client.name, prefix)
            have, last = self._allowance.get(key, (10.0, self.clock))
            have = min(10.0, have + (self.clock - last))
            if have < 1:
                self._allowance[key] = (have, self.clock)
                self.refused += 1
                return 3  # Enum.SendAddonMessageResult.AddonMessageThrottle
            self._allowance[key] = (have - 1, self.clock)
        self.outbox.append((client.name, prefix, text, channel, target))
        return 0

    def _deliver(self):
        while self.outbox:
            who, prefix, text, channel, target = self.outbox.pop(0)
            self.sent.append((who, prefix, channel, text))
            for c in self.clients.values():
                if not c.online:
                    continue
                if c.name == who and channel in ("GUILD", "RAID"):
                    # Like WoW Forever: your own guild and raid messages don't come back to you.
                    ok = self.echo
                elif channel == "GUILD":
                    ok = True
                elif channel == "RAID":
                    ok = c.in_raid and self.clients[who].in_raid
                elif channel == "WHISPER":
                    if target is not None and " " in target:
                        if c.name == who:
                            self.bad_whispers += 1
                        ok = False
                    else:
                        ok = target is not None and target.split("-")[0] == c.name and c.name != who
                else:
                    ok = False
                if ok:
                    c.fire("CHAT_MSG_ADDON", prefix, text, channel, who + (" Realm" if self.realm_space else "-Realm"))

    def run(self, seconds, step=0.1):
        """Let time pass: timers run and messages are delivered as it goes."""
        for _ in range(max(1, int(round(seconds / step)))):
            self.clock += step
            for c in self.clients.values():
                if c.online:
                    c.lua.globals().RunDue()
            self._deliver()

    def jump(self, seconds):
        """Move the clock forward at once (nothing runs in between)."""
        self.clock += seconds
