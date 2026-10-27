#!/usr/bin/env python3
"""Island v3 generator v1.2 (Dino Arcade) -> tools/island_v3/payloads/*.luau + tools/island_v3/preview.png

DinoIsland 3.0: the island 2.0 layout (tools/island_v2/island_v2_generator.py, kept unchanged) at double size with
elevation, deep lakes and coconut-palm woods.
User: "double the size of the map. there are wayyy too many trees but thats because this map is too small. there needs
  to be elevation as well. this is modeled after the east plains from the isle video game. the lakes on the map will be
  for crocodiles to attack at ... as well as that open field area" ... "the trees themselves should be mostly coconut
  trees. ranging from thick based tall trees to skinnier long ones".
Answers: 2048 x 2048; about 400 trees spread out; hills to ~40, rock ridges to ~60; lakes with a shallow wading rim
  dropping to ~12 studs deep.

Pipeline (deterministic):
1. Photo classes as island 2.0 (ocean / lake / forest / meadow / rock); the photo now spans x, z in [-940, 940].
2. Grid: 128 x 128 cells of CELL = 16 studs over [-1024, 1024] (16, not 8: 2-stud contours on 8-stud cells broke the
   ground into ~14,000 blocks; 16-stud cells give the island 2.0 look at twice the size). Photo up = -Z (north).
   Distances below are in 8-stud units (U = CELL / 8) so they mean the same number of studs as in island 2.0.
3. Island mask: noisy superellipse R = 940 +/- 46. Enclosed sea >= 24 cells -> lake; land specks < 12 cells removed.
   Lakes grow LAKE_GROW cells (not within 4 cells of the sea) and get a MEADOW shore ring SHORE cells wide.
4. Surfaces: SAND = land within 2 cells of the sea (not rock); SHALLOWS = sea within 6 cells of land (top -2.2).
5. Heights (even numbers, so every step is a 2-stud stair):
   targets from large smooth noise (HILL_SCALE cells): FOREST 0..HILL_MAX (40), MEADOW (the open field) 0..MEADOW_MAX (6),
   ROCK = 60 % of the hill + 6 + 3 per cell into the rock, capped at RIDGE_MAX (60).
   Walkable relaxation: water / beach cells are 0; every land cell is capped at (lowest 4-neighbour + step), step 2
   (rock 4), repeated until stable, so ground never rises more than 2 studs per 8-stud cell (rock: 4) and lakes and
   the coast sit in valleys. SAND -0.4, SHALLOWS -2.2.
   Lakes (crocodile ambush): rim ring top -2.8 = 2 studs of water to wade in, then a steeper bowl: the first ring 4 studs
   deeper, each further ring 6 deeper, down to -30.8 = 30 studs of water (user: "the lakes should be deeper" -> ~30,
   steeper bowl). The narrow north-east lake reaches -24.8. Beds are named "Shallows" (ShakeOffServer water test).
6. Ground blocks: greedy rectangles of equal (surface, top); each runs from y = BOTTOM (-36) to its top.
7. Placements: tall-grass fields first (near lakes and the coast, low ground), then trees (85 % coconut palms with a
   per-tree shape t: 0 = thick-based tall ... 1 = skinny long and curved, 15 % island 1.1 jungle trees; beach palms
   lean away from the centre), boulders, 3 raptor + 1 T-Rex bot spawns at fields, player spawn on the south beach.
8. Payloads for tools/island_v3_install.luau (sections common + begin, or guard + stage, + tail), manifest.json.

Changelog:
1.0  first version.
1.1  begin DATA.seabed: the sea floor (top -8) as rectangles that leave out each lake's bounding box (+1 cell); 1.0's
     four seabed quadrants cut through every lake at -8, so the 30-stud lake bowls were only ~7 studs of water.
     Manifest expect.seabed and hashes["00_begin"] added. Nothing else changes (same layout, same data hashes).
1.2  DinoIsland 3.1. User: "connect the two lakes make them one big lake. as well as the elevation part needs to be an
     actual mountain type of build" -> middle + south lakes, ~200 peak on the north ridge, steep cliffs + one trail.
     join_lakes(): the lakes nearest JOIN_LAKE_POINTS are merged by a closing with a JOIN_RADIUS (12-cell) disk (not
     within 4 cells of the sea); depth rings as before (rim -2.8 .. -30.8).
     mountain(): elliptical footprint 340 x 260 around (282, -240) (MOUNTAIN_ROUGH noise for ridges / gullies), cone
     from 8 at the foot, cut into 14-stud cliff bands (light / dark rock per band), summit plateau at 200; one spiral
     trail (new surface TRAIL -> ground kind 7 "Trail") from the south foot to the summit: every 4-connected
     centre-line cell 2 studs higher than the last (walkable like the hills), 2 cells wide. Mountain cells are pinned in
     the walkable relaxation. Each feature has an on/off switch (JOIN_LAKES, MOUNTAIN). Preview: trail colour, rock
     shading scaled to the mountain.
"""
import math, os, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

