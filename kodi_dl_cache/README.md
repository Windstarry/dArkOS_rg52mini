# kodi_dl_cache

Pre-seed cache for the Kodi binary-addons build (`build_kodi.sh`).

Some Kodi addons build their own bundled dependencies (e.g.
`inputstream.ffmpegdirect` builds a static ffmpeg → gnutls → nettle → **gmp**).
Those dependency tarballs are fetched from upstream hosts at build time via
CMake `ExternalProject`. A few of those hosts are unreliable — notably
`gmplib.org`, which frequently drops connections mid-transfer (curl status 56),
failing the addon build.

Any tarball placed in this directory is copied into the addon download dir
(`.../binary-addons/native/build/download/`) **before** the addon build runs.
`ExternalProject` then finds the file, verifies it against the addon's expected
`*.sha256`, and skips the network download entirely.

## Adding a tarball

1. Download the exact file the build asks for (the log shows the URL, e.g.
   `https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz`).
2. Confirm its sha256 matches the addon's expected hash. The addon stores it at
   `depends/common/<dep>/<dep>.sha256` in the addon repo. A mismatched file is
   rejected and re-downloaded from the network, so the hash must match exactly.
3. Drop the file here. No filename mangling — keep the upstream filename.

## Current contents

| File | sha256 | Why |
|------|--------|-----|
| `gmp-6.3.0.tar.xz` | `a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898` | gmplib.org drops connections; needed by `inputstream.ffmpegdirect`'s bundled ffmpeg (gnutls→nettle→gmp). |
