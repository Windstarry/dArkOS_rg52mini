#!/usr/bin/env python3
"""
make_panel_lut.py — generate a 1D gamma LUT for the Rockchip VOP2.

Output format matches Linux DRM's struct drm_color_lut:
    1024 entries of (R, G, B, reserved) as 4× u16 little-endian
    Total: 8192 bytes

The LUT is consumed by apply_panel_lut.py on the device, which loads it
into the VOP2 hardware via drmModeCrtcSetGamma. Once loaded, the
hardware applies it for every pixel during scanout with zero CPU cost.

The LUT shape is: out_channel = (in_value/1023)^gamma_channel * gain_channel * 65535

Where:
  in_value   : raw 10-bit input gray code (0..1023)
  gain_*     : per-channel multiplier (1.0 = unity)
  gamma_*    : per-channel power-law exponent (1.0 = linear ramp through LUT)
  65535      : 16-bit u16 max output value

For the RG43H cool tint, the typical first guess is something like:
  R 1.00, G 0.96, B 0.85  (per-channel gains)
  gamma 1.0 across all channels (don't apply additional gamma curve;
  let the panel side handle gamma).
"""

import argparse
import struct
import sys

LUT_SIZE = 1024


def make_lut(r_gain, g_gain, b_gain, r_gamma, g_gamma, b_gamma):
    """Return the 8192-byte LUT as bytes."""
    out = bytearray()
    for i in range(LUT_SIZE):
        x = i / (LUT_SIZE - 1)  # 0.0 .. 1.0 normalized
        r = min(65535, int(round(((x ** r_gamma) * r_gain) * 65535)))
        g = min(65535, int(round(((x ** g_gamma) * g_gain) * 65535)))
        b = min(65535, int(round(((x ** b_gamma) * b_gain) * 65535)))
        out.extend(struct.pack('<HHHH', max(0, r), max(0, g), max(0, b), 0))
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('-o', '--output', required=True,
                    help='Output .lut file path')
    ap.add_argument('--red',   type=float, default=1.00,
                    help='Red channel gain (default 1.00)')
    ap.add_argument('--green', type=float, default=0.96,
                    help='Green channel gain (default 0.96)')
    ap.add_argument('--blue',  type=float, default=0.85,
                    help='Blue channel gain (default 0.85, pulls cool down)')
    ap.add_argument('--gamma',     type=float, default=1.0,
                    help='Gamma exponent applied to all channels (default 1.0 — linear)')
    ap.add_argument('--gamma-red',   type=float, default=None)
    ap.add_argument('--gamma-green', type=float, default=None)
    ap.add_argument('--gamma-blue',  type=float, default=None)
    args = ap.parse_args()

    r_gamma = args.gamma_red   if args.gamma_red   is not None else args.gamma
    g_gamma = args.gamma_green if args.gamma_green is not None else args.gamma
    b_gamma = args.gamma_blue  if args.gamma_blue  is not None else args.gamma

    print(f"Generating LUT with:")
    print(f"  R: gain={args.red:.3f}  gamma={r_gamma:.3f}")
    print(f"  G: gain={args.green:.3f}  gamma={g_gamma:.3f}")
    print(f"  B: gain={args.blue:.3f}  gamma={b_gamma:.3f}")

    data = make_lut(args.red, args.green, args.blue, r_gamma, g_gamma, b_gamma)
    assert len(data) == LUT_SIZE * 8

    with open(args.output, 'wb') as f:
        f.write(data)
    print(f"Wrote {args.output} ({len(data)} bytes)")

    # Show endpoint values for sanity
    last_r, last_g, last_b, _ = struct.unpack_from('<HHHH', data, (LUT_SIZE - 1) * 8)
    print(f"  White output: R=0x{last_r:04x} ({last_r}) "
          f"G=0x{last_g:04x} ({last_g}) "
          f"B=0x{last_b:04x} ({last_b})")
    print(f"  Black output: R=G=B=0x0000")


if __name__ == '__main__':
    main()
