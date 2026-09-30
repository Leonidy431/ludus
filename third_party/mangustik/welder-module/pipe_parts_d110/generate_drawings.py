#!/usr/bin/env python3
"""Generate GOST-style 2D drawing sheets (SVG) for the d110 pipe parts kit.

Companion to lib_d110.scad (which defines the 3D models). This script owns
its own copy of the same dimension constants — see README.md for which are
GOST 18599-2001-verified vs. engineering estimates; the split is identical
to lib_d110.scad's comments and is not repeated in full here.

Output: one A4-landscape SVG per part into drawings/, each with a full
longitudinal-section main view, an end view, a dimension table, and a
simplified (explicitly labelled as such) GOST 2.104-style title block.

Usage: python3 generate_drawings.py
"""
import math
import os

# ---- Shared constants (mirrors lib_d110.scad) ------------------------------
OD_110 = 110.0
WALL_SDR17 = 6.6
WALL_SDR11 = 10.0
SOCKET_DEPTH = 55.0
SOCKET_CLEARANCE = 1.0
CENTER_LAND = 15.0
FITTING_WALL = WALL_SDR11
TERMINAL_DIA = 4.0
TERMINAL_LEN = 8.0
TERMINAL_INSET = 20.0
ELBOW_BEND_RADIUS = 1.5 * OD_110
DEMO_PIPE_LENGTH = 300.0
PE_DENSITY_G_CM3 = 0.95  # standard PE100 density reference, ~950 kg/m3

FITTING_OD = OD_110 + 2 * FITTING_WALL
SOCKET_BORE = OD_110 + SOCKET_CLEARANCE
COUPLING_LEN = 2 * SOCKET_DEPTH + CENTER_LAND

OUT_DIR = os.path.join(os.path.dirname(__file__), "drawings")

# ---- Tiny SVG helper layer --------------------------------------------------
SHEET_W, SHEET_H = 297.0, 210.0  # A4 landscape, mm == user units


