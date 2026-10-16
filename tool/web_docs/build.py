# Builds docs/web/ (static HTML, like WhereWillWeVisit's docs/web) from content.py.
# Edit content.py (or the layout here), then from the repo root:
#   python tool/web_docs/build.py
# The pages are written over; assets/styles.css is edited by hand.
import html
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from content import LANES, COMPONENTS, EXTERNAL, FLOWS, CORE_CARDS, FLOW_CARDS, CARD_TEXT, NOTES  # noqa: E402

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'docs', 'web')
E = html.escape

# Every cited source file must exist.
for cid, c in COMPONENTS.items():
    for f in c['files']:
        assert os.path.exists(os.path.join(ROOT, f)), (cid, f)
    for fl in c['flows']:
        assert fl in FLOWS, (cid, fl)
for fid, fl in FLOWS.items():
    for f in fl['files']:
        assert os.path.exists(os.path.join(ROOT, f)), (fid, f)
    for st in fl['steps']:
        assert st[3] is None or st[3] in COMPONENTS, (fid, st[3])

SUB = {
    'target-camera': 'interface · CameraFrame',
    'live-camera': 'back camera via the plugin',
    'recorded-camera': 'Live test recordings',
    'recording-analysis-feed': 'every frame of a clip, in order',
    'cropped-camera': 'one board\'s square',
    'queued-camera': 'every live crop, in order',
    'throw-watcher': 'motion → throw events',
    'throw-classifier': 'stuck · bounce · fell out · visit',
    'quick-draw-watcher': 'both boards, every frame',
    'play-boards-watcher': 'Play on two boards',
    'quick-draw-judge': 'first to stick wins',
    'start-signal': '5 beeps, a pause, go',
    'target-model': 'ring scores 5 … 0',
    'game-session': '3, 5 or 9 rounds × 3 throws',
    'game-history': 'finished games, one JSON file',
    'auth-service': 'interface only',
    'ring-locator': 'rings → ellipses',
    'tapped-target-locator': 'the board at a tap',
    'target-calibration': 'the locked rings',
    'target-mapping': 'pixel → target point',
    'motion-detector': 'episodes and impact',
    'entry-point': 'where the blade went in',
    'signal-sounds': 'beep · go · chime',
    'providers': 'Riverpod: each layer behind a provider, so tests swap in fakes',
}

FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">\n'
         '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
         '<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">')


def head(title, css):
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{E(title)} — Thrower App</title>
{FONTS}
<link rel="stylesheet" href="{css}">
</head>
<body>
<div class="page">
'''


def eyebrow(lane, text):
    return (f'<span class="eyebrow"><span class="swatch" style="background:var(--{lane});display:inline-block;'
            f'margin-right:6px;border-radius:2px;width:9px;height:9px;"></span>{E(text)}</span>')


def tail(colophon):
    return f'''
  <footer class="colophon">{colophon}</footer>
