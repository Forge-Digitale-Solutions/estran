#!/usr/bin/env python3
"""Render styled App Store frames from the raw simulator captures.

- portrait 6.9" set  -> build/store/final/6.9/NN-*.png   (1320 x 2868)
- landscape set      -> build/store/final/6.9-landscape/  (2868 x 1320)
- contact sheet      -> build/store/final/contact-sheet.png

Headless Google Chrome only (no Pillow / ImageMagick on this Mac).
Templates and this script are build artefacts: not committed.
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
SRC = ROOT / "build/store/frames-src"
RAW = ROOT / "docs/store/screenshots/raw"
ALT = ROOT / "docs/store/screenshots/raw"
OUT = ROOT / "build/store/final/6.9"
OUT_LAND = ROOT / "docs/store/screenshots/landscape"
OUT_HEADER = ROOT / "docs/store/screenshots/header"
ICON = ROOT / "Estran/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
HEADERS = [
    {"w": 5244, "h": 2950, "out": "header-5244x2950.png"},
    {"w": 3840, "h": 1646, "out": "header-3840x1646.png"},
]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# ---------------------------------------------------------------- portrait ---
PW, PH = 1320, 2868
MARGIN = 80
KICKER_TOP = 150
KICKER_SIZE = 34
CAP_SIZE = 112
DEVICE_TOP = 532
BEZEL = 14
DEVICE_W = 1108                      # 84 % of the canvas width
CONTENT_W = DEVICE_W - 2 * BEZEL     # 1080
CONTENT_H = round(CONTENT_W * PH / PW)   # 2346 - exact capture ratio
DEVICE_H = CONTENT_H + 2 * BEZEL
RADIUS = 140
IRADIUS = 126

# --------------------------------------------------------------- landscape ---
LW, LH = 2868, 1320
LMARGIN = 110
LCAP_SIZE = 96
LKICKER_SIZE = 32
LDEVICE_W = 1728
LCONTENT_W = LDEVICE_W - 2 * BEZEL    # 1700
LCONTENT_H = round(LCONTENT_W * LH / LW)  # 782
LDEVICE_H = LCONTENT_H + 2 * BEZEL
LRADIUS = 206
LIRADIUS = 192
LDEVICE_TOP = 470

def first_existing(*paths):
    for p in paths:
        if p.exists():
            return p
    return paths[0]


FRAMES = [
    {
        "n": "01",
        "out": "01-home-oui.png",
        # top-framed capture: « Maintenant », the spot chip and the green « Oui »
        # with the engine's own positive sentence (« C'est bon pour la balade. »).
        "src": ALT / "01-alt-top-conseil-under-bar.png",
        "kicker": "Marée · vent · houle · pluie · lumière",
        "lines": ["C’est le bon moment\u00a0?"],
        "alt": "Pointe de Grave, balade : Oui, créneau en cours",
    },
    {
        "n": "02",
        "out": "02-home-non-raison.png",
        "src": RAW / "02-home-non-raison.png",
        "kicker": "La raison, tout de suite",
        "lines": ["Et si c’est non,", "tu sais pourquoi"],
        "alt": "Bateau : Non, vent trop fort, prochain créneau",
    },
    {
        "n": "03",
        "out": "03-detail-maree.png",
        "src": RAW / "03-detail-maree.png",
        "kicker": "Hauteur · marnage · créneau",
        "lines": ["La marée,", "d’un doigt"],
        "alt": "Courbe de marée du jour et créneau balade",
    },
    {
        "n": "04",
        "out": "04-baignade.png",
        "src": RAW / "04-baignade.png",
        "kicker": "Courants estimés · baïnes",
        "lines": ["La baignade,", "sans fausse promesse"],
        "alt": "Avertissement baïnes et niveau de courants",
    },
    {
        "n": "05",
        "out": "05-spots-carte.png",
        "src": RAW / "05-spots-carte.png",
        "kicker": "Deux spots · cinq sorties",
        "lines": ["Tes spots,", "en un coup d’œil"],
        "alt": "Carte du spot et réponse du moment",
    },
    {
        "n": "06",
        "out": "06-reglages-glossaire.png",
        "src": RAW / "07-reglages-glossaire.png",
        "kicker": "Chaque indicateur expliqué",
        "lines": ["Tout comprendre,", "simplement"],
        "alt": "Glossaire des indicateurs dans Réglages",
    },
    {
        # Reserved slot: rendered only once the owner's device capture exists.
        "n": "07",
        "out": "07-widgets.png",
        "src": RAW / "06-widgets-nodock.png",
        "kicker": "Réglables par spot et activité",
        "lines": ["Tes widgets,", "à ta main"],
        "alt": "Widgets écran d'accueil et écran verrouillé",
    },
]

LANDSCAPE = {
    "n": "01",
    "out": "01-paysage.png",
    "src": RAW / "08-paysage.png",
    "kicker": "Paysage · grand écran",
    "lines": ["Grand écran,", "deux colonnes"],
    "alt": "Home en paysage, deux colonnes",
}

BASE_CSS = """
  * {{ box-sizing: border-box; }}
  html, body {{ margin:0; padding:0; width:{w}px; height:{h}px; overflow:hidden; }}
  body {{
    position:relative;
    font-family: -apple-system, "SF Pro Display", "SF Pro Text", sans-serif;
    -webkit-font-smoothing: antialiased;
    background:
      radial-gradient({g1x}px {g1y}px at {g1px}% {g1py}%, rgba(48,213,200,0.32), rgba(48,213,200,0) 62%),
      radial-gradient({g2x}px {g2y}px at {g2px}% {g2py}%, rgba(0,145,255,0.30), rgba(0,145,255,0) 68%),
      radial-gradient({g3x}px {g3y}px at 48% 46%, rgba(18,80,124,0.55), rgba(18,80,124,0) 72%),
      linear-gradient(180deg, #031426 0%, #05203a 46%, #0A3D62 100%);
  }}
  body::before {{
    content:""; position:absolute; inset:0;
    background:
      radial-gradient({l1x}px {l1y}px at 50% 40px, rgba(120,225,240,0.14), rgba(120,225,240,0) 70%),
      radial-gradient({l2x}px {l2y}px at 50% {hpx}px, rgba(48,213,200,0.10), rgba(48,213,200,0) 65%);
  }}
  body::after {{
    content:""; position:absolute; inset:0;
    background: radial-gradient({vx}px {vy}px at 50% 40%, rgba(2,12,24,0) 42%, rgba(2,12,24,0.42) 100%);
  }}
  .kicker {{
    font-size:{ksize}px; line-height:1.2; font-weight:600; letter-spacing:.17em;
    text-transform:uppercase; color:#30D5C8; opacity:.95; margin:0 0 {kgap}px 0;
  }}
  h1 {{
    margin:0; font-size:{csize}px; line-height:1.05; font-weight:800;
    letter-spacing:-0.035em; color:#FFFFFF;
    text-shadow: 0 4px 26px rgba(2,14,28,.45);
  }}
  .device {{
    position:absolute; padding:{bezel}px; border-radius:{radius}px; z-index:2;
    background: linear-gradient(158deg, #26333f 0%, #0a121c 32%, #05090f 66%, #1d2836 100%);
    box-shadow:
      0 0 0 2px rgba(160,220,240,0.18),
      0 54px 96px rgba(0,0,0,0.58),
      0 14px 28px rgba(0,0,0,0.45);
  }}
  .screen {{
    width:{cw}px; height:{ch}px; display:block; border-radius:{iradius}px;
    overflow:hidden; background:#031426;
  }}
  .screen img {{ width:100%; height:100%; display:block; object-fit:cover; }}
"""

PORTRAIT_HTML = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<style>""" + BASE_CSS + """
  .caption {{
    position:absolute; top:{ktop}px; left:{margin}px; width:{cbox}px;
    text-align:center; z-index:3;
  }}
  .halo {{
    position:absolute; top:{halo_top}px; left:50%; transform:translateX(-50%);
    width:1240px; height:800px; z-index:1;
    background: radial-gradient(closest-side, rgba(48,213,200,0.20), rgba(48,213,200,0.06) 55%, rgba(48,213,200,0) 100%);
  }}
  .device {{ top:{dtop}px; left:50%; transform:translateX(-50%); width:{dw}px; height:{dh}px; }}
</style></head><body>
  <div class="caption">
    <p class="kicker">{kicker}</p>
    <h1>{title}</h1>
  </div>
  <div class="brandglow"></div>
  <div class="halo"></div>
  <div class="device"><div class="screen"><img src="{img}"></div></div>
</body></html>
"""

LANDSCAPE_HTML = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<style>""" + BASE_CSS + """
  body {{
    display:flex; align-items:center; justify-content:flex-start;
  }}
  .caption {{
    position:absolute; top:50%; transform:translateY(-50%);
    left:{margin}px; width:{cbox}px; text-align:left; z-index:3;
  }}
  .halo {{
    position:absolute; top:{halo_top}px; left:820px; width:1500px; height:900px; z-index:1;
    background: radial-gradient(closest-side, rgba(48,213,200,0.18), rgba(48,213,200,0.05) 55%, rgba(48,213,200,0) 100%);
  }}
  .device {{ top:{dtop}px; right:{margin}px; width:{dw}px; height:{dh}px; }}
</style></head><body>
  <div class="caption">
    <p class="kicker">{kicker}</p>
    <h1>{title}</h1>
  </div>
  <div class="brandglow"></div>
  <div class="halo"></div>
  <div class="device"><div class="screen"><img src="{img}"></div></div>
</body></html>
"""

BASE_VARS = dict(
    g1x=1150, g1y=860, g1px=86, g1py=-10,
    g2x=1300, g2y=1050, g2px=2, g2py=114,
    g3x=1000, g3y=900,
    l1x=760, l1y=400,
    l2x=1500, l2y=900,
    vx=1500, vy=1200,
    ksize=KICKER_SIZE, kgap=28,
    bezel=BEZEL,
)


def native_source(p):
    """Return a copy of `p` without its PNG eXIf chunk (EXIF orientation).

    The landscape capture of this pass carries Orientation=8 in an eXIf chunk
    while its pixels are already upright: sips and Preview ignore it, Chrome
    honours it and shows the screen rotated 90°. The App Store reads pixels, so
    the chunk is dropped for rendering — the raw file is left untouched.
    """
    data = p.read_bytes() if p.exists() else b""
    if b"eXIf" not in data:
        return p
    out = SRC / "cache" / p.name
    out.parent.mkdir(parents=True, exist_ok=True)
    chunks, i = [data[:8]], 8
    while i < len(data):
        length = int.from_bytes(data[i : i + 4], "big")
        kind = data[i + 4 : i + 8]
        if kind != b"eXIf":
            chunks.append(data[i : i + 12 + length])
        i += 12 + length
    out.write_bytes(b"".join(chunks))
    return out


def shot(html_path, out_png, w, h):
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--window-size={w},{h}",
            f"--screenshot={out_png}",
            html_path.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def render_portrait(f):
    html_path = SRC / f"frame-{f['n']}.html"
    title = "<br>".join(f["lines"])
    html_path.write_text(
        PORTRAIT_HTML.format(
            **BASE_VARS,
            w=PW, h=PH, hpx=PH,
            csize=CAP_SIZE,
            radius=RADIUS, iradius=IRADIUS,
            cw=CONTENT_W, ch=CONTENT_H,
            ktop=KICKER_TOP, margin=MARGIN, cbox=PW - 2 * MARGIN,
            halo_top=DEVICE_TOP + 40,
            dtop=DEVICE_TOP, dw=DEVICE_W, dh=DEVICE_H,
            kicker=f["kicker"], title=title, img=native_source(f["src"]).as_uri(),
        ),
        encoding="utf-8",
    )
    if not f["src"].exists():
        print("SKIP (missing source) {} <- {}".format(f["out"], f["src"]))
        return
    shot(html_path, OUT / f["out"], PW, PH)
    print(OUT / f["out"])


def render_landscape(f):
    html_path = SRC / "frame-landscape.html"
    title = "<br>".join(f["lines"])
    html_path.write_text(
        LANDSCAPE_HTML.format(
            **dict(BASE_VARS, ksize=LKICKER_SIZE),
            w=LW, h=LH, hpx=LH,
            csize=LCAP_SIZE,
            radius=LRADIUS, iradius=LIRADIUS,
            cw=LCONTENT_W, ch=LCONTENT_H,
            margin=LMARGIN, cbox=LW - 2 * LMARGIN - LDEVICE_W - 40,
            halo_top=LDEVICE_TOP + 60,
            dtop=LDEVICE_TOP, dw=LDEVICE_W, dh=LDEVICE_H,
            kicker=f["kicker"], title=title, img=native_source(f["src"]).as_uri(),
        ),
        encoding="utf-8",
    )
    shot(html_path, OUT_LAND / f["out"], LW, LH)
    print(OUT_LAND / f["out"])


def header_geometry(W, H):
    """All header sizes are fractions of the canvas height/size, so the two
    required sizes share one composition."""
    g = {}
    g["icon"] = round(0.155 * H)
    g["icon_r"] = round(g["icon"] * 0.2237)     # iOS app-icon corner radius
    g["g1"] = round(0.020 * H)
    g["name"] = round(0.125 * H)
    g["g2"] = round(0.014 * H)
    g["tag"] = round(0.0415 * H)
    g["g3"] = round(0.012 * H)
    g["spots"] = round(0.023 * H)
    g["left"] = round(0.225 * W)               # inside the central 60 %
    g["halo_w"] = round(0.42 * W)
    g["halo_x"] = round(0.70 * W)

    def phone(outer_h, x_frac, top_frac):
        ch = round(outer_h / 1.0129)
        cw = round(ch * PW / PH)
        b = max(8, round(0.014 * cw))
        return {
            "x": round(x_frac * W),
            "y": round(top_frac * H),
            "cw": cw,
            "ch": ch,
            "bz": b,
            "w": cw + 2 * b,
            "h": ch + 2 * b,
            "r": round(0.1264 * (cw + 2 * b)),
            "ir": round(0.1166 * cw),
        }

    g["front"] = phone(0.94 * H, 0.645, 0.11)
    g["back"] = phone(0.80 * H, 0.845, 0.05)
    return g


HEADER_HTML = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<style>
  * {{ box-sizing:border-box; }}
  html, body {{ margin:0; padding:0; width:{w}px; height:{h}px; overflow:hidden; }}
  body {{
    position:relative;
    font-family: -apple-system, "SF Pro Display", "SF Pro Text", sans-serif;
    -webkit-font-smoothing: antialiased;
    background:
      radial-gradient({g1x}px {g1y}px at 88% -12%, rgba(48,213,200,0.30), rgba(48,213,200,0) 62%),
      radial-gradient({g2x}px {g2y}px at 2% 118%, rgba(0,145,255,0.38), rgba(0,145,255,0) 66%),
      radial-gradient({g3x}px {g3y}px at 46% 44%, rgba(18,80,124,0.55), rgba(18,80,124,0) 72%),
      linear-gradient(180deg, #031426 0%, #05203a 46%, #0A3D62 100%);
  }}
  body::before {{
    content:""; position:absolute; inset:0;
    background: radial-gradient({l1x}px {l1y}px at 30% 34%, rgba(120,225,240,0.10), rgba(120,225,240,0) 70%);
  }}
  body::after {{
    content:""; position:absolute; inset:0;
    background: radial-gradient({vx}px {vy}px at 45% 45%, rgba(2,12,24,0) 44%, rgba(2,12,24,0.45) 100%);
  }}
  .brandglow {{
    position:absolute; left:{bgx}px; top:50%; width:{bgw}px; height:{bgh}px;
    transform:translate(-50%,-50%); z-index:1;
    background: radial-gradient(closest-side, rgba(120,225,240,0.11), rgba(48,213,200,0.04) 58%, rgba(48,213,200,0) 100%);
  }}
  .halo {{
    position:absolute; left:{halo_x}px; top:6%; width:{halo_w}px; height:88%;
    transform:translateX(-50%); z-index:1;
    background: radial-gradient(closest-side, rgba(48,213,200,0.20), rgba(48,213,200,0.05) 58%, rgba(48,213,200,0) 100%);
  }}
  .phone {{
    position:absolute; padding:{fbz}px; border-radius:{fr}px; z-index:2;
    background: linear-gradient(158deg, #26333f 0%, #0a121c 32%, #05090f 66%, #1d2836 100%);
    box-shadow:
      0 0 0 2px rgba(160,220,240,0.18),
      0 60px 130px rgba(0,0,0,0.60),
      0 16px 34px rgba(0,0,0,0.45);
  }}
  .phone .screen {{ display:block; overflow:hidden; background:#031426; }}
  .phone img {{ width:100%; height:100%; display:block; object-fit:cover; }}
  .brand {{ position:absolute; left:{left}px; top:50%; transform:translateY(-50%); z-index:3; }}
  .icon {{
    width:{icon}px; height:{icon}px; border-radius:{icon_r}px; overflow:hidden;
    box-shadow: 0 44px 96px rgba(0,0,0,0.55), 0 0 0 3px rgba(255,255,255,0.10);
  }}
  .icon img {{ width:100%; height:100%; display:block; }}
  .name {{
    margin:{g1}px 0 0; font-size:{name}px; line-height:1.0; font-weight:800;
    letter-spacing:-0.032em; color:#FFFFFF; text-shadow:0 6px 34px rgba(2,14,28,.45);
  }}
  .tagline {{
    margin:{g2}px 0 0; font-size:{tag}px; line-height:1.16; font-weight:600;
    letter-spacing:-0.015em; color:rgba(255,255,255,0.90);
    text-shadow:0 4px 24px rgba(2,14,28,.40); white-space:nowrap;
  }}
  .spots {{
    margin:{g3}px 0 0; font-size:{spots}px; line-height:1.2; font-weight:600;
    letter-spacing:.16em; text-transform:uppercase; color:#30D5C8; white-space:nowrap;
  }}
</style></head><body>
  <div class="brandglow"></div>
  <div class="halo"></div>
  <div class="phone" style="left:{bx}px; top:{by}px; width:{bw}px; height:{bh}px; border-radius:{br}px; opacity:.96">
    <div class="screen" style="width:{bcw}px; height:{bch}px; border-radius:{bir}px"><img src="{back_img}"></div>
  </div>
  <div class="phone" style="left:{fx}px; top:{fy}px; width:{fw}px; height:{fh}px; border-radius:{fr}px">
    <div class="screen" style="width:{fcw}px; height:{fch}px; border-radius:{fir}px"><img src="{front_img}"></div>
  </div>
  <div class="brand">
    <div class="icon"><img src="{icon_img}"></div>
    <p class="name">Estran</p>
    <p class="tagline">C\u2019est le bon moment pour sortir\u00a0?</p>
    <p class="spots">Pointe de Grave · Arcachon-Eyrac</p>
  </div>
</body></html>
"""


def render_header(hd):
    g = header_geometry(hd["w"], hd["h"])
    html_path = SRC / f"header-{hd['w']}x{hd['h']}.html"
    html_path.write_text(
        HEADER_HTML.format(
            w=hd["w"], h=hd["h"],
            g1x=round(0.55 * hd["w"]), g1y=round(0.30 * hd["h"]),
            g2x=round(0.60 * hd["w"]), g2y=round(0.45 * hd["h"]),
            g3x=round(0.55 * hd["w"]), g3y=round(0.35 * hd["h"]),
            l1x=round(0.35 * hd["w"]), l1y=round(0.40 * hd["h"]),
            vx=round(0.60 * hd["w"]), vy=round(0.55 * hd["h"]),
            halo_x=g["halo_x"], halo_w=g["halo_w"],
            bgx=round(g["left"] + 0.16 * hd["w"]),
            bgw=round(0.56 * hd["w"]),
            bgh=round(0.86 * hd["h"]),
            icon=g["icon"], icon_r=g["icon_r"],
            g1=g["g1"], name=g["name"], g2=g["g2"], tag=g["tag"],
            g3=g["g3"], spots=g["spots"], left=g["left"],
            fbz=g["front"]["bz"], fr=g["front"]["r"],
            fx=g["front"]["x"], fy=g["front"]["y"],
            fw=g["front"]["w"], fh=g["front"]["h"],
            fcw=g["front"]["cw"], fch=g["front"]["ch"], fir=g["front"]["ir"],
            bx=g["back"]["x"], by=g["back"]["y"],
            bw=g["back"]["w"], bh=g["back"]["h"],
            br=g["back"]["r"], bcw=g["back"]["cw"], bch=g["back"]["ch"],
            bir=g["back"]["ir"],
            icon_img=ICON.as_uri(),
            front_img=native_source(RAW / "01-home-oui.png").as_uri(),
            back_img=native_source(RAW / "03-detail-maree.png").as_uri(),
        ),
        encoding="utf-8",
    )
    out = OUT_HEADER / hd["out"]
    shot(html_path, out, hd["w"], hd["h"])
    print(out)


def contact_sheet(rendered_portraits):
    """Portrait row on top, landscape row underneath, for a quick review."""
    tw = 340
    gap = 24
    pad = 40
    cols = len(rendered_portraits)
    lw = 1440
    sheet_w = max(cols * tw + (cols - 1) * gap, lw) + 2 * pad
    th = round(tw * PH / PW)
    lh = round(lw * LH / LW)
    sheet_h = pad + th + 34 + gap + lh + 62 + pad

    def cell(path, width, label):
        return (
            f'<figure style="width:{width}px"><img src="{path.as_uri()}" '
            f'style="width:{width}px"><figcaption>{label}</figcaption></figure>'
        )

    top = "\n".join(
        cell(OUT / f["out"], tw, f"{f['n']} · {f['kicker']}") for f in rendered_portraits
    )
    bottom = cell(OUT_LAND / LANDSCAPE["out"], lw, "paysage · 2868 × 1320")

    hw = 1000
    heads = "\n".join(
        cell(OUT_HEADER / h["out"], hw, f"en-tête · {h['w']} × {h['h']}") for h in HEADERS
    )
    hh = max(round(hw * h["h"] / h["w"]) for h in HEADERS)
    sheet_h += hh + gap + 29

    html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
  * {{ box-sizing:border-box; }}
  html,body {{ margin:0; width:{sheet_w}px; height:{sheet_h}px; overflow:hidden;
    background:linear-gradient(180deg,#031426,#0A3D62);
    font-family:-apple-system,"SF Pro Display",sans-serif; -webkit-font-smoothing:antialiased; }}
  .pad {{ padding:{pad}px; }}
  .row {{ display:flex; gap:{gap}px; align-items:flex-start; }}
  .headers {{ justify-content:center; }}
  .wide {{ justify-content:center; }}
  figure {{ margin:0; }}
  figure img {{ display:block; border-radius:16px; box-shadow:0 18px 40px rgba(0,0,0,.5); }}
  figcaption {{ margin-top:12px; font-size:14px; color:#8fd8d2; text-align:center;
    letter-spacing:.02em; }}
  .wide figcaption {{ text-align:left; }}
</style></head><body><div class="pad">
  <div class="row">{top}</div>
  <div class="row wide" style="margin-top:{gap + 34}px">{bottom}</div>
  <div class="row headers" style="margin-top:{gap + 34}px">{heads}</div>
</div></body></html>"""
    path = SRC / "contact-sheet.html"
    path.write_text(html, encoding="utf-8")
    out = ROOT / "docs/store/screenshots/contact-sheet.png"
    shot(path, out, sheet_w, sheet_h)
    print(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    OUT_LAND.mkdir(parents=True, exist_ok=True)
    OUT_HEADER.mkdir(parents=True, exist_ok=True)
    rendered = []
    for f in FRAMES:
        render_portrait(f)
        if f["src"].exists():
            rendered.append(f)
    render_landscape(LANDSCAPE)
    for hd in HEADERS:
        render_header(hd)
    (SRC / "frames.json").write_text(
        json.dumps(
            {
                "portrait": [
                    {k: str(v) for k, v in f.items()} for f in FRAMES
                ],
                "landscape": {k: str(v) for k, v in LANDSCAPE.items()},
                "headers": HEADERS,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    contact_sheet(rendered)
    # App Store Connect's iPhone slot takes 1206 x 2622: resize the 6.9" set.
    out_63 = ROOT / "docs/store/screenshots/appstore-6.3"
    out_63.mkdir(parents=True, exist_ok=True)
    for f in rendered:
        subprocess.run(
            ["sips", "-z", "2622", "1206", str(OUT / f["out"]), "--out", str(out_63 / f["out"])],
            check=True, capture_output=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
