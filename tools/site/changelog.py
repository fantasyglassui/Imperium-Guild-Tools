"""
The website's changelog pages: docs/changelog/ (English, every version in full,
from CHANGELOG.md) and docs/<lang>/changelog/ (each version's notes as the
addon shows them in game, in that language, from UI/Updates.lua; versions
older than those notes link to the English page).

The header, footer and styles come from that language's main page, so the
pages always look like the rest of the site. Called by build.py.
"""
import html
import re

SITE = "https://warcrest-addon.com/"

TEXT = {
    "en": {
        "title": "Changelog: every version of Warcrest",
        "description": "Every version of Warcrest, the guild addon for World of Warcraft: Forever, and what changed in it, newest first.",
        "label": "Changelog",
        "h1": "Every version, every change.",
        "intro": "Everything that has changed in Warcrest since the first version, newest first. In game, <code>/warcrest updates</code> shows what's new since the version you last used.",
        "search": "Search the changelog",
        "versions": "Versions",
        "count": "{n} versions",
        "shown": "{n} of {total} versions",
        "none": "No version mentions that.",
        "older": "Notes for this version are in English.",
        "english": "Full notes in English",
        "link": "Link to this version",
        "back": "Back to the top",
    },
    "de": {
        "title": "Änderungen: jede Version von Warcrest",
        "description": "Jede Version von Warcrest, dem Gilden-Addon für World of Warcraft: Forever, und was sich geändert hat, die neueste zuerst.",
        "label": "Änderungen",
        "h1": "Jede Version, jede Änderung.",
        "intro": "Alles, was sich seit der ersten Version an Warcrest geändert hat, die neueste zuerst, so wie Warcrest es im Spiel zeigt (<code>/warcrest updates</code>). Die ausführlichen Notizen gibt es auf <a href=\"/changelog/\" hreflang=\"en\">Englisch</a>.",
        "search": "Änderungen durchsuchen",
        "versions": "Versionen",
        "count": "{n} Versionen",
        "shown": "{n} von {total} Versionen",
        "none": "Keine Version erwähnt das.",
        "older": "Die Notizen zu dieser Version gibt es nur auf Englisch.",
        "english": "Ausführlich auf Englisch",
        "link": "Link zu dieser Version",
        "back": "Nach oben",
    },
    "fr": {
        "title": "Journal des modifications : chaque version de Warcrest",
        "description": "Chaque version de Warcrest, l'addon de guilde pour World of Warcraft: Forever, et ce qui a changé, de la plus récente à la plus ancienne.",
        "label": "Journal",
        "h1": "Chaque version, chaque changement.",
        "intro": "Tout ce qui a changé dans Warcrest depuis la première version, du plus récent au plus ancien, tel que Warcrest l'affiche en jeu (<code>/warcrest updates</code>). Les notes détaillées sont en <a href=\"/changelog/\" hreflang=\"en\">anglais</a>.",
        "search": "Rechercher dans le journal",
        "versions": "Versions",
        "count": "{n} versions",
        "shown": "{n} sur {total} versions",
        "none": "Aucune version n'en parle.",
        "older": "Les notes de cette version sont en anglais.",
        "english": "Notes détaillées en anglais",
        "link": "Lien vers cette version",
        "back": "Haut de page",
    },
    "es": {
        "title": "Registro de cambios: cada versión de Warcrest",
        "description": "Cada versión de Warcrest, el addon de hermandad para World of Warcraft: Forever, y lo que cambió, de la más nueva a la más antigua.",
        "label": "Cambios",
        "h1": "Cada versión, cada cambio.",
        "intro": "Todo lo que ha cambiado en Warcrest desde la primera versión, de lo más nuevo a lo más antiguo, tal como Warcrest lo muestra en el juego (<code>/warcrest updates</code>). Las notas detalladas están en <a href=\"/changelog/\" hreflang=\"en\">inglés</a>.",
        "search": "Buscar en los cambios",
        "versions": "Versiones",
        "count": "{n} versiones",
        "shown": "{n} de {total} versiones",
        "none": "Ninguna versión lo menciona.",
        "older": "Las notas de esta versión están en inglés.",
        "english": "Notas detalladas en inglés",
        "link": "Enlace a esta versión",
        "back": "Volver arriba",
    },
}

