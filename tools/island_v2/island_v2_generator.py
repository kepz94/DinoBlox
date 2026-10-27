#!/usr/bin/env python3
"""Island v2 generator v1.0 (Dino Arcade) -> tools/island_v2/payloads/*.luau + tools/island_v2/preview.png

Builds the data for Workspace.DinoIsland 2.0 from the user's reference photo (tools/island_v2/reference_photo.webp,
an aerial view: ocean north-west, central meadow, three lakes, grey rock outcrops, dense forest), turned into a
1024 x 1024-stud island in the game's blocky studded style (island 1.0 / 1.1 palette and shapes).

Pipeline (deterministic: no randomness except numpy RandomState(seed) below):
1. Classify the photo per pixel (smoothed 5 px): ocean / lake / forest / meadow / rock.
   Ocean = the dark-blue component(s) touching the photo border; enclosed dark water = lake.
2. Grid: 128 x 128 cells of CELL = 8 studs over x, z in [-512, 512] (photo 513 px -> 4 px per cell, majority vote).
   Photo up = -Z (north), photo right = +X (east).
3. Island mask: photo land AND inside a noisy superellipse (|x/R|^4 + |z/R|^4 <= 1, R = 470 +/- 22 studs) so the
   photo's south / east land ends in a coast. Sea holes enclosed by land become lake (>= 6 cells) or land.
   Land specks < 3 cells in the sea are removed (rocky islets of >= 3 cells are kept).
4. Surface types: SAND = land within 2 cells of the sea (not rock); SHALLOWS = sea within 4 cells of land (top -2.2,
   like island 1.0); LAKE = lake cells (bed top -2.2 at the rim, -4.2 inside; named "Shallows" so ShakeOffServer counts
   it as water); MEADOW, FOREST, ROCK from the photo.
5. Heights (top of the ground, studs, multiples of 2 so every step is a 2-stud stair like island 1.0 hills):
   SAND -0.4; MEADOW 0 / 2 (gentle); FOREST rolling hills 0..10 from smooth value noise, faded to 0 within 4 cells of
   any water; ROCK mesas: 2 + 2 * floor(1.6 * d) (d = cells into the rock region), cap 30, so outcrops terrace up.
   Land touching a lake is held at 0 (the lake water top is -0.8, same as the sea).
6. Ground blocks: greedy rectangles of equal (surface, top) cells; each block runs from y = -8 (seabed top) to its top.
7. Placements (studs, with the ground top under each):
   trees  - Poisson-disk on FOREST (jungle 30 % / pine 70 %, spacing 26) + sparse lone jungle trees on MEADOW;
            palms on SAND; none within 2 cells of a lake or on ROCK.
   grass  - tall-grass hunting fields near water: patch centres on flat MEADOW / FOREST cells (top <= 2) within
            3..9 cells of a lake or 2..6 cells of the sea, clustered into fields; each patch = one TallGrass model
            (radius 15) like island 1.1 (BotServer hides by each patch's bounding box).
   rocks  - boulders scattered on ROCK edges and the forest floor.
   bots   - 3 Raptor + 1 TRex spawn markers next to the hunting fields (same counts as island 1.0).
   spawn  - player SpawnLocation on the south beach.
8. Payloads: Luau chunks to paste with execute_luau (tools/island_v2_install.luau has the builder; each payload is
   that builder + one data slice). Manifest: counts per folder + a geometry hash the installer re-computes in Studio.
"""
import math, os, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

VERSION = "1.0"
ISLAND_VERSION = "2.0"
ROOT = os.path.dirname(os.path.abspath(__file__))
PHOTO = os.path.join(ROOT, "reference_photo.webp")
OUT_DIR = os.path.join(ROOT, "payloads")
PREVIEW = os.path.join(ROOT, "preview.png")

CELL = 8
N = 128                     # cells per side
HALF = N * CELL // 2        # 512
SEED = 7
LAKE_GROW = 2               # cells added around each photo lake
SHORE = 2.5                 # meadow ring around lakes (cells)

OCEAN, LAKE, FOREST, MEADOW, ROCK, SAND, SHALLOWS, SEA = range(8)
NAMES = ["Ocean", "Lake", "Forest", "Meadow", "Rock", "Sand", "Shallows", "Sea"]


