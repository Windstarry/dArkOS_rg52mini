#!/usr/bin/env python3
"""
apply_panel_lut.py — push a 1D gamma LUT to the active DRM CRTC.

Reads a LUT file in DRM color_lut format (1024 entries of 4× u16 = 8192 bytes)
and applies it via the legacy DRM_IOCTL_MODE_SETGAMMA / drmModeCrtcSetGamma
path. Uses libdrm.so.2 via ctypes — no compiled deps beyond the system libdrm.

Designed to run on the device (Debian Trixie, Python 3.13, libdrm 2.4+).
Typical invocation:
    sudo apply_panel_lut /etc/panel-lut/current.lut

If atomic-master ordering becomes an issue (CRTC state gets reset when a
later master takes over and does a modeset), this script will need to be
sequenced after the display server's first modeset, or replaced by an
atomic-blob variant. The legacy SetGamma path is the simplest first try.
"""

import ctypes
import ctypes.util
import os
import struct
import sys
import time

LUT_SIZE = 1024
DRM_NODE = '/dev/dri/card0'


# ---------------------------------------------------------------------------
# libdrm bindings (just enough)
# ---------------------------------------------------------------------------

_lib_path = ctypes.util.find_library('drm') or 'libdrm.so.2'
libdrm = ctypes.CDLL(_lib_path)


class DrmModeRes(ctypes.Structure):
    _fields_ = [
        ('count_fbs',        ctypes.c_int),
        ('fbs',              ctypes.POINTER(ctypes.c_uint32)),
        ('count_crtcs',      ctypes.c_int),
        ('crtcs',            ctypes.POINTER(ctypes.c_uint32)),
        ('count_connectors', ctypes.c_int),
        ('connectors',       ctypes.POINTER(ctypes.c_uint32)),
        ('count_encoders',   ctypes.c_int),
        ('encoders',         ctypes.POINTER(ctypes.c_uint32)),
        ('min_width',        ctypes.c_uint32),
        ('max_width',        ctypes.c_uint32),
        ('min_height',       ctypes.c_uint32),
        ('max_height',       ctypes.c_uint32),
    ]


class DrmModeModeInfo(ctypes.Structure):
    _fields_ = [
        ('clock',       ctypes.c_uint32),
        ('hdisplay',    ctypes.c_uint16),
        ('hsync_start', ctypes.c_uint16),
        ('hsync_end',   ctypes.c_uint16),
        ('htotal',      ctypes.c_uint16),
        ('hskew',       ctypes.c_uint16),
        ('vdisplay',    ctypes.c_uint16),
        ('vsync_start', ctypes.c_uint16),
        ('vsync_end',   ctypes.c_uint16),
        ('vtotal',      ctypes.c_uint16),
        ('vscan',       ctypes.c_uint16),
        ('vrefresh',    ctypes.c_uint32),
        ('flags',       ctypes.c_uint32),
        ('type',        ctypes.c_uint32),
        ('name',        ctypes.c_char * 32),
    ]


class DrmModeCrtc(ctypes.Structure):
    _fields_ = [
        ('crtc_id',          ctypes.c_uint32),
        ('buffer_id',        ctypes.c_uint32),
        ('x',                ctypes.c_uint32),
        ('y',                ctypes.c_uint32),
        ('width',            ctypes.c_uint32),
        ('height',           ctypes.c_uint32),
        ('mode_valid',       ctypes.c_int),
        ('mode',             DrmModeModeInfo),
        ('gamma_size',       ctypes.c_int),
    ]


libdrm.drmModeGetResources.restype  = ctypes.POINTER(DrmModeRes)
libdrm.drmModeGetResources.argtypes = [ctypes.c_int]

libdrm.drmModeFreeResources.restype  = None
libdrm.drmModeFreeResources.argtypes = [ctypes.POINTER(DrmModeRes)]

libdrm.drmModeGetCrtc.restype  = ctypes.POINTER(DrmModeCrtc)
libdrm.drmModeGetCrtc.argtypes = [ctypes.c_int, ctypes.c_uint32]

libdrm.drmModeFreeCrtc.restype  = None
libdrm.drmModeFreeCrtc.argtypes = [ctypes.POINTER(DrmModeCrtc)]

