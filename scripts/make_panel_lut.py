#!/usr/bin/env python3
"""
make_panel_lut.py — generate a 3D color-correction LUT for the Rockchip VOP2.

Produces a 9×9×9 = 729-entry LUT in DRM color_lut format (4× u16 per entry,
total 5832 bytes) that maps sRGB input to the panel's native RGB drive
values needed to faithfully reproduce sRGB color on a non-sRGB panel.

Pipeline:
  1. Build the panel's RGB→XYZ matrix from its primary chromaticities + white.
  2. Take the published sRGB→XYZ matrix (D65).
  3. Build a Bradford chromatic-adaptation matrix from D65 to panel native white.
  4. Combined matrix M = M_panel⁻¹ · M_CAT · M_sRGB takes a linear sRGB triple
     to the linear panel-RGB drive values that produce the same color.
  5. Sample on the 9×9×9 input grid (input is gamma-encoded; apply sRGB EOTF
     to linearize, multiply by M, hard-clip to [0,1] for out-of-gamut input,
     apply sRGB OETF to re-encode).
  6. Quantize to u16 (round to 0..65535) and serialize.

Output index convention: R varies fastest, B slowest
  index(r, g, b) = r + g*N + b*N*N    (N = 9)

Per-channel precision: 12 bits. The VOP2 cubic-LUT hardware uses 12-bit
values per channel; the kernel driver masks each drm_color_lut field
with 0xfff before packing to hardware. We quantize to 4095 and leave
the high 4 bits of each u16 zero so nothing is silently truncated.

Defaults are calibrated for the JC-TLCM4505 panel used in the AISLPC RG43H Pro:
  R: (0.664, 0.323)
  G: (0.287, 0.593)
  B: (0.134, 0.119)
  W: (0.299, 0.327)   ← spec typical
Target: ~5650K = (0.3290, 0.3445) — warm white, the midpoint between D65 and
a 5000K (D50) reference. Splits the difference between an accurate-but-cool
neutral and the warmer 5000K some handheld builders prefer; at ~60% backlight
this reads as a comfortable warm-neutral on this panel.

White-retarget is ABSOLUTE: the panel's native white is ~7300K, so the
neutral axis is driven with attenuated blue/green to actually shift the
displayed white (not merely adapt-to-native, which leaves white untouched).

Loaded by apply_panel_lut.py via the atomic DRM CUBIC_LUT property.
"""

import argparse
import struct
import sys

CUBE_N = 9                  # 9x9x9
LUT_SIZE = CUBE_N ** 3      # 729
BYTES_PER_ENTRY = 8         # u16 R, G, B, reserved
OUTPUT_BYTES = LUT_SIZE * BYTES_PER_ENTRY  # 5832


# ---------------------------------------------------------------------------
# 3x3 matrix helpers (pure Python, no NumPy)
# ---------------------------------------------------------------------------

def mat_mul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(M, v):
    return [sum(M[i][k] * v[k] for k in range(3)) for i in range(3)]


def mat_inv(M):
    a, b, c = M[0]
    d, e, f = M[1]
    g, h, i = M[2]
    det = a*(e*i - f*h) - b*(d*i - f*g) + c*(d*h - e*g)
    if abs(det) < 1e-12:
        raise ValueError("singular matrix")
    inv_det = 1.0 / det
    return [
        [(e*i - f*h) * inv_det, (c*h - b*i) * inv_det, (b*f - c*e) * inv_det],
        [(f*g - d*i) * inv_det, (a*i - c*g) * inv_det, (c*d - a*f) * inv_det],
        [(d*h - e*g) * inv_det, (b*g - a*h) * inv_det, (a*e - b*d) * inv_det],
    ]


# ---------------------------------------------------------------------------
# Color space math
# ---------------------------------------------------------------------------

def xyY_to_XYZ(x, y, Y=1.0):
    """xy chromaticity (+ luminance Y) → XYZ."""
    if y <= 0:
        return [0.0, 0.0, 0.0]
    return [x * Y / y, Y, (1.0 - x - y) * Y / y]