def classify_photo():
    im = np.asarray(Image.open(PHOTO).convert("RGB")).astype(float)
    sm = np.stack([ndi.uniform_filter(im[..., c], 5) for c in range(3)], -1)
    r, g, b = sm[..., 0], sm[..., 1], sm[..., 2]
    lum = (r + g + b) / 3
    cls = np.full(r.shape, FOREST)
    dark_water = (b > r + 25) & (lum < 70)
    lake = (~dark_water) & (b >= r - 5) & (g > r + 5) & (lum > 70) & (lum < 140) & (np.abs(g - b) < 25)
    meadow = (r > 140) & (g > 130) & (r - b > 35)
    rock = (lum > 105) & (np.abs(r - g) < 15) & (r - b < 35) & (~lake)
    cls[meadow] = MEADOW
    cls[rock] = ROCK
    cls[lake] = LAKE
    # dark water: ocean only where its component touches the border, else it is lake
    lab, n = ndi.label(dark_water)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    for k in range(1, n + 1):
        cls[lab == k] = OCEAN if k in border else LAKE
    return cls


PHOTO_SPAN = 470  # the photo covers x, z in [-PHOTO_SPAN, PHOTO_SPAN]; cells outside sample the photo's edge


def to_grid(cls):
    h, w = cls.shape
    grid = np.zeros((N, N), int)  # [row j (z), col i (x)]

    def px(v, size):
        return int(min(size - 1, max(0, (v + PHOTO_SPAN) / (2 * PHOTO_SPAN) * size)))
    for j in range(N):
        for i in range(N):
            xa, za = -HALF + i * CELL, -HALF + j * CELL
            x0, x1 = px(xa, w), px(xa + CELL, w)
            y0, y1 = px(za, h), px(za + CELL, h)
            block = cls[y0:max(y1, y0 + 1), x0:max(x1, x0 + 1)].ravel()
            grid[j, i] = np.bincount(block, minlength=5).argmax()
    return grid


def cell_center(i, j):
    return -HALF + (i + 0.5) * CELL, -HALF + (j + 0.5) * CELL


def value_noise(seed, scale, octaves=3):
    rng = np.random.RandomState(seed)
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = scale / (2 ** o)
        k = int(math.ceil(N / s)) + 2
        lattice = rng.rand(k, k)
        jj, ii = np.mgrid[0:N, 0:N] / s
        j0, i0 = np.floor(jj).astype(int), np.floor(ii).astype(int)
        fj, fi = jj - j0, ii - i0
        fj, fi = fj * fj * (3 - 2 * fj), fi * fi * (3 - 2 * fi)
        a = lattice[j0, i0] * (1 - fi) + lattice[j0, i0 + 1] * fi
        b = lattice[j0 + 1, i0] * (1 - fi) + lattice[j0 + 1, i0 + 1] * fi
        out += amp * (a * (1 - fj) + b * fj)
        total += amp
        amp *= 0.5
    return out / total