class Svg:
    def __init__(self):
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def line(self, x1, y1, x2, y2, cls="thin"):
        self.add(f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" class="{cls}"/>')

    def rect(self, x, y, w, h, cls="thin", fill="none"):
        self.add(f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" class="{cls}" fill="{fill}"/>')

    def text(self, x, y, s, size=3.2, anchor="start", cls="txt", weight="normal"):
        self.add(
            f'<text x="{x:.2f}" y="{y:.2f}" font-size="{size}" text-anchor="{anchor}" '
            f'font-family="DejaVu Sans, Arial, sans-serif" font-weight="{weight}" class="{cls}">{s}</text>'
        )

    def hatched_rect(self, x, y, w, h):
        # Note: must NOT use the "outline" class here — its CSS fill:none
        # would win over the presentation-attribute fill below (CSS class
        # rules beat presentation attributes in the SVG/CSS cascade).
        self.rect(x, y, w, h, cls="hatchrect", fill="url(#hatch)")

    def arrow_h(self, x, y, pointing_right=True):
        d = 1.6
        if pointing_right:
            self.add(f'<polygon points="{x:.2f},{y:.2f} {x-d:.2f},{y-0.6:.2f} {x-d:.2f},{y+0.6:.2f}" class="fillblk"/>')
        else:
            self.add(f'<polygon points="{x:.2f},{y:.2f} {x+d:.2f},{y-0.6:.2f} {x+d:.2f},{y+0.6:.2f}" class="fillblk"/>')

    def arrow_v(self, x, y, pointing_down=True):
        d = 1.6
        if pointing_down:
            self.add(f'<polygon points="{x:.2f},{y:.2f} {x-0.6:.2f},{y-d:.2f} {x+0.6:.2f},{y-d:.2f}" class="fillblk"/>')
        else:
            self.add(f'<polygon points="{x:.2f},{y:.2f} {x-0.6:.2f},{y+d:.2f} {x+0.6:.2f},{y+d:.2f}" class="fillblk"/>')

    def dim_horizontal(self, x1, x2, y, label):
        self.line(x1, y - 2, x1, y + 2, cls="ext")
        self.line(x2, y - 2, x2, y + 2, cls="ext")
        self.line(x1, y, x2, y, cls="dim")
        self.arrow_h(x1, y, pointing_right=True)
        self.arrow_h(x2, y, pointing_right=False)
        self.text((x1 + x2) / 2, y - 1.2, label, anchor="middle", size=3.0)

    def dim_vertical(self, y1, y2, x, label):
        self.line(x - 2, y1, x + 2, y1, cls="ext")
        self.line(x - 2, y2, x + 2, y2, cls="ext")
        self.line(x, y1, x, y2, cls="dim")
        self.arrow_v(x, y1, pointing_down=True)
        self.arrow_v(x, y2, pointing_down=False)
        self.text(x + 1.5, (y1 + y2) / 2, label, size=3.0)

    def render(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SHEET_W}mm" height="{SHEET_H}mm" '
            f'viewBox="0 0 {SHEET_W} {SHEET_H}">\n'
            "<defs>\n"
            '<pattern id="hatch" patternUnits="userSpaceOnUse" width="2.2" height="2.2" '
            'patternTransform="rotate(45)">\n'
            '<line x1="0" y1="0" x2="0" y2="2.2" stroke="#333" stroke-width="0.25"/>\n'
            "</pattern>\n"
            "</defs>\n"
            "<style>\n"
            "  .outline{stroke:#111;stroke-width:0.35;fill:none}\n"
            "  .hatchrect{stroke:#111;stroke-width:0.35}\n"
            "  .thin{stroke:#111;stroke-width:0.2;fill:none}\n"
            "  .dim{stroke:#111;stroke-width:0.15;fill:none}\n"
            "  .ext{stroke:#555;stroke-width:0.12;fill:none}\n"
            "  .center{stroke:#933;stroke-width:0.15;stroke-dasharray:6,1.5,1,1.5;fill:none}\n"
            "  .fillblk{fill:#111;stroke:none}\n"
            "  .txt{fill:#111}\n"
            "  .hdr{fill:#111}\n"
            "  .note{fill:#333;font-style:italic}\n"
            "  .border{stroke:#111;stroke-width:0.5;fill:none}\n"
            "</style>\n"
            + f'<rect x="0" y="0" width="{SHEET_W}" height="{SHEET_H}" fill="#fdfdf7"/>\n'
            + "\n".join(self.parts)
            + "\n</svg>\n"
        )


def title_block(svg: Svg, x, y, w, h, designation, name, material, mass_kg, scale, sheet_no, note):
    """Simplified GOST 2.104-style title block. Explicitly NOT a certified
    ESKD form — labelled as a simplified reference block (see README.md)."""
    svg.rect(x, y, w, h, cls="border")
    row_h = h / 5
    for i in range(1, 5):
        svg.line(x, y + i * row_h, x + w, y + i * row_h, cls="thin")
    col1 = x + w * 0.62
    svg.line(col1, y, col1, y + h, cls="thin")

    svg.text(x + 2, y + row_h - 1.3, f"Обозн.: {designation}", size=3.0, weight="bold")
    svg.text(x + 2, y + 2 * row_h - 1.3, name, size=3.0, weight="bold")
    svg.text(x + 2, y + 3 * row_h - 1.3, f"Материал: PE100, {material}", size=2.8)
    svg.text(x + 2, y + 4 * row_h - 1.3, f"Расчётная масса: {mass_kg:.2f} кг", size=2.8)
    svg.text(x + 2, y + 5 * row_h - 1.3, note, size=2.1, cls="note")

    svg.text(col1 + 2, y + row_h - 1.3, f"Масштаб {scale}", size=2.8)
    svg.text(col1 + 2, y + 2 * row_h - 1.3, f"Лист {sheet_no} Листов 1", size=2.8)
    svg.text(col1 + 2, y + 3 * row_h - 1.3, "Мангустик / welder-module", size=2.6)
    svg.text(col1 + 2, y + 4 * row_h - 1.3, "УПРОЩЁННЫЙ ШТАМП", size=2.4, cls="note")
    svg.text(col1 + 2, y + 5 * row_h - 1.3, "(не для юр. подачи)", size=2.2, cls="note")


def sourcing_footnote(svg: Svg, x, y, lines):
    for i, l in enumerate(lines):
        svg.text(x, y + i * 3.0, l, size=2.4, cls="note")


def draw_straight_tube(name_ru, designation, out_r, in_r, length, material_note, mass_kg,
                        footnote_lines, extra_marks=None):
    svg = Svg()
    svg.rect(3, 3, SHEET_W - 6, SHEET_H - 6, cls="border")

    # Layout: main longitudinal full-section view on the left, end view top-right.
    # Cap scale on BOTH length and diameter so the section view never collides
    # with the header text (above) or the title block (below, fixed at
    # SHEET_H-45).
    scale = min(150.0 / length, 100.0 / (2 * out_r), 1.0)
    ox, oy = 20.0, 95.0  # origin: left end of the part, axis at y=oy

    def X(z):
        return ox + z * scale

    def Y(r):
        return oy - r * scale

    # Wall hatch — top half and bottom half
    svg.hatched_rect(X(0), Y(out_r), length * scale, (out_r - in_r) * scale)
    svg.hatched_rect(X(0), oy, length * scale, (out_r - in_r) * scale)
    # Outline
    svg.line(X(0), Y(out_r), X(length), Y(out_r), cls="outline")
    svg.line(X(0), Y(in_r), X(length), Y(in_r), cls="outline")
    svg.line(X(0), oy + (out_r - in_r) * scale, X(length), oy + (out_r - in_r) * scale, cls="outline")
    svg.line(X(0), oy + out_r * scale, X(length), oy + out_r * scale, cls="outline")
    svg.line(X(0), Y(out_r), X(0), oy + out_r * scale, cls="outline")
    svg.line(X(length), Y(out_r), X(length), oy + out_r * scale, cls="outline")
    # Centerline
    svg.line(X(-8), oy, X(length + 8), oy, cls="center")

    if extra_marks:
        for z in extra_marks:
            svg.line(X(z), Y(out_r) - 1.5, X(z), Y(out_r), cls="thin")
            r_out_scaled = out_r * scale
            svg.add(
                f'<circle cx="{X(z):.2f}" cy="{Y(out_r) - 1.0:.2f}" r="0.9" class="thin" fill="#111"/>'
            )

    # Dimensions
    svg.dim_horizontal(X(0), X(length), Y(out_r) - 8, f"L={length:.0f}")
    svg.dim_vertical(Y(out_r), oy + out_r * scale, X(length) + 8, f"⌀{2*out_r:.1f}")
    svg.dim_vertical(Y(in_r), oy + (out_r - in_r) * scale, X(length) + 16, f"⌀{2*in_r:.1f}")

    # End view (circle), top-right
    cx, cy, R = SHEET_W - 60, 40, 20
    svg.add(f'<circle cx="{cx}" cy="{cy}" r="{R}" class="hatchrect" fill="url(#hatch)"/>')
    svg.add(f'<circle cx="{cx}" cy="{cy}" r="{R * in_r/out_r}" class="outline" fill="#fdfdf7"/>')
    svg.line(cx - R - 4, cy, cx + R + 4, cy, cls="center")
    svg.line(cx, cy - R - 4, cx, cy + R + 4, cls="center")
    svg.text(cx, cy - R - 6, "Вид с торца", anchor="middle", size=3.0)

    svg.text(20, 20, name_ru, size=5.0, weight="bold")
    svg.text(20, 26, f"d110, {material_note}", size=3.2)

    sourcing_footnote(svg, 20, SHEET_H - 40, footnote_lines)

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, designation, name_ru,
                material_note, mass_kg, f"{scale:.2f}:1", "1",
                "См. README.md (верифиц./оценочные размеры)")
    return svg


