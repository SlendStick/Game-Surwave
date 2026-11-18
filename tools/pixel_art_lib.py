# -*- coding: utf-8 -*-
"""Pure-Python pixel-art rasterizer & PNG encoder for Surwave.

Zero external dependencies (uses only Python stdlib: zlib, struct, math, random).
Follows VISUAL_SPECIFICATION_SURWAVE.md: muted Diablo-2 gothic palette,
1-bit crisp pixel outlines, directional shading, nearest-neighbor friendly.
"""

from __future__ import annotations

import math
import os
import random
import struct
import zlib
from pathlib import Path
from typing import Iterable

Color = tuple[int, int, int, int]

# --- Diablo-2 / Surwave Muted Gothic Palette (VISUAL_SPECIFICATION_SURWAVE.md)
PAL: dict[str, tuple[int, int, int]] = {
    # Base earths & shadows
    "black": (10, 8, 6),
    "void": (13, 11, 9),
    "dark_brown": (22, 19, 16),
    "umbra": (35, 29, 23),
    "umber": (44, 34, 26),
    "soil_dark": (46, 38, 32),
    "soil": (58, 47, 38),
    "leather": (75, 60, 48),
    "leather_lt": (94, 74, 58),
    "sand_dk": (122, 98, 80),
    "sand": (152, 128, 106),
    "sand_lt": (184, 158, 130),
    "bone": (212, 188, 154),
    "parchment": (234, 219, 192),
    "cream": (245, 235, 218),
    "white": (255, 255, 255),
    # Cold stones & ice
    "slate_vd": (26, 29, 32),
    "slate_dk": (38, 42, 46),
    "slate": (52, 56, 61),
    "stone_dk": (66, 71, 77),
    "stone": (82, 88, 96),
    "stone_lt": (101, 108, 117),
    "moon_stone": (122, 130, 140),
    "frost_dk": (145, 154, 165),
    "frost": (169, 179, 191),
    "snow_dk": (193, 204, 217),
    "snow": (216, 226, 238),
    "snow_lt": (236, 243, 250),
    # Blood & fire
    "blood_vd": (26, 5, 6),
    "blood_dk": (46, 10, 12),
    "maroon": (69, 16, 20),
    "crimson_dk": (97, 24, 28),
    "crimson": (125, 32, 37),
    "blood": (155, 42, 48),
    "scarlet": (188, 52, 58),
    "ember_red": (220, 64, 69),
    "lava": (232, 90, 37),
    "flame": (244, 134, 42),
    "amber": (250, 168, 42),
    "gold_glow": (255, 208, 74),
    # Poison, nature & arcane
    "swamp_vd": (10, 26, 13),
    "swamp_dk": (22, 42, 24),
    "moss_dk": (35, 68, 36),
    "moss": (51, 96, 52),
    "poison": (70, 130, 71),
    "life": (90, 165, 91),
    "glow_green": (127, 196, 128),
    "pale_green": (168, 224, 169),
    "arcane_vd": (41, 22, 66),
    "arcane_dk": (59, 31, 94),
    "arcane": (90, 46, 140),
    "violet": (122, 63, 194),
    "violet_lt": (162, 92, 232),
    "ghost_violet": (197, 140, 255),
    # Sky & water
    "night": (14, 26, 46),
    "deep_water": (26, 42, 68),
    "water": (37, 61, 96),
    "water_lt": (51, 83, 126),
    "ice_blue": (68, 107, 155),
    "ice_lt": (91, 136, 190),
    "frost_blue": (128, 168, 216),
    "ice_glow": (165, 198, 236),
    # Gold & metals
    "rust": (31, 26, 16),
    "iron_dk": (58, 48, 32),
    "iron": (85, 72, 48),
    "bronze_dk": (110, 96, 72),
    "bronze": (138, 120, 88),
    "brass": (168, 144, 104),
    "gold": (199, 170, 122),
    "gold_lt": (230, 201, 138),
}


def c(name_or_hex: str | tuple[int, int, int] | Color, a: int = 255) -> Color:
    if isinstance(name_or_hex, tuple):
        if len(name_or_hex) == 4:
            return name_or_hex
        return (name_or_hex[0], name_or_hex[1], name_or_hex[2], a)
    if name_or_hex in PAL:
        r, g, b = PAL[name_or_hex]
        return (r, g, b, a)
    s = name_or_hex.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def mix(c1: Color, c2: Color, t: float) -> Color:
    t = max(0.0, min(1.0, t))
    return (
        int(round(c1[0] + (c2[0] - c1[0]) * t)),
        int(round(c1[1] + (c2[1] - c1[1]) * t)),
        int(round(c1[2] + (c2[2] - c1[2]) * t)),
        int(round(c1[3] + (c2[3] - c1[3]) * t)),
    )