def build_layout():
    photo = to_grid(classify_photo())
    # island mask: noisy superellipse
    jj, ii = np.mgrid[0:N, 0:N]
    x = -HALF + (ii + 0.5) * CELL
    z = -HALF + (jj + 0.5) * CELL
    ang = np.arctan2(z, x)
    rng = np.random.RandomState(SEED)
    phases = rng.rand(4) * 2 * math.pi
    R = 470 + 12 * np.sin(3 * ang + phases[0]) + 7 * np.sin(7 * ang + phases[1]) + 4 * np.sin(13 * ang + phases[2])
    inside = (np.abs(x / R) ** 4 + np.abs(z / R) ** 4) <= 1
    land = (photo != OCEAN) & inside
    # sea holes enclosed by land -> lake (big) or land (small)
    sea = ~land
    lab, n = ndi.label(sea)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    surf = photo.copy()
    for k in range(1, n + 1):
        if k not in border:
            m = lab == k
            if m.sum() >= 6:
                surf[m] = LAKE
                land[m] = True
            else:
                land[m] = True
                surf[m] = np.where(photo[m] == OCEAN, FOREST, photo[m])
    # land specks in the sea
    lab, n = ndi.label(land & (surf != LAKE))
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() < 3:
            land[m] = False
    # tiny lake bits (< 6 cells) -> meadow
    lab, n = ndi.label(land & (surf == LAKE))
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() < 6:
            surf[m] = MEADOW
    surf[~land] = SEA
    surf[land & (surf == OCEAN)] = FOREST
    # majority smoothing of land types (removes 1-cell noise), lakes / sea untouched
    for _ in range(2):
        new = surf.copy()
        counts = np.stack([ndi.uniform_filter((surf == t).astype(float), 3) for t in range(8)], -1)
        landtypes = [FOREST, MEADOW, ROCK]
        best = np.array(landtypes)[np.argmax(counts[..., landtypes], -1)]
        mask = np.isin(surf, landtypes)
        new[mask] = best[mask]
        surf = new
    # lakes: grow LAKE_GROW cells into land (photo lakes are ~50 studs, small next to a 40-stud T-Rex), never closer
    # than 4 cells to the sea; then a grassy MEADOW shore ring SHORE cells wide (rock stays rock)
    sea0 = surf == SEA
    far_from_sea = ndi.distance_transform_edt(~sea0) > 4
    for _ in range(LAKE_GROW):
        grow = ndi.binary_dilation(surf == LAKE) & (surf != SEA) & far_from_sea
        surf[grow] = LAKE
    shore = (ndi.distance_transform_edt(surf != LAKE) <= SHORE) & (surf == FOREST)
    surf[shore] = MEADOW
    sea = surf == SEA
    dist_sea = ndi.distance_transform_edt(~sea)          # land cells: cells to the sea
    dist_land = ndi.distance_transform_edt(sea)          # sea cells: cells to land
    lake = surf == LAKE
    dist_lake = ndi.distance_transform_edt(~lake)
    beach = (~sea) & (~lake) & (dist_sea <= 2.0) & (surf != ROCK)
    surf[beach] = SAND
    surf[sea & (dist_land <= 4.0)] = SHALLOWS
    # heights
    top = np.full((N, N), -8.0)
    noise = value_noise(SEED + 1, 22)
    small = value_noise(SEED + 2, 6)
    water_d = np.minimum(dist_sea, dist_lake)
    fade = np.clip((water_d - 1) / 4.0, 0, 1)
    forest_h = np.clip(np.round((noise - 0.35) * 26 * fade / 2) * 2, 0, 10)
    meadow_h = np.where((small > 0.62) & (fade >= 1), 2.0, 0.0)
    rock_mask = surf == ROCK
    d_in = ndi.distance_transform_edt(rock_mask)
    rock_h = np.minimum(30, 2 + 2 * np.floor(1.6 * (d_in - 1)))
    rock_h = np.where(dist_lake <= 1.5, 0, rock_h)
    top[surf == FOREST] = forest_h[surf == FOREST]
    top[surf == MEADOW] = meadow_h[surf == MEADOW]
    top[rock_mask] = np.maximum(rock_h[rock_mask], 2)
    top[surf == SAND] = -0.4
    top[surf == SHALLOWS] = -2.2
    lake_rim = lake & (ndi.distance_transform_edt(lake) <= 1.5)
    top[lake] = -4.2
    top[lake_rim] = -2.2
    near_lake_land = (~lake) & (~sea) & (dist_lake <= 1.5) & (surf != SAND)
    top[near_lake_land] = 0.0
    top[sea & ~(surf == SHALLOWS)] = -8.0  # open sea: no block (seabed only)
    return surf, top, dict(dist_sea=dist_sea, dist_lake=dist_lake, dist_land=dist_land)


def greedy(surf, top, keyfn):
    """Greedy rectangles of equal key; returns list of (i0, j0, w, d, key)."""
    used = np.zeros((N, N), bool)
    rects = []
    for j in range(N):
        for i in range(N):
            if used[j, i]:
                continue
            k = keyfn(i, j)
            if k is None:
                used[j, i] = True
                continue
            w = 1
            while i + w < N and not used[j, i + w] and keyfn(i + w, j) == k:
                w += 1
            d = 1
            ok = True
            while j + d < N and ok:
                for t in range(w):
                    if used[j + d, i + t] or keyfn(i + t, j + d) != k:
                        ok = False
                        break
                if ok:
                    d += 1
            used[j:j + d, i:i + w] = True
            rects.append((i, j, w, d, k))
    return rects


