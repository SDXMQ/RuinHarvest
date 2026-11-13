#!/usr/bin/env python3
"""
RuinHarvest Pixel Art & Sobel Normal Map Baker
Generates deterministic dark-tactical pixel art sprite sheets (*_d.png)
and cell-clamped OpenGL-convention normal maps (*_n.png) under assets/pixel/.

Conventions (empirically verified against Godot 4.7 CanvasTexture + PointLight2D):
- Texture filter: Nearest (pixel crispness)
- Normal map Y convention: OpenGL (+R = +X right, +G = -Y up / +dH/dy, +B = +Z out)
"""

import os
import math
import zlib
import json
import numpy as np
from PIL import Image

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT_DIR, "assets", "pixel")


def ensure_dirs() -> None:
    for sub in ["tiles", "entities", "weapons", "props", "icons"]:
        os.makedirs(os.path.join(OUT_DIR, sub), exist_ok=True)


def hex_rgba(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ==============================================================================
# Unified Dark Tactical 32-Color Ruin Palette (Darkwood / ZERO Sievert inspired)
# ==============================================================================
PAL = {
    "TRANS": (0, 0, 0, 0),
    "OUTLINE": hex_rgba("#0D0F14"),
    "SHADOW_DARK": hex_rgba("#14171E"),
    "CHARCOAL": hex_rgba("#1C2029"),
    "SLATE_DARK": hex_rgba("#272C37"),
    "SLATE_MID": hex_rgba("#383F4D"),
    "SLATE_LIGHT": hex_rgba("#525B6B"),
    "STEEL_BRIGHT": hex_rgba("#7C8798"),
    "WHITE_MUTED": hex_rgba("#BFC6CF"),

    "ASPHALT_DARK": hex_rgba("#181B20"),
    "ASPHALT_MID": hex_rgba("#22262C"),
    "ASPHALT_LIGHT": hex_rgba("#2E333B"),
    "ROAD_YELLOW": hex_rgba("#C79E2C"),
    "ROAD_YELLOW_DIM": hex_rgba("#8E6E1E"),

    "GRASS_DARK": hex_rgba("#1B2817"),
    "GRASS_MID": hex_rgba("#273A21"),
    "GRASS_LIGHT": hex_rgba("#38502C"),
    "GRASS_HIGH": hex_rgba("#4E693B"),

    "DIRT_DARK": hex_rgba("#2F241B"),
    "DIRT_MID": hex_rgba("#453528"),
    "DIRT_LIGHT": hex_rgba("#5D4937"),

    "WOOD_DARK": hex_rgba("#2D1D14"),
    "WOOD_MID": hex_rgba("#4A3122"),
    "WOOD_LIGHT": hex_rgba("#694832"),
    "WOOD_HIGH": hex_rgba("#876044"),

    "BRICK_DARK": hex_rgba("#321F1A"),
    "BRICK_MID": hex_rgba("#4F3128"),
    "BRICK_LIGHT": hex_rgba("#694236"),

    "RUST_DARK": hex_rgba("#4A2618"),
    "RUST_MID": hex_rgba("#783E24"),
    "RUST_LIGHT": hex_rgba("#A35731"),

    "OLIVE_DARK": hex_rgba("#1F281C"),
    "OLIVE_MID": hex_rgba("#31402B"),
    "OLIVE_LIGHT": hex_rgba("#475C3D"),

    "SKIN_ZOMBIE_DARK": hex_rgba("#314231"),
    "SKIN_ZOMBIE_MID": hex_rgba("#455C43"),
    "SKIN_HUMAN": hex_rgba("#C49F82"),
    "SKIN_HUMAN_SHAD": hex_rgba("#947259"),

    "WATER_DEEP": hex_rgba("#11222C"),
    "WATER_MID": hex_rgba("#183240"),
    "WATER_LIGHT": hex_rgba("#24485A"),

    "BLOOD_DARK": hex_rgba("#541012"),
    "BLOOD_MID": hex_rgba("#8B1C1E"),
    "BLOOD_BRIGHT": hex_rgba("#BD2E2A"),

    "BRASS": hex_rgba("#C89B35"),
    "BRASS_DARK": hex_rgba("#85631F"),
    "CYAN_GLASS": hex_rgba("#3898B8"),
    "CYAN_GLOW": hex_rgba("#70DAEC"),
    "NVG_GREEN": hex_rgba("#3AE664"),
    "RED_LED": hex_rgba("#E02828"),
    "MUZZLE_CORE": hex_rgba("#FFF2B0"),
    "MUZZLE_OUTER": hex_rgba("#F58822"),
}


def cell_hash(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def lerp_rgba(c1, c2, t: float):
    t = max(0.0, min(1.0, t))
    return (
        int(round(c1[0] + (c2[0] - c1[0]) * t)),
        int(round(c1[1] + (c2[1] - c1[1]) * t)),
        int(round(c1[2] + (c2[2] - c1[2]) * t)),
        int(round(c1[3] + (c2[3] - c1[3]) * t)),
    )


class Canvas:
    """Pixel buffer + matching scalar heightmap with cell-clamped Sobel normal export."""

    def __init__(self, width: int, height: int):
        self.w = width
        self.h = height
        self.rgba = np.zeros((height, width, 4), dtype=np.uint8)
        self.heightmap = np.zeros((height, width), dtype=np.float32)

    def set_px(self, x: int, y: int, col, h: float = None):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rgba[y, x] = col
            if h is not None:
                self.heightmap[y, x] = h

    def blend_px(self, x: int, y: int, col, h: float = None):
        if 0 <= x < self.w and 0 <= y < self.h:
            a = col[3] / 255.0
            if a <= 0.0:
                return
            dst = self.rgba[y, x]
            da = dst[3] / 255.0
            out_a = a + da * (1.0 - a)
            if out_a <= 1e-5:
                return
            for c in range(3):
                self.rgba[y, x, c] = int(
                    round((col[c] * a + dst[c] * da * (1.0 - a)) / out_a)
                )
            self.rgba[y, x, 3] = int(round(out_a * 255.0))
            if h is not None:
                self.heightmap[y, x] = self.heightmap[y, x] * (1.0 - a) + h * a

    def fill_rect(self, x0: int, y0: int, w: int, h: int, col, z: float = 0.2):
        for yy in range(y0, y0 + h):
            for xx in range(x0, x0 + w):
                self.set_px(xx, yy, col, z)

    def draw_circle(self, cx: float, cy: float, r: float, col, z: float = 0.4, dome: bool = False):
        x0 = int(math.floor(cx - r - 1))
        x1 = int(math.ceil(cx + r + 1))
        y0 = int(math.floor(cy - r - 1))
        y1 = int(math.ceil(cy + r + 1))
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                dx = xx - cx
                dy = yy - cy
                d2 = dx * dx + dy * dy
                if d2 <= r * r:
                    hv = z
                    if dome and r > 0:
                        hv = z + math.sqrt(max(0.0, 1.0 - d2 / (r * r))) * 0.45
                    self.set_px(xx, yy, col, hv)

    def add_outline_cell(self, ox: int, oy: int, cw: int, ch: int, col=PAL["OUTLINE"]):
        """Adds crisp 1px dark outline around non-transparent pixels strictly inside cell."""
        sub = self.rgba[oy:oy + ch, ox:ox + cw].copy()
        alpha = sub[:, :, 3] > 20
        to_outline = []
        for ly in range(ch):
            for lx in range(cw):
                if alpha[ly, lx]:
                    continue
                hit = False
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ny, nx = ly + dy, lx + dx
                    if 0 <= ny < ch and 0 <= nx < cw and alpha[ny, nx]:
                        hit = True
                        break
                if hit:
                    to_outline.append((lx, ly))
        for lx, ly in to_outline:
            self.set_px(ox + lx, oy + ly, col, 0.05)

    def _compute_region_normals(self, norm: np.ndarray, eff_h: np.ndarray, ox: int, oy: int, cw: int, ch: int, strength: float, wrap: bool = False) -> None:
        sub = eff_h[oy:oy + ch, ox:ox + cw]
        padded = np.pad(sub, 1, mode="wrap" if wrap else "edge")
        gx = (
            (padded[:-2, 2:] + 2.0 * padded[1:-1, 2:] + padded[2:, 2:])
            - (padded[:-2, :-2] + 2.0 * padded[1:-1, :-2] + padded[2:, :-2])
        ) * 0.25
        gy = (
            (padded[2:, :-2] + 2.0 * padded[2:, 1:-1] + padded[2:, 2:])
            - (padded[:-2, :-2] + 2.0 * padded[:-2, 1:-1] + padded[:-2, 2:])
        ) * 0.25

        # Verified Godot 4.7 GL normal convention: R = -gx, G = +gy
        nx = -gx * strength
        ny = gy * strength
        nz = np.ones_like(nx)
        length = np.sqrt(nx * nx + ny * ny + nz * nz)
        nx /= length
        ny /= length
        nz /= length

        norm[oy:oy + ch, ox:ox + cw, 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
        norm[oy:oy + ch, ox:ox + cw, 1] = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
        norm[oy:oy + ch, ox:ox + cw, 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
        norm[oy:oy + ch, ox:ox + cw, 3] = 255

    def build_normal_map(self, cell_w: int, cell_h: int, strength: float = 2.6, wrap_cells: set = None, flat_cells: set = None) -> np.ndarray:
        """
        Generates cell-clamped OpenGL normal map from scalar heightmap + alpha silhouette.
        """
        norm = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        norm[:, :, 0] = 128
        norm[:, :, 1] = 128
        norm[:, :, 2] = 255
        norm[:, :, 3] = 255

        alpha_f = (self.rgba[:, :, 3].astype(np.float32) / 255.0)
        eff_h = self.heightmap + alpha_f * 0.25

        cols = self.w // cell_w
        rows = self.h // cell_h
        for ry in range(rows):
            for rx in range(cols):
                if flat_cells is not None and (rx, ry) in flat_cells:
                    continue
                is_wrap = (wrap_cells is not None) and ((rx, ry) in wrap_cells)
                self._compute_region_normals(norm, eff_h, rx * cell_w, ry * cell_h, cell_w, cell_h, strength, wrap=is_wrap)
        return norm

    def build_normal_map_regions(self, regions: list, strength: float = 2.6) -> np.ndarray:
        """Generates OpenGL normal map clamped strictly to arbitrary (ox, oy, cw, ch) prop bounding boxes."""
        norm = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        norm[:, :, 0] = 128
        norm[:, :, 1] = 128
        norm[:, :, 2] = 255
        norm[:, :, 3] = 255

        alpha_f = (self.rgba[:, :, 3].astype(np.float32) / 255.0)
        eff_h = self.heightmap + alpha_f * 0.25

        for (ox, oy, cw, ch) in regions:
            self._compute_region_normals(norm, eff_h, ox, oy, cw, ch, strength)
        return norm

    def save_pair(self, rel_base: str, cell_w: int, cell_h: int, strength: float = 2.6, wrap_cells: set = None, flat_cells: set = None):
        d_path = os.path.join(OUT_DIR, f"{rel_base}_d.png")
        n_path = os.path.join(OUT_DIR, f"{rel_base}_n.png")
        Image.fromarray(self.rgba, "RGBA").save(d_path)
        norm = self.build_normal_map(cell_w, cell_h, strength, wrap_cells=wrap_cells, flat_cells=flat_cells)
        Image.fromarray(norm, "RGBA").save(n_path)
        return d_path, n_path

    def save_pair_regions(self, rel_base: str, regions: list, strength: float = 2.6):
        d_path = os.path.join(OUT_DIR, f"{rel_base}_d.png")
        n_path = os.path.join(OUT_DIR, f"{rel_base}_n.png")
        Image.fromarray(self.rgba, "RGBA").save(d_path)
        norm = self.build_normal_map_regions(regions, strength)
        Image.fromarray(norm, "RGBA").save(n_path)
        return d_path, n_path


# ==============================================================================
# 1. WORLD TILESET BAKER (256 x 192 = 8x6 tiles of 32x32)
# ==============================================================================
def bake_world_tileset():
    TS = 32
    c = Canvas(8 * TS, 6 * TS)

    # --- (0, 0) TILE_GRASS: Dark desaturated moss & clustered grass blades (seamless 32x32) ---
    ox, oy = 0 * TS, 0 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 101)
            patch = (
                math.sin(x * math.tau * 2.0 / TS) * 0.35
                + math.cos(y * math.tau * 2.0 / TS) * 0.35
                + math.sin((x + y) * math.tau / TS) * 0.30
            ) * 0.5 + 0.5
            col = PAL["GRASS_MID"]
            h = 0.25 + patch * 0.03 + r * 0.02
            if patch < 0.36 or r < 0.20:
                col = PAL["GRASS_DARK"]
                h -= 0.015
            elif r > 0.85:
                col = PAL["GRASS_LIGHT"]
                h += 0.02
            c.set_px(ox + x, oy + y, col, h)
    # Grass blade tufts
    tufts = [(4, 6), (18, 4), (25, 13), (9, 20), (21, 26), (13, 12)]
    for tx, ty in tufts:
        c.set_px(ox + tx, oy + ty, PAL["GRASS_LIGHT"], 0.31)
        c.set_px(ox + tx + 1, oy + ty - 1, PAL["GRASS_HIGH"], 0.33)
        c.set_px(ox + tx - 1, oy + ty - 1, PAL["GRASS_LIGHT"], 0.31)
        c.set_px(ox + tx, oy + ty + 1, PAL["GRASS_DARK"], 0.23)

    # --- (1, 0) TILE_DIRT: Packed damp earth & small stones ---
    ox, oy = 1 * TS, 0 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 202)
            undul = (math.sin(x * math.tau / TS) + math.cos(y * math.tau / TS)) * 0.015
            col = PAL["DIRT_MID"]
            h = 0.24 + undul + r * 0.025
            if r < 0.28:
                col = PAL["DIRT_DARK"]
                h -= 0.015
            elif r > 0.82:
                col = PAL["DIRT_LIGHT"]
                h += 0.018
            c.set_px(ox + x, oy + y, col, h)
    for px, py in [(6, 8), (19, 5), (12, 23), (27, 17), (3, 27)]:
        c.set_px(ox + px, oy + py, PAL["SLATE_MID"], 0.31)
        c.set_px(ox + px + 1, oy + py, PAL["DIRT_DARK"], 0.22)

    # --- (2, 0) TILE_ROAD: Dark weathered asphalt + aggregate & cracks ---
    def draw_asphalt_base(tx_off: int, ty_off: int, seed: int):
        for y in range(TS):
            for x in range(TS):
                r = cell_hash(x, y, seed)
                col = PAL["ASPHALT_MID"]
                h = 0.25 + r * 0.015
                if r < 0.20:
                    col = PAL["ASPHALT_DARK"]
                    h -= 0.01
                elif r > 0.88:
                    col = PAL["ASPHALT_LIGHT"]
                    h += 0.01
                c.set_px(tx_off + x, ty_off + y, col, h)
        # Subtle hairline tarmac crack
        cx, cy = 7, 10
        for step in range(9):
            c.set_px(tx_off + cx, ty_off + cy, PAL["SHADOW_DARK"], 0.20)
            cx += 1
            if step % 3 == 1:
                cy += 1

    draw_asphalt_base(2 * TS, 0 * TS, 303)

    # --- (3, 0) TILE_CONCRETE: Sidewalk paving slabs with subtle bevel seams ---
    ox, oy = 3 * TS, 0 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 404)
            is_seam = (x == 0 or y == 0 or x == 16 or y == 16)
            is_hi = (x == 1 or y == 1 or x == 17 or y == 17)
            if is_seam:
                c.set_px(ox + x, oy + y, PAL["SLATE_DARK"], 0.24)
            elif is_hi:
                c.set_px(ox + x, oy + y, PAL["STEEL_BRIGHT"] if r > 0.4 else PAL["SLATE_LIGHT"], 0.295)
            else:
                col = PAL["SLATE_LIGHT"] if r > 0.25 else PAL["SLATE_MID"]
                c.set_px(ox + x, oy + y, col, 0.28 + r * 0.01)
    # Grime chip
    for gx, gy in [(8, 7), (9, 7), (22, 24), (23, 25)]:
        c.set_px(ox + gx, oy + gy, PAL["SLATE_DARK"], 0.23)

    # --- (4, 0) TILE_FLOOR_WOOD: Staggered hardwood floorboards + nails ---
    ox, oy = 4 * TS, 0 * TS
    for y in range(TS):
        plank_idx = y // 8
        joint_x = 18 if (plank_idx % 2 == 0) else 6
        for x in range(TS):
            r = cell_hash(x, y, 505 + plank_idx)
            if y % 8 == 0 or x == joint_x:
                c.set_px(ox + x, oy + y, PAL["WOOD_DARK"], 0.24)
            elif y % 8 == 1:
                c.set_px(ox + x, oy + y, PAL["WOOD_LIGHT"], 0.295)
            else:
                grain = math.sin(x * math.tau * 2.0 / TS + plank_idx * 1.7)
                col = PAL["WOOD_MID"]
                if grain > 0.55 or r > 0.85:
                    col = PAL["WOOD_LIGHT"]
                elif r < 0.15:
                    col = PAL["WOOD_DARK"]
                c.set_px(ox + x, oy + y, col, 0.28 + r * 0.01)
        # Plank nails near joints
        c.set_px(ox + (joint_x + 2) % TS, oy + plank_idx * 8 + 3, PAL["SLATE_DARK"], 0.30)
        c.set_px(ox + (joint_x + 2) % TS, oy + plank_idx * 8 + 6, PAL["SLATE_DARK"], 0.30)

    # --- (5, 0) TILE_FLOOR_TILE: Cracked tactical ceramic tiles ---
    ox, oy = 5 * TS, 0 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 606)
            if x % 16 == 0 or y % 16 == 0:
                c.set_px(ox + x, oy + y, PAL["SLATE_DARK"], 0.25)
            elif x % 16 == 1 or y % 16 == 1:
                c.set_px(ox + x, oy + y, PAL["WHITE_MUTED"], 0.295)
            else:
                col = lerp_rgba(PAL["SLATE_LIGHT"], PAL["WHITE_MUTED"], 0.42 if ((x // 16 + y // 16) % 2 == 0) else 0.22)
                if r < 0.14:
                    col = PAL["SLATE_MID"]
                c.set_px(ox + x, oy + y, col, 0.285 + r * 0.008)
    # Crack across one corner
    for k in range(6):
        c.set_px(ox + 20 + k, oy + 20 + (k // 2), PAL["CHARCOAL"], 0.24)

    # --- (6, 0) TILE_ROAD_LINE (vertical yellow centerline on right) ---
    draw_asphalt_base(6 * TS, 0 * TS, 707)
    ox, oy = 6 * TS, 0 * TS
    for y in range(2, TS - 2):
        for x in range(TS - 4, TS - 1):
            r = cell_hash(x, y, 708)
            if r > 0.16:
                col = PAL["ROAD_YELLOW"] if x < TS - 1 else PAL["ROAD_YELLOW_DIM"]
                c.set_px(ox + x, oy + y, col, 0.265)

    # --- (7, 0) TILE_GRAVEL: Faceted crushed rock quarry surface ---
    ox, oy = 7 * TS, 0 * TS
    c.fill_rect(ox, oy, TS, TS, PAL["DIRT_DARK"], 0.22)
    for gy in range(0, TS, 4):
        for gx in range(0, TS, 4):
            r = cell_hash(gx, gy, 808)
            sw = 3 if r > 0.4 else 2
            sh = 3 if cell_hash(gx + 1, gy, 809) > 0.45 else 2
            stone_col = [PAL["SLATE_MID"], PAL["SLATE_LIGHT"], PAL["DIRT_MID"]][int(r * 3) % 3]
            for sy in range(sh):
                for sx in range(sw):
                    hi = (sx == 0 and sy == 0)
                    c.set_px(ox + gx + sx, oy + gy + sy, lerp_rgba(stone_col, PAL["WHITE_MUTED"], 0.22) if hi else stone_col, 0.29 if hi else 0.25)

    # --- (0, 1) OBJ_TREE: Rich multi-lobe woodland canopy contrasting cleanly above grass ---
    ox, oy = 0 * TS, 1 * TS
    CANOPY_HIGHLIGHT = hex_rgba("#67884C")
    # Trunk base peeking underneath
    c.draw_circle(ox + 16, oy + 21, 3.8, PAL["WOOD_MID"], 0.35)
    c.set_px(ox + 15, oy + 20, PAL["WOOD_LIGHT"], 0.40)
    clusters = [
        (16, 16, 12.6, PAL["GRASS_MID"], 0.52),
        (18, 19, 8.8, PAL["GRASS_DARK"], 0.46),
        (12, 13, 8.8, PAL["GRASS_LIGHT"], 0.68),
        (20, 14, 7.6, PAL["GRASS_LIGHT"], 0.64),
        (15, 19, 7.4, PAL["GRASS_MID"], 0.60),
        (14, 11, 6.8, PAL["GRASS_HIGH"], 0.82),
        (12, 9, 4.4, CANOPY_HIGHLIGHT, 0.94),
        (18, 11, 3.6, PAL["GRASS_HIGH"], 0.86),
    ]
    for cx, cy, cr, col, hv in clusters:
        for y in range(TS):
            for x in range(TS):
                dx = (ox + x) - (ox + cx)
                dy = (oy + y) - (oy + cy)
                d = math.sqrt(dx * dx + dy * dy)
                jitter = (cell_hash(x, y, 901) - 0.5) * 1.9
                if d + jitter <= cr:
                    local_h = hv + max(0.0, (cr - d) / max(1.0, cr)) * 0.22
                    # Subtle leaf dapple inside lobes without turning canopy black
                    if col == CANOPY_HIGHLIGHT and cell_hash(x, y, 907) < 0.22:
                        c.set_px(ox + x, oy + y, PAL["GRASS_HIGH"], local_h - 0.05)
                    else:
                        c.set_px(ox + x, oy + y, col, local_h)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (1, 1) OBJ_ROCK: Faceted dark slate boulder ---
    ox, oy = 1 * TS, 1 * TS
    for y in range(TS):
        for x in range(TS):
            dx = (x - 15.5) / 12.5
            dy = (y - 16.0) / 11.5
            r = cell_hash(x, y, 1001)
            dist = math.sqrt(dx * dx + dy * dy) + (r - 0.5) * 0.16
            if dist <= 1.0:
                facet = (-dx * 0.6 - dy * 0.5)
                if facet > 0.25:
                    col = PAL["STEEL_BRIGHT"]
                elif facet > -0.1:
                    col = PAL["SLATE_LIGHT"]
                elif facet > -0.45:
                    col = PAL["SLATE_MID"]
                else:
                    col = PAL["SLATE_DARK"]
                if dist < 0.72 and r > 0.88:
                    col = PAL["GRASS_MID"] # moss fleck
                c.set_px(ox + x, oy + y, col, 0.40 + (1.0 - dist) * 0.55)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (2, 1) OBJ_WALL: 2.5D Tactical Reinforced Brick/Concrete Wall ---
    ox, oy = 2 * TS, 1 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 1101)
            if y < 14:
                # Top concrete cap (flat top plane, bevels along edges)
                if y == 0 or y == 13 or x == 0 or x == TS - 1:
                    col = PAL["OUTLINE"] if (y == 0 or y == 13) else PAL["SLATE_DARK"]
                    c.set_px(ox + x, oy + y, col, 0.75)
                elif y == 1 or y == 12:
                    c.set_px(ox + x, oy + y, PAL["SLATE_LIGHT"], 0.90)
                else:
                    col = PAL["SLATE_MID"] if r > 0.2 else PAL["SLATE_DARK"]
                    c.set_px(ox + x, oy + y, col, 0.95)
            else:
                # Lower 18px front brick facade facing viewer (+Y slope height down)
                by = y - 14
                brick_row = by // 5
                mortar_h = (by % 5 == 4)
                brick_shift = (brick_row % 2) * 5
                mortar_v = ((x + brick_shift) % 10 == 0)
                slope_h = 0.88 - (by / 18.0) * 0.65
                if by >= 16:
                    c.set_px(ox + x, oy + y, PAL["OUTLINE"], 0.12) # bottom AO
                elif mortar_h or mortar_v:
                    c.set_px(ox + x, oy + y, PAL["SHADOW_DARK"], slope_h - 0.12)
                else:
                    col = PAL["BRICK_MID"]
                    if r > 0.78:
                        col = PAL["BRICK_LIGHT"]
                    elif r < 0.22:
                        col = PAL["BRICK_DARK"]
                    if by % 5 == 0:
                        col = PAL["BRICK_LIGHT"]
                    c.set_px(ox + x, oy + y, col, slope_h)

    # --- (3, 1) OBJ_CRATE: Reinforced Military Supply Crate ---
    ox, oy = 3 * TS, 1 * TS
    for y in range(2, TS - 2):
        for x in range(2, TS - 2):
            border = (x <= 4 or x >= TS - 5 or y <= 4 or y >= TS - 5)
            diag = (abs(x - y) <= 1 or abs(x - (TS - 1 - y)) <= 1)
            corner = ((x <= 6 or x >= TS - 7) and (y <= 6 or y >= TS - 7))
            if corner:
                c.set_px(ox + x, oy + y, PAL["SLATE_MID"], 0.80)
            elif border:
                col = PAL["WOOD_DARK"] if (x == 2 or y == 2 or x == TS - 3 or y == TS - 3) else PAL["WOOD_MID"]
                c.set_px(ox + x, oy + y, col, 0.72)
            elif diag:
                c.set_px(ox + x, oy + y, PAL["WOOD_LIGHT"], 0.68)
            else:
                col = PAL["WOOD_MID"] if (y % 4 != 0) else PAL["WOOD_DARK"]
                c.set_px(ox + x, oy + y, col, 0.50)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (4, 1) OBJ_BARREL: Top-down rusted industrial hazard drum ---
    ox, oy = 4 * TS, 1 * TS
    for y in range(TS):
        for x in range(TS):
            dx = x - 15.5
            dy = y - 15.5
            dist = math.sqrt(dx * dx + dy * dy)
            if dist <= 11.5:
                r = cell_hash(x, y, 1202)
                if dist >= 9.6:
                    c.set_px(ox + x, oy + y, PAL["SLATE_MID"] if dx + dy < 0 else PAL["SLATE_DARK"], 0.82)
                elif abs(dy) <= 3.0 and r > 0.15:
                    c.set_px(ox + x, oy + y, PAL["RUST_LIGHT"] if r > 0.35 else PAL["RUST_MID"], 0.72)
                else:
                    col = PAL["WATER_LIGHT"] if dx < -2 else PAL["WATER_MID"]
                    if r > 0.84:
                        col = PAL["RUST_DARK"]
                    c.set_px(ox + x, oy + y, col, 0.65)
    # Bung cap on barrel lid
    c.draw_circle(ox + 20, oy + 12, 2.0, PAL["SLATE_DARK"], 0.90)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (5, 1) OBJ_DEBRIS: Twisted scrap, cinderblock & rebar ---
    ox, oy = 5 * TS, 1 * TS
    c.fill_rect(ox + 5, oy + 12, 12, 9, PAL["SLATE_MID"], 0.55)
    c.fill_rect(ox + 7, oy + 14, 3, 4, PAL["SHADOW_DARK"], 0.30)
    c.fill_rect(ox + 13, oy + 14, 3, 4, PAL["SHADOW_DARK"], 0.30)
    c.fill_rect(ox + 14, oy + 7, 11, 8, PAL["RUST_MID"], 0.68)
    c.fill_rect(ox + 16, oy + 9, 6, 4, PAL["RUST_LIGHT"], 0.74)
    for k in range(18):
        c.set_px(ox + 5 + k, oy + 23 - (k // 3), PAL["SLATE_LIGHT"], 0.78)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (6, 1) OBJ_DOOR_CLOSED: Heavy oak door in iron frame ---
    ox, oy = 6 * TS, 1 * TS
    c.fill_rect(ox + 1, oy + 1, TS - 2, TS - 2, PAL["SLATE_DARK"], 0.75)
    c.fill_rect(ox + 3, oy + 3, TS - 6, TS - 6, PAL["WOOD_MID"], 0.58)
    for x in range(4, TS - 4):
        if x % 6 == 0:
            for y in range(4, TS - 4):
                c.set_px(ox + x, oy + y, PAL["WOOD_DARK"], 0.46)
    c.fill_rect(ox + 6, oy + 6, 20, 8, PAL["WOOD_LIGHT"], 0.64)
    c.fill_rect(ox + 6, oy + 18, 20, 8, PAL["WOOD_LIGHT"], 0.64)
    c.fill_rect(ox + 23, oy + 14, 4, 4, PAL["BRASS"], 0.85)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (7, 1) OBJ_DOOR_OPEN: Wood sill + door swung left ---
    ox, oy = 7 * TS, 1 * TS
    c.fill_rect(ox, oy, TS, TS, PAL["WOOD_MID"], 0.25)
    for x in range(TS):
        c.set_px(ox + x, oy + 15, PAL["WOOD_DARK"], 0.22)
    c.fill_rect(ox + 1, oy + 1, 5, TS - 2, PAL["SLATE_DARK"], 0.70)
    c.fill_rect(ox + TS - 6, oy + 1, 5, TS - 2, PAL["SLATE_DARK"], 0.70)
    # Swung door leaf along left jamb
    c.fill_rect(ox + 2, oy + 4, 5, TS - 8, PAL["WOOD_LIGHT"], 0.78)
    c.set_px(ox + 5, oy + 16, PAL["BRASS"], 0.90)

    # --- (0, 2) OBJ_FRIDGE: Dirty enameled fridge top-down ---
    ox, oy = 0 * TS, 2 * TS
    c.fill_rect(ox + 5, oy + 5, 22, 22, PAL["WHITE_MUTED"], 0.80)
    c.fill_rect(ox + 6, oy + 6, 20, 20, PAL["WHITE_MUTED"], 0.85)
    for y in range(6, 26):
        c.set_px(ox + 5, oy + y, PAL["SLATE_MID"], 0.70)
        c.set_px(ox + 26, oy + y, PAL["SLATE_DARK"], 0.65)
    for x in range(6, 26):
        c.set_px(ox + x, oy + 16, PAL["SLATE_MID"], 0.68)
        if cell_hash(x, 12, 1301) > 0.72:
            c.set_px(ox + x, oy + 11, PAL["RUST_MID"], 0.82)
            c.set_px(ox + x, oy + 21, PAL["RUST_DARK"], 0.82)
    c.fill_rect(ox + 22, oy + 18, 2, 5, PAL["SLATE_DARK"], 0.95)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (1, 2) OBJ_WINDOW: Reinforced sill + glass panes ---
    ox, oy = 1 * TS, 2 * TS
    c.fill_rect(ox + 1, oy + 1, TS - 2, TS - 2, PAL["SLATE_DARK"], 0.70)
    c.fill_rect(ox + 4, oy + 4, TS - 8, TS - 8, (48, 92, 118, 175), 0.42)
    c.fill_rect(ox + 15, oy + 3, 2, TS - 6, PAL["WOOD_DARK"], 0.68)
    c.fill_rect(ox + 3, oy + 15, TS - 6, 2, PAL["WOOD_DARK"], 0.68)
    for k in range(6):
        c.set_px(ox + 6 + k, oy + 6 + k, PAL["CYAN_GLOW"], 0.45)
        c.set_px(ox + 19 + k, oy + 19 + k, PAL["CYAN_GLOW"], 0.45)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (2, 2) OBJ_WINDOW_BROKEN: Shattered window sill + glass shards ---
    ox, oy = 2 * TS, 2 * TS
    c.fill_rect(ox + 1, oy + 1, TS - 2, 4, PAL["SLATE_DARK"], 0.65)
    c.fill_rect(ox + 1, oy + TS - 5, TS - 2, 4, PAL["SLATE_DARK"], 0.65)
    c.fill_rect(ox + 1, oy + 1, 4, TS - 2, PAL["SLATE_DARK"], 0.65)
    c.fill_rect(ox + TS - 5, oy + 1, 4, TS - 2, PAL["SLATE_DARK"], 0.65)
    for gx, gy in [(6, 6), (7, 7), (6, 8), (24, 6), (23, 7), (7, 23), (8, 22), (24, 24), (22, 23)]:
        c.set_px(ox + gx, oy + gy, PAL["CYAN_GLASS"], 0.45)
        c.set_px(ox + gx + 1, oy + gy, PAL["WHITE_MUTED"], 0.46)

    # --- (3, 2) OBJ_FENCE: Timber picket + barbed wire rail ---
    ox, oy = 3 * TS, 2 * TS
    c.fill_rect(ox, oy + 9, TS, 3, PAL["WOOD_DARK"], 0.55)
    c.fill_rect(ox, oy + 20, TS, 3, PAL["WOOD_DARK"], 0.55)
    for px in [3, 13, 24]:
        c.fill_rect(ox + px, oy + 3, 5, 26, PAL["WOOD_MID"], 0.72)
        c.fill_rect(ox + px + 1, oy + 4, 2, 23, PAL["WOOD_LIGHT"], 0.76)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (4, 2) OBJ_GATE: Open iron/wood gate posts ---
    ox, oy = 4 * TS, 2 * TS
    c.fill_rect(ox + 1, oy + 4, 6, 24, PAL["WOOD_MID"], 0.78)
    c.fill_rect(ox + TS - 7, oy + 4, 6, 24, PAL["WOOD_MID"], 0.78)
    c.fill_rect(ox + 2, oy + 6, 4, 20, PAL["SLATE_LIGHT"], 0.86)
    c.fill_rect(ox + TS - 6, oy + 6, 4, 20, PAL["SLATE_LIGHT"], 0.86)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (5, 2) OBJ_LIGHT_SWITCH: Breaker panel + green/red status indicator ---
    ox, oy = 5 * TS, 2 * TS
    c.fill_rect(ox + 9, oy + 6, 14, 20, PAL["SLATE_MID"], 0.72)
    c.fill_rect(ox + 11, oy + 8, 10, 16, PAL["SLATE_LIGHT"], 0.78)
    c.fill_rect(ox + 13, oy + 12, 6, 7, PAL["SLATE_DARK"], 0.90)
    c.fill_rect(ox + 14, oy + 13, 4, 3, PAL["NVG_GREEN"], 0.95)
    c.set_px(ox + 19, oy + 10, PAL["RED_LED"], 0.92)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (6, 2) TILE_ROOF: Dark slate shingle tactical roof ---
    ox, oy = 6 * TS, 2 * TS
    for y in range(TS):
        row = y // 8
        shift = (row % 2) * 8
        for x in range(TS):
            r = cell_hash(x, y, 1402)
            if y % 8 == 0 or (x + shift) % 16 == 0:
                c.set_px(ox + x, oy + y, PAL["OUTLINE"], 0.42)
            elif y % 8 == 1:
                c.set_px(ox + x, oy + y, PAL["SLATE_MID"], 0.56)
            else:
                col = PAL["CHARCOAL"] if r < 0.35 else PAL["SLATE_DARK"]
                c.set_px(ox + x, oy + y, col, 0.50 - (y % 8) * 0.01)

    # --- (7, 2) TILE_WATER: Murky pond water base ---
    ox, oy = 7 * TS, 2 * TS
    for y in range(TS):
        for x in range(TS):
            r = cell_hash(x, y, 1502)
            wave = math.sin(x * math.tau * 2.0 / TS + y * math.tau / TS)
            col = PAL["WATER_DEEP"]
            if wave > 0.35 or r > 0.85:
                col = PAL["WATER_LIGHT"]
            elif wave > -0.25:
                col = PAL["WATER_MID"]
            c.set_px(ox + x, oy + y, col, 0.24 + wave * 0.015)

    # --- (0, 3) OBJ_BED: Survivalist cot + navy/olive blanket & pillow ---
    ox, oy = 0 * TS, 3 * TS
    c.fill_rect(ox + 4, oy + 2, 24, 28, PAL["WOOD_DARK"], 0.62)
    c.fill_rect(ox + 6, oy + 4, 20, 24, PAL["OLIVE_MID"], 0.68)
    c.fill_rect(ox + 7, oy + 5, 18, 7, PAL["WHITE_MUTED"], 0.78)
    c.fill_rect(ox + 6, oy + 12, 20, 3, PAL["SLATE_LIGHT"], 0.72)
    for x in range(7, 25):
        if x % 5 == 0:
            c.set_px(ox + x, oy + 19, PAL["OLIVE_DARK"], 0.56)
            c.set_px(ox + x, oy + 22, PAL["OLIVE_LIGHT"], 0.74)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (1, 3) OBJ_DESK: Officer/office desk + documents & drawer pull ---
    ox, oy = 1 * TS, 3 * TS
    c.fill_rect(ox + 2, oy + 5, 28, 22, PAL["WOOD_MID"], 0.70)
    c.fill_rect(ox + 3, oy + 6, 26, 20, PAL["WOOD_LIGHT"], 0.75)
    for y in range(6, 26):
        c.set_px(ox + 19, oy + y, PAL["WOOD_DARK"], 0.60)
    c.fill_rect(ox + 6, oy + 9, 8, 9, PAL["WHITE_MUTED"], 0.80)
    c.fill_rect(ox + 8, oy + 11, 5, 2, PAL["SLATE_MID"], 0.81)
    c.fill_rect(ox + 22, oy + 23, 4, 2, PAL["BRASS"], 0.85)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (2, 3) OBJ_SHELF: Heavy warehouse supply rack ---
    ox, oy = 2 * TS, 3 * TS
    c.fill_rect(ox + 3, oy + 3, 26, 26, PAL["SLATE_DARK"], 0.75)
    c.fill_rect(ox + 4, oy + 4, 24, 24, PAL["SLATE_MID"], 0.66)
    c.fill_rect(ox + 4, oy + 12, 24, 2, PAL["CHARCOAL"], 0.72)
    c.fill_rect(ox + 4, oy + 20, 24, 2, PAL["CHARCOAL"], 0.72)
    # Goods on shelves
    c.fill_rect(ox + 6, oy + 6, 6, 5, PAL["BLOOD_MID"], 0.84)
    c.fill_rect(ox + 14, oy + 6, 9, 5, PAL["OLIVE_LIGHT"], 0.86)
    c.fill_rect(ox + 6, oy + 15, 10, 4, PAL["DIRT_LIGHT"], 0.82)
    c.fill_rect(ox + 19, oy + 15, 6, 4, PAL["CYAN_GLASS"], 0.84)
    c.fill_rect(ox + 7, oy + 23, 8, 4, PAL["BRASS_DARK"], 0.84)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (3, 3) OBJ_DOOR_LOCKED: Armored security vault door + keypad LED ---
    ox, oy = 3 * TS, 3 * TS
    c.fill_rect(ox + 1, oy + 1, TS - 2, TS - 2, PAL["CHARCOAL"], 0.85)
    c.fill_rect(ox + 3, oy + 3, TS - 6, TS - 6, PAL["SLATE_MID"], 0.78)
    for y in range(6, 10):
        for x in range(4, TS - 4):
            stripe = ((x + y) // 3) % 2 == 0
            c.set_px(ox + x, oy + y, PAL["BLOOD_BRIGHT"] if stripe else PAL["ROAD_YELLOW"], 0.82)
    c.fill_rect(ox + 21, oy + 14, 6, 9, PAL["BRASS"], 0.90)
    c.fill_rect(ox + 23, oy + 16, 2, 2, PAL["RED_LED"], 0.96)
    c.add_outline_cell(ox, oy, TS, TS)

    # --- (4, 3) TILE_ROAD_LINE_H: Horizontal centerline along bottom ---
    draw_asphalt_base(4 * TS, 3 * TS, 1603)
    ox, oy = 4 * TS, 3 * TS
    for x in range(2, TS - 2):
        for y in range(TS - 4, TS - 1):
            r = cell_hash(x, y, 1604)
            if r > 0.16:
                col = PAL["ROAD_YELLOW"] if y < TS - 1 else PAL["ROAD_YELLOW_DIM"]
                c.set_px(ox + x, oy + y, col, 0.265)

    # --- (5, 3) TILE_CROSSWALK: Weathered zebra stripes ---
    draw_asphalt_base(5 * TS, 3 * TS, 1703)
    ox, oy = 5 * TS, 3 * TS
    for sx in [3, 11, 19, 26]:
        for y in range(4, TS - 4):
            for dx in range(4):
                r = cell_hash(sx + dx, y, 1704)
                if sx + dx < TS - 2 and r > 0.14:
                    c.set_px(ox + sx + dx, oy + y, PAL["WHITE_MUTED"] if r > 0.35 else PAL["SLATE_LIGHT"], 0.265)

    # --- Rows y = 4..5: Transparent Shadows & Environmental Deco Overlays ---
    # (0, 4) SE Corner Drop Shadow (bottom-right triangular dither)
    ox, oy = 0 * TS, 4 * TS
    for y in range(TS):
        for x in range(TS):
            if x < 18 and y < 18 and (x + y) < 22:
                dither = ((x + y) % 2 == 0) or (x < 10 and y < 10)
                if dither:
                    c.set_px(ox + x, oy + y, (8, 10, 14, 115), 0.10)

    # (1, 4) South Cast Shadow (cast onto ground tile south of walls/buildings)
    ox, oy = 1 * TS, 4 * TS
    for y in range(14):
        alpha = int(145 * (1.0 - y / 14.0))
        for x in range(TS):
            if y < 9 or (x + y) % 2 == 0:
                c.set_px(ox + x, oy + y, (8, 10, 14, alpha), 0.10)

    # (2, 4) East Cast Shadow (cast east of walls)
    ox, oy = 2 * TS, 4 * TS
    for x in range(14):
        alpha = int(135 * (1.0 - x / 14.0))
        for y in range(TS):
            if x < 9 or (x + y) % 2 == 0:
                c.set_px(ox + x, oy + y, (8, 10, 14, alpha), 0.10)

    # (3, 4) Full Under-Object Soft Oval Shadow
    ox, oy = 3 * TS, 4 * TS
    for y in range(TS):
        for x in range(TS):
            dx = (x - 15.5) / 14.0
            dy = (y - 16.5) / 12.0
            d = dx * dx + dy * dy
            if d <= 1.0:
                alpha = int(125 * (1.0 - d))
                c.set_px(ox + x, oy + y, (8, 10, 14, alpha), 0.10)

    # (4, 4) Deco Grass Flowers & Tall Weeds (transparent overlay)
    ox, oy = 4 * TS, 4 * TS
    for wx, wy in [(6, 12), (22, 8), (14, 24)]:
        c.set_px(ox + wx, oy + wy, PAL["GRASS_HIGH"], 0.45)
        c.set_px(ox + wx - 1, oy + wy - 1, PAL["GRASS_LIGHT"], 0.48)
        c.set_px(ox + wx + 1, oy + wy - 1, PAL["GRASS_HIGH"], 0.48)
        if wx == 22:
            c.set_px(ox + wx, oy + wy - 2, PAL["WHITE_MUTED"], 0.55)

    # (5, 4) Deco Asphalt Cracks & Pothole
    ox, oy = 5 * TS, 4 * TS
    for k in range(12):
        px = 5 + k * 2
        py = 14 + int(math.sin(k * 0.9) * 5)
        c.set_px(ox + px, oy + py, PAL["OUTLINE"], 0.12)
        c.set_px(ox + px + 1, oy + py, PAL["ASPHALT_DARK"], 0.15)
    c.draw_circle(ox + 20, oy + 20, 4.0, PAL["ASPHALT_DARK"], 0.10)
    c.draw_circle(ox + 20, oy + 20, 2.5, PAL["DIRT_DARK"], 0.08)

    # (6, 4) Deco Iron Manhole Cover
    ox, oy = 6 * TS, 4 * TS
    c.draw_circle(ox + 16, oy + 16, 9.0, PAL["CHARCOAL"], 0.45)
    c.draw_circle(ox + 16, oy + 16, 7.5, PAL["SLATE_MID"], 0.55)
    for y in range(11, 21, 3):
        for x in range(11, 21, 3):
            if (x - 16) ** 2 + (y - 16) ** 2 < 36:
                c.set_px(ox + x, oy + y, PAL["OUTLINE"], 0.35)
                c.set_px(ox + x + 1, oy + y, PAL["SLATE_LIGHT"], 0.62)

    # (7, 4) Deco Rain Puddle
    ox, oy = 7 * TS, 4 * TS
    for y in range(TS):
        for x in range(TS):
            dx = (x - 16) / 11.0
            dy = (y - 16) / 8.0
            if dx * dx + dy * dy + (cell_hash(x, y, 2001) - 0.5) * 0.25 <= 0.85:
                c.set_px(ox + x, oy + y, (28, 52, 68, 145), 0.14)
    c.set_px(ox + 12, oy + 13, (95, 145, 170, 180), 0.16)
    c.set_px(ox + 13, oy + 13, (95, 145, 170, 180), 0.16)

    # (0, 5) Deco Dried Leaf Litter
    ox, oy = 0 * TS, 5 * TS
    for lx, ly in [(5, 9), (12, 5), (24, 15), (9, 25), (20, 22)]:
        c.set_px(ox + lx, oy + ly, PAL["RUST_MID"], 0.32)
        c.set_px(ox + lx + 1, oy + ly + 1, PAL["DIRT_LIGHT"], 0.30)

    # (1, 5) Deco Concrete Rubble Pebbles
    ox, oy = 1 * TS, 5 * TS
    for rx, ry in [(7, 10), (15, 7), (23, 18), (11, 22), (25, 8)]:
        c.fill_rect(ox + rx, oy + ry, 2, 2, PAL["SLATE_LIGHT"], 0.45)
        c.set_px(ox + rx + 1, oy + ry + 1, PAL["SLATE_DARK"], 0.32)

    # (2, 5) Deco Dried Blood / Oil Stain
    ox, oy = 2 * TS, 5 * TS
    c.draw_circle(ox + 14, oy + 15, 4.5, (72, 16, 18, 155), 0.18)
    c.draw_circle(ox + 18, oy + 18, 2.5, (55, 12, 14, 130), 0.18)

    # (3, 5) Deco Sewer Drain Grate
    ox, oy = 3 * TS, 5 * TS
    c.fill_rect(ox + 10, oy + 10, 12, 12, PAL["CHARCOAL"], 0.42)
    for x in range(12, 21, 2):
        c.fill_rect(ox + x, oy + 12, 1, 8, PAL["OUTLINE"], 0.20)
    c.add_outline_cell(ox, oy, TS, TS)

    wrap_floor_cells = {
        (0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0),
        (6, 2), (7, 2), (4, 3), (5, 3),
    }
    flat_shadow_cells = {(0, 4), (1, 4), (2, 4), (3, 4)}
    return c.save_pair("tiles/world_tileset", TS, TS, strength=2.4, wrap_cells=wrap_floor_cells, flat_cells=flat_shadow_cells)


# ==============================================================================
# 2. PLAYER PARTS SHEET (256 x 128 = 8x4 cells of 32x32, facing +X right)
# ==============================================================================
def bake_player_parts():
    CS = 32
    c = Canvas(8 * CS, 4 * CS)

    # Row 0: Contact shadow, Boot, Backpacks, Arm poses
    # (0, 0) Contact Shadow Oval
    ox, oy = 0 * CS, 0 * CS
    for y in range(CS):
        for x in range(CS):
            dx = (x - 15.5) / 11.0
            dy = (y - 16.0) / 13.0
            d = dx * dx + dy * dy
            if d <= 1.0:
                c.set_px(ox + x, oy + y, (8, 10, 14, int(130 * (1.0 - d))), 0.1)

    # (1, 0) Single Tactical Boot facing +X (centered in 32x32)
    ox, oy = 1 * CS, 0 * CS
    c.fill_rect(ox + 11, oy + 13, 10, 6, PAL["CHARCOAL"], 0.48)
    c.fill_rect(ox + 13, oy + 14, 7, 4, PAL["DIRT_MID"], 0.55)
    c.fill_rect(ox + 18, oy + 14, 3, 4, PAL["DIRT_LIGHT"], 0.62)
    c.add_outline_cell(ox, oy, CS, CS)

    # (2, 0) Backpack Tier 1 (Small olive canvas pack behind torso: x=3..11)
    ox, oy = 2 * CS, 0 * CS
    c.fill_rect(ox + 3, oy + 8, 8, 16, PAL["OLIVE_MID"], 0.65)
    c.fill_rect(ox + 4, oy + 10, 5, 12, PAL["OLIVE_LIGHT"], 0.78)
    c.fill_rect(ox + 9, oy + 11, 2, 10, PAL["OLIVE_DARK"], 0.60)
    c.add_outline_cell(ox, oy, CS, CS)

    # (3, 0) Backpack Tier 2 (Tactical Assault coyote/olive pack with side pouches)
    ox, oy = 3 * CS, 0 * CS
    c.fill_rect(ox + 2, oy + 7, 9, 18, PAL["DIRT_MID"], 0.68)
    c.fill_rect(ox + 3, oy + 9, 6, 14, PAL["DIRT_LIGHT"], 0.80)
    c.fill_rect(ox + 3, oy + 6, 5, 3, PAL["OLIVE_MID"], 0.72)
    c.fill_rect(ox + 3, oy + 23, 5, 3, PAL["OLIVE_MID"], 0.72)
    c.fill_rect(ox + 5, oy + 11, 1, 10, PAL["CHARCOAL"], 0.76)
    c.add_outline_cell(ox, oy, CS, CS)

    # (4, 0) Backpack Tier 3 (Heavy Expedition Black/Charcoal Pack + bedroll)
    ox, oy = 4 * CS, 0 * CS
    c.fill_rect(ox + 1, oy + 5, 10, 22, PAL["CHARCOAL"], 0.72)
    c.fill_rect(ox + 2, oy + 7, 7, 18, PAL["SLATE_DARK"], 0.85)
    c.fill_rect(ox + 3, oy + 4, 4, 24, PAL["OLIVE_MID"], 0.90) # sleeping roll
    for sy in [10, 16, 21]:
        c.fill_rect(ox + 4, oy + sy, 5, 2, PAL["BRASS_DARK"], 0.92)
    c.add_outline_cell(ox, oy, CS, CS)

    # Row 1: Torso / Vests (32x32 centered around (16,16), facing +X)
    def draw_torso_base(ox: int, oy: int, jacket_col, vest_col, hi_col, tier: int):
        # Shoulders spanning y=6..25, x=9..21
        for y in range(6, 26):
            half_len = 6 if (y < 9 or y > 22) else 7
            for x in range(15 - half_len, 16 + half_len):
                hv = 0.62 + (1.0 - abs(y - 15.5) / 11.0) * 0.25
                c.set_px(ox + x, oy + y, jacket_col, hv)
        # Tactical plate carrier chest overlay
        for y in range(8, 24):
            for x in range(10, 22):
                hv = 0.75 + (1.0 - abs(y - 15.5) / 10.0) * 0.20
                col = hi_col if (x in (14, 15, 20) and y > 10 and y < 21) else vest_col
                c.set_px(ox + x, oy + y, col, hv)
        if tier == 1:
            # Police zipper + yellow badge
            for y in range(9, 23):
                c.set_px(ox + 19, oy + y, PAL["CHARCOAL"], 0.80)
            c.fill_rect(ox + 17, oy + 10, 3, 2, PAL["BRASS"], 0.88)
        elif tier == 2:
            # MOLLE pouches front & side
            c.fill_rect(ox + 17, oy + 10, 4, 5, hi_col, 0.92)
            c.fill_rect(ox + 17, oy + 17, 4, 5, hi_col, 0.92)
            c.fill_rect(ox + 12, oy + 8, 3, 3, PAL["SLATE_LIGHT"], 0.86)
            c.fill_rect(ox + 12, oy + 21, 3, 3, PAL["SLATE_LIGHT"], 0.86)
        elif tier == 3:
            # Heavy 6B43 armored pauldrons + neck collar
            c.draw_circle(ox + 14, oy + 6, 4.2, hi_col, 0.92, True)
            c.draw_circle(ox + 14, oy + 25, 4.2, hi_col, 0.92, True)
            c.fill_rect(ox + 18, oy + 10, 4, 5, PAL["SLATE_LIGHT"], 0.95)
            c.fill_rect(ox + 18, oy + 17, 4, 5, PAL["SLATE_LIGHT"], 0.95)
        c.add_outline_cell(ox, oy, CS, CS)

    draw_torso_base(0 * CS, 1 * CS, PAL["SLATE_DARK"], PAL["SLATE_MID"], PAL["SLATE_LIGHT"], 0) # Jacket
    draw_torso_base(1 * CS, 1 * CS, PAL["SLATE_DARK"], PAL["WATER_LIGHT"], PAL["STEEL_BRIGHT"], 1) # T1 Police
    draw_torso_base(2 * CS, 1 * CS, PAL["DIRT_DARK"], PAL["DIRT_LIGHT"], PAL["OLIVE_LIGHT"], 2) # T2 Rig
    draw_torso_base(3 * CS, 1 * CS, PAL["OLIVE_DARK"], PAL["OLIVE_MID"], PAL["OLIVE_LIGHT"], 3) # T3 6B43

    # (5, 0) Arms Bare Hands (in 32x32 around center)
    ox, oy = 5 * CS, 0 * CS
    c.fill_rect(ox + 14, oy + 6, 8, 4, PAL["SLATE_MID"], 0.65)
    c.draw_circle(ox + 22, oy + 8, 2.3, PAL["SKIN_HUMAN"], 0.72, True)
    c.fill_rect(ox + 14, oy + 22, 8, 4, PAL["SLATE_MID"], 0.65)
    c.draw_circle(ox + 22, oy + 24, 2.3, PAL["SKIN_HUMAN"], 0.72, True)
    c.add_outline_cell(ox, oy, CS, CS)

    # (6, 0) Arms Rifle Two-Handed Pose
    ox, oy = 6 * CS, 0 * CS
    # Right arm back hand holding grip at (20, 19)
    for k in range(7):
        c.fill_rect(ox + 13 + k, oy + 23 - (k * 4 // 7), 4, 4, PAL["SLATE_MID"], 0.68)
    c.draw_circle(ox + 20, oy + 19, 2.5, PAL["SKIN_HUMAN"], 0.76, True)
    # Left support arm reaching forward to handguard at (25, 16)
    for k in range(11):
        c.fill_rect(ox + 14 + k, oy + 8 + (k * 7 // 11), 4, 4, PAL["SLATE_MID"], 0.68)
    c.draw_circle(ox + 25, oy + 15, 2.5, PAL["SKIN_HUMAN"], 0.76, True)
    c.add_outline_cell(ox, oy, CS, CS)

    # (7, 0) Arms Pistol Pose
    ox, oy = 7 * CS, 0 * CS
    for k in range(7):
        c.fill_rect(ox + 14 + k, oy + 22 - (k * 5 // 7), 4, 4, PAL["SLATE_MID"], 0.68)
        c.fill_rect(ox + 14 + k, oy + 10 + (k * 5 // 7), 4, 4, PAL["SLATE_MID"], 0.68)
    c.draw_circle(ox + 21, oy + 16, 2.6, PAL["SKIN_HUMAN"], 0.78, True)
    c.add_outline_cell(ox, oy, CS, CS)

    # Row 2: Heads / Helmets / NVG (32x32 centered at (16, 16), facing +X)
    # (0, 2) Survivor Head + Tactical Cap
    ox, oy = 0 * CS, 2 * CS
    c.draw_circle(ox + 16, oy + 16, 7.2, PAL["SKIN_HUMAN"], 0.80, True)
    # Cap dome + front brim facing +X
    c.draw_circle(ox + 15, oy + 16, 6.8, PAL["CHARCOAL"], 0.86, True)
    c.fill_rect(ox + 18, oy + 11, 7, 10, PAL["SLATE_DARK"], 0.84)
    c.fill_rect(ox + 14, oy + 12, 4, 8, PAL["SLATE_MID"], 0.92)
    c.add_outline_cell(ox, oy, CS, CS)

    # (1, 2) Helmet Tier 1 (Riot/Moto helmet crimson/dark visor)
    ox, oy = 1 * CS, 2 * CS
    c.draw_circle(ox + 16, oy + 16, 7.8, PAL["BLOOD_MID"], 0.88, True)
    c.draw_circle(ox + 15, oy + 14, 4.5, PAL["BLOOD_BRIGHT"], 0.95, True)
    c.fill_rect(ox + 20, oy + 10, 5, 12, PAL["CHARCOAL"], 0.86)
    c.fill_rect(ox + 22, oy + 12, 2, 8, PAL["SLATE_LIGHT"], 0.90)
    c.add_outline_cell(ox, oy, CS, CS)

    # (2, 2) Helmet Tier 2 (Ops-Core Military Helmet)
    ox, oy = 2 * CS, 2 * CS
    c.draw_circle(ox + 16, oy + 16, 8.0, PAL["OLIVE_MID"], 0.88, True)
    c.draw_circle(ox + 15, oy + 15, 5.2, PAL["OLIVE_LIGHT"], 0.94, True)
    c.fill_rect(ox + 12, oy + 8, 7, 2, PAL["DIRT_LIGHT"], 0.92) # ARC rail
    c.fill_rect(ox + 12, oy + 22, 7, 2, PAL["DIRT_LIGHT"], 0.92)
    c.fill_rect(ox + 22, oy + 14, 3, 4, PAL["SLATE_MID"], 0.95) # NVG shroud
    c.add_outline_cell(ox, oy, CS, CS)

    # (3, 2) Helmet Tier 3 (Altyn Heavy Titanium Dome + Steel Visor Slit)
    ox, oy = 3 * CS, 2 * CS
    c.draw_circle(ox + 16, oy + 16, 8.6, PAL["OLIVE_DARK"], 0.90, True)
    c.draw_circle(ox + 15, oy + 15, 6.2, PAL["OLIVE_MID"], 0.96, True)
    c.fill_rect(ox + 19, oy + 9, 6, 14, PAL["SLATE_LIGHT"], 0.94)
    c.fill_rect(ox + 22, oy + 12, 2, 8, PAL["CYAN_GLOW"], 0.90) # ballistic glass slit
    c.add_outline_cell(ox, oy, CS, CS)

    # (4, 2) NVG Dual-Tube Mount Overlay
    ox, oy = 4 * CS, 2 * CS
    c.fill_rect(ox + 21, oy + 11, 6, 4, PAL["CHARCOAL"], 0.92)
    c.fill_rect(ox + 21, oy + 17, 6, 4, PAL["CHARCOAL"], 0.92)
    c.fill_rect(ox + 25, oy + 12, 3, 2, PAL["NVG_GREEN"], 0.98)
    c.fill_rect(ox + 25, oy + 18, 3, 2, PAL["NVG_GREEN"], 0.98)
    c.add_outline_cell(ox, oy, CS, CS)

    # (5, 2) Gasmask Overlay
    ox, oy = 5 * CS, 2 * CS
    c.fill_rect(ox + 20, oy + 11, 5, 10, PAL["CHARCOAL"], 0.88)
    c.fill_rect(ox + 21, oy + 12, 2, 3, PAL["CYAN_GLASS"], 0.92)
    c.fill_rect(ox + 21, oy + 17, 2, 3, PAL["CYAN_GLASS"], 0.92)
    c.draw_circle(ox + 24, oy + 16, 2.5, PAL["SLATE_MID"], 0.96, True)
    c.add_outline_cell(ox, oy, CS, CS)

    return c.save_pair("entities/player_parts", CS, CS, strength=2.4)


# ==============================================================================
# 3. WEAPON PARTS SHEET (256 x 128 = 8x4 cells of 32x32, facing +X right)
# ==============================================================================
def bake_weapon_parts():
    CS = 32
    c = Canvas(8 * CS, 4 * CS)

    # Row 0: Receivers / Base Firearms & Primary Melee
    # (0, 0) M9 Beretta
    ox, oy = 0 * CS, 0 * CS
    c.fill_rect(ox + 10, oy + 14, 12, 4, PAL["SLATE_MID"], 0.75)
    c.fill_rect(ox + 12, oy + 15, 9, 2, PAL["SLATE_LIGHT"], 0.85)
    c.add_outline_cell(ox, oy, CS, CS)

    # (1, 0) AK-47 Rifle
    ox, oy = 1 * CS, 0 * CS
    c.fill_rect(ox + 7, oy + 14, 10, 4, PAL["SLATE_MID"], 0.78)
    c.fill_rect(ox + 17, oy + 14, 8, 4, PAL["WOOD_LIGHT"], 0.82)
    c.fill_rect(ox + 11, oy + 15, 6, 2, PAL["CHARCOAL"], 0.86)
    c.add_outline_cell(ox, oy, CS, CS)

    # (2, 0) M4A1 Carbine
    ox, oy = 2 * CS, 0 * CS
    c.fill_rect(ox + 7, oy + 14, 11, 4, PAL["CHARCOAL"], 0.80)
    c.fill_rect(ox + 18, oy + 14, 7, 4, PAL["SLATE_DARK"], 0.82)
    for px in range(8, 24, 2):
        c.set_px(ox + px, oy + 15, PAL["SLATE_LIGHT"], 0.90) # picatinny rail highlight
    c.add_outline_cell(ox, oy, CS, CS)

    # (3, 0) Remington 870 Shotgun
    ox, oy = 3 * CS, 0 * CS
    c.fill_rect(ox + 7, oy + 14, 9, 4, PAL["SLATE_MID"], 0.80)
    c.fill_rect(ox + 16, oy + 14, 9, 4, PAL["WOOD_MID"], 0.84)
    c.fill_rect(ox + 17, oy + 15, 6, 2, PAL["WOOD_DARK"], 0.78)
    c.add_outline_cell(ox, oy, CS, CS)

    # (4, 0) SV-98 Sniper
    ox, oy = 4 * CS, 0 * CS
    c.fill_rect(ox + 6, oy + 13, 18, 6, PAL["OLIVE_MID"], 0.82)
    c.fill_rect(ox + 10, oy + 14, 12, 3, PAL["CHARCOAL"], 0.88)
    c.fill_rect(ox + 13, oy + 18, 2, 3, PAL["STEEL_BRIGHT"], 0.92) # bolt knob
    c.add_outline_cell(ox, oy, CS, CS)

    # (5, 0) Lever Action
    ox, oy = 5 * CS, 0 * CS
    c.fill_rect(ox + 7, oy + 14, 8, 4, PAL["BRASS"], 0.84)
    c.fill_rect(ox + 15, oy + 14, 10, 4, PAL["WOOD_MID"], 0.82)
    c.add_outline_cell(ox, oy, CS, CS)

    # (6, 0) Fire Axe
    ox, oy = 6 * CS, 0 * CS
    c.fill_rect(ox + 6, oy + 15, 17, 3, PAL["WOOD_LIGHT"], 0.72)
    c.fill_rect(ox + 18, oy + 9, 6, 9, PAL["BLOOD_MID"], 0.85)
    c.fill_rect(ox + 22, oy + 9, 2, 9, PAL["WHITE_MUTED"], 0.92) # sharpened edge
    c.add_outline_cell(ox, oy, CS, CS)

    # (7, 0) Combat Knife
    ox, oy = 7 * CS, 0 * CS
    c.fill_rect(ox + 10, oy + 15, 6, 3, PAL["CHARCOAL"], 0.76)
    c.fill_rect(ox + 16, oy + 14, 9, 4, PAL["STEEL_BRIGHT"], 0.88)
    c.fill_rect(ox + 18, oy + 15, 7, 1, PAL["WHITE_MUTED"], 0.94)
    c.add_outline_cell(ox, oy, CS, CS)

    # Row 1: Modular Barrels, Muzzles, Stocks, Magazines (aligned to +X relative anchors)
    # (0, 1) Standard/Short Barrel
    ox, oy = 0 * CS, 1 * CS
    c.fill_rect(ox + 10, oy + 15, 11, 2, PAL["SLATE_DARK"], 0.82)
    c.fill_rect(ox + 10, oy + 15, 11, 1, PAL["SLATE_LIGHT"], 0.88)
    c.add_outline_cell(ox, oy, CS, CS)

    # (1, 1) Long Match Heavy Barrel
    ox, oy = 1 * CS, 1 * CS
    c.fill_rect(ox + 8, oy + 14, 17, 4, PAL["SLATE_MID"], 0.84)
    c.fill_rect(ox + 8, oy + 15, 17, 2, PAL["STEEL_BRIGHT"], 0.90)
    c.add_outline_cell(ox, oy, CS, CS)

    # (2, 1) Tactical Suppressor
    ox, oy = 2 * CS, 1 * CS
    c.fill_rect(ox + 10, oy + 14, 13, 4, PAL["CHARCOAL"], 0.86)
    for bx in [13, 17, 21]:
        c.fill_rect(ox + bx, oy + 14, 1, 4, PAL["SLATE_LIGHT"], 0.90)
    c.add_outline_cell(ox, oy, CS, CS)

    # (3, 1) Muzzle Compensator
    ox, oy = 3 * CS, 1 * CS
    c.fill_rect(ox + 12, oy + 14, 7, 4, PAL["SLATE_LIGHT"], 0.88)
    c.set_px(ox + 14, oy + 14, PAL["CHARCOAL"], 0.65)
    c.set_px(ox + 16, oy + 14, PAL["CHARCOAL"], 0.65)
    c.add_outline_cell(ox, oy, CS, CS)

    # (4, 1) Light Folding Stock
    ox, oy = 4 * CS, 1 * CS
    c.fill_rect(ox + 8, oy + 14, 9, 4, PAL["CHARCOAL"], 0.78)
    c.fill_rect(ox + 7, oy + 13, 2, 6, PAL["SLATE_MID"], 0.84)
    c.add_outline_cell(ox, oy, CS, CS)

    # (5, 1) PRS Precision Stock
    ox, oy = 5 * CS, 1 * CS
    c.fill_rect(ox + 5, oy + 13, 12, 6, PAL["OLIVE_MID"], 0.84)
    c.fill_rect(ox + 8, oy + 15, 7, 2, PAL["CHARCOAL"], 0.70)
    c.fill_rect(ox + 5, oy + 12, 2, 8, PAL["CHARCOAL"], 0.88)
    c.add_outline_cell(ox, oy, CS, CS)

    # (6, 1) Extended Magazine (side curved contour)
    ox, oy = 6 * CS, 1 * CS
    c.fill_rect(ox + 13, oy + 14, 5, 7, PAL["SLATE_MID"], 0.78)
    c.fill_rect(ox + 15, oy + 19, 4, 4, PAL["SLATE_DARK"], 0.76)
    c.add_outline_cell(ox, oy, CS, CS)

    # (7, 1) 50-rd Drum Magazine
    ox, oy = 7 * CS, 1 * CS
    c.draw_circle(ox + 16, oy + 18, 5.2, PAL["CHARCOAL"], 0.84, True)
    c.draw_circle(ox + 16, oy + 18, 3.0, PAL["SLATE_MID"], 0.90)
    c.add_outline_cell(ox, oy, CS, CS)

    # Row 2: Optics, Foregrips, Laser Module, Pipe, Grenade, Muzzle Flash
    # (0, 2) Red Dot Reflex
    ox, oy = 0 * CS, 2 * CS
    c.fill_rect(ox + 13, oy + 14, 6, 4, PAL["CHARCOAL"], 0.92)
    c.fill_rect(ox + 15, oy + 15, 2, 2, PAL["RED_LED"], 0.96)
    c.add_outline_cell(ox, oy, CS, CS)

    # (1, 2) 4x ACOG Scope
    ox, oy = 1 * CS, 2 * CS
    c.fill_rect(ox + 11, oy + 14, 10, 4, PAL["SLATE_DARK"], 0.94)
    c.fill_rect(ox + 13, oy + 15, 4, 2, PAL["MUZZLE_OUTER"], 0.96) # fiber strip
    c.fill_rect(ox + 20, oy + 14, 2, 4, PAL["CYAN_GLOW"], 0.96)
    c.add_outline_cell(ox, oy, CS, CS)

    # (2, 2) 8x Long Sniper Scope
    ox, oy = 2 * CS, 2 * CS
    c.fill_rect(ox + 9, oy + 14, 14, 4, PAL["CHARCOAL"], 0.95)
    c.fill_rect(ox + 21, oy + 13, 3, 6, PAL["SLATE_MID"], 0.96)
    c.fill_rect(ox + 23, oy + 14, 2, 4, PAL["CYAN_GLOW"], 0.98)
    c.add_outline_cell(ox, oy, CS, CS)

    # (3, 2) Vertical Foregrip
    ox, oy = 3 * CS, 2 * CS
    c.fill_rect(ox + 14, oy + 15, 4, 5, PAL["DIRT_DARK"], 0.72)
    c.add_outline_cell(ox, oy, CS, CS)

    # (4, 2) Tactical Rail Laser/Light Pod
    ox, oy = 4 * CS, 2 * CS
    c.fill_rect(ox + 13, oy + 12, 6, 3, PAL["OLIVE_LIGHT"], 0.88)
    c.set_px(ox + 18, oy + 13, PAL["RED_LED"], 0.95)
    c.add_outline_cell(ox, oy, CS, CS)

    # (5, 2) Steel Pipe / Bat
    ox, oy = 5 * CS, 2 * CS
    c.fill_rect(ox + 7, oy + 14, 17, 4, PAL["SLATE_LIGHT"], 0.84)
    c.fill_rect(ox + 19, oy + 13, 4, 6, PAL["RUST_LIGHT"], 0.88)
    c.add_outline_cell(ox, oy, CS, CS)

    # (6, 2) Frag Grenade
    ox, oy = 6 * CS, 2 * CS
    c.draw_circle(ox + 16, oy + 16, 4.2, PAL["OLIVE_MID"], 0.84, True)
    c.fill_rect(ox + 15, oy + 10, 3, 3, PAL["BRASS"], 0.90)
    c.add_outline_cell(ox, oy, CS, CS)

    # (7, 2) Pixel Muzzle Flash Star Burst (pivot near left x=8, y=16)
    ox, oy = 7 * CS, 2 * CS
    for x in range(8, 27):
        spread = max(0, 4 - (x - 8) // 4)
        for dy in range(-spread, spread + 1):
            dist = abs(dy)
            if x < 14 and dist <= 2:
                c.set_px(ox + x, oy + 16 + dy, PAL["MUZZLE_CORE"], 0.95)
            elif (x - 8) % 2 == 0 or dist <= 1:
                c.set_px(ox + x, oy + 16 + dy, PAL["MUZZLE_OUTER"], 0.80)
    # Up/down side vents
    for s in range(1, 7):
        c.set_px(ox + 10 + s // 2, oy + 16 - s, PAL["MUZZLE_CORE"] if s < 4 else PAL["MUZZLE_OUTER"], 0.85)
        c.set_px(ox + 10 + s // 2, oy + 16 + s, PAL["MUZZLE_CORE"] if s < 4 else PAL["MUZZLE_OUTER"], 0.85)

    return c.save_pair("weapons/weapon_parts", CS, CS, strength=2.2)


# ==============================================================================
# 4. ENEMIES SPRITE SHEET (384 x 96 = 8x2 cells of 48x48, facing +X right)
# ==============================================================================
def bake_enemies():
    ES = 48
    c = Canvas(8 * ES, 2 * ES)

    def draw_infected_body(idx: int, skin_c, skin_d, cloth_c, cloth_d, scale: float = 1.0, reach: int = 0, obsidian: bool = False):
        ox, oy = idx * ES, 0
        cx, cy = ox + 22, oy + 24
        sh_y = int(round(11 * scale))
        # Outstretched arms
        arm_len = int(round((12 + reach) * scale))
        arm_th = max(3, int(round(4 * scale)))
        for ay in (-sh_y, sh_y - arm_th + 1):
            c.fill_rect(cx + 1, cy + ay, arm_len, arm_th, skin_c, 0.65)
            c.fill_rect(cx + arm_len - 2, cy + ay, 4, arm_th, PAL["BLOOD_MID"] if not obsidian else PAL["SLATE_LIGHT"], 0.72)
        # Torso
        tw = int(round(14 * scale))
        th = int(round(22 * scale))
        c.fill_rect(cx - tw // 2, cy - th // 2, tw, th, cloth_c, 0.78)
        c.fill_rect(cx - tw // 2 + 2, cy - th // 2 + 2, tw - 5, th - 4, cloth_d, 0.68)
        # Torn shoulder skin
        c.fill_rect(cx - 2, cy - th // 2 + 1, 5, 4, skin_c, 0.75)
        if obsidian:
            for node_x in [-4, 0]:
                c.set_px(cx + node_x, cy, PAL["CYAN_GLOW"], 0.92)
        # Head facing +X
        c.draw_circle(cx + int(round(3 * scale)), cy, 6.8 * scale, skin_c, 0.88, True)
        c.draw_circle(cx + int(round(1 * scale)), cy, 4.2 * scale, skin_d, 0.92)
        if obsidian:
            # Obsidian dorsal spines & glowing cyan spine nodes visible on head/back
            c.set_px(cx - 5, cy - 1, PAL["CYAN_GLOW"], 0.96)
            c.set_px(cx - 5, cy + 1, PAL["CYAN_GLOW"], 0.96)
            c.set_px(cx - 1, cy, PAL["CYAN_GLASS"], 0.96)
            c.set_px(cx + 4, cy, PAL["CYAN_GLOW"], 0.98)
            for ay in (-sh_y, sh_y - arm_th + 1):
                c.fill_rect(cx + arm_len + 1, cy + ay + 1, 3, max(1, arm_th - 2), PAL["CYAN_GLOW"], 0.80)
        c.add_outline_cell(ox, oy, ES, ES)

    # (0, 0) ZOMBIE
    draw_infected_body(0, PAL["SKIN_ZOMBIE_MID"], PAL["SKIN_ZOMBIE_DARK"], PAL["SLATE_MID"], PAL["SLATE_DARK"], 1.0, 2)
    # (1, 0) RUNNER
    draw_infected_body(1, PAL["RUST_MID"], PAL["BLOOD_DARK"], PAL["BLOOD_MID"], PAL["BLOOD_DARK"], 0.88, 5)
    # (2, 0) TANK
    draw_infected_body(2, PAL["SKIN_ZOMBIE_MID"], PAL["SKIN_ZOMBIE_DARK"], PAL["WATER_LIGHT"], PAL["OLIVE_DARK"], 1.32, 3)

    # (3, 0) SCAV (Brown jacket, beanie, carbine/shotgun)
    ox, oy = 3 * ES, 0
    cx, cy = ox + 22, oy + 24
    c.fill_rect(cx - 8, cy - 11, 14, 22, PAL["DIRT_LIGHT"], 0.78)
    c.fill_rect(cx - 6, cy - 9, 10, 18, PAL["DIRT_MID"], 0.82)
    # Arms + Shotgun
    c.fill_rect(cx + 2, cy + 5, 11, 4, PAL["DIRT_MID"], 0.68)
    c.fill_rect(cx + 3, cy - 8, 12, 4, PAL["DIRT_MID"], 0.68)
    c.fill_rect(cx + 7, cy - 1, 17, 4, PAL["WOOD_MID"], 0.84)
    c.fill_rect(cx + 14, cy, 12, 2, PAL["SLATE_MID"], 0.86)
    c.draw_circle(cx + 2, cy, 6.8, PAL["RUST_MID"], 0.90, True) # Reddish beanie
    c.add_outline_cell(ox, oy, ES, ES)

    # (4, 0) RAIDER (Olive plate carrier + tactical helmet + AR)
    ox, oy = 4 * ES, 0
    cx, cy = ox + 22, oy + 24
    c.fill_rect(cx - 9, cy - 12, 16, 24, PAL["OLIVE_MID"], 0.80)
    c.fill_rect(cx - 6, cy - 9, 12, 18, PAL["OLIVE_LIGHT"], 0.86)
    c.fill_rect(cx + 2, cy + 5, 12, 4, PAL["OLIVE_MID"], 0.70)
    c.fill_rect(cx + 3, cy - 8, 13, 4, PAL["OLIVE_MID"], 0.70)
    c.fill_rect(cx + 8, cy - 1, 20, 4, PAL["CHARCOAL"], 0.88) # Suppressed AR
    c.draw_circle(cx + 2, cy, 7.2, PAL["OLIVE_LIGHT"], 0.92, True)
    c.fill_rect(cx + 6, cy - 4, 4, 8, PAL["NVG_GREEN"], 0.95)
    c.add_outline_cell(ox, oy, ES, ES)

    # (5, 0) BOSS (Juggernaut black/crimson armor, gold trim, Altyn helmet + LMG)
    ox, oy = 5 * ES, 0
    cx, cy = ox + 21, oy + 24
    c.fill_rect(cx - 11, cy - 15, 20, 30, PAL["CHARCOAL"], 0.86)
    c.fill_rect(cx - 8, cy - 12, 15, 24, PAL["BLOOD_DARK"], 0.90)
    c.draw_circle(cx - 1, cy - 13, 4.5, PAL["BRASS"], 0.94, True)
    c.draw_circle(cx - 1, cy + 13, 4.5, PAL["BRASS"], 0.94, True)
    # Heavy arms + Drum LMG
    c.fill_rect(cx + 3, cy + 6, 13, 5, PAL["CHARCOAL"], 0.76)
    c.fill_rect(cx + 4, cy - 9, 14, 5, PAL["CHARCOAL"], 0.76)
    c.fill_rect(cx + 7, cy - 2, 23, 5, PAL["SLATE_MID"], 0.90)
    c.draw_circle(cx + 15, cy + 4, 3.8, PAL["CHARCOAL"], 0.92, True)
    # Heavy Helmet + Visor
    c.draw_circle(cx + 3, cy, 8.6, PAL["SLATE_DARK"], 0.94, True)
    c.fill_rect(ox + 26, oy + 19, 5, 10, PAL["RED_LED"], 0.96)
    c.add_outline_cell(ox, oy, ES, ES)

    # (6, 0) NIGHT_STALKER (Obsidian chitin + elongated claws + cyan dorsal nodes)
    draw_infected_body(6, PAL["CHARCOAL"], PAL["SHADOW_DARK"], PAL["SHADOW_DARK"], PAL["OUTLINE"], 1.06, 6, obsidian=True)

    # (7, 0) Blood Wound Overlay (overlays when hp < 0.7)
    ox, oy = 7 * ES, 0
    for bx, by, br in [(16, 18, 3.0), (24, 29, 3.6), (19, 25, 2.2), (28, 21, 2.4)]:
        c.draw_circle(ox + bx, oy + by, br, (145, 20, 22, 185), 0.70)

    # Row 1: Animation Extras (48x48)
    # (0, 1) Striding Combat Boot (centered around (24, 24) for Enemy leg animation)
    ox, oy = 0 * ES, 1 * ES
    c.fill_rect(ox + 19, oy + 21, 10, 6, PAL["CHARCOAL"], 0.45)
    c.fill_rect(ox + 21, oy + 22, 7, 4, PAL["DIRT_MID"], 0.52)
    c.add_outline_cell(ox, oy, ES, ES)

    # (3, 1) Boss Frag Grenade (centered)
    ox, oy = 3 * ES, 1 * ES
    c.draw_circle(ox + 24, oy + 24, 5.5, PAL["OLIVE_MID"], 0.85, True)
    c.fill_rect(ox + 23, oy + 17, 3, 3, PAL["BRASS"], 0.92)
    c.set_px(ox + 25, oy + 16, PAL["MUZZLE_CORE"], 0.96)
    c.add_outline_cell(ox, oy, ES, ES)

    return c.save_pair("entities/enemies", ES, ES, strength=2.6)


# ==============================================================================
# 5. WORLD PROPS SHEET (256 x 192: Cars 48x96, Airdrop, Objectives, Extract)
# ==============================================================================
def bake_world_props():
    c = Canvas(256, 192)

    # 4 Abandoned Cars (each 48x96 at y=0..96, x = 0, 48, 96, 144)
    car_schemes = [
        (PAL["RUST_MID"], PAL["RUST_LIGHT"], PAL["RUST_DARK"]),
        (PAL["WATER_LIGHT"], PAL["CYAN_GLASS"], PAL["WATER_DEEP"]),
        (PAL["OLIVE_MID"], PAL["OLIVE_LIGHT"], PAL["OLIVE_DARK"]),
        (PAL["ROAD_YELLOW_DIM"], PAL["ROAD_YELLOW"], PAL["DIRT_DARK"]),
    ]
    for ci, (base, hi, dark) in enumerate(car_schemes):
        ox, oy = ci * 48, 0
        # 4 Tires sticking slightly out of wheel wells
        for ty in [16, 70]:
            c.fill_rect(ox + 3, oy + ty, 5, 11, PAL["CHARCOAL"], 0.50)
            c.fill_rect(ox + 40, oy + ty, 5, 11, PAL["CHARCOAL"], 0.50)
        # Main Chassis (6..41 x 6..89)
        c.fill_rect(ox + 6, oy + 6, 36, 84, base, 0.72)
        c.fill_rect(ox + 9, oy + 8, 30, 80, hi if ci != 0 else base, 0.78)
        # Hood & Trunk panel grooves + organic weathered rust patches
        c.fill_rect(ox + 15, oy + 10, 18, 12, lerp_rgba(base, hi, 0.45), 0.80)
        c.fill_rect(ox + 16, oy + 11, 2, 10, dark, 0.72)
        c.fill_rect(ox + 30, oy + 11, 2, 10, dark, 0.72)
        rust_patches = [
            (13 + (ci * 3) % 6, 13, 2.6),
            (29 - (ci * 2) % 5, 18, 2.2),
            (16 + (ci * 4) % 8, 77, 2.4),
        ]
        for rx, ry, rr in rust_patches:
            c.draw_circle(ox + rx, oy + ry, rr, PAL["RUST_DARK"], 0.74)
            c.draw_circle(ox + rx - 1, oy + ry, rr * 0.55, PAL["RUST_MID"], 0.76)
        c.fill_rect(ox + 9, oy + 26, 30, 2, dark, 0.65)
        # Shattered Windshield (y=28..37)
        c.fill_rect(ox + 9, oy + 28, 30, 9, PAL["WATER_DEEP"], 0.62)
        for k in range(8):
            c.set_px(ox + 12 + k, oy + 29 + k, PAL["CYAN_GLOW"], 0.68)
            c.set_px(ox + 32 - k, oy + 30 + (k // 2), PAL["WHITE_MUTED"], 0.68)
        # Roof (y=37..68)
        c.fill_rect(ox + 10, oy + 37, 28, 30, lerp_rgba(base, PAL["WHITE_MUTED"], 0.16), 0.90)
        c.fill_rect(ox + 12, oy + 39, 24, 26, hi, 0.94)
        # Rear window (y=67..74)
        c.fill_rect(ox + 10, oy + 67, 28, 7, PAL["WATER_DEEP"], 0.62)
        # Broken headlights & taillights
        c.fill_rect(ox + 8, oy + 6, 7, 3, PAL["SLATE_LIGHT"], 0.82)
        c.fill_rect(ox + 33, oy + 6, 7, 3, PAL["SLATE_LIGHT"], 0.82)
        c.fill_rect(ox + 8, oy + 87, 7, 3, PAL["BLOOD_MID"], 0.82)
        c.fill_rect(ox + 33, oy + 87, 7, 3, PAL["BLOOD_MID"], 0.82)
        # Side mirrors
        c.fill_rect(ox + 3, oy + 29, 3, 5, dark, 0.78)
        c.fill_rect(ox + 42, oy + 29, 3, 5, dark, 0.78)
        c.add_outline_cell(ox, oy, 48, 96)

    # 5th Slot (192..240, 0..96): Armored Extraction SUV
    ox, oy = 192, 0
    for ty in [15, 69]:
        c.fill_rect(ox + 3, oy + ty, 6, 13, PAL["CHARCOAL"], 0.55)
        c.fill_rect(ox + 39, oy + ty, 6, 13, PAL["CHARCOAL"], 0.55)
    c.fill_rect(ox + 6, oy + 5, 36, 86, PAL["CHARCOAL"], 0.78)
    c.fill_rect(ox + 8, oy + 8, 32, 80, PAL["OLIVE_DARK"], 0.84)
    c.fill_rect(ox + 9, oy + 24, 30, 8, PAL["WATER_MID"], 0.72)
    c.fill_rect(ox + 10, oy + 32, 28, 44, PAL["OLIVE_MID"], 0.92)
    for rx in range(13, 35, 5):
        c.fill_rect(ox + rx, oy + 36, 2, 34, PAL["SLATE_MID"], 0.95) # roof rack rails
    c.fill_rect(ox + 9, oy + 5, 8, 3, PAL["ROAD_YELLOW"], 0.90) # headlights
    c.fill_rect(ox + 31, oy + 5, 8, 3, PAL["ROAD_YELLOW"], 0.90)
    c.add_outline_cell(ox, oy, 48, 96)

    # Airdrop Crate (48x48 at 0, 96)
    ox, oy = 0, 96
    c.fill_rect(ox + 6, oy + 6, 36, 36, PAL["OLIVE_MID"], 0.78)
    c.fill_rect(ox + 8, oy + 8, 32, 32, PAL["OLIVE_LIGHT"], 0.84)
    c.fill_rect(ox + 6, oy + 21, 36, 6, PAL["SLATE_DARK"], 0.88)
    c.fill_rect(ox + 21, oy + 6, 6, 36, PAL["SLATE_DARK"], 0.88)
    c.fill_rect(ox + 14, oy + 14, 20, 20, PAL["ROAD_YELLOW"], 0.90)
    c.fill_rect(ox + 17, oy + 17, 14, 14, PAL["OLIVE_MID"], 0.84)
    c.add_outline_cell(ox, oy, 48, 48)

    # Airdrop Deployed Parachute Canopy (96x48 at 48, 96)
    ox, oy = 48, 96
    for y in range(4, 42):
        for x in range(6, 90):
            dx = (x - 48) / 42.0
            dy = (y - 34) / 28.0
            d2 = dx * dx + dy * dy
            if d2 <= 1.0 and y <= 36 - int(abs(math.sin(dx * math.pi * 2.0)) * 4):
                panel = int((dx + 1.0) * 3.0)
                col = PAL["OLIVE_LIGHT"] if panel % 2 == 0 else PAL["OLIVE_MID"]
                if abs(dx * 3 - round(dx * 3)) < 0.08:
                    col = PAL["OLIVE_DARK"]
                c.set_px(ox + x, oy + y, col, 0.75 + (1.0 - d2) * 0.2)
    c.add_outline_cell(ox, oy, 96, 48)

    # Collapsed Parachute Cloth (64x48 at 144, 96)
    ox, oy = 144, 96
    for y in range(10, 40):
        for x in range(8, 56):
            dx = (x - 32) / 24.0
            dy = (y - 24) / 14.0
            if dx * dx + dy * dy + (cell_hash(x, y, 4010) - 0.5) * 0.25 <= 0.88:
                col = PAL["OLIVE_LIGHT"] if ((x + y) // 4) % 2 == 0 else PAL["OLIVE_MID"]
                c.set_px(ox + x, oy + y, col, 0.55)
    c.add_outline_cell(ox, oy, 64, 48)

    # Field Objectives Row (y=144..192, 48x48 cells)
    # (0, 3) 48x48 at x=0, y=144: Military Hacking Terminal
    ox, oy = 0, 144
    c.fill_rect(ox + 8, oy + 12, 32, 26, PAL["SLATE_DARK"], 0.76)
    c.fill_rect(ox + 10, oy + 14, 28, 22, PAL["SLATE_MID"], 0.82)
    c.fill_rect(ox + 13, oy + 17, 18, 11, PAL["WATER_DEEP"], 0.84)
    c.fill_rect(ox + 15, oy + 20, 14, 2, PAL["CYAN_GLOW"], 0.86)
    c.fill_rect(ox + 17, oy + 24, 10, 2, PAL["NVG_GREEN"], 0.86)
    c.fill_rect(ox + 34, oy + 4, 3, 24, PAL["STEEL_BRIGHT"], 0.94) # Antenna mast
    c.add_outline_cell(ox, oy, 48, 48)

    # (1, 3) 48x48 at x=48, y=144: Hospital Biosampler
    ox, oy = 48, 144
    c.fill_rect(ox + 9, oy + 10, 30, 28, PAL["WHITE_MUTED"], 0.78)
    c.fill_rect(ox + 12, oy + 13, 24, 22, PAL["SLATE_MID"], 0.84)
    c.draw_circle(ox + 24, oy + 24, 7.0, PAL["NVG_GREEN"], 0.92, True)
    c.fill_rect(ox + 12, oy + 32, 24, 3, PAL["ROAD_YELLOW"], 0.86)
    c.add_outline_cell(ox, oy, 48, 48)

    # (2, 3) 48x48 at x=96, y=144: Commercial Radio Relay
    ox, oy = 96, 144
    c.fill_rect(ox + 8, oy + 14, 32, 24, PAL["DIRT_LIGHT"], 0.76)
    c.fill_rect(ox + 11, oy + 17, 20, 16, PAL["CHARCOAL"], 0.82)
    c.fill_rect(ox + 13, oy + 19, 14, 4, PAL["ROAD_YELLOW"], 0.86)
    c.fill_rect(ox + 33, oy + 3, 4, 28, PAL["STEEL_BRIGHT"], 0.95)
    c.fill_rect(ox + 29, oy + 8, 12, 2, PAL["SLATE_LIGHT"], 0.95)
    c.add_outline_cell(ox, oy, 48, 48)

    # (3, 3) 48x48 at x=144, y=144: Helipad H Stencil Pad
    ox, oy = 144, 144
    c.fill_rect(ox + 4, oy + 4, 40, 40, PAL["SLATE_DARK"], 0.30)
    c.fill_rect(ox + 12, oy + 10, 5, 28, PAL["ROAD_YELLOW"], 0.36)
    c.fill_rect(ox + 31, oy + 10, 5, 28, PAL["ROAD_YELLOW"], 0.36)
    c.fill_rect(ox + 17, oy + 21, 14, 6, PAL["ROAD_YELLOW"], 0.36)
    c.add_outline_cell(ox, oy, 48, 48)

    # (4, 3) 48x48 at x=192, y=144: Bunker Vault Steel Hatch
    ox, oy = 192, 144
    c.fill_rect(ox + 4, oy + 6, 40, 36, PAL["SLATE_DARK"], 0.74)
    c.fill_rect(ox + 7, oy + 9, 34, 30, PAL["SLATE_MID"], 0.82)
    c.fill_rect(ox + 23, oy + 9, 2, 30, PAL["CHARCOAL"], 0.65)
    c.draw_circle(ox + 24, oy + 24, 6.0, PAL["STEEL_BRIGHT"], 0.94, True)
    c.draw_circle(ox + 24, oy + 24, 2.5, PAL["CYAN_GLOW"], 0.96)
    c.add_outline_cell(ox, oy, 48, 48)

    # Sandbag / Vehicle Extraction Barricade (48x48 at 208, 96)
    ox, oy = 208, 96
    c.fill_rect(ox + 6, oy + 12, 36, 24, PAL["DIRT_DARK"], 0.65)
    for row_i, sy in enumerate([13, 21, 29]):
        for bag_x in range(8 + (row_i % 2) * 4, 38, 10):
            c.fill_rect(ox + bag_x, oy + sy, 8, 6, PAL["DIRT_LIGHT"], 0.82)
            c.fill_rect(ox + bag_x + 1, oy + sy + 1, 5, 3, PAL["OLIVE_LIGHT"], 0.88)
    c.fill_rect(ox + 8, oy + 18, 32, 3, PAL["ROAD_YELLOW"], 0.90)
    c.add_outline_cell(ox, oy, 48, 48)

    prop_regions = [
        (0, 0, 48, 96),     # car_0 (rust)
        (48, 0, 48, 96),    # car_1 (blue)
        (96, 0, 48, 96),    # car_2 (olive)
        (144, 0, 48, 96),   # car_3 (yellow)
        (192, 0, 48, 96),   # extract_suv
        (0, 96, 48, 48),    # airdrop_crate
        (48, 96, 96, 48),   # parachute_open
        (144, 96, 64, 48),  # parachute_collapsed
        (208, 96, 48, 48),  # barricade_sandbags
        (0, 144, 48, 48),   # obj_terminal
        (48, 144, 48, 48),  # obj_biosampler
        (96, 144, 48, 48),  # obj_radio_relay
        (144, 144, 48, 48), # extract_helipad
        (192, 144, 48, 48), # extract_bunker_hatch
    ]
    return c.save_pair_regions("props/world_props", prop_regions, strength=2.2)


# ==============================================================================
# MAIN
# ==============================================================================
def main():
    ensure_dirs()
    generated = []
    generated.append(("tiles/world_tileset", bake_world_tileset()))
    generated.append(("entities/player_parts", bake_player_parts()))
    generated.append(("weapons/weapon_parts", bake_weapon_parts()))
    generated.append(("entities/enemies", bake_enemies()))
    generated.append(("props/world_props", bake_world_props()))

    manifest = {"atlases": {}}
    print("=== PIXEL ASSETS BAKED SUCCESSFULLY ===")
    for key, (d_path, n_path) in generated:
        im_d = Image.open(d_path)
        im_n = Image.open(n_path)
        rel_d = os.path.relpath(d_path, ROOT_DIR).replace("\\", "/")
        rel_n = os.path.relpath(n_path, ROOT_DIR).replace("\\", "/")
        manifest["atlases"][key] = {
            "diffuse": f"res://{rel_d}",
            "normal": f"res://{rel_n}",
            "width": im_d.size[0],
            "height": im_d.size[1],
        }
        print(f" - {rel_d} ({im_d.size[0]}x{im_d.size[1]} {im_d.mode})")
        print(f" - {rel_n} ({im_n.size[0]}x{im_n.size[1]} {im_n.mode})")

    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f" - {os.path.relpath(manifest_path, ROOT_DIR)}")


if __name__ == "__main__":
    main()