VERSION = "1.2"
ISLAND_VERSION = "3.1"      # v1.2 (3.0 with generator 1.0 / 1.1)
ROOT = os.path.dirname(os.path.abspath(__file__))
PHOTO = os.path.join(ROOT, "reference_photo.webp")
OUT_DIR = os.path.join(ROOT, "payloads")
PREVIEW = os.path.join(ROOT, "preview.png")

CELL = 16
N = 128                     # cells per side
U = CELL / 8.0              # cell size in 8-stud units (distance thresholds below are in 8-stud units)
HALF = N * CELL // 2        # 1024
SEED = 7
LAKE_GROW = 6               # 8-stud units added around each photo lake (48 studs: bigger crocodile lakes)
SHORE = 3.0                 # meadow ring around lakes (8-stud units)
BOTTOM = -36.0              # every ground block runs from here to its top (below the deepest lake bed)
HILL_SCALE = 30             # cells per hill wave (16-stud cells: ~480 studs)
HILL_MAX = 40
HILL_TARGET = 80            # noise target; the walkable-slope cap keeps real hills at ~40 or below
MEADOW_MAX = 6
RIDGE_MAX = 60
LAKE_RIM_TOP = -2.8         # 2 studs of water at the lake rim
LAKE_DEEP_TOP = -30.8       # 30 studs of water in the middle (user: "the lakes should be deeper" -> ~30)
LAKE_STEP = 4.0             # studs deeper for the first ring inside the rim (user: steeper bowl)
LAKE_STEP_IN = 6.0          # studs deeper per ring after that (so ~250-stud lakes reach -30.8)

OCEAN, LAKE, FOREST, MEADOW, ROCK, SAND, SHALLOWS, SEA = range(8)
NAMES = ["Ocean", "Lake", "Forest", "Meadow", "Rock", "Sand", "Shallows", "Sea", "Trail"]
TRAIL = 8                   # v1.2: the mountain trail surface (ground kind 7 "Trail")

# v1.2 (user: "connect the two lakes make them one big lake" -> middle + south lakes)
JOIN_LAKES = True
JOIN_LAKE_POINTS = ((271, 237), (-16, 534))  # the middle and south lake centres (1.1 layout)
JOIN_RADIUS = 12            # cells: morphological closing radius that fills the land between the two lakes
# v1.2 (user: "the elevation part needs to be an actual mountain type of build" -> ~200 peak on the north ridge,
#   steep cliffs + one walkable trail)
MOUNTAIN = True
MOUNTAIN_CENTER = (282, -240)   # the north rock ridge (1.1 centre (282, -159)) moved north, away from the joined lake
MOUNTAIN_RX, MOUNTAIN_RZ = 340, 260  # elliptical footprint radii (studs)
MOUNTAIN_BASE = 8           # height at the footprint edge
MOUNTAIN_SUMMIT = 200       # summit plateau height
MOUNTAIN_TIER = 14          # cliff band height: rock faces in 14-stud steps (> the raptor's 11-stud leap); 14 makes the
                            # light / dark rock colour alternate per band
TRAIL_END_RHO = 0.14        # the trail reaches the summit at this normalised radius
TRAIL_START_DEG = 100       # trail foot on the south side (towards the lake and the meadow)
TRAIL_STEP = 2              # studs per trail cell (same walkable 2-stud stair as the hills)
MOUNTAIN_ROUGH = 0.12       # +/- share of the radius: noise that gives the cliffs ridges and gullies (not on the trail)


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


PHOTO_SPAN = 940  # the photo covers x, z in [-PHOTO_SPAN, PHOTO_SPAN]; cells outside sample the photo's edge


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