CSS = """
/* The changelog page */
.cl-head { padding-block: 56px 28px; }
.cl-head h1 { font-size: clamp(2.1rem, 4.2vw, 3.1rem); line-height: 1.08; }
.cl-head p { color: var(--muted); max-width: 46em; margin: 0; }
.cl-head code, .cl-entry code { font: 500 .86em var(--f-mono); color: var(--text); }
.cl-head a, .cl-entry a { color: var(--gold); }
.cl-tools { display: flex; flex-wrap: wrap; align-items: center; gap: 14px; margin-top: 8px; }
.cl-search { flex: 1 1 280px; max-width: 420px; height: 42px; padding: 0 14px; border-radius: 2px; border: 1px solid var(--edge);
  background: var(--panel); color: var(--text); font: inherit; font-size: .95rem; }
.cl-search:focus { outline: none; border-color: color-mix(in srgb, var(--gold) 60%, var(--edge)); }
.cl-count { color: var(--faint); font-size: .88rem; }
.cl-body { display: grid; grid-template-columns: 200px minmax(0, 1fr); gap: 40px; align-items: start; padding-bottom: 80px; }
.cl-nav { position: sticky; top: 84px; max-height: calc(100vh - 110px); overflow: auto; padding-right: 6px; }
.cl-nav h2 { font-family: var(--f-body); font-size: .72rem; font-weight: 600; letter-spacing: .12em; text-transform: uppercase; color: var(--faint); margin: 0 0 8px; }
.cl-nav h2:not(:first-child) { margin-top: 18px; }
.cl-nav h2 { text-transform: none; letter-spacing: .04em; font-size: .8rem; }
.cl-nav ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 1px; }
.cl-nav a { display: block; padding: 4px 10px; border-left: 2px solid var(--line); color: var(--muted); font: 500 .86rem var(--f-mono); }
.cl-nav a:hover { color: var(--text); text-decoration: none; border-left-color: var(--edge); }
.cl-nav a[aria-current] { color: var(--gold); border-left-color: var(--gold); }
.cl-list { display: grid; gap: 16px; }
.cl-entry { border: 1px solid var(--line); background: var(--panel); padding: 24px 26px 26px; border-radius: 2px; scroll-margin-top: 84px; }
.cl-entry:first-child { border-color: color-mix(in srgb, var(--gold) 45%, var(--line)); }
.cl-entry > header { display: flex; align-items: baseline; gap: 14px; flex-wrap: wrap; margin-bottom: 12px; }
.cl-entry h2 { font-size: 1.7rem; line-height: 1.1; }
.cl-entry h2 a { color: var(--text); }
.cl-entry h2 a:hover { color: var(--gold); text-decoration: none; }
.cl-entry time { color: var(--faint); font-size: .85rem; }
.cl-entry h3 { font: 600 .98rem var(--f-body); color: var(--text); margin: 18px 0 8px; }
.cl-entry p { margin: 0 0 10px; color: var(--soft); }
.cl-entry ul { margin: 0; padding: 0; list-style: none; display: grid; gap: 8px; }
.cl-entry ul ul { margin-top: 8px; padding-left: 18px; }
.cl-entry li { padding-left: 18px; position: relative; color: var(--muted); }
.cl-entry li::before { content: ""; position: absolute; left: 2px; top: .66em; width: 6px; height: 6px; background: var(--gold); transform: rotate(45deg); }
.cl-entry li li::before { background: var(--faint); }
.cl-entry strong { color: var(--text); font-weight: 600; }
.cl-entry .cl-more { margin: 14px 0 0; font-size: .9rem; }
.cl-entry .cl-old { color: var(--faint); }
.cl-none { color: var(--muted); padding: 24px 0; }
mark { background: var(--gold-dim); color: var(--text); padding: 0 1px; border-radius: 2px; }
@media (max-width: 860px) { .cl-body { grid-template-columns: minmax(0, 1fr); } .cl-nav { display: none; } .cl-entry { padding: 20px 18px 22px; } }
"""

