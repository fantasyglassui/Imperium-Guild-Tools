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
