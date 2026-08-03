# Build

## Prerequisites

- `gcc`
- `libpam-dev` (PAM development headers)
- `pkg-config`
- `dpkg-architecture` (for Debian packaging — part of `dpkg-dev`)
- `dpkg-deb` (for Debian packaging)

Install on Debian/Ubuntu:

```sh
sudo apt install gcc libpam-dev pkg-config dpkg-dev
```

## Makefile

### make / make all

Compiles both build artifacts into `build/`:

| Output | Source | Description |
|---|---|---|
| `build/pam/lid-open-check.so` | `src/lib/pam/lid-open-check.c` | Shared PAM module (position-independent, linked against libpam) |
| `build/lid-open-check-cli` | `src/lid-open-check-cli.c` | CLI tool for testing lid state |

PAM include paths and link flags are resolved via `pkg-config libpam`, falling back to `/usr/include` and `-lpam`.

### make dist

Builds everything and assembles a standalone distribution bundle under `build/dist/`:

```
build/dist/
├── lid-open-check-cli
├── pam-lid-open-check.conf
└── module/pam/
    ├── lid-open-check.so
    └── lid-open-check-profile
```

Use this for manual installation without packaging.

### make deb

Builds a Debian package at `build/lid-open-check_<version>_<arch>.deb`.

The package installs:

| File | Destination |
|---|---|
| `pam_lid-open-check.so` | `/lib/<multiarch>/security/` |
| `lid-open-check-profile` | `/usr/share/pam-configs/lid-open-check` |
| `pam-lid-open-check.conf` | `/etc/pam-lid-open-check.conf` (conffile) |
| `lid-open-check-cli` | `/usr/local/bin/lid-open-check-cli` |

The postinst script runs `pam-auth-update --enable lid-open-check` automatically.

Install the resulting package:

```sh
sudo dpkg -i build/lid-open-check_1.1.0_amd64.deb
```

### make clean

Removes the entire `build/` directory.

## Architecture detection

The target PAM library path and `.deb` architecture are resolved via `dpkg-architecture`. On non-Debian systems or when `dpkg-architecture` is unavailable, they fall back to `x86_64-linux-gnu` / `amd64`.

To cross-compile or override the target architecture:

```sh
make deb DEB_HOST_MULTIARCH=aarch64-linux-gnu DEB_HOST_ARCH=arm64
```