SCRIPT = """
<script>
(function () {
  var input = document.getElementById("cl-search"), count = document.getElementById("cl-count"),
      none = document.getElementById("cl-none"), entries = [].slice.call(document.querySelectorAll(".cl-entry")),
      links = {}, total = entries.length, T = JSON.parse(document.getElementById("cl-text").textContent);
  document.querySelectorAll(".cl-nav a").forEach(function (a) { links[a.getAttribute("href").slice(1)] = a; });
  entries.forEach(function (e) { e.dataset.text = e.textContent.toLowerCase(); });
  function clearMarks(root) {
    root.querySelectorAll("mark").forEach(function (m) { m.replaceWith(document.createTextNode(m.textContent)); });
    root.normalize();
  }
  function mark(root, q) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT), nodes = [], n;
    while ((n = walker.nextNode())) nodes.push(n);
    nodes.forEach(function (node) {
      var t = node.nodeValue, i = t.toLowerCase().indexOf(q);
      if (i < 0) return;
      var frag = document.createDocumentFragment(), last = 0;
      while (i >= 0) {
        frag.appendChild(document.createTextNode(t.slice(last, i)));
        var m = document.createElement("mark"); m.textContent = t.slice(i, i + q.length); frag.appendChild(m);
        last = i + q.length; i = t.toLowerCase().indexOf(q, last);
      }
      frag.appendChild(document.createTextNode(t.slice(last)));
      node.replaceWith(frag);
    });
  }
  function filter() {
    var q = input.value.trim().toLowerCase(), shown = 0;
    entries.forEach(function (e) {
      clearMarks(e);
      var ok = !q || e.dataset.text.indexOf(q) >= 0;
      e.hidden = !ok;
      if (links[e.id]) links[e.id].parentNode.hidden = !ok;
      if (ok) { shown++; if (q) mark(e, q); }
    });
    none.hidden = shown > 0;
    count.textContent = q ? T.shown.replace("{n}", shown).replace("{total}", total) : T.count.replace("{n}", total);
  }
  var timer;
  input.addEventListener("input", function () { clearTimeout(timer); timer = setTimeout(filter, 120); });
  // The version in view is highlighted in the list.
  if ("IntersectionObserver" in window) {
    var current;
    var io = new IntersectionObserver(function (seen) {
      seen.forEach(function (s) {
        if (!s.isIntersecting) return;
        if (current) current.removeAttribute("aria-current");
        current = links[s.target.id];
        if (current) current.setAttribute("aria-current", "true");
      });
    }, { rootMargin: "-90px 0px -70% 0px" });
    entries.forEach(function (e) { io.observe(e); });
  }
  filter();
})();
</script>
"""


def anchor(version):
    return "v" + version.replace(".", "-")


def inline(text):
    """Markdown inline: `code`, **bold**, [text](url), escaped."""
    out, pos = [], 0
    for m in re.finditer(r"`([^`]+)`|\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)", text):
        out.append(html.escape(text[pos:m.start()], quote=False))
        if m.group(1) is not None:
            out.append("<code>%s</code>" % html.escape(m.group(1), quote=False))
        elif m.group(2) is not None:
            out.append("<strong>%s</strong>" % inline(m.group(2)))
        else:
            url = m.group(4)
            ext = url.startswith("http") and "warcrest-addon.com" not in url
            out.append('<a href="%s"%s>%s</a>' % (html.escape(url), ' target="_blank" rel="noopener"' if ext else "",
                                                  inline(m.group(3))))
        pos = m.end()
    out.append(html.escape(text[pos:], quote=False))
    return "".join(out)


def markdown_releases(src):
    """CHANGELOG.md -> [(version, body html)], newest first."""
    out = []
    for block in re.split(r"^## ", src, flags=re.M)[1:]:
        head, _, body = block.partition("\n")
        version = head.strip()
        parts, para, stack = [], [], []   # stack: open list depths

        def flush_para():
            if para:
                parts.append("<p>%s</p>" % inline(" ".join(para)))
                del para[:]

        def close_lists(depth):
            while len(stack) > depth:
                stack.pop()
                parts.append("</li></ul>")

        for line in body.split("\n"):
            m = re.match(r"^(\s*)- (.*)$", line)
            if m:
                flush_para()
                depth = len(m.group(1)) // 2 + 1
                if len(stack) < depth:
                    parts.append("<ul><li>")
                    stack.append(depth)
                else:
                    close_lists(depth)
                    parts.append("</li><li>")
                parts.append(inline(m.group(2)))
            elif line.startswith("### "):
                flush_para(); close_lists(0)
                parts.append("<h3>%s</h3>" % inline(line[4:].strip()))
            elif not line.strip():
                flush_para()
            elif stack and line.startswith("  "):
                parts.append(" " + inline(line.strip()))   # a list item carried onto the next line
            else:
                close_lists(0)
                para.append(line.strip())
        flush_para(); close_lists(0)
        out.append((version, "".join(parts)))
    return out