def volume_tube_cm3(out_d, in_d, length):
    return math.pi / 4 * (out_d ** 2 - in_d ** 2) * length / 1000.0


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # ---- Pipe segment (SDR17, PN10) ---------------------------------------
    in_r = (OD_110 - 2 * WALL_SDR17) / 2
    out_r = OD_110 / 2
    vol = volume_tube_cm3(OD_110, OD_110 - 2 * WALL_SDR17, DEMO_PIPE_LENGTH)
    mass = vol * PE_DENSITY_G_CM3 / 1000.0
    svg = draw_straight_tube(
        "Труба ПЭ100 d110 SDR17 (PN10)",
        "MNG-PIPE-D110-SDR17",
        out_r, in_r, DEMO_PIPE_LENGTH,
        "SDR17 (стенка 6.6мм, PN10)",
        mass,
        [
            "ВЕРИФИЦИРОВАНО: ⌀110 нар., стенка 6.6мм — ГОСТ 18599-2001, PE100 SDR17,",
            "перекрёстно подтверждено >=3 независимыми источниками (см. README.md).",
            "Длина 300мм — образец для стенда сварки, НЕ длина по ГОСТ (реальная поставка L=12м).",
        ],
    )
    with open(os.path.join(OUT_DIR, "pipe_segment_d110.svg"), "w") as f:
        f.write(svg.render())

    # ---- Straight coupling (муфта) ----------------------------------------
    in_r = SOCKET_BORE / 2
    out_r = FITTING_OD / 2
    vol = volume_tube_cm3(FITTING_OD, SOCKET_BORE, COUPLING_LEN)
    mass = vol * PE_DENSITY_G_CM3 / 1000.0
    svg = draw_straight_tube(
        "Муфта электросварная ПЭ100 d110",
        "MNG-COUPLING-D110",
        out_r, in_r, COUPLING_LEN,
        "экв. SDR11 стенка",
        mass,
        [
            "ОЦЕНОЧНАЯ ГЕОМЕТРИЯ: длина муфты, глубина раструба, посадочный зазор, диаметр/шаг",
            "выводов нагревателя НЕ взяты из единой таблицы ГОСТ 32415-2013 (она задаёт",
            "требования к испытаниям/материалу, а не CAD-размеры — те по ТУ производителя).",
            "⌀110+1.0мм посадочный зазор — типовое инженерное значение, не из даташита.",
        ],
        extra_marks=[TERMINAL_INSET, COUPLING_LEN - TERMINAL_INSET],
    )
    with open(os.path.join(OUT_DIR, "coupling_d110.svg"), "w") as f:
        f.write(svg.render())

    # ---- 90-degree elbow (schematic, not full section) --------------------
    svg = Svg()
    svg.rect(3, 3, SHEET_W - 6, SHEET_H - 6, cls="border")
    r = ELBOW_BEND_RADIUS
    leg = SOCKET_DEPTH
    fit_od = FITTING_OD
    # Bounding box of the schematic (bend + both legs, incl. outer-wall
    # offset) is roughly [-leg-off, r+off] on both local axes — scale/offset
    # chosen so that box clears the header text (top) and the title block
    # (bottom-right) on the fixed A4 sheet.
    scale = 0.32
    ox, oy = 65.0, 120.0

    def P(x, y):
        return (ox + x * scale, oy - y * scale)

    # centerline arc + legs (schematic single-line representation)
    p0 = P(r, -leg)
    p1 = P(r, 0)
    p2 = P(0, r)
    p3 = P(-leg, r)
    svg.line(*p0, *p1, cls="center")
    svg.add(
        f'<path d="M {p1[0]:.2f} {p1[1]:.2f} A {r*scale:.2f} {r*scale:.2f} 0 0 0 {p2[0]:.2f} {p2[1]:.2f}" class="center"/>'
    )
    svg.line(*p2, *p3, cls="center")

    # outer/inner walls as offset arcs+lines (schematic double-line pipe representation)
    for off, cls in [(fit_od / 2, "outline"), (SOCKET_BORE / 2, "thin")]:
        q0 = P(r - off, -leg)
        q1 = P(r - off, 0)
        q2 = P(0, r - off)
        q3 = P(-leg, r - off)
        w0 = P(r + off, -leg)
        w1 = P(r + off, 0)
        w2 = P(0, r + off)
        w3 = P(-leg, r + off)
        svg.line(*q0, *q1, cls=cls)
        svg.add(f'<path d="M {q1[0]:.2f} {q1[1]:.2f} A {(r-off)*scale:.2f} {(r-off)*scale:.2f} 0 0 0 {q2[0]:.2f} {q2[1]:.2f}" class="{cls}"/>')
        svg.line(*q2, *q3, cls=cls)
        svg.line(*w0, *w1, cls=cls)
        svg.add(f'<path d="M {w1[0]:.2f} {w1[1]:.2f} A {(r+off)*scale:.2f} {(r+off)*scale:.2f} 0 0 0 {w2[0]:.2f} {w2[1]:.2f}" class="{cls}"/>')
        svg.line(*w2, *w3, cls=cls)
        svg.line(*q0, *w0, cls=cls)
        svg.line(*q3, *w3, cls=cls)

    svg.text(20, 20, "Отвод 90° электросварной ПЭ100 d110", size=5.0, weight="bold")
    svg.text(20, 26, "по SDR11-эквивалентной стенке", size=3.2)
    svg.text(20, 32, "Схематичный вид (не полное сечение) — см. README.md", size=2.6, cls="note")

    vol_bend = (math.pi / 2) * r * (math.pi / 4 * (fit_od ** 2 - SOCKET_BORE ** 2)) / 1000.0
    vol_legs = 2 * leg * (math.pi / 4 * (fit_od ** 2 - SOCKET_BORE ** 2)) / 1000.0
    mass = (vol_bend + vol_legs) * PE_DENSITY_G_CM3 / 1000.0

    sourcing_footnote(
        svg, 20, SHEET_H - 46,
        [
            "ОЦЕНОЧНАЯ ГЕОМЕТРИЯ: радиус гиба (1.5x⌀110=165мм — типовое правило long-radius",
            "отвода), длина ниппеля/раструба — инженерные оценки, НЕ из даташита или",
            "единой таблицы ГОСТ 32415-2013 (см. README.md). Модель — упрощённая, гладкий",
            "гиб постоянного радиуса, не точная торовая геометрия конкретного производителя.",
        ],
    )
    svg.dim_horizontal(P(-leg, r)[0], P(0, r)[0] - 0, P(-leg, r)[1] + 10, f"нипель {leg:.0f}")
    svg.text(P(r, r * 0.4)[0] + 5, P(r, r * 0.4)[1], f"R{r:.0f} (осевая линия гиба)", size=2.8)
    svg.dim_vertical(P(r, -leg)[1], P(r, -leg)[1] - (fit_od) * scale, P(r, -leg)[0] + 12, f"⌀{fit_od:.0f}")

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-ELBOW90-D110",
                "Отвод 90° ПЭ100 d110", "по SDR11-экв. стенке", mass, f"{scale:.2f}:1", "1",
                "См. README.md (верифиц./оценочные размеры)")

    with open(os.path.join(OUT_DIR, "elbow90_d110.svg"), "w") as f:
        f.write(svg.render())

    # ---- T-junction (тройник) ------------------------------------------------
    tee_center_sphere = 20.0
    tee_socket_depth = SOCKET_DEPTH
    tee_main_leg_len = SOCKET_DEPTH  # simplification: each leg segment

    svg = Svg()
    svg.rect(3, 3, SHEET_W - 6, SHEET_H - 6, cls="border")

    # Schematic longitudinal view of T-junction: vertical main pipe with horizontal branches
    scale = 0.4
    ox, oy = 30.0, 110.0

    def Tx(x): return ox + x * scale
    def Ty(y): return oy - y * scale

    # Main vertical leg (top and bottom sockets)
    main_height = 2 * tee_socket_depth + tee_center_sphere
    svg.line(Tx(-OD_110/2), Ty(main_height/2), Tx(OD_110/2), Ty(main_height/2), cls="center")
    svg.line(Tx(-OD_110/2), Ty(-main_height/2), Tx(OD_110/2), Ty(-main_height/2), cls="center")

    # Horizontal branch (schematic centerline)
    branch_width = 2 * (tee_socket_depth + 10)
    svg.line(Tx(-branch_width/2), Ty(0), Tx(branch_width/2), Ty(0), cls="center")

    # Central sphere (simplified T-junction core)
    sphere_r = tee_center_sphere / 2 * scale
    svg.add(f'<circle cx="{Tx(0)}" cy="{Ty(0)}" r="{sphere_r}" class="outline"/>')

    # Outer walls (pipe outlines)
    outer_r = (FITTING_OD / 2) * scale
    inner_r = (SOCKET_BORE / 2) * scale

    # Vertical pipe sections (double-line representation)
    for x_off in [-outer_r, 0, outer_r]:
        svg.line(Tx(-OD_110/2 + x_off), Ty(main_height/2), Tx(-OD_110/2 + x_off), Ty(tee_socket_depth * scale), cls="outline" if abs(x_off) == outer_r else "thin")
        svg.line(Tx(-OD_110/2 + x_off), Ty(-main_height/2), Tx(-OD_110/2 + x_off), Ty(-tee_socket_depth * scale), cls="outline" if abs(x_off) == outer_r else "thin")

    # Horizontal branch (double-line representation)
    for y_off in [-outer_r, 0, outer_r]:
        svg.line(Tx(-branch_width/2), Ty(y_off), Tx(-tee_socket_depth * scale), Ty(y_off), cls="outline" if abs(y_off) == outer_r else "thin")
        svg.line(Tx(branch_width/2), Ty(y_off), Tx(tee_socket_depth * scale), Ty(y_off), cls="outline" if abs(y_off) == outer_r else "thin")

    # Terminal markers (heater points)
    terminal_positions = [
        (Tx(0), Ty(tee_socket_depth + 10)),  # top
        (Tx(0), Ty(-tee_socket_depth - 10)),  # bottom
        (Tx(tee_socket_depth + 10), Ty(0))    # side
    ]
    for px, py in terminal_positions:
        svg.add(f'<circle cx="{px:.2f}" cy="{py:.2f}" r="1.2" class="fillblk"/>')

    # Dimensions
    svg.dim_vertical(Ty(main_height/2), Ty(-main_height/2), Tx(FITTING_OD/2 + 15), f"H={main_height:.0f}")
    svg.dim_horizontal(Tx(-branch_width/2), Tx(branch_width/2), Ty(-outer_r - 8), f"W={branch_width:.0f}")

    # End view (circle showing 3-way junction)
    cx, cy, R = SHEET_W - 60, 50, 22
    svg.add(f'<circle cx="{cx}" cy="{cy}" r="{R}" class="outline"/>')
    svg.add(f'<circle cx="{cx}" cy="{cy}" r="{R * SOCKET_BORE/FITTING_OD}" class="thin" fill="#fdfdf7"/>')
    # Draw radial lines showing the three branch directions
    svg.line(cx, cy - R - 1, cx, cy + R + 1, cls="thin")
    svg.line(cx - R - 1, cy, cx + R + 1, cy, cls="thin")
    svg.text(cx, cy - R - 6, "Вид с торца (тройник)", anchor="middle", size=2.8)

    svg.text(20, 20, "Тройник электросварной ПЭ100 d110 (три раструба)", size=4.8, weight="bold")
    svg.text(20, 26, "по SDR11-эквивалентной стенке", size=3.2)
    svg.text(20, 32, "Схематичный вид — центральный узел + три ортогональных раструба", size=2.6, cls="note")

    vol_tee_sphere = (4/3) * math.pi * ((tee_center_sphere / 2) ** 3) / 1000.0
    vol_tee_legs = 3 * tee_socket_depth * (math.pi / 4 * (FITTING_OD ** 2 - SOCKET_BORE ** 2)) / 1000.0
    mass_tee = (vol_tee_sphere + vol_tee_legs) * PE_DENSITY_G_CM3 / 1000.0

    sourcing_footnote(
        svg, 20, SHEET_H - 46,
        [
            "ОЦЕНОЧНАЯ ГЕОМЕТРИЯ: диаметр центрального узла (20мм), глубины раструбов (55мм),",
            "расстояния между осями — инженерные оценки. Модель упрощена: гладкая сфера вместо",
            "реальной конусной/пирамидальной переходной геометрии, характерной для",
            "электросварных тройников. Применить реальный CAD от производителя перед производством.",
        ],
    )

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-TEE-D110",
                "Тройник ПЭ100 d110", "по SDR11-экв. стенке", mass_tee, f"{scale:.2f}:1", "1",
                "См. README.md (верифиц./оценочные размеры)")

    with open(os.path.join(OUT_DIR, "tee_d110.svg"), "w") as f:
        f.write(svg.render())

    # ---- End cap (заглушка) --------------------------------------------------
    svg = Svg()
    svg.rect(3, 3, SHEET_W - 6, SHEET_H - 6, cls="border")

    scale = 0.5
    ox, oy = 50.0, 110.0

    def Cx(x): return ox + x * scale
    def Cy(y): return oy - y * scale

    cap_socket_depth = SOCKET_DEPTH
    cap_dome_radius = OD_110 / 2
    cap_total_len = cap_socket_depth + cap_dome_radius

    # Longitudinal section: socket barrel + hemispherical dome
    # Socket part (cylindrical)
    svg.line(Cx(0), Cy(OD_110/2), Cx(cap_socket_depth), Cy(OD_110/2), cls="outline")
    svg.line(Cx(0), Cy(-(OD_110/2)), Cx(cap_socket_depth), Cy(-(OD_110/2)), cls="outline")
    svg.line(Cx(0), Cy(SOCKET_BORE/2), Cx(cap_socket_depth), Cy(SOCKET_BORE/2), cls="thin")
    svg.line(Cx(0), Cy(-(SOCKET_BORE/2)), Cx(cap_socket_depth), Cy(-(SOCKET_BORE/2)), cls="thin")

    # Hemispherical dome (represented as circular arc in section)
    svg.add(f'<path d="M {Cx(cap_socket_depth):.2f} {Cy(OD_110/2):.2f} A {cap_dome_radius*scale:.2f} {cap_dome_radius*scale:.2f} 0 0 1 {Cx(cap_socket_depth + cap_dome_radius):.2f} {Cy(0):.2f}" class="outline"/>')
    svg.add(f'<path d="M {Cx(cap_socket_depth):.2f} {Cy(-(OD_110/2)):.2f} A {cap_dome_radius*scale:.2f} {cap_dome_radius*scale:.2f} 0 0 0 {Cx(cap_socket_depth + cap_dome_radius):.2f} {Cy(0):.2f}" class="outline"/>')

    # Wall hatch (cap material)
    svg.hatched_rect(Cx(0), Cy(OD_110/2), cap_socket_depth * scale, ((OD_110 - SOCKET_BORE) / 2) * scale)
    svg.hatched_rect(Cx(0), Cy(-(OD_110/2)), cap_socket_depth * scale, ((OD_110 - SOCKET_BORE) / 2) * scale)

    # Centerline
    svg.line(Cx(-5), Cy(0), Cx(cap_total_len + 5), Cy(0), cls="center")

    # Terminal marker (if applicable for electrofusion)
    svg.add(f'<circle cx="{Cx(cap_socket_depth/2):.2f}" cy="{Cy(OD_110/2 - 3):.2f}" r="1.2" class="fillblk"/>')

    # End view (circle)
    cx2, cy2, R2 = SHEET_W - 60, 50, 20
    svg.add(f'<circle cx="{cx2}" cy="{cy2}" r="{R2}" class="hatchrect" fill="url(#hatch)"/>')
    svg.add(f'<circle cx="{cx2}" cy="{cy2}" r="{R2 * SOCKET_BORE/FITTING_OD}" class="outline" fill="#fdfdf7"/>')
    svg.line(cx2 - R2 - 4, cy2, cx2 + R2 + 4, cy2, cls="center")
    svg.line(cx2, cy2 - R2 - 4, cx2, cy2 + R2 + 4, cls="center")
    svg.text(cx2, cy2 - R2 - 6, "Вид с торца", anchor="middle", size=2.8)

    # Dimensions
    svg.dim_horizontal(Cx(0), Cx(cap_socket_depth), Cy(OD_110/2) + 8, f"раструб {cap_socket_depth:.0f}")
    svg.dim_horizontal(Cx(cap_socket_depth), Cx(cap_socket_depth + cap_dome_radius), Cy(-OD_110/2) - 8, f"купол R{cap_dome_radius:.0f}")
    svg.dim_vertical(Cy(OD_110/2), Cy(-(OD_110/2)), Cx(cap_total_len) + 10, f"⌀{OD_110:.0f}")

    svg.text(20, 20, "Заглушка электросварная ПЭ100 d110 (колпак)", size=4.8, weight="bold")
    svg.text(20, 26, "по SDR11-эквивалентной стенке", size=3.2)
    svg.text(20, 32, "Гемисферическая герметизирующая поверхность", size=2.6, cls="note")

    vol_cap_socket = (math.pi / 4 * (FITTING_OD ** 2 - SOCKET_BORE ** 2)) * cap_socket_depth / 1000.0
    vol_cap_dome = (2.0/3.0) * math.pi * ((OD_110 / 2) ** 3) / 1000.0
    mass_cap = (vol_cap_socket + vol_cap_dome) * PE_DENSITY_G_CM3 / 1000.0

    sourcing_footnote(
        svg, 20, SHEET_H - 46,
        [
            "ОЦЕНОЧНАЯ ГЕОМЕТРИЯ: диаметр купола (0.5×⌀110=55мм, гемисфера), глубина раструба —",
            "инженерные оценки. Модель: идеальная полусфера, без фаски, без шероховатости",
            "герметизирующей поверхности. Реальные заглушки включают камеру пазов/борозд для",
            "смятия уплотнителя и точные контуры края. Уточнить по даташиту производителя.",
        ],
    )

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-CAP-D110",
                "Заглушка ПЭ100 d110", "по SDR11-экв. стенке", mass_cap, f"{scale:.2f}:1", "1",
                "См. README.md (верифиц./оценочные размеры)")

    with open(os.path.join(OUT_DIR, "cap_d110.svg"), "w") as f:
        f.write(svg.render())

    # ---- Housing assembly (summary schematic) --------------------------------
    svg = Svg()
    svg.rect(3, 3, SHEET_W - 6, SHEET_H - 6, cls="border")

    svg.text(20, 20, "Сборка корпуса d110 — модульная конфигурация", size=5.0, weight="bold")
    svg.text(20, 26, "Вертикальная ось + два горизонтальных ответвления (эскиз)", size=3.2)

    # Simplified block diagram of the housing assembly
    assembly_text = [
        "ГЛАВНАЯ ОСЬ (вертикальная, Z-направление):",
        "  • Нижний сегмент трубы: 200 мм (SDR17)",
        "  • Тройник на Z=200 мм (основная развилка)",
        "  • Средний сегмент: 150 мм",
        "  • Тройник на Z=350 мм (дополнительные ветви)",
        "  • Верхний сегмент: 100 мм",
        "  • Заглушка верхняя (Z=500 мм) — закрытие оси",
        "",
        "БОКОВЫЕ ВЕТВИ (горизонтальные, X/Y-направления):",
        "  • Каждое ответвление выходит из тройника",
        "  • Колено 90° (отвод) для переориентации",
        "  • Завершение заглушкой или быстрым разъёмом",
        "",
        "ГАБАРИТЫ СБОРКИ:",
        "  • Высота: 500 мм (главная ось)",
        "  • Ширина (боковая): ±300 мм",
        "  • Глубина: ±250 мм",
        "",
        "ЭЛЕКТРОСВАРНАЯ ИНТЕГРАЦИЯ:",
        "  • Каждый элемент имеет видимые выводы (⌀4мм)",
        "  • Верхний/средний/нижний ярусы — трёхполюсная схема питания",
        "  • Реальная компоновка нагревателя — по ТУ производителя",
    ]

    y_pos = 36
    for line in assembly_text:
        svg.text(20, y_pos, line, size=2.6, cls="txt" if line.startswith(" ") else "hdr")
        y_pos += 4.5

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-HOUSING-D110-ASM",
                "Сборка корпуса d110", "компоновка d110 PE100", 0.0, "эскиз", "1",
                "Упрощённая схема, масштаб условный")

    with open(os.path.join(OUT_DIR, "housing_d110_assembly.svg"), "w") as f:
        f.write(svg.render())

    # ---- Flanged connector (Strategy 2) ----------------------------------------
    drawing_flanged_connector()

    # ---- Camlock connector (Strategy 3) ----------------------------------------
    drawing_camlock_connector()