def mul(col: Color, f: float) -> Color:
    return (
        max(0, min(255, int(round(col[0] * f)))),
        max(0, min(255, int(round(col[1] * f)))),
        max(0, min(255, int(round(col[2] * f)))),
        col[3],
    )


def save_png(path: Path, w: int, h: int, pixels: list[Color]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter type None
        row_off = y * w
        for x in range(w):
            r, g, b, a = pixels[row_off + x]
            raw.extend((r & 255, g & 255, b & 255, a & 255))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    path.write_bytes(png)


def bezier(p0, p1, p2, n: int = 26) -> list[tuple[float, float]]:
    """Точки квадратичной кривой Безье — для плавных лезвий и дуг."""
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1],
        ))
    return out


class Canvas:
    def __init__(self, w: int, h: int, fill: Color = (0, 0, 0, 0)) -> None:
        self.w = w
        self.h = h
        self.buf: list[Color] = [fill] * (w * h)

    def get(self, x: int, y: int) -> Color:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.buf[y * self.w + x]
        return (0, 0, 0, 0)

    def px(self, x: int, y: int, col: Color, blend_alpha: bool = False) -> None:
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if col[3] == 0:
            return
        idx = y * self.w + x
        if not blend_alpha or col[3] == 255 or self.buf[idx][3] == 0:
            self.buf[idx] = col
        else:
            t = col[3] / 255.0
            dst = self.buf[idx]
            self.buf[idx] = (
                int(round(dst[0] * (1 - t) + col[0] * t)),
                int(round(dst[1] * (1 - t) + col[1] * t)),
                int(round(dst[2] * (1 - t) + col[2] * t)),
                max(dst[3], col[3]),
            )

    def rect(self, x0: int, y0: int, w: int, h: int, col: Color, blend: bool = False) -> None:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.px(x, y, col, blend)

    def box_outline(self, x0: int, y0: int, w: int, h: int, col: Color) -> None:
        for x in range(x0, x0 + w):
            self.px(x, y0, col)
            self.px(x, y0 + h - 1, col)
        for y in range(y0, y0 + h):
            self.px(x0, y, col)
            self.px(x0 + w - 1, y, col)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: Color, thickness: int = 1) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            if thickness <= 1:
                self.px(x, y, col)
            else:
                r = thickness // 2
                self.rect(x - r, y - r, thickness, thickness, col)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: Color, blend: bool = False) -> None:
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(math.floor(cy - ry - 1)), int(math.ceil(cy + ry + 1))):
            for x in range(int(math.floor(cx - rx - 1)), int(math.ceil(cx + rx + 1))):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    self.px(x, y, col, blend)

    def ring(self, cx: float, cy: float, r_outer: float, r_inner: float, col: Color, blend: bool = False) -> None:
        for y in range(int(math.floor(cy - r_outer - 1)), int(math.ceil(cy + r_outer + 1))):
            for x in range(int(math.floor(cx - r_outer - 1)), int(math.ceil(cx + r_outer + 1))):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if r_inner <= d <= r_outer:
                    self.px(x, y, col, blend)

    def poly(self, pts: Iterable[tuple[float, float]], col: Color, blend: bool = False) -> None:
        pts_l = list(pts)
        if len(pts_l) < 3:
            return
        min_x = int(math.floor(min(p[0] for p in pts_l)))
        max_x = int(math.ceil(max(p[0] for p in pts_l)))
        min_y = int(math.floor(min(p[1] for p in pts_l)))
        max_y = int(math.ceil(max(p[1] for p in pts_l)))
        for y in range(min_y, max_y + 1):
            py = y + 0.5
            for x in range(min_x, max_x + 1):
                px = x + 0.5
                inside = False
                j = len(pts_l) - 1
                for i in range(len(pts_l)):
                    xi, yi = pts_l[i]
                    xj, yj = pts_l[j]
                    if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / ((yj - yi) or 1e-9) + xi):
                        inside = not inside
                    j = i
                if inside:
                    self.px(x, y, col, blend)

    def stamp(self, grid: list[str], legend: dict[str, Color], ox: int = 0, oy: int = 0, mirror_x: bool = False) -> None:
        for dy, row in enumerate(grid):
            w = len(row)
            for dx, ch in enumerate(row):
                if ch in (".", " "):
                    continue
                col = legend.get(ch)
                if col is None:
                    continue
                px_x = ox + (w - 1 - dx if mirror_x else dx)
                self.px(px_x, oy + dy, col)

    def tapered(self, pts: list[tuple[float, float]], w0: float, w1: float, col: Color,
                blend: bool = False, side: float = 1.0) -> list[tuple[float, float]]:
        """Мазок переменной толщины вдоль ломаной (лезвия, клыки, рога).

        Возвращает точки режущей кромки — удобно подсветить их отдельным цветом.
        """
        edge: list[tuple[float, float]] = []
        n = len(pts)
        for i, (x, y) in enumerate(pts):
            t = i / max(1, n - 1)
            nx, ny = 0.0, -1.0
            if i + 1 < n:
                dx, dy = pts[i + 1][0] - x, pts[i + 1][1] - y
            else:
                dx, dy = x - pts[i - 1][0], y - pts[i - 1][1]
            ln = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / ln * side, dx / ln * side
            w = w0 + (w1 - w0) * t
            k = 0.0
            while k <= w:
                self.px(int(round(x + nx * k)), int(round(y + ny * k)), col, blend)
                k += 1.0
            edge.append((x + nx * w, y + ny * w))
        return edge

    def outline(self, col: Color = (10, 8, 6, 255), diagonal: bool = False) -> None:
        src = list(self.buf)
        nbrs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diagonal:
            nbrs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if src[y * self.w + x][3] > 0:
                    continue
                for dx, dy in nbrs:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h:
                        if src[ny * self.w + nx][3] >= 180:
                            self.buf[y * self.w + x] = col
                            break

    def directional_shade(self, strength: float = 0.14) -> None:
        """Top-left light / bottom-right subtle shade on opaque interior pixels."""
        src = list(self.buf)
        for y in range(self.h):
            for x in range(self.w):
                col = src[y * self.w + x]
                if col[3] < 200 or (col[0] < 18 and col[1] < 18 and col[2] < 18):
                    continue
                up_empty = y == 0 or src[(y - 1) * self.w + x][3] < 100
                dn_empty = y == self.h - 1 or src[(y + 1) * self.w + x][3] < 100
                lt_empty = x == 0 or src[y * self.w + x - 1][3] < 100
                rt_empty = x == self.w - 1 or src[y * self.w + x + 1][3] < 100
                if up_empty or lt_empty:
                    self.buf[y * self.w + x] = mul(col, 1.0 + strength)
                elif dn_empty or rt_empty:
                    self.buf[y * self.w + x] = mul(col, 1.0 - strength * 1.1)

    def add_ground_shadow(self, cx: float, cy: float, rx: float, ry: float, alpha: int = 85) -> None:
        sh = (10, 8, 6, alpha)
        for y in range(int(math.floor(cy - ry - 1)), int(math.ceil(cy + ry + 1))):
            for x in range(int(math.floor(cx - rx - 1)), int(math.ceil(cx + rx + 1))):
                if 0 <= x < self.w and 0 <= y < self.h and self.buf[y * self.w + x][3] == 0:
                    nx = (x + 0.5 - cx) / rx
                    ny = (y + 0.5 - cy) / ry
                    if nx * nx + ny * ny <= 1.0:
                        self.buf[y * self.w + x] = sh

    def copy(self) -> Canvas:
        out = Canvas(self.w, self.h)
        out.buf = list(self.buf)
        return out

    def save(self, path: Path) -> None:
        save_png(path, self.w, self.h, self.buf)