def join_lakes(surf, far_from_sea):
    """v1.2: the lake components nearest JOIN_LAKE_POINTS become one lake: a closing (dilate, then erode) with a disk of
    JOIN_RADIUS cells fills the land between them; never within 4 cells of the sea (same rule as the lake growth)."""
    lab, n = ndi.label(surf == LAKE)
    jj, ii = np.mgrid[0:N, 0:N]
    cx, cz = -HALF + (ii + 0.5) * CELL, -HALF + (jj + 0.5) * CELL
    ids = []
    for (px, pz) in JOIN_LAKE_POINTS:
        d2 = np.where(lab > 0, (cx - px) ** 2 + (cz - pz) ** 2, np.inf)
        ids.append(int(lab.flat[int(np.argmin(d2))]))
    assert len(set(ids)) == len(ids), "join points hit the same lake"
    pair = np.isin(lab, ids)
    r = JOIN_RADIUS
    disk = (np.mgrid[-r:r + 1, -r:r + 1] ** 2).sum(0) <= r * r
    pad = r + 1
    closed = ndi.binary_erosion(ndi.binary_dilation(np.pad(pair, pad), disk), disk)[pad:-pad, pad:-pad]
    add = closed & ~pair & (surf != SEA) & far_from_sea
    surf[add] = LAKE
    lab2, _ = ndi.label(surf == LAKE)
    joined = set(int(v) for v in np.unique(lab2[pair]))
    assert len(joined) == 1, "lakes not joined"


def mountain(surf):
    """v1.2: the mountain. Footprint: ellipse MOUNTAIN_RX x MOUNTAIN_RZ around MOUNTAIN_CENTER on land (not lake, sea,
    shallows or sand). Cone height BASE (edge) .. cone apex, cut into MOUNTAIN_TIER-stud cliff bands, capped at the
    summit; summit plateau (rho <= TRAIL_END_RHO + 0.05) at MOUNTAIN_SUMMIT. One trail: a spiral from the south foot
    (TRAIL_START_DEG) up to the summit, each 4-connected centre-line cell TRAIL_STEP higher than the one before, plus
    the cell next to it towards the centre at the same height (2 cells = 32 studs wide). The spiral's radius follows
    the cone: rho = 1 - (h - BASE) / (apex - BASE), so the trail stays at the cone surface. Returns heights (NaN off
    the mountain); sets surf ROCK / TRAIL."""
    mx, mz = MOUNTAIN_CENTER
    apex = MOUNTAIN_BASE + (MOUNTAIN_SUMMIT - MOUNTAIN_BASE) / (1 - TRAIL_END_RHO)
    jj, ii = np.mgrid[0:N, 0:N]
    cx, cz = -HALF + (ii + 0.5) * CELL, -HALF + (jj + 0.5) * CELL
    rho = np.sqrt(((cx - mx) / MOUNTAIN_RX) ** 2 + ((cz - mz) / MOUNTAIN_RZ) ** 2)
    rough = rho * (1 + MOUNTAIN_ROUGH * (2 * value_noise(SEED + 5, 6, octaves=2) - 1))  # ridges / gullies
    foot = (np.minimum(rho, rough) <= 1) & ~np.isin(surf, (LAKE, SEA, SHALLOWS, SAND))
    cone = MOUNTAIN_BASE + (apex - MOUNTAIN_BASE) * (1 - np.clip(rough, 0, 1))
    tiers = np.maximum(MOUNTAIN_BASE, np.floor(cone / MOUNTAIN_TIER) * MOUNTAIN_TIER)
    mh = np.where(foot, np.minimum(tiers, MOUNTAIN_SUMMIT - MOUNTAIN_TIER), np.nan)
    summit = foot & (rho <= TRAIL_END_RHO + 0.05)
    mh[summit] = MOUNTAIN_SUMMIT
    surf[foot] = ROCK
    # trail centre line
    line, hts = [], []
    theta = math.radians(TRAIL_START_DEG)
    h = MOUNTAIN_BASE

    def cell_at(r, th):
        return cell_of(mx + MOUNTAIN_RX * r * math.cos(th), mz + MOUNTAIN_RZ * r * math.sin(th))
    cur = cell_at(0.95, theta)                       # foot cell just inside the footprint edge
    line.append(cur)
    hts.append(h)
    guard = 0
    while h < MOUNTAIN_SUMMIT - TRAIL_STEP:
        guard += 1
        assert guard < 200000, "trail did not reach the summit"
        r = 1 - (h - MOUNTAIN_BASE) / (apex - MOUNTAIN_BASE)
        theta += 1.5 / max(40.0, (MOUNTAIN_RX + MOUNTAIN_RZ) / 2 * r)   # ~1.5 studs along the spiral per step
        nxt = cell_at(min(0.95, r), theta)
        if nxt == cur or nxt in line:
            continue
        # 4-connected walk cur -> nxt through cells not on the line yet (x first, else z first); the centre line never
        # jumps a cell, so every trail step is exactly TRAIL_STEP
        walks = []
        for order in ("xz", "zx"):
            a, b = cur
            path = []
            for ax in order:
                while (a if ax == "x" else b) != (nxt[0] if ax == "x" else nxt[1]):
                    if ax == "x":
                        a += 1 if nxt[0] > a else -1
                    else:
                        b += 1 if nxt[1] > b else -1
                    path.append((a, b))
            walks.append(path)
        free = [p for p in walks if not any(c in line for c in p)]
        if not free:
            continue
        for c in free[0]:
            h += TRAIL_STEP
            line.append(c)
            hts.append(h)
            cur = c
    trail = {}
    for (i, j), th in zip(line, hts):
        trail[(i, j)] = th
    for (i, j), th in zip(line, hts):
        x, z = cell_center(i, j)
        dx, dz = mx - x, mz - z
        L = math.hypot(dx, dz) or 1.0
        k = cell_of(x + dx / L * CELL, z + dz / L * CELL)
        if k not in trail and not summit[k[1], k[0]]:
            trail[k] = th
    for (i, j), th in trail.items():
        assert foot[j, i], "trail leaves the mountain footprint at %s (rho %.3f, surf %s)" % (cell_center(i, j), rho[j, i], NAMES[surf[j, i]])
        surf[j, i] = TRAIL
        mh[j, i] = th
    last = line[-1]
    assert summit[max(0, last[1] - 1):last[1] + 2, max(0, last[0] - 1):last[0] + 2].any(), "trail does not reach the summit"
    MOUNTAIN_INFO.update(trail_cells=len(trail), line_cells=len(line), trail_top=hts[-1], apex=apex,
                         foot=int(foot.sum()), start=cell_center(*line[0]))
    return mh