</div>
</body>
</html>
'''


GLYPH = {
    'ui': '<rect x="6" y="2.5" width="8" height="15" rx="1.8"/><line x1="9" y1="15" x2="11" y2="15"/>',
    'wiring': '<path d="M7,2 V6 M13,2 V6 M5,6 H15 V10 A5,5 0 0 1 5,10 Z M10,15 V18"/>',
    'camera': '<rect x="2.5" y="6" width="15" height="10" rx="2"/><path d="M7,6 L8.5,3.5 H11.5 L13,6"/><circle cx="10" cy="11" r="3"/>',
    'game': '<circle cx="10" cy="10" r="6.5"/><path d="M10,1.5 V5.5 M10,14.5 V18.5 M1.5,10 H5.5 M14.5,10 H18.5"/>',
    'vision': '<path d="M1.8,10 Q10,2.5 18.2,10 Q10,17.5 1.8,10 Z"/><circle cx="10" cy="10" r="2.6"/>',
    'scoring': '<circle cx="10" cy="10" r="7.5"/><circle cx="10" cy="10" r="4.5"/><circle cx="10" cy="10" r="1.4" fill="#fff"/>',
    'sound': '<path d="M3,8 H6.5 L11,4 V16 L6.5,12 H3 Z"/><path d="M13.5,7 A4,4 0 0 1 13.5,13 M15.5,5 A7,7 0 0 1 15.5,15"/>',
    'history': '<circle cx="10" cy="10" r="7.5"/><path d="M10,5.5 V10 L13,12"/>',
    'auth': '<rect x="4.5" y="9" width="11" height="8.5" rx="1.5"/><path d="M7,9 V6.5 A3,3 0 0 1 13,6.5 V9"/>',
    'external': '<rect x="5" y="5" width="10" height="10" rx="1.5"/><path d="M8,2 V5 M12,2 V5 M8,15 V18 M12,15 V18 M2,8 H5 M2,12 H5 M15,8 H18 M15,12 H18"/>',
}


def badge(x, y, lane, size=22):
    """A rounded square in the layer's colour with its white glyph."""
    lane = 'external' if lane == 'native' else lane
    k = size / 20 * 0.8
    off = size * 0.1
    return (f'<rect x="{x}" y="{y}" width="{size}" height="{size}" rx="6" style="fill:var(--{lane})"></rect>'
            f'<g transform="translate({x + off},{y + off}) scale({k})" fill="none" stroke="#fff" stroke-width="1.7" '
            f'stroke-linecap="round" stroke-linejoin="round">{GLYPH[lane]}</g>')


def node(x, y, w, h, lane, title, sub, href=None, dashed=False, title_size=12, tip=None):
    if dashed:
        rect = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" style="fill:var(--surface-2);stroke:var(--external)" '
                f'stroke-width="1.4" stroke-dasharray="5 4"></rect>')
        colour = 'var(--external)'
    else:
        rect = (f'<rect class="node-box" x="{x}" y="{y}" width="{w}" height="{h}" rx="9" '
                f'style="fill:var(--node-fill);stroke:var(--{lane})" stroke-width="1.6"></rect>')
        colour = f'var(--{lane})'
    bs = 22
    tx = x + 12 + bs + 9
    ty = y + h / 2 - (2 if sub else -4)
    t = (f'<text x="{tx}" y="{ty}" style="font-family:\'IBM Plex Mono\';font-size:{title_size}px;'
         f'font-weight:600;fill:{colour}">{E(title)}</text>')
    s = (f'<text x="{tx}" y="{ty + 14}" style="font-family:\'IBM Plex Sans\';font-size:9.5px;'
         f'fill:var(--text-dim)">{E(sub)}</text>') if sub else ''
    tooltip = f'<title>{E(tip)}</title>' if tip else ''
    g = f'<g>{tooltip}{rect}{badge(x + 12, y + (h - bs) / 2, "external" if dashed else lane, bs)}{t}{s}</g>'
    if href and not dashed:
        return f'<a class="node-link" href="{href}" aria-label="{E(title)}">{g}</a>'
    return g


def lane_box(x, y, w, h, lane, label):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" style="fill:none;stroke:var(--border)" stroke-width="1.2"></rect>'
            f'<text x="{x + 14}" y="{y + 20}" style="font-family:\'IBM Plex Mono\';font-size:11px;font-weight:600;'
            f'letter-spacing:0.06em;fill:var(--{lane})">{E(label.upper())}</text>')


def arrow(x1, y1, x2, y2, label=None, lx=None):
    a = (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" style="stroke:var(--text-faint)" stroke-width="1.5" '
         f'marker-end="url(#arrow)"></line>')
    if label:
        a += (f'<text x="{(lx if lx is not None else x1 + 8)}" y="{(y1 + y2) / 2 + 4}" style="font-family:\'IBM Plex Sans\';'
              f'font-size:10px;fill:var(--text-faint)">{E(label)}</text>')
    return a


DEFS = ('<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" style="fill:var(--text-faint)"></path></marker></defs>')


def lane_label(lane):
    name, where = LANES[lane]
    return name if where == 'external' else f'{name} · {where}'


# ---------- overview diagram ----------
def overview_svg():
    W = 1200
    parts = []
    y = 20
    # UI row
    screens = ['HomeScreen', 'PlayScreen', 'CalibrationScreen', 'LiveTestScreen', 'QuickDrawScreen', 'LiveQuickDrawScreen']
    subs = ['Play · Quick draw · …', 'rounds of 3, 1 or 2 players', 'find, adjust, lock', 'the recordings', 'the recorded duel', 'the live duel']
    parts.append(lane_box(20, y, W - 40, 100, 'ui', lane_label('ui')))
    bw = (W - 40 - 32 - 5 * 12) / 6
    for i, (s, sub) in enumerate(zip(screens, subs)):
        parts.append(node(36 + i * (bw + 12), y + 36, bw, 48, 'ui', s, sub, 'components/screens.html', title_size=10.5, tip=COMPONENTS['screens']['dek']))
    y += 100
    parts.append(arrow(W / 2, y + 2, W / 2, y + 34, 'ref.watch / ref.read', W / 2 + 10))
    y += 36
    parts.append(lane_box(20, y, W - 40, 86, 'wiring', lane_label('wiring')))
    parts.append(node(36, y + 30, W - 72, 44, 'wiring', 'Providers', SUB['providers'], 'components/providers.html', tip=COMPONENTS['providers']['dek']))
    y += 86
    parts.append(arrow(W / 2, y + 2, W / 2, y + 34))
    y += 36
    cols = [
        ('camera', 20, 330, ['target-camera', 'live-camera', 'recorded-camera', 'recording-analysis-feed', 'cropped-camera', 'queued-camera']),
        ('game', 365, 330, ['throw-watcher', 'throw-classifier', 'quick-draw-watcher', 'quick-draw-judge', 'start-signal', 'play-boards-watcher']),
        ('scoring', 710, 260, ['target-model', 'game-session']),
        ('auth', 985, 195, ['auth-service']),
    ]
    bh, gap = 46, 10
    h = 36 + 6 * (bh + gap) + 6
    for lane, x, w, ids in cols:
        parts.append(lane_box(x, y, w, h, lane, LANES[lane][0] + ' · ' + LANES[lane][1]))
        for i, cid in enumerate(ids):
            c = COMPONENTS[cid]
            name = 'ThrowTracker' if cid == 'throw-classifier' else c['name']
            parts.append(node(x + 14, y + 34 + i * (bh + gap), w - 28, bh, lane, name, SUB[cid], f'components/{cid}.html', tip=c['dek']))
    parts.append(arrow(352, y + 34 + bh / 2, 377, y + 34 + bh / 2))  # camera → game
    parts.append(arrow(697, y + 34 + bh / 2, 722, y + 34 + bh / 2))  # game → scoring
    y += h
    parts.append(arrow(185, y + 2, 185, y + 34, 'CameraFrame (data only)', 195))
    parts.append(arrow(530, y + 2, 530, y + 34, 'frames, episodes', 540))
    y += 36
    vis = ['ring-locator', 'tapped-target-locator', 'target-calibration', 'target-mapping', 'motion-detector', 'entry-point']
    parts.append(lane_box(20, y, W - 40, 100, 'vision', lane_label('vision')))
    for i, cid in enumerate(vis):
        parts.append(node(36 + i * (bw + 12), y + 36, bw, 48, 'vision', COMPONENTS[cid]['name'], SUB[cid], f'components/{cid}.html', title_size=11, tip=COMPONENTS[cid]['dek']))
    y += 120
    parts.append(lane_box(20, y, 330, 156, 'sound', lane_label('sound')))
    parts.append(node(34, y + 36, 302, 48, 'sound', 'SignalSounds', SUB['signal-sounds'], 'components/signal-sounds.html', tip=COMPONENTS['signal-sounds']['dek']))
    parts.append(lane_box(365, y, 330, 156, 'history', lane_label('history')))
    parts.append(node(379, y + 36, 302, 48, 'history', 'GameHistory', SUB['game-history'], 'components/game-history.html', tip=COMPONENTS['game-history']['dek']))
    parts.append(lane_box(710, y, W - 730, 156, 'external', lane_label('native')))
    ew = (W - 730 - 28 - 12) / 2
    for i, (t, s) in enumerate(EXTERNAL):
        parts.append(node(724 + (i % 2) * (ew + 12), y + 36 + (i // 2) * 56, ew, 48, 'external', t, s, dashed=True))
    y += 156
    parts.append(arrow(W / 2, y + 2, W / 2, y + 34, 'deferred: no network calls today', W / 2 + 10))
    y += 36
    parts.append(node(W / 2 - 190, y, 380, 48, 'external', 'Backend + accounts: not chosen', 'backlog #4', dashed=True))
    y += 68
    label = ('Layered architecture of Thrower App. The UI screens read every layer through Riverpod providers. Below them, the camera '
             'layer (TargetCamera and its live, recorded, cropped and queued implementations) feeds the game layer (ThrowWatcher, '
             'ThrowTracker, QuickDrawWatcher, judgeQuickDraw, StartSignal, PlayBoardsWatcher), which scores through the scoring layer (TargetModel, '
             'GameSession). Vision functions, pure Dart, find the rings, the tapped boards, motion and the entry point. Sound plays the '
             'start signal. History keeps finished games in a file on the phone. Plugins: camera, audioplayers, path_provider and the Flutter image codec. No backend yet.')
    return (f'<svg viewBox="0 0 {W} {y}" role="img" aria-label="{E(label)}">{DEFS}' + ''.join(parts) + '</svg>'), W


# ---------- flow pipeline diagram ----------
def flow_svg(fl):
    W = 820
    parts = []
    y = 20
    bw = 560
    x = (W - bw) / 2
    for i, (lane, title, lines, cid, label) in enumerate(fl['steps']):
        h = 40 + 15 * len(lines)
        dashed = lane == 'native'
        href = f'../components/{cid}.html' if cid else None
        if dashed:
            rect = (f'<rect x="{x}" y="{y}" width="{bw}" height="{h}" rx="8" style="fill:var(--surface-2);stroke:var(--external)" '
                    f'stroke-width="1.4" stroke-dasharray="5 4"></rect>')
            colour = 'var(--external)'
        else:
            rect = (f'<rect class="node-box" x="{x}" y="{y}" width="{bw}" height="{h}" rx="8" '
                    f'style="fill:var(--node-fill);stroke:var(--{lane})" stroke-width="1.8"></rect>')
            colour = f'var(--{lane})'
        tag = (f'<text x="{x + bw - 14}" y="{y + 27}" text-anchor="end" style="font-family:\'IBM Plex Mono\';font-size:9.5px;'
               f'letter-spacing:0.06em;fill:var(--text-faint)">{E(LANES[lane][0].upper())}</text>')
        t = (f'<text x="{x + 46}" y="{y + 27}" style="font-family:\'IBM Plex Mono\';font-size:12.5px;font-weight:600;'
             f'fill:{colour}">{E(title)}</text>')
        ls = ''.join(f'<text x="{x + 46}" y="{y + 46 + 15 * j}" style="font-family:\'IBM Plex Sans\';font-size:11px;'
                     f'fill:var(--text-dim)">{E(line)}</text>' for j, line in enumerate(lines))
        tip = f'<title>{E(COMPONENTS[cid]["dek"])}</title>' if cid else ''
        g = f'<g>{tip}{rect}{badge(x + 14, y + 12, lane, 22)}{tag}{t}{ls}</g>'
        parts.append(f'<a class="node-link" href="{href}" aria-label="{E(title)}">{g}</a>' if href and not dashed else g)
        y += h
        if i < len(fl['steps']) - 1:
            parts.append(arrow(W / 2, y + 2, W / 2, y + 36, label, W / 2 + 10))
            y += 38
    y += 20
    label = fl['title'] + ': ' + ' → '.join(s[1] for s in fl['steps'])
    return f'<svg viewBox="0 0 {W} {y}" role="img" aria-label="{E(label)}">{DEFS}' + ''.join(parts) + '</svg>', W


def card(href, lane, cat, title, text):
    return f'''    <a class="flow-card" href="{href}">
      <div class="cat"><span class="swatch" style="background:var(--{lane})"></span>{E(cat)}</div>
      <h3>{E(title)}</h3>
      <p>{E(text)}</p>
      <span class="more">Open →</span>
    </a>