def drawing_flanged_connector():
    """Flanged bulkhead connector (Strategy 2) — 150mm flange, 4×M8 bolts."""
    svg = Svg()

    # Specifications box
    specs_text = [
        "ФЛАНЦЕВОЕ СОЕДИНЕНИЕ d110 (Стратегия 2):",
        "  • OD фланца: 150 мм",
        "  • Толщина: 12 мм",
        "  • Глубина гнезда: 55 мм (электросварное, d110)",
        "  • Болтовой паттерн: 4× M8 на PCD 120 мм",
        "  • Седло O-ring: 15 мм диаметр, 4 мм глубина",
        "  • Уплотнение: эластомер (FKM/Viton)",
        "  • Рейтинг: PN16 (160 бар) при надлежащем затяге",
        "ПРИМЕЧАНИЕ: быстрое разъединение, модульное исполнение",
    ]

    y_pos = 50
    for line in specs_text:
        svg.text(20, y_pos, line, size=2.4, cls="txt" if line.startswith(" ") else "hdr")
        y_pos += 3.5

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-FLANGED-CONN",
                "Фланцевый разьём d110", "быстр.-разьём PN16", 0.0, "эскиз", "1",
                "Болтовой разъём 4×M8, FKM O-ring")

    with open(os.path.join(OUT_DIR, "connector_d110_flange.svg"), "w") as f:
        f.write(svg.render())