MOUNTAIN_INFO = {}


def build_layout():
    photo = to_grid(classify_photo())
    # island mask: noisy superellipse
    jj, ii = np.mgrid[0:N, 0:N]
    x = -HALF + (ii + 0.5) * CELL
    z = -HALF + (jj + 0.5) * CELL
    ang = np.arctan2(z, x)
    rng = np.random.RandomState(SEED)
    phases = rng.rand(4) * 2 * math.pi
    R = 940 + 24 * np.sin(3 * ang + phases[0]) + 14 * np.sin(7 * ang + phases[1]) + 8 * np.sin(13 * ang + phases[2])
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
            if m.sum() * U * U >= 24:
                surf[m] = LAKE
                land[m] = True
            else:
                land[m] = True
                surf[m] = np.where(photo[m] == OCEAN, FOREST, photo[m])
    # land specks in the sea
    lab, n = ndi.label(land & (surf != LAKE))
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() * U * U < 12:
            land[m] = False
    # tiny lake bits (< 24 cells) -> meadow
    lab, n = ndi.label(land & (surf == LAKE))
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() * U * U < 24:
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
    far_from_sea = ndi.distance_transform_edt(~sea0) * U > 4
    for _ in range(max(1, int(round(LAKE_GROW / U)))):
        grow = ndi.binary_dilation(surf == LAKE) & (surf != SEA) & far_from_sea
        surf[grow] = LAKE
    if JOIN_LAKES:
        join_lakes(surf, far_from_sea)
    shore = (ndi.distance_transform_edt(surf != LAKE) * U <= SHORE) & (surf == FOREST)
    surf[shore] = MEADOW
    sea = surf == SEA
    dist_sea = ndi.distance_transform_edt(~sea) * U      # land cells: distance to the sea (8-stud units)
    dist_land = ndi.distance_transform_edt(sea) * U      # sea cells: distance to land (8-stud units)
    lake = surf == LAKE
    dist_lake = ndi.distance_transform_edt(~lake) * U
    beach = (~sea) & (~lake) & (dist_sea <= 2.0 * U) & (surf != ROCK)
    surf[beach] = SAND
    surf[sea & (dist_land <= 6.0)] = SHALLOWS
    # v1.2: the mountain (rock cells + trail cells, heights pinned for the relaxation below)
    mh = mountain(surf) if MOUNTAIN else np.full((N, N), np.nan)
    pinned = ~np.isnan(mh)
    # heights
    hills = value_noise(SEED + 1, HILL_SCALE)
    hill01 = np.clip((hills - 0.30) / 0.55, 0, 1)
    rock_mask = surf == ROCK
    d_in = ndi.distance_transform_edt(rock_mask)
    target = np.zeros((N, N))
    forest = surf == FOREST
    meadow = surf == MEADOW
    target[forest] = np.minimum(HILL_MAX, hill01 * HILL_TARGET)[forest]
    target[meadow] = np.minimum(MEADOW_MAX, hill01 * HILL_MAX * 0.3)[meadow]
    target[rock_mask] = np.minimum(RIDGE_MAX, hill01 * HILL_MAX * 0.6 + 6 + 10 * d_in)[rock_mask]
    target = np.floor(target / 2) * 2
    fixed = ~(forest | meadow | rock_mask) & ~pinned  # sea, shallows, sand, lake: 0 for the relaxation
    target[fixed] = 0
    target[pinned] = mh[pinned]                     # v1.2: mountain cells keep their heights (never relaxed)
    step = np.where(rock_mask, 6.0, 2.0)            # rock: cliffs (raptors leap 11)
    h = target.copy()
    for _ in range(400):
        pad = np.pad(h, 1, constant_values=0)
        nb = np.minimum(np.minimum(pad[:-2, 1:-1], pad[2:, 1:-1]), np.minimum(pad[1:-1, :-2], pad[1:-1, 2:]))
        new = np.where(fixed, 0, np.where(pinned, target, np.minimum(h, nb + step)))
        if np.array_equal(new, h):
            break
        h = new
    top = np.full((N, N), BOTTOM)
    land_cells = forest | meadow | rock_mask | pinned
    top[land_cells] = h[land_cells]
    top[surf == SAND] = -0.4
    top[surf == SHALLOWS] = -2.2
    d_lake_in = ndi.distance_transform_edt(lake)
    ring = np.ceil(d_lake_in - 1.5)                # 0 = rim, 1 = first ring inside it, ...
    drop = np.where(ring <= 0, 0, LAKE_STEP + LAKE_STEP_IN * np.maximum(0, ring - 1))
    lake_top = np.maximum(LAKE_DEEP_TOP, LAKE_RIM_TOP - drop)
    top[lake] = lake_top[lake]
    top[sea & ~(surf == SHALLOWS)] = BOTTOM  # open sea: no block (seabed only)
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
    dist_rock = ndi.distance_transform_edt(~rock) * U

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

    def low_around(x, z, r):
        # v3: fields only on low ground (every sample within r studs has top <= 6)
        for dx in (-r, 0, r):
            for dz in (-r, 0, r):
                if S(x + dx, z + dz)[1] > 6:
                    return False
        return True

    def grass_ok(x, z):
        s, t, ds, dl, dr, i, j = S(x, z)
        if s not in (MEADOW, FOREST) or t > 4 or dr < 3:
            return False
        return (2.6 <= dl <= 7 or 3.2 <= ds <= 7) and land_around(x, z, GRASS_R) and low_around(x, z, GRASS_R)
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
    # clear the ground under the fields (MEADOW); v3 keeps its height (blades sit on the ground by a ray)
    for (x, z) in patches:
        r = GRASS_R + 4
        for dx in range(-r, r + 1, 4):
            for dz in range(-r, r + 1, 4):
                if dx * dx + dz * dz <= r * r:
                    i, j = cell_of(x + dx, z + dz)
                    if surf[j, i] in (MEADOW, FOREST):
                        surf[j, i] = MEADOW

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
    # v3: tree type by ground height (user: coconut trees near the coast line, other trees at higher elevation):
    #   top + jitter <= PALM_TOP -> coconut palm, <= JUNGLE_TOP -> jungle tree, above -> pine; jitter +/- BAND_JITTER
    #   blends the band edges. Palm shape t (0 thick-based tall .. 1 skinny long) per tree; beach palms lean away
    #   from the centre (lean yaw), inland palms lean a random way.
    trees, shapes = [], []

    def kind_at(x, z):
        t = S(x, z)[1] + rng.uniform(-BAND_JITTER, BAND_JITTER)
        return "palm" if t <= PALM_TOP else ("jungle" if t <= JUNGLE_TOP else "pine")
    for (x, z) in forest_pts + meadow_pts:
        k = kind_at(x, z)
        trees.append((k, x, z))
        shapes.append((rng.uniform(0, 1), rng.uniform(0, 360)) if k == "palm" else None)
    for (x, z) in palm_pts:
        trees.append(("palm", x, z))
        shapes.append((rng.uniform(0, 1), math.degrees(math.atan2(-x, -z)) + rng.uniform(-35, 35)))

    # 3. boulders: around the rock outcrops and a few on the forest floor
    def boulder_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s in (FOREST, MEADOW) and dl >= 2.5 and ds >= 2.5 and 1 <= dr <= 3
    tree_out = [(x, z, 8) for (_, x, z) in trees] + [(x, z, GRASS_R + 3) for (x, z) in patches]
    b1 = poisson(rng, boulder_ok, 60, tries=40000, existing=tree_out)

    def boulder2_ok(x, z):
        s, t, ds, dl, dr = S(x, z)[:5]
        return s == FOREST and dl >= 3 and ds >= 3
    b2 = poisson(rng, boulder2_ok, 220, tries=40000, existing=tree_out + [(x, z, 30) for (x, z) in b1])
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
            if s in (MEADOW, FOREST) and t <= 4 and dl >= 2.5 and ds >= 3 and dr >= 2:
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

    # 5. player spawn: the flat south-beach sand cell nearest (0, +940)
    best = None
    for j in range(N):
        for i in range(N):
            if surf[j, i] != SAND:
                continue
            nb = surf[max(0, j - 1):j + 2, max(0, i - 1):i + 2]
            if not np.all(np.isin(nb, (SAND, MEADOW, FOREST))):
                continue
            x, z = cell_center(i, j)
            d = (x - 0) ** 2 + (z - 940) ** 2
            if best is None or d < best[0]:
                best = (d, x, z)
    player_spawn = (best[1], best[2])
    return dict(patches=patches, fields=fields, trees=trees, shapes=shapes, boulders=boulders, spawns=spawns, player_spawn=player_spawn)


