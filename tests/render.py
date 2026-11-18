"""
Draws the addon's interface as a picture, from the layout the addon's own code
sets up in the test stand-in (tests/wow.lua). A developer tool for checking the
look without the game; it's an approximation (no game textures, scroll bars or
tooltips), not a screenshot.

    python3 tests/render.py out-folder      # one PNG per panel tab and window
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import ROOT  # noqa: E402

MEDIA = os.path.join(ROOT, "Media")
LAYERS = ["BACKGROUND", "BORDER", "ARTWORK", "OVERLAY"]

H_OF = {"LEFT": 0, "CENTER": 0.5, "RIGHT": 1}
V_OF = {"TOP": 0, "CENTER": 0.5, "BOTTOM": 1}


def split_point(p):
    p = (p or "CENTER").upper()
    v = "TOP" if p.startswith("TOP") else "BOTTOM" if p.startswith("BOTTOM") else "CENTER"
    h = "LEFT" if p.endswith("LEFT") else "RIGHT" if p.endswith("RIGHT") else "CENTER"
    return h, v


def media_path(path):
    """A game texture path inside our addon, as a file here."""
    if not isinstance(path, str) or "TheImperium" not in path:
        return None
    rel = path.split("TheImperium\\", 1)[1].replace("\\", "/")
    for ext in ("", ".tga", ".png"):
        f = os.path.join(ROOT, rel + ext)
        if os.path.isfile(f):
            return f
    return None


class Renderer:
    def __init__(self, client, scale=2):
        self.c, self.scale = client, scale
        self.rects = {}
        self.fonts = {}
        L = client.lua
        self.ui = L.eval("UIParent")
        L.execute("UIParent._layout = { points = {}, w = 1280, h = 760 }")

    # --- text ---------------------------------------------------------------
    def font_of(self, w):
        lay = w["_layout"]
        f = lay and lay["font"]
        size, path, color = 12, None, (1, 1, 1)
        if f is not None and f["_layout"] is not None:
            fl = f["_layout"]
            size = fl["size"] or 12
            path = fl["path"]
            if fl["textColor"] is not None:
                tc = fl["textColor"]
                color = (tc[1], tc[2], tc[3])
        if lay and lay["textColor"] is not None:
            tc = lay["textColor"]
            color = (tc[1], tc[2], tc[3])
        file = media_path(path) or os.path.join(MEDIA, "Fonts", "Inter-Regular.ttf")
        key = (file, size)
        if key not in self.fonts:
            self.fonts[key] = ImageFont.truetype(file, int(size * self.scale))
        return self.fonts[key], size, color

    @staticmethod
    def segments(text, color):
        """Text with |cffRRGGBB ... |r color codes, as (text, color) pieces."""
        text = re.sub(r"\|T.*?\|t", "", text)
        text = re.sub(r"\|H.*?\|h(.*?)\|h", r"\1", text)
        out, stack = [], [color]
        for part in re.split(r"(\|c[0-9a-fA-F]{8}|\|r)", text):
            if part.startswith("|c") and len(part) == 10:
                h = part[4:]
                stack.append(tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))
            elif part == "|r":
                if len(stack) > 1:
                    stack.pop()
            elif part:
                out.append((part, stack[-1]))
        return out

    def text_lines(self, w):
        text = w["_GetText"]
        if text is None or text == "":
            return None
        font, size, color = self.font_of(w)
        segs = self.segments(str(text), color)
        lay = w["_layout"]
        width = lay["w"] if lay is not None else None
        # Word-wrap pieces into lines of (text, color) runs.
        lines, line, used = [], [], 0
        limit = width * self.scale if width else None
        if lay is not None and lay["nowrap"] and limit:
            # One line, cut short with an ellipsis like the game does.
            flat = "".join(s for s, _ in segs).replace("\n", " ")
            if font.getlength(flat) > limit:
                while flat and font.getlength(flat + "...") > limit:
                    flat = flat[:-1]
                flat = flat.rstrip() + "..."
            # Keep the first piece's color for the whole line.
            return font, size, [[(flat, segs[0][1] if segs else color)]]
        for seg, col in segs:
            for i, chunk in enumerate(seg.split("\n")):
                if i > 0:
                    lines.append(line)
                    line, used = [], 0
                for word in re.findall(r"\S+\s*|\s+", chunk):
                    wlen = font.getlength(word)
                    if limit and used + wlen > limit and line:
                        lines.append(line)
                        line, used = [], 0
                        word = word.lstrip()
                        wlen = font.getlength(word)
                    line.append((word, col))
                    used += wlen
        lines.append(line)
        return font, size, lines

    def natural_size(self, w):
        kind = w["kind"]
        if kind == "FontString":
            t = self.text_lines(w)
            if not t:
                return 0, 0
            font, size, lines = t
            width = max(sum(font.getlength(s) for s, _ in ln) for ln in lines) / self.scale
            return width, len(lines) * size * 1.25
        return 0, 0

    # --- layout ---------------------------------------------------------------
    def rect(self, w, depth=0):
        """(left, top, right, bottom) in interface units, y downwards."""
        key = w["_uid"]
        if key in self.rects:
            return self.rects[key]
        if depth > 60:
            return (0, 0, 0, 0)
        lay = w["_layout"]
        if lay is None:
            parent = w["_parent"]
            r = self.rect(parent, depth + 1) if parent is not None else (0, 0, 1280, 760)
            self.rects[key] = r
            return r
        nat_w, nat_h = self.natural_size(w)
        width = lay["w"] if lay["w"] else (nat_w or None)
        height = lay["h"] if lay["h"] else (nat_h or None)
        parent = w["_parent"]
        xs, ys = {}, {}
        points = lay["points"]
        sp = w["_scrollParent"]
        if sp is not None:
            pr = self.rect(sp, depth + 1)
            xs["LEFT"], ys["TOP"] = pr[0], pr[1]
        elif points is not None and len(points) > 0:
            for i in range(1, len(points) + 1):
                p = points[i]
                rel = p["rel"] if p["rel"] is not None else parent
                rr = self.rect(rel, depth + 1) if rel is not None else (0, 0, 1280, 760)
                rh, rv = split_point(p["relPoint"])
                tx = rr[0] + (rr[2] - rr[0]) * H_OF[rh] + (p["x"] or 0)
                ty = rr[1] + (rr[3] - rr[1]) * V_OF[rv] - (p["y"] or 0)
                h, v = split_point(p["point"])
                xs[h], ys[v] = tx, ty
        else:
            pr = self.rect(parent, depth + 1) if parent is not None else (0, 0, 1280, 760)
            self.rects[key] = pr
            return pr

        def solve(d, size, a, b):
            if a in d and b in d:
                return d[a], d[b]
            size = size or 0
            if a in d:
                return d[a], d[a] + size
            if b in d:
                return d[b] - size, d[b]
            c = d.get("CENTER", 0)
            return c - size / 2, c + size / 2

        left, right = solve(xs, width, "LEFT", "RIGHT")
        top, bottom = solve(ys, height, "TOP", "BOTTOM")
        r = (left, top, right, bottom)
        self.rects[key] = r
        return r

    # --- drawing --------------------------------------------------------------
    def visible(self, w):
        return w["_IsShown"] is not False

    @staticmethod
    def region_shown(t):
        # A checkbox's tick only shows while it's ticked.
        if t["_disabledCheckOf"] is not None:
            return False
        owner = t["_checkedOf"]
        if owner is not None:
            return owner["_GetChecked"] is True
        return True

    def kids(self, w):
        k = w["_kids"]
        return [k[i] for i in range(1, len(k) + 1)] if k is not None else []

    def draw_region(self, img, w, clip, alpha):
        lay = w["_layout"]
        if lay is None:
            return
        l, t, r, b = self.rect(w)
        s = self.scale
        box = [int(round(l * s)), int(round(t * s)), int(round(r * s)), int(round(b * s))]
        if clip:
            box = [max(box[0], clip[0]), max(box[1], clip[1]), min(box[2], clip[2]), min(box[3], clip[3])]
        a = alpha * (lay["alpha"] if lay["alpha"] is not None else 1)
        if w["kind"] == "Texture":
            if box[2] <= box[0] or box[3] <= box[1]:
                return
            if lay["color"] is not None:
                c = lay["color"]
                layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
                ImageDraw.Draw(layer).rectangle([box[0], box[1], box[2] - 1, box[3] - 1],
                                                fill=(int(c[1] * 255), int(c[2] * 255), int(c[3] * 255), int(c[4] * 255 * a)))
                img.alpha_composite(layer)
            elif media_path(lay["tex"]):
                im = Image.open(media_path(lay["tex"])).convert("RGBA")
                size = (int(round((r - l) * s)), int(round((b - t) * s)))
                if size[0] <= 0 or size[1] <= 0:
                    return
                im = im.resize(size, Image.LANCZOS)
                if lay["tint"] is not None:
                    tc = lay["tint"]
                    px = Image.new("RGBA", im.size, (int(tc[1] * 255), int(tc[2] * 255), int(tc[3] * 255), 255))
                    px.putalpha(im.getchannel("A"))
                    im = px
                if a < 1:
                    im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
                layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
                layer.paste(im, (int(round(l * s)), int(round(t * s))))
                if clip:
                    mask = Image.new("L", img.size, 0)
                    ImageDraw.Draw(mask).rectangle(clip, fill=255)
                    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
                img.alpha_composite(layer)
        elif w["kind"] == "FontString":
            tl = self.text_lines(w)
            if not tl:
                return
            font, size, lines = tl
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            justify = (lay["justify"] or "LEFT").upper()
            y = t * s
            for ln in lines:
                lw = sum(font.getlength(x) for x, _ in ln)
                x = l * s
                if justify == "CENTER":
                    x = (l + r) / 2 * s - lw / 2
                elif justify == "RIGHT":
                    x = r * s - lw
                for word, col in ln:
                    d.text((x, y), word, font=font, fill=(int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), int(255 * a)))
                    x += font.getlength(word)
                y += size * 1.25 * s
            if clip:
                mask = Image.new("L", img.size, 0)
                ImageDraw.Draw(mask).rectangle(clip, fill=255)
                layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
            img.alpha_composite(layer)

    def draw_frame(self, img, w, clip=None, alpha=1.0):
        if not self.visible(w):
            return
        lay = w["_layout"]
        a = alpha * (lay["alpha"] if lay is not None and lay["alpha"] is not None else 1)
        regions = [k for k in self.kids(w) if k["kind"] in ("Texture", "FontString") and self.visible(k)
                   and self.region_shown(k)]
        for layer in LAYERS:
            for k in regions:
                kl = k["_layout"]
                if kl is not None and (kl["layer"] or "ARTWORK") == layer:
                    self.draw_region(img, k, clip, a)
        if w["kind"] == "EditBox" and w["_GetText"]:
            # Typed text, inset like the real box.
            font, size, color = self.font_of(w)
            l, t, r, b = self.rect(w)
            s = self.scale
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(layer).text(((l + 7) * s, ((t + b) / 2 - size * 0.62) * s), str(w["_GetText"]), font=font,
                                       fill=(int(color[0] * 255), int(color[1] * 255), int(color[2] * 255), 255))
            img.alpha_composite(layer)
        child_clip = clip
        if lay is not None and lay["scrollChild"] is not None:
            l, t, r, b = self.rect(w)
            s = self.scale
            child_clip = [int(l * s), int(t * s), int(r * s), int(b * s)]
            if clip:
                child_clip = [max(child_clip[0], clip[0]), max(child_clip[1], clip[1]),
                              min(child_clip[2], clip[2]), min(child_clip[3], clip[3])]
        for k in self.kids(w):
            if k["kind"] not in ("Texture", "FontString"):
                self.draw_frame(img, k, child_clip, a)

    def render(self, frame, path, pad=24):
        self.rects = {}
        l, t, r, b = self.rect(frame)
        s = self.scale
        img = Image.new("RGBA", (1280 * s, 760 * s), (5, 7, 11, 255))
        self.draw_frame(img, frame)
        crop = (max(0, int((l - pad) * s)), max(0, int((t - pad) * s)),
                min(img.size[0], int((r + pad) * s)), min(img.size[1], int((b + pad) * s)))
        img.crop(crop).convert("RGB").save(path)
        return path


def demo_guild():
    """A small guild with some history, so every tab has something to show."""
    from harness import Guild
    members = [("Thorne", 1, "WARRIOR"), ("Lyra", 3, "MAGE"), ("Mira", 3, "PRIEST"), ("Brakk", 3, "ROGUE"),
               ("Aldric", 3, "PALADIN"), ("Seren", 3, "DRUID", 58)]
    guild = Guild(members, raid=["Thorne", "Lyra", "Mira", "Brakk"])
    me = guild["Thorne"]
    t = int(guild.clock)
    kills = [("Ganker", ["Thorne", "Lyra"]), ("Shadowstep", ["Lyra"]), ("Grimtusk", ["Brakk", "Thorne", "Mira"]),
             ("Venomfang", ["Mira"]), ("Bonecrusher", ["Thorne"]), ("Nightreaver", ["Lyra"])]
    for i, (victim, killers) in enumerate(kills):
        me.ns.MergeKill(me.lua.eval('{ t = %d, kind = "kill_world", victim = "%s", zone = "Stranglethorn Vale", killers = { %s } }'
                                    % (t - i * 3000, victim, ",".join('"%s"' % k for k in killers))))
    deaths = [("Lyra", "Ganker-Stormrage"), ("Lyra", "Ganker-Stormrage"), ("Mira", "Ganker-Stormrage"),
              ("Brakk", "Shadowfang-Stormrage"), ("Seren", "Shadowfang-Stormrage"), ("Brakk", "Shadowfang-Stormrage")]
    for i, (who, killer) in enumerate(deaths):
        me.ns.MergeDeath(me.lua.eval('{ t = %d, who = "%s", kind = "pvp", sub = "world", zone = "Stranglethorn Vale", killer = "%s" }'
                                     % (t - 20000 - i * 4000, who, killer)))
    me.lua.eval('function(ns, t) table.insert(ns.db.spotted, 1, { name = "Shadowfang", zone = "Booty Bay", by = "Thorne", t = t, mapID = 1434, x = 0.3, y = 0.7 }); ns.OnHistoryChanged() end')(me.ns, t - 600)
    me.lua.eval("""function(ns, t)
      local log = ns.db.audit
      local function add(dt, actor, action, target, detail)
        table.insert(log, 1, { t = t - dt, actor = actor, action = action, target = target, detail = detail or "" })
      end
      add(400000, "Seren", "join", "Seren")
      add(300000, "Thorne", "promote", "Lyra", "Officer")
      add(200000, "Thorne", "onote", "Brakk")
      add(90000, "Aldric", "join", "Aldric")
      add(40000, "Thorne", "motd")
      add(5000, "Thorne", "promote", "Mira", "Veteran")
    end""")(me.ns, t)
    items = [(19019, "Thunderfury, Blessed Blade of the Windseeker"), (16901, "Stormrage Legguards"),
             (17076, "Bonereaver's Edge"), (18814, "Choker of the Fire Lord"), (16922, "Leggings of Transcendence")]
    def link(i):
        return "|cffa335ee|Hitem:%d::::::::60:::::::|h[%s]|h|r" % items[i]
    for who, wishes in [("Lyra", [(0, "need"), (3, "want")]), ("Brakk", [(0, "need"), (2, "need")]),
                        ("Mira", [(4, "need"), (3, "need")]), ("Thorne", [(1, "want"), (2, "want"), (0, "want")])]:
        for i, prio in wishes:
            guild[who].ns.WishlistAdd(link(i), prio)
    guild.run(2)
    ev = me.ns.CreateRaid("Molten Core", t + 3 * 86400, "")
    guild.run(2)
    for n, role in [("Lyra", "dps"), ("Mira", "healer"), ("Brakk", "dps")]:
        guild[n].ns.SignUp(ev.id, "accept", role)
        guild.run(0.5)
    me.ns.StartRaidSession(ev.id, "Molten Core", 10, 10, 15)
    guild.run(3)
    me.ns.AwardDKP(me.lua.table_from(["Lyra", "Mira"]), 25, "Ragnaros bonus")
    guild.run(3)
    return guild, me


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "render"
    os.makedirs(out, exist_ok=True)
    guild, me = demo_guild()
    rd = Renderer(me)
    panel = None
    for tab in ("roster", "raids", "dkp", "wishlist", "kills", "wanted", "settings", "officers", "addon"):
        me.ns.OpenPanel(tab)
        me.ns.RefreshPanel()
        panel = me.lua.eval("TheImperiumPanel")
        print(rd.render(panel, os.path.join(out, "panel-%s.png" % tab)))
    for tab, view in (("settings", "general"),):
        me.ns.OpenPanel(tab, view)
        print(rd.render(panel, os.path.join(out, "panel-%s-%s.png" % (tab, view))))
    me.ns.OpenPanel("settings", "alerts")
    me.ns.ShowAltsWindow()
    print(rd.render(me.lua.eval("TheImperiumAlts"), os.path.join(out, "window-alts.png")))
    me.ns.ShowPlayerCard("Lyra")
    print(rd.render(me.lua.eval("TheImperiumPlayerCard"), os.path.join(out, "window-player-card.png")))
