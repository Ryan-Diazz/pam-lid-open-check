# Build

## Prerequisites

| Tool | Needed for |
|---|---|
| `gcc` | compiling the module |
| PAM development headers | compiling the module |
| `pkg-config` | finding the PAM headers and libs (optional, falls back to `-lpam`) |
| `tar`, `gzip`, `ar` (binutils) | `make deb` |
| `makepkg` (pacman) | `make arch` |

`make deb` does **not** need `dpkg-deb`; the `.deb` is assembled with `tar` and `ar`, so it can be built on any distro.

Install on Debian/Ubuntu:

```sh
sudo apt install gcc libpam0g-dev pkg-config binutils
```

Install on Arch:

```sh
sudo pacman -S --needed base-devel pam
```

## Sources

| File | Description |
|---|---|
| `src/pam_lidcheck.c` | The PAM module |
| `src/pam_lidcheck-profile` | `pam-auth-update` profile (Debian/Ubuntu only) |

## Makefile

All packages end up in `.output/`; intermediate files go in `build/`.

### make / make all

Compiles the module:

| Output | Source | Description |
|---|---|---|
| `build/pam_lidcheck.so` | `src/pam_lidcheck.c` | Shared PAM module (position-independent, linked against libpam) |

PAM include paths and link flags are resolved via `pkg-config pam`, falling back to `-lpam`. `CFLAGS`, `CPPFLAGS` and `LDFLAGS` from the environment are respected.

### make install

Installs the module to `$(DESTDIR)$(PAM_LIBDIR)/pam_lidcheck.so`. `PAM_LIBDIR` defaults to `/usr/lib/security` (Arch, Fedora).

```sh
sudo make install                                               # Arch
sudo make install PAM_LIBDIR=/usr/lib/x86_64-linux-gnu/security # Debian/Ubuntu
```

This only copies the module; the PAM configuration still has to be enabled (see [README.md](README.md#installation)).

### make deb

Builds a Debian package at `.output/pam-lidcheck_<version>_<arch>.deb`.

Debian package names may not contain `_`, so the package is called `pam-lidcheck`; the module itself keeps the name `pam_lidcheck`.

The package installs:

| File | Destination |
|---|---|
| `pam_lidcheck.so` | `/usr/lib/<multiarch>/security/` |
| `pam_lidcheck-profile` | `/usr/share/pam-configs/pam_lidcheck` |

- `postinst` runs `pam-auth-update --package`, which enables the module (the profile has `Default: yes`).
- `prerm` runs `pam-auth-update --package --remove pam_lidcheck` when the package is removed.

Install the resulting package:

```sh
sudo apt install ./.output/pam-lidcheck_1.2.0_amd64.deb
```

### make arch

Builds an Arch package at `.output/pam_lidcheck-<version>-1-<arch>.pkg.tar.gz`.

The target writes a `PKGBUILD` and `.install` script to `build/arch-staging/` and runs `makepkg` on it. makepkg compiles the module from the project root using its own `CFLAGS`/`LDFLAGS` from `/etc/makepkg.conf`.

The package installs:

| File | Destination |
|---|---|
| `pam_lidcheck.so` | `/usr/lib/security/` |
| `LICENSE` | `/usr/share/licenses/pam_lidcheck/` |

Arch has no `pam-auth-update`, so the profile is not included. After install, the `.install` script prints the line to add to `/etc/pam.d/*`.

Install the resulting package:

```sh
sudo pacman -U .output/pam_lidcheck-1.2.0-1-x86_64.pkg.tar.gz
```

The compression is set by `ARCH_PKGEXT` in the Makefile (must be `.pkg.tar*`, e.g. `.pkg.tar.zst`).

### make clean

Removes `build/` and `.output/`.

### make clean-build

Removes only `build/`, keeping the packages in `.output/`.

## Architecture detection

The Debian library path and `.deb` architecture are resolved via `dpkg-architecture`. When it is unavailable (e.g. building on Arch), they fall back to `x86_64-linux-gnu` / `amd64`.

To build for another architecture:

```sh
make deb DEB_HOST_MULTIARCH=aarch64-linux-gnu DEB_HOST_ARCH=arm64 CC=aarch64-linux-gnu-gcc
```

The Arch package architecture comes from `uname -m` and can be overridden with `ARCH_HOST`.
