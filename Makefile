# Makefile for pam-lid-open-check

CC      ?= gcc
CFLAGS  ?= -O2
CFLAGS  += -Wall -Wextra -fPIC

PAM_INCLUDE = $(shell pkg-config --cflags-only-I pam 2>/dev/null)
PAM_LIBS    = $(shell pkg-config --libs pam 2>/dev/null || echo "-lpam")

VERSION     = 1.2.0
PACKAGE     = pam_lidcheck
DESCRIPTION = PAM module that skips fingerprint auth when the laptop lid is closed
MAINTAINER  = Ryan Diazz https://github.com/Ryan-Diazz
URL         = https://github.com/Ryan-Diazz/pam_lidcheck

BUILD_DIR   = build
OUTPUT_DIR  = .output

MODULE_NAME   = pam_lidcheck
MODULE_SRC    = src/pam_lidcheck.c
MODULE_OBJ    = $(BUILD_DIR)/$(MODULE_NAME).o
MODULE_TARGET = $(BUILD_DIR)/$(MODULE_NAME).so

PROFILE_SRC = src/pam_lidcheck-profile

# Install locations (overridden per package format)
DESTDIR    ?=
PAM_LIBDIR ?= /usr/lib/security


# ====================================================
# Build
# ====================================================
all: $(MODULE_TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(MODULE_OBJ): $(MODULE_SRC) | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(PAM_INCLUDE) -c -o $@ $<

$(MODULE_TARGET): $(MODULE_OBJ)
	$(CC) $(LDFLAGS) -shared -o $@ $^ $(PAM_LIBS)

install: $(MODULE_TARGET)
	install -Dm0644 $(MODULE_TARGET) $(DESTDIR)$(PAM_LIBDIR)/$(MODULE_NAME).so

# ====================================================
# Debian package
# ====================================================
DEB_HOST_MULTIARCH ?= $(shell dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "x86_64-linux-gnu")
DEB_HOST_ARCH      ?= $(shell dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null || echo "amd64")

# Debian package names may not contain '_'
DEB_PACKAGE = $(subst _,-,$(PACKAGE))
DEB_STAGING = $(BUILD_DIR)/deb-staging
DEB_TARGET  = $(OUTPUT_DIR)/$(DEB_PACKAGE)_$(VERSION)_$(DEB_HOST_ARCH).deb

# Same flags as dpkg-deb --root-owner-group, so no dpkg is needed to build
DEB_TAR = tar --owner=0 --group=0 --numeric-owner --sort=name -czf

define DEB_CONTROL
Package: $(DEB_PACKAGE)
Version: $(VERSION)
Architecture: $(DEB_HOST_ARCH)
Maintainer: $(MAINTAINER)
Homepage: $(URL)
Depends: libpam-runtime (>= 0.76)
Description: $(DESCRIPTION)
endef
export DEB_CONTROL

define DEB_POSTINST
#!/bin/sh
set -e
pam-auth-update --package
endef
export DEB_POSTINST

define DEB_PRERM
#!/bin/sh
set -e
if [ "$$1" = "remove" ]; then
	pam-auth-update --package --remove $(MODULE_NAME)
fi
endef
export DEB_PRERM

deb: $(MODULE_TARGET)
	rm -rf $(DEB_STAGING)
	$(MAKE) install DESTDIR=$(DEB_STAGING) PAM_LIBDIR=/usr/lib/$(DEB_HOST_MULTIARCH)/security
	install -Dm0644 $(PROFILE_SRC) $(DEB_STAGING)/usr/share/pam-configs/$(MODULE_NAME)

	mkdir -p $(DEB_STAGING)/control
	printf '%s\n' "$$DEB_CONTROL"  > $(DEB_STAGING)/control/control
	printf '%s\n' "$$DEB_POSTINST" > $(DEB_STAGING)/control/postinst
	printf '%s\n' "$$DEB_PRERM"    > $(DEB_STAGING)/control/prerm
	chmod 0755 $(DEB_STAGING)/control/postinst $(DEB_STAGING)/control/prerm
	cd $(DEB_STAGING) && find usr -type f -exec md5sum {} + > control/md5sums

	$(DEB_TAR) $(DEB_STAGING)/control.tar.gz -C $(DEB_STAGING)/control .
	$(DEB_TAR) $(DEB_STAGING)/data.tar.gz    -C $(DEB_STAGING) ./usr
	printf '2.0\n' > $(DEB_STAGING)/debian-binary

	mkdir -p $(OUTPUT_DIR)
	rm -f $(DEB_TARGET)
	cd $(DEB_STAGING) && ar rcD '$(abspath $(DEB_TARGET))' debian-binary control.tar.gz data.tar.gz
	@echo ""
	@echo "Package: $(DEB_TARGET)"
	@echo "Install with: sudo dpkg -i $(DEB_TARGET)"

# ====================================================
# Arch package
# ====================================================
ARCH_STAGING = $(BUILD_DIR)/arch-staging
ARCH_HOST    ?= $(shell uname -m)
ARCH_PKGEXT  = .pkg.tar.gz
ARCH_TARGET  = $(OUTPUT_DIR)/$(PACKAGE)-$(VERSION)-$(ARCH_HOST)$(ARCH_PKGEXT)

# makepkg builds from the project root using its own CFLAGS/LDFLAGS
define ARCH_PKGBUILD
pkgname=$(PACKAGE)
pkgver=$(VERSION)
pkgrel=1
pkgdesc='$(DESCRIPTION)'
arch=('$(ARCH_HOST)')
url='$(URL)'
license=('MIT')
depends=('pam')
options=('!debug')
install=$(PACKAGE).install

build() {
	make -C '$(CURDIR)' BUILD_DIR="$$srcdir/build" all
}

package() {
	make -C '$(CURDIR)' BUILD_DIR="$$srcdir/build" DESTDIR="$$pkgdir" PAM_LIBDIR=/usr/lib/security install
	install -Dm0644 '$(CURDIR)/LICENSE' "$$pkgdir/usr/share/licenses/$$pkgname/LICENSE"
}
endef
export ARCH_PKGBUILD

define ARCH_INSTALL
post_install() {
	echo "==> Arch has no pam-auth-update; enable the module manually."
	echo "==> Add this line to /etc/pam.d/system-auth directly above pam_fprintd.so:"
	echo "==>   auth  [success=1 default=ignore]  $(MODULE_NAME).so"
}

pre_remove() {
	echo "==> Remove the $(MODULE_NAME).so line from /etc/pam.d/* before uninstalling."
}
endef
export ARCH_INSTALL

arch:
	rm -rf $(ARCH_STAGING)
	mkdir -p $(ARCH_STAGING) $(OUTPUT_DIR)
	printf '%s\n' "$$ARCH_PKGBUILD" > $(ARCH_STAGING)/PKGBUILD
	printf '%s\n' "$$ARCH_INSTALL"  > $(ARCH_STAGING)/$(PACKAGE).install
	cd $(ARCH_STAGING) && PKGDEST='$(abspath $(OUTPUT_DIR))' PKGEXT='$(ARCH_PKGEXT)' makepkg --force --cleanbuild
	@echo ""
	@echo "Package: $(ARCH_TARGET)"
	@echo "Install with: sudo pacman -U $(ARCH_TARGET)"

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)

clean-build:
	rm -rf $(BUILD_DIR)

.PHONY: all install deb arch clean