def rgb_to_xyz_matrix(rx, ry, gx, gy, bx, by, wx, wy):
    """
    Build the RGB→XYZ matrix for a display with the given primary
    chromaticities and white point.

    The 3 columns are the XYZ of R=1,G=0,B=0 / R=0,G=1,B=0 / R=0,G=0,B=1
    respectively, scaled so that R=G=B=1 produces the white point at Y=1.
    """
    # Unscaled column vectors: each primary at xy with Y=1.
    M_primaries = [
        [rx / ry,           gx / gy,           bx / by          ],
        [1.0,               1.0,               1.0              ],
        [(1 - rx - ry) / ry,(1 - gx - gy) / gy,(1 - bx - by) / by],
    ]
    # Solve for per-primary luminance scaling (Y_R, Y_G, Y_B) such that
    # M_primaries · [Y_R, Y_G, Y_B] = white_XYZ (with white at Y=1).
    W = xyY_to_XYZ(wx, wy, 1.0)
    M_inv = mat_inv(M_primaries)
    S = mat_vec(M_inv, W)
    # Scale each column by its luminance.
    return [[M_primaries[i][j] * S[j] for j in range(3)] for i in range(3)]


def bradford_cat(src_white_xy, dst_white_xy):
    """
    Bradford chromatic adaptation matrix from src to dst white point.
    src and dst given as (x, y).
    """
    M_BFD = [
        [ 0.8951,  0.2664, -0.1614],
        [-0.7502,  1.7135,  0.0367],
        [ 0.0389, -0.0685,  1.0296],
    ]
    M_BFD_inv = mat_inv(M_BFD)

    src_XYZ = xyY_to_XYZ(*src_white_xy)
    dst_XYZ = xyY_to_XYZ(*dst_white_xy)
    src_LMS = mat_vec(M_BFD, src_XYZ)
    dst_LMS = mat_vec(M_BFD, dst_XYZ)

    D = [
        [dst_LMS[0] / src_LMS[0], 0.0,                       0.0                      ],
        [0.0,                       dst_LMS[1] / src_LMS[1], 0.0                      ],
        [0.0,                       0.0,                       dst_LMS[2] / src_LMS[2]],
    ]
    return mat_mul(M_BFD_inv, mat_mul(D, M_BFD))


def srgb_eotf(x):
    """sRGB encoded → linear (per-channel)."""
    if x <= 0.04045:
        return x / 12.92
    return ((x + 0.055) / 1.055) ** 2.4


def srgb_oetf(x):
    """linear → sRGB encoded (per-channel), clamped to [0,1]."""
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    if x <= 0.0031308:
        return x * 12.92
    return 1.055 * (x ** (1.0 / 2.4)) - 0.055


# ---------------------------------------------------------------------------
# LUT construction
# ---------------------------------------------------------------------------