def drawing_camlock_connector():
    """Camlock quick-disconnect (Strategy 3) — ISO 16028, 1-inch bore, flat-face."""
    svg = Svg()

    # Specifications
    specs_text = [
        "КАМЛОК-БЫСТРОРАЗЪЁМ d110 (Стратегия 3):",
        "  • Диаметр канала: 25.4 мм (1 дюйм ISO 16028)",
        "  • Обойма OD: 110 мм (d110 интеграция)",
        "  • Длина корпуса: 80 мм",
        "  • Диаметр плоской закрытой поверхности: 35 мм",
        "  • Эксплуатационное давление: PN16 (160 бар)",
        "  • Рычаг включает: поворот 1/4 оборота, самоуплотняющийся (без пролива)",
        "  • Уплотнение: эластомер FKM, плоская закрытая поверхность",
        "ПРИМЕЧАНИЕ: 3 кулачка, расположенные в окружности, для сбалансированной фиксации",
    ]

    y_pos = 50
    for line in specs_text:
        svg.text(20, y_pos, line, size=2.4, cls="txt" if line.startswith(" ") else "hdr")
        y_pos += 3.5

    title_block(svg, SHEET_W - 130, SHEET_H - 45, 120, 35, "MNG-CAMLOCK-CONN",
                "Камлок разъём d110", "быстр.-разъём ISO 16028", 0.0, "эскиз", "1",
                "Рычаг 1/4 оборота, плоское закрытое, PN16")

    with open(os.path.join(OUT_DIR, "connector_d110_camlock.svg"), "w") as f:
        f.write(svg.render())


if __name__ == "__main__":
    main()