def draw_icon_frame(cv: Canvas, accent: Color, bg_top: Color | None = None, bg_bot: Color | None = None) -> None:
    """Draws a crisp Diablo-2 beveled gothic frame with corner rivets onto a 24x24 Canvas."""
    w, h = cv.w, cv.h
    t_col = bg_top or mix(c("slate_dk"), accent, 0.14)
    b_col = bg_bot or mix(c("umbra"), accent, 0.08)
    cx, cy = w * 0.5, h * 0.5
    for y in range(2, h - 2):
        frac = (y - 2) / max(1, h - 5)
        row_col = mix(t_col, b_col, frac)
        for x in range(2, w - 2):
            dist = math.hypot(x - cx, y - cy) / (w * 0.5)
            glow = max(0.0, 1.0 - dist * 0.85) * 0.25
            col = mix(row_col, accent, glow * 0.35)
            if ((x * 7 + y * 13) % 19) == 0:
                col = mul(col, 1.12)
            elif ((x * 11 + y * 5) % 23) == 0:
                col = mul(col, 0.90)
            cv.px(x, y, col)
    # Outer dark border
    cv.box_outline(0, 0, w, h, c("black"))
    # Beveled metallic rim
    rim_hi = mix(accent, c("gold_lt"), 0.25)
    rim_lo = mul(accent, 0.55)
    cv.line(1, 1, w - 2, 1, rim_hi)
    cv.line(1, 1, 1, h - 2, rim_hi)
    cv.line(1, h - 2, w - 2, h - 2, rim_lo)
    cv.line(w - 2, 1, w - 2, h - 2, rim_lo)
    # Inner dark groove
    cv.box_outline(2, 2, w - 4, h - 4, c("void"))
    # Corner rivets
    rivet = mix(accent, c("gold"), 0.45)
    for rx, ry in [(1, 1), (w - 3, 1), (1, h - 3), (w - 3, h - 3)]:
        cv.rect(rx, ry, 2, 2, rivet)
        cv.px(rx, ry, c("parchment"))
