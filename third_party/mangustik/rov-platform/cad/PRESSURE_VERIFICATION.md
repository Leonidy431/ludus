# Main pressure hull — closed-form verification

Hull: ⌀200×10 mm wall, Al 6061-T6, design depth 300 m (3.02 MPa).

- Hoop stress (Lamé, inner surface): 31.8 MPa (thin-wall cross-check: 28.7 MPa)
- Yield SF: 8.7 (vs 276 MPa)
- Long-tube elastic collapse: 22.5 MPa → buckling SF 7.5 (conservative: end caps ignored)
- Governing mode: buckling, SF 7.5

End cap (flat plate, a=90 mm, t=30 mm): σ=20.4 MPa clamped / 33.7 MPa simply-supported.
**Open item**: the ⌀80 mm optical cutout is a stress concentration this formula cannot see — FEA or a bolted port vendor rating is required before fabrication.

O-ring (CS 3.53 mm, radial static): groove depth 2.75 mm (22% squeeze, inside HLD's 20–25% band), width 4.74 mm (75% fill).

Constants are literature-typical (not lot certs); calcs are screening-
level and do not replace FEA for cutouts and weld/anodize effects.