def cell_of(x, z):
    i = int(math.floor((x + HALF) / CELL))
    j = int(math.floor((z + HALF) / CELL))
    return min(N - 1, max(0, i)), min(N - 1, max(0, j))


def poisson(rng, ok, spacing, tries=30000, existing=()):
    """Dart throwing: points (x, z) with ok(x, z) true, at least `spacing` apart (and from `existing`)."""
    pts = []
    gs = 16.0
    grid = {}  # cell -> [(x, z, keep-out radius)]
    maxr = spacing
    for (ex, ez, esp) in existing:
        grid.setdefault((int(ex // gs), int(ez // gs)), []).append((ex, ez, esp))
        maxr = max(maxr, esp)
    reach = int(math.ceil(maxr / gs)) + 1

    def blocked(x, z):
        gi, gj = int(x // gs), int(z // gs)
        for di in range(-reach, reach + 1):
            for dj in range(-reach, reach + 1):
                for (px, pz, pr) in grid.get((gi + di, gj + dj), ()):
                    if (px - x) ** 2 + (pz - z) ** 2 < pr * pr:
                        return True
        return False
    for _ in range(tries):
        x = rng.uniform(-HALF, HALF)
        z = rng.uniform(-HALF, HALF)
        if not ok(x, z) or blocked(x, z):
            continue
        pts.append((x, z))
        grid.setdefault((int(x // gs), int(z // gs)), []).append((x, z, spacing))
    return pts


def place(surf, top, aux):
    rng = np.random.RandomState(SEED + 10)
    dist_sea, dist_lake = aux["dist_sea"], aux["dist_lake"]
    rock = surf == ROCK
    dist_rock = ndi.distance_transform_edt(~rock)

    def S(x, z):
        i, j = cell_of(x, z)
        return surf[j, i], top[j, i], dist_sea[j, i], dist_lake[j, i], dist_rock[j, i], i, j

    def flat_around(x, z, r):
        # every cell within r studs is land (meadow / forest), top <= 2
        for dx in (-r, 0, r):
            for dz in (-r, 0, r):
                s, t = S(x + dx, z + dz)[:2]
                if s not in (MEADOW, FOREST) or t > 2:
                    return False
        return True

    # 1. tall-grass hunting fields near water (lake shores and the coast). A field is a clearing: the ground under it
    #    becomes MEADOW at top 0 (done here, before the ground is meshed).
    def land_around(x, z, r):
        for dx in (-r, 0, r):
            for dz in (-r, 0, r):
                s = S(x + dx, z + dz)[0]
                if s not in (MEADOW, FOREST):
                    return False
        return True

    def grass_ok(x, z):
        s, t, ds, dl, dr, i, j = S(x, z)
        if s not in (MEADOW, FOREST) or t > 4 or dr < 3:
            return False
        return (2.6 <= dl <= 7 or 3.2 <= ds <= 7) and land_around(x, z, GRASS_R)
    cand = poisson(rng, grass_ok, GRASS_SPACING, tries=80000)
    clusters = []
    left = list(cand)
    while left:
        c = [left.pop(0)]
        grew = True
        while grew:
            grew = False
            for p in list(left):
                if any((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 <= GRASS_LINK ** 2 for q in c):
                    c.append(p)
                    left.remove(p)
                    grew = True
        clusters.append(c)
    lake_fields, sea_fields = [], []
    for c in clusters:
        if len(c) < 3:
            continue
        lakey = sum(1 for p in c if S(*p)[3] <= 7) * 2 >= len(c)
        key = (lambda p: S(*p)[3]) if lakey else (lambda p: S(*p)[2])
        c.sort(key=key)
        f = c[:GRASS_PER_FIELD]
        (lake_fields if lakey else sea_fields).append(f)
    lake_fields.sort(key=lambda f: -len(f))
    sea_fields.sort(key=lambda f: -len(f))
    fields = lake_fields[:GRASS_LAKE_FIELDS] + sea_fields[:GRASS_SEA_FIELDS]
    patches = [p for f in fields for p in f]
    # clear + level the ground under the fields
    for (x, z) in patches:
        r = GRASS_R + 4
        for dx in range(-r, r + 1, 4):
            for dz in range(-r, r + 1, 4):
                if dx * dx + dz * dz <= r * r:
                    i, j = cell_of(x + dx, z + dz)
                    if surf[j, i] in (MEADOW, FOREST):
                        surf[j, i] = MEADOW
                        top[j, i] = 0.0

    # 2. trees (avoid grass fields, water edges and rock)
    keep_out = [(x, z, GRASS_R + 8) for (x, z) in patches]

    def forest_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s == FOREST and ds >= 2.5 and dl >= 3 and dr >= 1.5
    forest_pts = poisson(rng, forest_ok, TREE_SPACING, tries=120000, existing=keep_out)

    def meadow_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s == MEADOW and dl >= 6 and ds >= 4 and dr >= 2
    meadow_pts = poisson(rng, meadow_ok, LONE_SPACING, tries=20000, existing=keep_out + [(x, z, 24) for (x, z) in forest_pts])

    def palm_ok(x, z):
        s, t, ds = S(x, z)[:3]
        return s == SAND and ds <= 1.6
    palm_pts = poisson(rng, palm_ok, PALM_SPACING, tries=40000)[:PALM_MAX]
    trees = []
    for (x, z) in forest_pts:
        trees.append(("jungle" if rng.rand() < JUNGLE_SHARE else "pine", x, z))
    for (x, z) in meadow_pts:
        trees.append(("jungle", x, z))
    for (x, z) in palm_pts:
        trees.append(("palm", x, z))

    # 3. boulders: around the rock outcrops and a few on the forest floor
    def boulder_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s in (FOREST, MEADOW) and dl >= 2.5 and ds >= 2.5 and 1 <= dr <= 3
    tree_out = [(x, z, 8) for (_, x, z) in trees] + [(x, z, GRASS_R + 3) for (x, z) in patches]
    b1 = poisson(rng, boulder_ok, 34, tries=20000, existing=tree_out)

    def boulder2_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s == FOREST and dl >= 3 and ds >= 3
    b2 = poisson(rng, boulder2_ok, 110, tries=20000, existing=tree_out + [(x, z, 30) for (x, z) in b1])
    boulders = []
    for (x, z) in b1 + b2:
        size = (rng.uniform(5, 12), rng.uniform(3, 7), rng.uniform(5, 10))
        boulders.append((x, z, size, rng.uniform(0, 90), int(rng.rand() < 0.5), int(rng.rand() < 0.45)))

    # 4. bot spawns: 3 raptors at the three biggest fields, the T-Rex at the next one (or the meadow centre)
    def field_spawn(f):
        cx = sum(p[0] for p in f) / len(f)
        cz = sum(p[1] for p in f) / len(f)
        best = None
        for k in range(400):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(GRASS_R + 10, GRASS_R + 40)
            x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
            s, t, ds, dl, dr = S(x, z)[:5]
            if s in (MEADOW, FOREST) and t <= 2 and dl >= 2.5 and ds >= 3 and dr >= 2:
                if all((x - p[0]) ** 2 + (z - p[1]) ** 2 > (GRASS_R + 4) ** 2 for p in patches):
                    if all((x - tx) ** 2 + (z - tz) ** 2 > 64 for (_, tx, tz) in trees):
                        best = (x, z)
                        break
        return best or (cx, cz)
    spawns = []
    order = [0, len(lake_fields[:GRASS_LAKE_FIELDS]), 1, 2]  # raptor: biggest lake field, biggest coast field, 2nd lake; T-Rex: 3rd lake
    for k, sp in enumerate(["Raptor", "Raptor", "Raptor", "TRex"]):
        f = fields[min(order[k], len(fields) - 1)]
        x, z = field_spawn(f)
        spawns.append((sp, x, z))

    # 5. player spawn: the flat south-beach sand cell nearest (0, +470)
    best = None
    for j in range(N):
        for i in range(N):
            if surf[j, i] != SAND:
                continue
            nb = surf[max(0, j - 1):j + 2, max(0, i - 1):i + 2]
            if not np.all(np.isin(nb, (SAND, MEADOW, FOREST))):
                continue
            x, z = cell_center(i, j)
            d = (x - 0) ** 2 + (z - 470) ** 2
            if best is None or d < best[0]:
                best = (d, x, z)
    player_spawn = (best[1], best[2])
    return dict(patches=patches, fields=fields, trees=trees, boulders=boulders, spawns=spawns, player_spawn=player_spawn)


GRASS_R = 15          # patch radius (studs)
GRASS_SPACING = 24    # patch centres apart (patches overlap a little -> one continuous field)
GRASS_LINK = 34       # patches within this distance belong to one field
GRASS_PER_FIELD = 7
GRASS_LAKE_FIELDS = 5
GRASS_SEA_FIELDS = 3
TREE_SPACING = 30
LONE_SPACING = 80
PALM_SPACING = 70
PALM_MAX = 24
JUNGLE_SHARE = 0.3


def render_preview(surf, top, pl, path):
    cols = {SEA: (63, 167, 214), SHALLOWS: (201, 181, 126), SAND: (230, 210, 154), LAKE: (40, 120, 170),
            FOREST: (106, 174, 69), MEADOW: (147, 190, 78), ROCK: (138, 141, 145)}
    img = np.zeros((N, N, 3), np.uint8)
    for j in range(N):
        for i in range(N):
            c = np.array(cols[int(surf[j, i])], float)
            if surf[j, i] in (FOREST, MEADOW):
                c = c * (0.85 + 0.15 * top[j, i] / 10)
            elif surf[j, i] == ROCK:
                c = c * (0.7 + 0.5 * top[j, i] / 30)
            img[j, i] = np.clip(c, 0, 255)
    big = Image.fromarray(img).resize((1024, 1024), Image.NEAREST)
    from PIL import ImageDraw
    d = ImageDraw.Draw(big)

    def P(x, z):
        return (x + HALF), (z + HALF)
    for (x, z) in pl["patches"]:
        cx, cz = P(x, z)
        d.ellipse([cx - GRASS_R, cz - GRASS_R, cx + GRASS_R, cz + GRASS_R], fill=(196, 220, 90), outline=(120, 150, 40))
    for (kind, x, z) in pl["trees"]:
        cx, cz = P(x, z)
        r = {"jungle": 11, "pine": 7, "palm": 6}[kind]
        col = {"jungle": (47, 122, 48), "pine": (36, 96, 44), "palm": (79, 168, 60)}[kind]
        d.ellipse([cx - r, cz - r, cx + r, cz + r], fill=col, outline=(25, 60, 25))
    for (x, z, size, yaw, dark, two) in pl["boulders"]:
        cx, cz = P(x, z)
        d.rectangle([cx - size[0] / 2, cz - size[2] / 2, cx + size[0] / 2, cz + size[2] / 2], fill=(110, 113, 117))
    for (sp, x, z) in pl["spawns"]:
        cx, cz = P(x, z)
        d.ellipse([cx - 9, cz - 9, cx + 9, cz + 9], fill=(220, 40, 40) if sp == "TRex" else (240, 140, 30), outline=(0, 0, 0))
    cx, cz = P(*pl["player_spawn"])
    d.rectangle([cx - 9, cz - 9, cx + 9, cz + 9], fill=(255, 255, 255), outline=(0, 0, 0))
    big.save(path)


def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ",".join(f"{k}={lua(x)}" for k, x in v.items()) + "}"
    if isinstance(v, float):
        r = round(v, 1)
        return str(int(r)) if r == int(r) else str(r)
    return str(int(v))


def checksum(b):
    h1, h2 = 0, 7
    for x in b:
        h1 = (h1 * 31 + x) % 2147483647
        h2 = (h2 * 131 + x) % 1000000007
    return f"{len(b)}:{h1}:{h2}"


KIND_ID = {FOREST: 1, MEADOW: 2, ROCK: 3, SAND: 4, SHALLOWS: 5, LAKE: 6}


def write_payloads(surf, top, rects, pl):
    src = open(os.path.join(os.path.dirname(ROOT), "island_v2_install.luau"), encoding="utf-8").read()
    # split the installer at its "--@section NAME" markers; a payload carries common + begin (or guard + its own
    # stage section) + tail, without full-line comments (the repo file is the commented source)
    sections, cur = {}, None
    for line in src.splitlines(True):
        if line.startswith("--@section "):
            cur = line.split()[1]
            sections[cur] = ""
            continue
        if cur and not line.lstrip().startswith("--"):
            sections[cur] += line

    def installer_for(stage):
        parts = ["common"] + (["begin"] if stage == "begin" else ["guard", stage]) + ["tail"]
        return "".join(sections[p] for p in parts)
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        if f.endswith(".luau"):
            os.remove(os.path.join(OUT_DIR, f))
    payloads = []

    def emit(name, stage, data):
        text = (f"-- payload {name} (island_v2_generator {VERSION} -> DinoIsland {ISLAND_VERSION}); generated, do not edit\n"
                f"local STAGE, DATA = {lua(stage)}, {lua(data)}\n" + installer_for(stage))
        path = os.path.join(OUT_DIR, name + ".luau")
        open(path, "w", encoding="utf-8").write(text)
        payloads.append((name, checksum(text.encode("utf-8"))))

    def top_at(x, z):
        i, j = cell_of(x, z)
        return float(top[j, i])
    sx, sz = pl["player_spawn"]
    bots = [(sp, x, top_at(x, z), z) for (sp, x, z) in pl["spawns"]]
    emit("00_begin", "begin", {"generator": VERSION, "spawn": (sx, top_at(sx, sz), sz), "bots": bots})
    flat = []
    for (i, j, w, d, (kind, t)) in rects:
        flat.append((i, j, w, d, KIND_ID[kind], int(round(t * 10))))
    CH = 800
    nchunks = int(math.ceil(len(flat) / CH))
    for c in range(nchunks):
        part = flat[c * CH:(c + 1) * CH]
        emit(f"{1 + c:02d}_ground", "ground", {"chunk": f"{c + 1}/{nchunks}", "rects": [v for r in part for v in r]})
    lakes = greedy(surf, top, lambda i, j: 1 if surf[j, i] == LAKE else None)
    emit("10_water", "water", {"lakes": [v for (i, j, w, d, k) in lakes for v in (i, j, w, d)]})
    boulders = [(x, z, sz_[0], sz_[1], sz_[2], yaw, dark, two) for (x, z, sz_, yaw, dark, two) in pl["boulders"]]
    emit("11_rocks", "rocks", {"boulders": boulders})
    counters = {"jungle": 0, "pine": 0, "palm": 0}
    trees = []
    for (k, x, z) in pl["trees"]:
        counters[k] += 1
        trees.append(({"jungle": 1, "pine": 2, "palm": 3}[k], counters[k], x, z))
    TCH = 140
    tn = int(math.ceil(len(trees) / TCH))
    for c in range(tn):
        emit(f"{20 + c:02d}_trees", "trees", {"chunk": f"{c + 1}/{tn}", "trees": trees[c * TCH:(c + 1) * TCH]})
    patches = []
    n = 0
    for fi, f in enumerate(pl["fields"]):
        for (x, z) in f:
            n += 1
            patches.append((n, fi + 1, x, z))
    emit("30_grass", "grass", {"radius": GRASS_R, "fields": len(pl["fields"]), "patches": patches})
    expect = {"ground": len(flat), "lakes": len(lakes), "boulders": len(boulders), "trees": len(trees),
              "patches": len(patches), "spawns": len(bots)}
    emit("99_finish", "finish", {"expect": expect})
    manifest = {"generator": VERSION, "island": ISLAND_VERSION, "expect": expect, "trees": counters,
                "fields": [len(f) for f in pl["fields"]], "spawn": pl["player_spawn"], "bots": bots,
                "payloads": dict(payloads)}
    json.dump(manifest, open(os.path.join(ROOT, "manifest.json"), "w"), indent=1)
    print("payloads:", ", ".join(f"{n} {c}" for n, c in payloads))


if __name__ == "__main__":
    surf, top, aux = build_layout()
    for t in range(8):
        print(NAMES[t], int((surf == t).sum()))
    pl = place(surf, top, aux)
    rects = greedy(surf, top, lambda i, j: None if surf[j, i] == SEA else (int(surf[j, i]), float(top[j, i])))
    print("ground rects", len(rects))
    kinds = {}
    for (k, x, z) in pl["trees"]:
        kinds[k] = kinds.get(k, 0) + 1
    print("fields", [len(f) for f in pl["fields"]], "patches", len(pl["patches"]), "trees", kinds,
          "boulders", len(pl["boulders"]), "spawns", pl["spawns"], "player", pl["player_spawn"])
    render_preview(surf, top, pl, PREVIEW)
    write_payloads(surf, top, rects, pl)