def build_correction_matrix(panel_R, panel_G, panel_B, panel_W, target_W,
                             srgb_R=(0.640, 0.330),
                             srgb_G=(0.300, 0.600),
                             srgb_B=(0.150, 0.060),
                             srgb_W=(0.3127, 0.3290)):
    """
    Returns the 3×3 matrix that maps a linear sRGB triple to the linear
    panel-RGB drive values that reproduce sRGB color on the panel AND
    retarget the displayed white point to `target_W`.

    Intent is ABSOLUTE white retargeting (not adapt-to-display-white): the
    sRGB D65 white is mapped to `target_W` and then expressed in panel drive
    values. Because the panel's native white is cooler than the target, the
    panel's blue (and some green) drive is attenuated for the neutral axis —
    this is what actually warms the displayed white. The matrix is then scaled
    so the brightest channel of white = 1.0 (no clipping at the neutral axis;
    the warm shift comes from attenuating the other channels, exactly like the
    old empirical 1D LUT's R=1.00/G=0.95/B=0.80).

    NOTE: `srgb_W` is the TRUE sRGB white (D65) and must stay D65 — the white
    retarget is carried entirely by the D65→target_W adaptation below. Setting
    srgb_W to the target (the previous bug) makes the CAT cancel out and pins
    the displayed white to the panel's native point.
    """
    M_sRGB = rgb_to_xyz_matrix(*srgb_R, *srgb_G, *srgb_B, *srgb_W)
    M_panel = rgb_to_xyz_matrix(*panel_R, *panel_G, *panel_B, *panel_W)
    M_panel_inv = mat_inv(M_panel)
    # Adapt the sRGB D65 white to the desired displayed white point.
    M_CAT = bradford_cat(srgb_W, target_W)
    # panel_lin = M_panel_inv · M_CAT · M_sRGB · srgb_lin
    M = mat_mul(M_panel_inv, mat_mul(M_CAT, M_sRGB))
    # Normalize so neutral white (1,1,1) maps to max-channel = 1.0: keeps the
    # brightest primary at full drive and realizes the warm shift by pulling
    # the others down, rather than letting white clip.
    white_drive = mat_vec(M, [1.0, 1.0, 1.0])
    s = max(white_drive)
    if s > 0:
        M = [[v / s for v in row] for row in M]
    return M


