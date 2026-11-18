"""Every tab draws, and nothing on it sticks out past the edges of the panel."""
import os

import pytest

pytest.importorskip("PIL")
from render import Renderer, demo_guild  # noqa: E402

TABS = ("roster", "raids", "dkp", "kills", "wanted", "settings", "officers", "addon")


def sticking_out(rd, node, bounds, found, in_scroll=False):
    """Text and textures drawn outside bounds. Content in a scrolling area is
    clipped to that area, so it's allowed to run past."""
    for k in rd.kids(node):
        if not rd.visible(k) or not rd.region_shown(k):
            continue
        if k["kind"] in ("Texture", "FontString"):
            if in_scroll:
                continue
            l, t, r, b = rd.rect(k)
            if r - l <= 0 or b - t <= 0:
                continue
            if l < bounds[0] - 4 or t < bounds[1] - 4 or r > bounds[2] + 4 or b > bounds[3] + 4:
                found.append((k["kind"], k["_GetText"], (round(l), round(t), round(r), round(b))))
        else:
            lay = k["_layout"]
            scrolls = lay is not None and lay["scrollChild"] is not None
            sticking_out(rd, k, bounds, found, in_scroll or scrolls)


@pytest.mark.parametrize("tab", TABS)
def test_tab_fits_in_panel(tab, tmp_path):
    guild, me = demo_guild()
    me.ns.OpenPanel(tab)
    rd = Renderer(me)
    panel = me.lua.eval("TheImperiumPanel")
    rd.render(panel, os.path.join(tmp_path, tab + ".png"))
    found = []
    sticking_out(rd, panel, rd.rect(panel), found)
    assert found == [], found
    assert me.errors() == []


@pytest.mark.parametrize("tab", TABS)
def test_tab_fits_in_a_bigger_window(tab, tmp_path):
    guild, me = demo_guild()
    me.ns.db.panelWidth, me.ns.db.panelHeight = 1300, 760   # dragged bigger from the corner
    me.ns.OpenPanel(tab)
    rd = Renderer(me)
    panel = me.lua.eval("TheImperiumPanel")
    rd.render(panel, os.path.join(tmp_path, tab + "-big.png"))
    l, t, r, b = rd.rect(panel)
    assert (r - l, b - t) == (1300, 760)
    found = []
    sticking_out(rd, panel, (l, t, r, b), found)
    assert found == [], found
    assert me.errors() == []


def test_lists_grow_with_the_window():
    guild, me = demo_guild()
    me.ns.db.panelWidth, me.ns.db.panelHeight = 1300, 760
    me.ns.OpenPanel("officers")
    rd = Renderer(me)
    lists = [k for k in rd.kids(me.lua.eval("TheImperiumPanel")) if k["kind"] == "Frame"]
    # The officer log's list fills the extra room: 390 wider and 240 taller than normal.
    page_lists = []
    def walk(node):
        for k in rd.kids(node):
            if k["_template"] == "UIPanelScrollFrameTemplate" and rd.visible(k):
                page_lists.append(k)
            walk(k)
    for f in lists:
        walk(f)
    sizes = {(round(rd.rect(f)[2] - rd.rect(f)[0]), round(rd.rect(f)[3] - rd.rect(f)[1])) for f in page_lists}
    assert (640 + 390, 330 + 240) in sizes, sizes


def test_window_size_setting_scales_panel_and_windows():
    guild, me = demo_guild()
    me.ns.OpenPanel("roster")
    me.ns.ShowAltsWindow()
    me.ns.SetPanelScale(1.25)
    assert me.ns.db.panelScale == 1.25
    me.ns.SetPanelScale(5)      # kept within limits
    assert me.ns.db.panelScale == 1.5
    me.ns.ResetPanelSize()
    assert me.ns.db.panelScale == 1 and me.ns.db.panelWidth is None