GRASS_R = 15          # patch radius (studs)
GRASS_SPACING = 24    # patch centres apart (patches overlap a little -> one continuous field)
GRASS_LINK = 34       # patches within this distance belong to one field
GRASS_PER_FIELD = 10
GRASS_LAKE_FIELDS = 6
GRASS_SEA_FIELDS = 3
TREE_SPACING = 62
LONE_SPACING = 160
PALM_SPACING = 90     # beach palms
PALM_MAX = 60
PALM_TOP = 10         # ground top (studs) up to which trees are coconut palms
JUNGLE_TOP = 24       # ... jungle trees up to here, pines above
BAND_JITTER = 4


def render_preview(surf, top, pl, path):
    # v3: 1024 px for 2048 studs (0.5 px / stud), hill shading from the height field
    cols = {SEA: (63, 167, 214), SHALLOWS: (201, 181, 126), SAND: (230, 210, 154), LAKE: (40, 120, 170),
            FOREST: (106, 174, 69), MEADOW: (147, 190, 78), ROCK: (138, 141, 145), TRAIL: (214, 178, 112)}
    rock_max = max(RIDGE_MAX, float(top[surf == ROCK].max()) if (surf == ROCK).any() else 0)  # v1.2: mountain
    hz = np.where(top < 0, 0, top)
    gy, gx = np.gradient(hz)
    shade = np.clip(1.0 - 0.06 * (gx + gy), 0.65, 1.25)
    img = np.zeros((N, N, 3), np.uint8)
    for j in range(N):
        for i in range(N):
            k = int(surf[j, i])
            c = np.array(cols[k], float)
            if k in (FOREST, MEADOW):
                c = c * (0.8 + 0.35 * top[j, i] / HILL_MAX) * shade[j, i]
            elif k == ROCK:
                c = c * (0.7 + 0.5 * top[j, i] / rock_max) * shade[j, i]
            elif k == TRAIL:
                c = c * (0.75 + 0.35 * top[j, i] / rock_max)
            elif k == LAKE:
                c = c * (1.15 + 0.06 * top[j, i])
            img[j, i] = np.clip(c, 0, 255)
    big = Image.fromarray(img).resize((1024, 1024), Image.NEAREST)
    from PIL import ImageDraw
    d = ImageDraw.Draw(big)
    sc = 1024 / (2 * HALF)

    def P(x, z):
        return (x + HALF) * sc, (z + HALF) * sc
    r0 = GRASS_R * sc
    for (x, z) in pl["patches"]:
        cx, cz = P(x, z)
        d.ellipse([cx - r0, cz - r0, cx + r0, cz + r0], fill=(196, 220, 90), outline=(120, 150, 40))
    for (kind, x, z) in pl["trees"]:
        cx, cz = P(x, z)
        r = {"jungle": 11, "pine": 7, "palm": 6}[kind] * sc * 1.4
        col = {"jungle": (47, 122, 48), "pine": (22, 70, 40), "palm": (150, 200, 60)}[kind]
        d.ellipse([cx - r, cz - r, cx + r, cz + r], fill=col, outline=(25, 60, 25))
    for (x, z, size, yaw, dark, two) in pl["boulders"]:
        cx, cz = P(x, z)
        d.rectangle([cx - size[0] * sc / 2, cz - size[2] * sc / 2, cx + size[0] * sc / 2, cz + size[2] * sc / 2], fill=(110, 113, 117))
    for (sp, x, z) in pl["spawns"]:
        cx, cz = P(x, z)
        d.ellipse([cx - 7, cz - 7, cx + 7, cz + 7], fill=(220, 40, 40) if sp == "TRex" else (240, 140, 30), outline=(0, 0, 0))
    cx, cz = P(*pl["player_spawn"])
    d.rectangle([cx - 7, cz - 7, cx + 7, cz + 7], fill=(255, 255, 255), outline=(0, 0, 0))
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


