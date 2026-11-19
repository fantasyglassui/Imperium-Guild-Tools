"""Alert sounds: a sound for each kind of alert, picked from Warcrest's own,
the game's, SharedMedia's or your own files, on the channel you choose."""
from harness import Guild

FOLDER = "Interface\\AddOns\\WarcrestSounds\\"


def played(c):
    out = [(s[1], s[2], s[3]) for s in c.lua.eval("soundsPlayed").values()]
    c.run("soundsPlayed = {}")
    return out


def one():
    guild = Guild([("Thorne", 1)])
    c = guild["Thorne"]
    played(c)
    return guild, c


def test_each_kind_has_its_own_sound():
    guild, c = one()
    c.ns.Notify("x", None, None, True, "kill")
    c.ns.Notify("x", None, None, True, "wanted")
    files = [p for kind, p, ch in played(c) if kind == "file"]
    assert files == ["Interface\\AddOns\\Warcrest\\Media\\Sounds\\SwordClash.ogg",
                     "Interface\\AddOns\\Warcrest\\Media\\Sounds\\LowGrowl.ogg"]


def test_pick_a_game_sound_and_a_channel():
    guild, c = one()
    c.ns.SetAlertSound("kill", "kit:READY_CHECK")
    c.ns.db.soundChannel = "SFX"
    c.ns.Notify("x", None, None, True, "kill")
    assert played(c) == [("kit", 8960, "SFX")]
    # Game sounds this client doesn't have aren't offered.
    ids = [s.id for s in c.ns.SoundLibrary().values()]
    assert "kit:READY_CHECK" in ids and "kit:UI_EPICLOOT_TOAST" not in ids
    assert len([i for i in ids if i.startswith("wc:")]) >= 35


def test_no_sound_and_sounds_off():
    guild, c = one()
    c.ns.SetAlertSound("kill", "none")
    c.ns.Notify("x", None, None, True, "kill")
    assert played(c) == []
    c.ns.SetAlertSound("kill", "wc:Gong")
    c.ns.db.sound = False
    c.ns.Notify("x", None, None, True, "kill")
    assert played(c) == []


def test_your_own_sounds():
    guild, c = one()
    c.run('MISSING_SOUNDS["%smissing.ogg"] = true' % FOLDER.replace("\\", "\\\\"))
    assert not c.ns.AddCustomSound("missing.ogg")
    assert c.said("Couldn't play missing.ogg")
    assert not c.ns.AddCustomSound("song.wav")              # only .ogg and .mp3
    assert c.ns.AddCustomSound("horn.ogg")
    assert c.ns.SoundByID("custom:horn.ogg").name == "horn"
    played(c)
    c.ns.SetAlertSound("raid", "custom:horn.ogg")
    c.ns.Notify("x", None, None, True, "raid")
    assert played(c) == [("file", FOLDER + "horn.ogg", "Master")]
    # Removing it puts that alert back to its own sound.
    c.ns.RemoveCustomSound("horn.ogg")
    assert c.ns.AlertSound("raid") == "wc:WarHorn"


def test_a_missing_file_falls_back_to_the_default():
    guild, c = one()
    assert c.ns.AddCustomSound("horn.ogg")
    c.ns.SetAlertSound("kill", "custom:horn.ogg")
    c.run('MISSING_SOUNDS["%shorn.ogg"] = true' % FOLDER.replace("\\", "\\\\"))   # deleted since
    played(c)
    c.ns.Notify("x", None, None, True, "kill")
    assert [p for _, p, _ in played(c)] == ["Interface\\AddOns\\Warcrest\\Media\\Sounds\\SwordClash.ogg"]


def test_sharedmedia_sounds_are_offered():
    guild, c = one()
    c.run("""
      local lsm = { sounds = { ["Air Horn"] = "Interface\\\\AddOns\\\\SharedMedia\\\\airhorn.ogg", ["None"] = "Interface\\\\Quiet.ogg" } }
      function lsm:List() local t = {} for k in pairs(self.sounds) do t[#t + 1] = k end return t end
      function lsm:Fetch(_, name) return self.sounds[name] end
      function LibStub(name) if name == "LibSharedMedia-3.0" then return lsm end end
    """)
    c.ns.RefreshSoundLibrary()
    s = c.ns.SoundByID("lsm:Air Horn")
    assert s and s.group == "SharedMedia"
    assert c.ns.SoundByID("lsm:None") is None


def test_settings_view_and_picker():
    guild, c = one()
    c.ns.OpenPanel("settings", "sounds")
    c.ns.ShowSoundPicker("kill")
    assert c.lua.eval("WarcrestSoundPicker:IsShown()")
    assert not c.errors()