def build_3d_lut(M):
    """
    Sample the correction matrix on a 9×9×9 grid and return 5832 bytes
    of DRM color_lut data.

    Input/output channels are gamma-encoded (sRGB). The matrix is applied
    in linear-light space.
    """
    out = bytearray()
    # R varies fastest, G middle, B slowest — index = r + g*N + b*N*N.
    # This is the standard IRIDAS .cube convention; the VOP2 hardware
    # uses the same convention.
    for b_idx in range(CUBE_N):
        for g_idx in range(CUBE_N):
            for r_idx in range(CUBE_N):
                r_enc = r_idx / (CUBE_N - 1)
                g_enc = g_idx / (CUBE_N - 1)
                b_enc = b_idx / (CUBE_N - 1)

                # Linearize via sRGB EOTF.
                lin = [srgb_eotf(r_enc), srgb_eotf(g_enc), srgb_eotf(b_enc)]

                # Apply correction matrix.
                drive = mat_vec(M, lin)

                # Hard-clip out-of-gamut to [0, 1].
                drive = [max(0.0, min(1.0, v)) for v in drive]

                # Re-encode and quantize to 12 bits (hardware width).
                r_u16 = int(round(srgb_oetf(drive[0]) * 4095))
                g_u16 = int(round(srgb_oetf(drive[1]) * 4095))
                b_u16 = int(round(srgb_oetf(drive[2]) * 4095))

                out.extend(struct.pack('<HHHH',
                                       max(0, min(4095, r_u16)),
                                       max(0, min(4095, g_u16)),
                                       max(0, min(4095, b_u16)),
                                       0))
    return bytes(out)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def fmt_mat(M, name):
    lines = [f"{name}:"]
    for row in M:
        lines.append("  " + "  ".join(f"{v:+.6f}" for v in row))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument('-o', '--output', required=True,
                    help='Output .lut file path (5832 bytes)')

    # Panel primary chromaticities — defaults from JC-TLCM4505 datasheet.
    ap.add_argument('--panel-rx', type=float, default=0.664)
    ap.add_argument('--panel-ry', type=float, default=0.323)
    ap.add_argument('--panel-gx', type=float, default=0.287)
    ap.add_argument('--panel-gy', type=float, default=0.593)
    ap.add_argument('--panel-bx', type=float, default=0.134)
    ap.add_argument('--panel-by', type=float, default=0.119)
    ap.add_argument('--panel-wx', type=float, default=0.299)
    ap.add_argument('--panel-wy', type=float, default=0.327)

    # Target white point. Default ~5650K (midpoint of D65 and a 5000K
    # reference) — warm-neutral on this panel at ~60% backlight; see the
    # module docstring for the rationale.
    ap.add_argument('--target-wx', type=float, default=0.3290)
    ap.add_argument('--target-wy', type=float, default=0.3445)

    ap.add_argument('--dump-matrix', action='store_true',
                    help='Print intermediate matrices for sanity checking')

    args = ap.parse_args()

    panel_R = (args.panel_rx, args.panel_ry)
    panel_G = (args.panel_gx, args.panel_gy)
    panel_B = (args.panel_bx, args.panel_by)
    panel_W = (args.panel_wx, args.panel_wy)
    target_W = (args.target_wx, args.target_wy)

    print(f"Panel primaries:")
    print(f"  R = ({panel_R[0]:.3f}, {panel_R[1]:.3f})")
    print(f"  G = ({panel_G[0]:.3f}, {panel_G[1]:.3f})")
    print(f"  B = ({panel_B[0]:.3f}, {panel_B[1]:.3f})")
    print(f"  W = ({panel_W[0]:.3f}, {panel_W[1]:.3f})")
    print(f"Target white = ({target_W[0]:.4f}, {target_W[1]:.4f})")

    M = build_correction_matrix(
        panel_R, panel_G, panel_B, panel_W, target_W,
    )

    if args.dump_matrix:
        D65 = (0.3127, 0.3290)
        M_panel = rgb_to_xyz_matrix(*panel_R, *panel_G, *panel_B, *panel_W)
        M_sRGB = rgb_to_xyz_matrix(
            0.640, 0.330, 0.300, 0.600, 0.150, 0.060,
            D65[0], D65[1],
        )
        M_CAT = bradford_cat(D65, target_W)
        white_drive = mat_vec(M, [1.0, 1.0, 1.0])
        print()
        print(fmt_mat(M_sRGB,  "M_sRGB (sRGB linear → XYZ, D65)"))
        print(fmt_mat(M_panel, "M_panel (panel linear → XYZ)"))
        print(fmt_mat(M_CAT,   "M_CAT (D65 → target white)"))
        print(fmt_mat(M,       "M (sRGB linear → panel linear, normalized)"))
        print(f"white (1,1,1) → panel drive "
              f"R={white_drive[0]:.4f} G={white_drive[1]:.4f} B={white_drive[2]:.4f}")
        print()

    data = build_3d_lut(M)
    assert len(data) == OUTPUT_BYTES, f"LUT size {len(data)} != {OUTPUT_BYTES}"

    with open(args.output, 'wb') as f:
        f.write(data)

    print(f"Wrote {args.output} ({len(data)} bytes, {LUT_SIZE} entries, 9×9×9 cube)")

    # Endpoint sanity.
    def entry(r, g, b):
        idx = r + g*CUBE_N + b*CUBE_N*CUBE_N
        return struct.unpack_from('<HHHH', data, idx * BYTES_PER_ENTRY)

    print(f"  black input → R=0x{entry(0,0,0)[0]:04x} "
          f"G=0x{entry(0,0,0)[1]:04x} B=0x{entry(0,0,0)[2]:04x}")
    print(f"  white input → R=0x{entry(8,8,8)[0]:04x} "
          f"G=0x{entry(8,8,8)[1]:04x} B=0x{entry(8,8,8)[2]:04x}")
    print(f"  red input   → R=0x{entry(8,0,0)[0]:04x} "
          f"G=0x{entry(8,0,0)[1]:04x} B=0x{entry(8,0,0)[2]:04x}")
    print(f"  green input → R=0x{entry(0,8,0)[0]:04x} "
          f"G=0x{entry(0,8,0)[1]:04x} B=0x{entry(0,8,0)[2]:04x}")
    print(f"  blue input  → R=0x{entry(0,0,8)[0]:04x} "
          f"G=0x{entry(0,0,8)[1]:04x} B=0x{entry(0,0,8)[2]:04x}")


if __name__ == '__main__':
    main()