def data_hash(obj, h=7):
    """Same as island_v3_install dataHash: every number in order (as emitted, 0.1 precision), x10 rounded."""
    for v in obj:
        if isinstance(v, (list, tuple)):
            h = data_hash(v, h)
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            r = round(v, 1)
            h = (h * 31 + math.floor(r * 10 + 0.5) % 1000003 + 1000003) % 2147483647
    return h


def checksum(b):
    h1, h2 = 0, 7
    for x in b:
        h1 = (h1 * 31 + x) % 2147483647
        h2 = (h2 * 131 + x) % 1000000007
    return f"{len(b)}:{h1}:{h2}"


KIND_ID = {FOREST: 1, MEADOW: 2, ROCK: 3, SAND: 4, SHALLOWS: 5, LAKE: 6, TRAIL: 7}  # v1.2: TRAIL


SEABED_SPAN = 1700  # v1.1: the sea floor covers +/- 1700, as the island_v3_install 1.0 quadrants did


def seabed_rects(surf):
    """v1.1: the sea floor (top -8) as rectangles that leave out every lake cell and its 8 neighbours, so the deep
    lake beds (down to -30.8) are not covered by it (1.0: four 1700 x 1700 quadrants cut through every lake at -8).
    The left-out cells are land or lake (asserted: no SEA cell), where the ground blocks run down to BOTTOM, so the
    gap never shows. Inside the grid: greedy rectangles per quadrant (split at x = 0 and z = 0 like the 1.0 quadrants:
    a part is at most 2048 long); outside the grid out to +/- SEABED_SPAN: 8 frame strips. Returns [(x0, z0, x1, z1)]."""
    hole = ndi.binary_dilation(surf == LAKE, structure=np.ones((3, 3), bool))
    assert not (hole & (surf == SEA)).any(), "lake hole touches the sea"
    free = ~hole
    out = []
    H, M = N // 2, HALF
    for (i0, i1) in ((0, H), (H, N)):
        for (j0, j1) in ((0, H), (H, N)):
            used = np.zeros_like(free)
            for j in range(j0, j1):
                for i in range(i0, i1):
                    if not free[j, i] or used[j, i]:
                        continue
                    i2 = i
                    while i2 + 1 < i1 and free[j, i2 + 1] and not used[j, i2 + 1]:
                        i2 += 1
                    j2 = j
                    while j2 + 1 < j1 and (free[j2 + 1, i:i2 + 1] & ~used[j2 + 1, i:i2 + 1]).all():
                        j2 += 1
                    used[j:j2 + 1, i:i2 + 1] = True
                    out.append((-M + i * CELL, -M + j * CELL, -M + (i2 + 1) * CELL, -M + (j2 + 1) * CELL))
    S = SEABED_SPAN
    for s in (-1, 1):
        zr = (-S, -M) if s < 0 else (M, S)          # north / south strips, full width, split at x = 0
        out += [(-S, zr[0], 0, zr[1]), (0, zr[0], S, zr[1])]
        xr = (-S, -M) if s < 0 else (M, S)          # west / east strips between them, split at z = 0
        out += [(xr[0], -M, xr[1], 0), (xr[0], 0, xr[1], M)]
    return out