libdrm.drmModeCrtcSetGamma.restype  = ctypes.c_int
libdrm.drmModeCrtcSetGamma.argtypes = [
    ctypes.c_int,
    ctypes.c_uint32,
    ctypes.c_uint32,
    ctypes.POINTER(ctypes.c_uint16),
    ctypes.POINTER(ctypes.c_uint16),
    ctypes.POINTER(ctypes.c_uint16),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_active_crtcs(fd):
    """Yield (crtc_id, gamma_size, mode_name) for each active CRTC."""
    res_ptr = libdrm.drmModeGetResources(fd)
    if not res_ptr:
        raise RuntimeError(
            f"drmModeGetResources failed on {DRM_NODE}: {os.strerror(ctypes.get_errno())}"
        )
    try:
        res = res_ptr.contents
        for i in range(res.count_crtcs):
            crtc_id = res.crtcs[i]
            crtc_ptr = libdrm.drmModeGetCrtc(fd, crtc_id)
            if not crtc_ptr:
                continue
            try:
                c = crtc_ptr.contents
                if c.mode_valid:
                    yield (c.crtc_id, c.gamma_size, c.mode.name.decode('ascii', 'replace'))
            finally:
                libdrm.drmModeFreeCrtc(crtc_ptr)
    finally:
        libdrm.drmModeFreeResources(res_ptr)


def load_lut(path):
    """Return three c_uint16 arrays (red, green, blue) of length LUT_SIZE."""
    with open(path, 'rb') as f:
        data = f.read()
    expected = LUT_SIZE * 8
    if len(data) != expected:
        raise ValueError(f"LUT file {path}: {len(data)} bytes, expected {expected}")

    red   = (ctypes.c_uint16 * LUT_SIZE)()
    green = (ctypes.c_uint16 * LUT_SIZE)()
    blue  = (ctypes.c_uint16 * LUT_SIZE)()
    for i in range(LUT_SIZE):
        r, g, b, _ = struct.unpack_from('<HHHH', data, i * 8)
        red[i]   = r
        green[i] = g
        blue[i]  = b
    return red, green, blue


def apply_once(lut_path, verbose=True):
    """One apply attempt. Returns True on success, False if nothing took."""
    red, green, blue = load_lut(lut_path)
    if verbose:
        print(f"Loaded {lut_path}: {LUT_SIZE} entries")
        print(f"  white: R=0x{red[LUT_SIZE-1]:04x} "
              f"G=0x{green[LUT_SIZE-1]:04x} B=0x{blue[LUT_SIZE-1]:04x}")

    fd = os.open(DRM_NODE, os.O_RDWR)
    try:
        applied_any = False
        for crtc_id, gamma_size, mode_name in find_active_crtcs(fd):
            if verbose:
                print(f"CRTC {crtc_id}: gamma_size={gamma_size} mode='{mode_name}'")
            if gamma_size != LUT_SIZE:
                if verbose:
                    print(f"  skipping: gamma_size {gamma_size} != "
                          f"LUT_SIZE {LUT_SIZE}", file=sys.stderr)
                continue
            rc = libdrm.drmModeCrtcSetGamma(fd, crtc_id, LUT_SIZE,
                                             red, green, blue)
            if rc != 0:
                err = ctypes.get_errno()
                if verbose:
                    print(f"  drmModeCrtcSetGamma failed: rc={rc} errno={err} "
                          f"({os.strerror(err)})", file=sys.stderr)
                continue
            if verbose:
                print(f"  applied")
            applied_any = True
        return applied_any
    finally:
        os.close(fd)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <lut-file>", file=sys.stderr)
        sys.exit(1)

    lut_path = sys.argv[1]

    # Retry loop: when invoked from systemd at boot or on resume, the active
    # CRTC may not be settled yet. APPLY_RETRIES/APPLY_RETRY_DELAY env vars
    # let the operator tune; defaults handle the typical boot race.
    retries = int(os.environ.get('APPLY_RETRIES', '20'))
    delay = float(os.environ.get('APPLY_RETRY_DELAY', '0.5'))

    last_err = None
    for attempt in range(retries):
        try:
            if apply_once(lut_path, verbose=(attempt == 0)):
                return
            last_err = "no CRTC accepted the LUT"
        except Exception as e:
            last_err = repr(e)
        if attempt < retries - 1:
            time.sleep(delay)

    print(f"Gave up after {retries} attempts: {last_err}", file=sys.stderr)
    sys.exit(2)


if __name__ == '__main__':
    main()
