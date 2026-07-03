#!/usr/bin/env python3
"""Emit sparkline SVG matching GainSparklineView layout and colors."""

from __future__ import annotations

WIDTH, HEIGHT = 300, 36
POS = "#4CE06B"
NEG = "#F26B6B"
POS_FILL = "rgba(76, 224, 107, 0.22)"
NEG_FILL = "rgba(242, 107, 107, 0.22)"

SAMPLES = [
    (0.00, -1.2),
    (0.08, -2.4),
    (0.16, -3.8),
    (0.24, -5.6),
    (0.32, -7.2),
    (0.38, -8.1),
    (0.44, -6.8),
    (0.50, -4.5),
    (0.54, -2.1),
    (0.57, 0.0),
    (0.62, 1.4),
    (0.70, 2.6),
    (0.78, 3.4),
    (0.86, 4.0),
    (0.93, 4.5),
    (1.00, 4.8),
]


def y(gain: float, min_gain: float, gain_span: float) -> float:
    return HEIGHT * (1 - (gain - min_gain) / gain_span)


def x(t: float) -> float:
    return t * WIDTH


def main() -> None:
    gains = [g for _, g in SAMPLES]
    raw_min = min(min(gains), 0.0)
    raw_max = max(max(gains), 0.0)
    span = max(raw_max - raw_min, 1.0)
    padding = span * 0.08
    min_gain = raw_min - padding
    max_gain = raw_max + padding
    gain_span = max(max_gain - min_gain, 1.0)
    zero_y = y(0.0, min_gain, gain_span)

    segments: list[tuple[bool, list[tuple[float, float]]]] = []
    current_sign = SAMPLES[0][1] > 0
    current: list[tuple[float, float]] = []

    for t, g in SAMPLES:
        sign = g > 0 if g != 0 else current_sign
        if current and sign != current_sign:
            segments.append((current_sign, current))
            current = [(t, g)]
            current_sign = sign
        else:
            current.append((t, g))
            if g != 0:
                current_sign = sign
    if current:
        segments.append((current_sign, current))

    def polyline_points(pts: list[tuple[float, float]]) -> str:
        return " ".join(
            f"{x(t):.2f},{y(g, min_gain, gain_span):.2f}" for t, g in pts
        )

    def area_path(pts: list[tuple[float, float]]) -> str:
        first_x = x(pts[0][0])
        first_y = y(pts[0][1], min_gain, gain_span)
        lines = [f"M {first_x:.2f} {first_y:.2f}"]
        for t, g in pts[1:]:
            lines.append(f"L {x(t):.2f} {y(g, min_gain, gain_span):.2f}")
        lines.append(f"L {x(pts[-1][0]):.2f} {zero_y:.2f}")
        lines.append(f"L {x(pts[0][0]):.2f} {zero_y:.2f} Z")
        return " ".join(lines)

    print(
        f'<svg class="sparkline" viewBox="0 0 {WIDTH} {HEIGHT}" '
        'preserveAspectRatio="none" aria-hidden="true">'
    )
    print(
        f'<line x1="0" y1="{zero_y:.2f}" x2="{WIDTH}" y2="{zero_y:.2f}" '
        'stroke="rgba(152,152,157,0.35)" stroke-width="0.5" stroke-dasharray="3 3"/>'
    )
    for positive, pts in segments:
        stroke = POS if positive else NEG
        fill = POS_FILL if positive else NEG_FILL
        print(f'<path d="{area_path(pts)}" fill="{fill}"/>')
        print(
            f'<polyline fill="none" stroke="{stroke}" stroke-width="1.5" '
            f'stroke-linecap="round" stroke-linejoin="round" '
            f'points="{polyline_points(pts)}"/>'
        )
    print("</svg>")


if __name__ == "__main__":
    main()