def write_payloads(surf, top, rects, pl):
    src = open(os.path.join(os.path.dirname(ROOT), "island_v3_install.luau"), encoding="utf-8").read()
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
    hashes = {}

    def emit(name, stage, data):
        key = {"begin": "seabed", "ground": "rects", "water": "lakes", "rocks": "boulders", "trees": "trees", "grass": "patches"}.get(stage)
        if key:
            hashes[name] = data_hash(data[key])
        text = (f"-- payload {name} (island_v3_generator {VERSION} -> DinoIsland {ISLAND_VERSION}); generated, do not edit\n"
                f"local STAGE, DATA = {lua(stage)}, {lua(data)}\n" + installer_for(stage))
        path = os.path.join(OUT_DIR, name + ".luau")
        open(path, "w", encoding="utf-8").write(text)
        payloads.append((name, checksum(text.encode("utf-8"))))

    def top_at(x, z):
        i, j = cell_of(x, z)
        return float(top[j, i])
    sx, sz = pl["player_spawn"]
    bots = [(sp, x, top_at(x, z), z) for (sp, x, z) in pl["spawns"]]
    seabed = seabed_rects(surf)
    emit("00_begin", "begin", {"generator": VERSION, "spawn": (sx, top_at(sx, sz), sz), "bots": bots,
                               "half": HALF, "cell": CELL, "bottom": BOTTOM,
                               "seabed": [v for r in seabed for v in r]})
    flat = []
    for (i, j, w, d, (kind, t)) in rects:
        flat.append((i, j, w, d, KIND_ID[kind], int(round(t * 10))))
    CH = 1200
    nchunks = int(math.ceil(len(flat) / CH))
    for c in range(nchunks):
        part = flat[c * CH:(c + 1) * CH]
        emit(f"{1 + c:02d}_ground", "ground", {"chunk": f"{c + 1}/{nchunks}", "rects": [v for r in part for v in r]})
    lakes = greedy(surf, top, lambda i, j: 1 if surf[j, i] == LAKE else None)
    emit("10_water", "water", {"lakes": [v for (i, j, w, d, k) in lakes for v in (i, j, w, d)]})
    boulders = [(x, z, sz_[0], sz_[1], sz_[2], yaw, dark, two) for (x, z, sz_, yaw, dark, two) in pl["boulders"]]
    emit("11_rocks", "rocks", {"boulders": boulders})
    # v3 tree record: {kind (1 jungle, 2 pine, 4 coconut palm), index, x, z, shape t, lean yaw (degrees)}
    counters = {"jungle": 0, "pine": 0, "palm": 0}
    trees = []
    for (k, x, z), shape in zip(pl["trees"], pl["shapes"]):
        counters[k] += 1
        t, yaw = shape if shape else (0, 0)
        trees.append(({"jungle": 1, "pine": 2, "palm": 4}[k], counters[k], x, z, round(t, 2), round(yaw)))
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
              "patches": len(patches), "spawns": len(bots), "seabed": len(seabed)}
    emit("99_finish", "finish", {"expect": expect})
    manifest = {"generator": VERSION, "island": ISLAND_VERSION, "expect": expect, "trees": counters,
                "fields": [len(f) for f in pl["fields"]], "spawn": pl["player_spawn"], "bots": bots,
                "payloads": dict(payloads), "hashes": hashes}
    json.dump(manifest, open(os.path.join(ROOT, "manifest.json"), "w"), indent=1)
    print("payloads:", ", ".join(f"{n} {c}" for n, c in payloads))
    print("data hashes:", hashes)


if __name__ == "__main__":
    surf, top, aux = build_layout()
    for t in range(8):
        print(NAMES[t], int((surf == t).sum()))
    pl = place(surf, top, aux)
    rects = greedy(surf, top, lambda i, j: None if surf[j, i] == SEA else (int(surf[j, i]), float(top[j, i])))
    print("ground rects", len(rects), "mountain", MOUNTAIN_INFO)
    kinds = {}
    for (k, x, z) in pl["trees"]:
        kinds[k] = kinds.get(k, 0) + 1
    print("fields", [len(f) for f in pl["fields"]], "patches", len(pl["patches"]), "trees", kinds,
          "boulders", len(pl["boulders"]), "spawns", pl["spawns"], "player", pl["player_spawn"])
    render_preview(surf, top, pl, PREVIEW)
    if os.environ.get("NO_PAYLOADS") != "1":
        write_payloads(surf, top, rects, pl)