def page(lang, main_page, entries, dates, version, local_date, iso_date):
    """The changelog page in `lang`. main_page: that language's built main page.
    entries: [(version, body html, english_only)]."""
    t = TEXT[lang]
    base = "/" if lang == "en" else "/%s/" % lang
    url = SITE + ("changelog/" if lang == "en" else lang + "/changelog/")
    style = re.search(r"<style>.*?</style>", main_page, re.S).group(0).replace("</style>", CSS + "</style>")
    header = re.search(r'<header class="top">.*?\n</header>', main_page, re.S).group(0)
    footer = re.search(r"<footer>.*?</footer>", main_page, re.S).group(0)

    def relink(part):
        part = re.sub(r'href="/((?:de/|fr/|es/)?)"', r'href="/\1changelog/"', part)        # language menus
        part = re.sub(r'href="#([a-z-]*)"', lambda m: 'href="%s%s"' % (base, "#" + m.group(1) if m.group(1) != "top" else ""), part)
        part = part.replace('aria-label="Warcrest, back to top"', 'aria-label="Warcrest"')
        return part

    header, footer = relink(header), relink(footer)
    header = header.replace('<a href="%schangelog/">' % base, '<a href="%schangelog/" aria-current="page">' % base)
    footer = re.sub(r'data-version="">[^<]*<', 'data-version="">%s<' % version, footer)

    alternates = "\n".join('<link rel="alternate" hreflang="%s" href="%s%schangelog/">' % (c, SITE, "" if c == "en" else c + "/")
                           for c in ("en", "de", "fr", "es"))
    alternates += '\n<link rel="alternate" hreflang="x-default" href="%schangelog/">' % SITE
    hl = {"en": "en", "de": "de", "fr": "fr", "es": "es"}[lang]
    icon = "/img/crest.png"
    head = """<!doctype html>
<html lang="%s">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>%s</title>
<meta name="description" content="%s">
%s
<link rel="canonical" href="%s">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Warcrest">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:url" content="%s">
<meta property="og:image" content="%sog.jpg">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#e0b94c">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap">
%s
<link rel="icon" href="%s">
</head>
<body>
""" % (hl, html.escape(t["title"]), html.escape(t["description"]), alternates, url, html.escape(t["title"]),
       html.escape(t["description"]), url, SITE, style, icon)

    # The list of versions, by major version.
    groups = []
    for v, _, _ in entries:
        major = v.split(".")[0] + ".x"
        if not groups or groups[-1][0] != major:
            groups.append((major, []))
        groups[-1][1].append(v)
    nav = "".join('<h2>%s</h2><ul>%s</ul>' % (major, "".join('<li><a href="#%s">%s</a></li>' % (anchor(v), v) for v in vs))
                  for major, vs in groups)

    articles = []
    for v, body, english_only in entries:
        date = dates.get(v)
        when = '<time datetime="%s">%s</time>' % (iso_date(date), local_date(lang, date)) if date else ""
        more = ""
        if lang != "en":
            more = '<p class="cl-more"><a href="/changelog/#%s" hreflang="en">%s</a></p>' % (anchor(v), html.escape(t["english"]))
            if english_only:
                body = '<p class="cl-old">%s</p>' % html.escape(t["older"])
        articles.append('<article class="cl-entry" id="%s"><header><h2><a href="#%s" title="%s">%s</a></h2>%s</header>%s%s</article>'
                        % (anchor(v), anchor(v), html.escape(t["link"]), v, when, body, more))

    texts = '<script type="application/json" id="cl-text">%s</script>' % (
        '{"count": "%s", "shown": "%s"}' % (t["count"], t["shown"]))
    main = """
<main id="top">
  <section class="cl-head">
    <div class="wrap">
      <div class="sec-head" style="margin-bottom:22px">
        <span class="label">%s</span>
        <h1>%s</h1>
        <p>%s</p>
      </div>
      <div class="cl-tools">
        <input class="cl-search" id="cl-search" type="search" placeholder="%s" aria-label="%s" autocomplete="off">
        <span class="cl-count" id="cl-count" aria-live="polite">%s</span>
      </div>
    </div>
  </section>
  <div class="wrap cl-body">
    <nav class="cl-nav" aria-label="%s">%s</nav>
    <div>
      <div class="cl-list">
        %s
      </div>
      <p class="cl-none" id="cl-none" hidden>%s</p>
    </div>
  </div>
</main>
""" % (html.escape(t["label"]), html.escape(t["h1"]), t["intro"], html.escape(t["search"]), html.escape(t["search"]),
       t["count"].replace("{n}", str(len(entries))), html.escape(t["versions"]), nav, "\n        ".join(articles),
       html.escape(t["none"]))
    return head + "\n" + header + "\n" + main + "\n" + footer + "\n" + texts + SCRIPT + "\n</body>\n</html>\n"