'''


def write(path, text):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


# ---------- index ----------
svg, w = overview_svg()
legend = ''.join(f'<span class="legend-item"><span class="swatch" style="background:var(--{k})"></span>{E(v[0])}</span>'
                 for k, v in LANES.items() if k != 'native')
legend += '<span class="legend-item"><span class="swatch dashed"></span>Plugins / external</span>'
rings = ''.join(f'<circle cx="60" cy="60" r="{r}" style="fill:var(--{c})"></circle>' for r, c in
                [(52, 'board-b'), (42, 'board-a'), (32, 'board-b'), (22, 'board-a'), (11, 'board-b')])
knife = ('<g transform="rotate(-35 64 46)"><rect x="60" y="2" width="8" height="28" rx="3" style="fill:var(--knife-handle)"></rect>'
         '<path d="M61,30 L67,30 L66.2,47 L64,51 L61.8,47 Z" style="fill:var(--knife-blade)"></path></g>')
HERO = (f'<svg class="hero-board" viewBox="0 0 120 120" aria-hidden="true">'
        f'<circle cx="60" cy="60" r="58" style="fill:var(--board-bark)"></circle>{rings}{knife}</svg>')
idx = head('App Architecture', 'assets/styles.css') + f'''
  <header class="title-block hero">
    {HERO}
    <span class="eyebrow">Thrower App · Architecture Reference</span>
    <h1>App Architecture</h1>
    <p class="dek">
      A Flutter app for iOS and Android. A phone on a static mount, off to the side of the throwing lane, watches a
      5-ring board (5 for the inner ring down to 1 for the outer) and scores each knife thrown at it. Everything runs on
      the phone; there is no backend yet. Click any solid box in the diagram for what that component is; click a card
      below it for the full flow it's part of.
    </p>
  </header>

  <div class="legend" aria-hidden="true">{legend}</div>
  <p class="legend-note">
    Each layer depends only on the ones below it. Vision and scoring are pure Dart, so they run in background isolates
    and in tests on a PC. Dashed boxes are plugins or things not built yet, and aren't clickable.
  </p>

  <figure>
    <div class="diagram-wrap" style="--svg-width:{w}px">
{svg}
    </div>
    <figcaption>
      Names match the code. The vault's ASCII versions are <code>docs/thrower/Architecture/System Diagram.md</code> and
      <code>Data Flow.md</code>; terms are defined in <code>Glossary.md</code>.
    </figcaption>
  </figure>

  <h2 class="section-heading">Core mechanisms</h2>
  <div class="flow-grid">
{''.join(card(f'flows/{f}.html', FLOWS[f]['lane'], 'Core mechanism', FLOWS[f]['title'], CARD_TEXT[f]) for f in CORE_CARDS)}  </div>

  <h2 class="section-heading">Game flows</h2>
  <div class="flow-grid">
{''.join(card(f'flows/{f}.html', FLOWS[f]['lane'], 'Game flow', FLOWS[f]['title'], CARD_TEXT[f]) for f in FLOW_CARDS)}  </div>

  <h2 class="section-heading">Operational notes</h2>
  <div class="notes-grid">
{''.join('    <div><h4>' + E(t) + '</h4><ul>' + ''.join('<li>' + li + '</li>' for li in items) + '</ul></div>' + chr(10) for t, items in NOTES)}  </div>
''' + tail('lib/providers.dart · lib/ui · lib/camera · lib/game · lib/vision · lib/scoring · lib/sound · lib/auth')
write('index.html', idx)

# ---------- flows ----------
for fid, fl in FLOWS.items():
    svg, w = flow_svg(fl)
    used = sorted({s[3] for s in fl['steps'] if s[3]}, key=list(COMPONENTS).index)
    page = head(fl['title'], '../assets/styles.css') + f'''  <nav class="breadcrumb"><a href="../index.html">← Architecture overview</a></nav>

  <header class="title-block">
    {eyebrow(fl['lane'], ('Core mechanism' if fl['cat'] == 'core' else 'Game flow'))}
    <h1>{E(fl['title'])}</h1>
    <p class="dek">{E(fl['dek'])}</p>
  </header>

  <div class="detail-body">
{''.join('    <p>' + p + '</p>' + chr(10) for p in fl['body'])}  </div>

  <div class="legend" aria-hidden="true" style="margin-top:0;">
    <span class="legend-item">→ the next step (label: what's passed on)</span>
    <span class="legend-item">click a box for its component</span>
  </div>

  <figure>
    <div class="diagram-wrap" style="--svg-width:{w}px">
{svg}
    </div>
    <figcaption>{E(fl['caption'])}</figcaption>
  </figure>

  <h2 class="section-heading">Components</h2>
  <div class="used-in-grid">
{''.join(card(f'../components/{c}.html', COMPONENTS[c]['lane'], LANES[COMPONENTS[c]['lane']][0], COMPONENTS[c]['name'], COMPONENTS[c]['dek']) for c in used)}  </div>
''' + tail(' · '.join(fl['files']))
    write(f'flows/{fid}.html', page)

# ---------- components ----------
for cid, c in COMPONENTS.items():
    lane = c['lane']
    funcs = ''
    if c['functions']:
        funcs = ('  <h2 class="section-heading">Functions</h2>\n  <dl class="functions">\n' +
                 ''.join(f'    <div><dt><code>{E(n)}</code></dt><dd>{E(d)}</dd></div>\n' for n, d in c['functions']) +
                 '  </dl>\n\n')
    used = ''.join(card(f'../flows/{f}.html', FLOWS[f]['lane'], 'Core mechanism' if FLOWS[f]['cat'] == 'core' else 'Game flow',
                        FLOWS[f]['title'], CARD_TEXT[f]) for f in c['flows'])
    used_block = (f'  <h2 class="section-heading">Used in</h2>\n  <div class="used-in-grid">\n{used}  </div>\n' if used else
                  '  <h2 class="section-heading">Used in</h2>\n  <p class="detail-body">No flow yet.</p>\n')
    files = ''.join(f'<code>{E(f)}</code><br>' for f in c['files'])
    page = head(c['name'], '../assets/styles.css') + f'''  <nav class="breadcrumb"><a href="../index.html">← Architecture overview</a></nav>

  <header class="title-block">
    {eyebrow(lane, LANES[lane][0] + ' · Component')}
    <h1>{E(c['name'])}</h1>
    <p class="dek">{E(c['dek'])}</p>
  </header>

  <dl class="facts-strip">
    <div><dt>Type</dt><dd>{E(c['type'])}</dd></div>
    <div><dt>Defined in</dt><dd>{files}</dd></div>
    <div><dt>Used when</dt><dd>{E(c['trigger'])}</dd></div>
  </dl>

  <div class="detail-body">
{''.join('    <p>' + p + '</p>' + chr(10) for p in c['body'])}  </div>

{funcs}{used_block}''' + tail(' · '.join(c['files']))
    write(f'components/{cid}.html', page)

print('index + %d flows + %d components' % (len(FLOWS), len(COMPONENTS)))
