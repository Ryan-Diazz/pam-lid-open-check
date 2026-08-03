# Makefile for pam-lid-open-check

CC      = gcc
CFLAGS  = -Wall -Wextra

PAM_INCLUDE = $(shell pkg-config --cflags-only-I libpam 2>/dev/null || echo "-I/usr/include")
PAM_LIBS    = $(shell pkg-config --libs libpam 2>/dev/null || echo "-lpam")

DEB_HOST_MULTIARCH ?= $(shell dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "x86_64-linux-gnu")
DEB_HOST_ARCH      ?= $(shell dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null || echo "amd64")
PAM_LIBDIR          = /lib/$(DEB_HOST_MULTIARCH)/security

VERSION = 1.1.0
PACKAGE = lid-open-check

BUILD_DIR 	= build
OUTPUT_DIR  = .output
DIST_DIR 	= $(OUTPUT_DIR)/dist

MODULE_SRC    = src/lib/pam/lid-open-check.c
MODULE_OBJ    = $(BUILD_DIR)/pam/lid-open-check.o
MODULE_TARGET = $(BUILD_DIR)/pam/lid-open-check.so

CLI_SRC    = src/lid-open-check-cli.c
CLI_TARGET = $(BUILD_DIR)/lid-open-check-cli

BASH_COMPLETION_SRC = src/completions/lid-open-check-cli.bash

PROFILE_SRC = src/lib/pam/lid-open-check-profile
CONFIG_SRC  = src/pam-lid-open-check.conf


# ====================================================
# Build
# ====================================================
all: $(MODULE_TARGET) $(CLI_TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/pam

$(MODULE_OBJ): $(MODULE_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -fPIC -DPAM_MODULE_NAME=lid_open_check $(PAM_INCLUDE) -c -o $@ $<

$(MODULE_TARGET): $(MODULE_OBJ)
	$(CC) -shared $(PAM_LIBS) -o $@ $^

$(CLI_TARGET): $(CLI_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $<

# ====================================================config
# Dist bundle (standalone: CLI + module + profile)
# ====================================================
dist: $(MODULE_TARGET) $(CLI_TARGET)
	mkdir -p $(DIST_DIR)/module
	mkdir -p $(DIST_DIR)/module/pam
	mkdir -p $(DIST_DIR)/completions/bash
	cp $(CLI_TARGET)    		$(DIST_DIR)/lid-open-check-cli
	cp $(BASH_COMPLETION_SRC)	$(DIST_DIR)/completions/bash/lid-open-check-cli
	cp $(MODULE_TARGET) 		$(DIST_DIR)/module/pam/lid-open-check.so
	cp $(PROFILE_SRC)   		$(DIST_DIR)/module/pam/lid-open-check-profile
	cp $(CONFIG_SRC)    		$(DIST_DIR)/pam-lid-open-check.conf

# ====================================================
# Debian package
# ====================================================
DEB_STAGING = $(BUILD_DIR)/deb-staging
DEB_TARGET  = $(OUTPUT_DIR)/$(PACKAGE)_$(VERSION)_$(DEB_HOST_ARCH).deb

deb: $(MODULE_TARGET) $(CLI_TARGET)
	rm -rf $(DEB_STAGING)
	mkdir -p $(DEB_STAGING)/DEBIAN
	mkdir -p $(DEB_STAGING)$(PAM_LIBDIR)
	mkdir -p $(DEB_STAGING)/usr/share/pam-configs
	mkdir -p $(DEB_STAGING)/usr/share/bash-completion/completions
	mkdir -p $(DEB_STAGING)/usr/local/bin
	mkdir -p $(DEB_STAGING)/etc

	cp $(MODULE_TARGET) 		$(DEB_STAGING)$(PAM_LIBDIR)/pam_lid-open-check.so
	cp $(PROFILE_SRC)   		$(DEB_STAGING)/usr/share/pam-configs/lid-open-check
	cp $(CONFIG_SRC)    		$(DEB_STAGING)/etc/pam-lid-open-check.conf
	cp $(CLI_TARGET)    		$(DEB_STAGING)/usr/local/bin/lid-open-check-cli
	cp $(BASH_COMPLETION_SRC)	$(DEB_STAGING)/usr/share/bash-completion/completions/lid-open-check-cli

	chmod 0644 $(DEB_STAGING)$(PAM_LIBDIR)/pam_lid-open-check.so
	chmod 0644 $(DEB_STAGING)/usr/share/pam-configs/lid-open-check
	chmod 0644 $(DEB_STAGING)/etc/pam-lid-open-check.conf
	chmod 0755 $(DEB_STAGING)/usr/local/bin/lid-open-check-cli
	chmod 0644 $(DEB_STAGING)/usr/share/bash-completion/completions/lid-open-check-cli

	printf 'Package: $(PACKAGE)\nVersion: $(VERSION)\nArchitecture: $(DEB_HOST_ARCH)\nMaintainer: Ryan Diazz https://github.com/Ryan-Diazz \nDepends: libpam-runtime (>= 0.76)\nDescription: PAM module that blocks fingerprint auth when the laptop lid is closed\n' \
		> $(DEB_STAGING)/DEBIAN/control

	printf '/etc/pam-lid-open-check.conf\n' \
		> $(DEB_STAGING)/DEBIAN/conffiles

	printf '#!/bin/sh\nset -e\npam-auth-update --enable lid-open-check\n' \
		> $(DEB_STAGING)/DEBIAN/postinst
	chmod 0755 $(DEB_STAGING)/DEBIAN/postinst

	printf '#!/bin/sh\nset -e\npam-auth-update --remove lid-open-check\n' \
		> $(DEB_STAGING)/DEBIAN/prerm
	chmod 0755 $(DEB_STAGING)/DEBIAN/prerm

	dpkg-deb --build $(DEB_STAGING) $(DEB_TARGET)
	@echo ""
	@echo "Package: $(DEB_TARGET)"
	@echo "Install with: sudo dpkg -i $(DEB_TARGET)"

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)

.PHONY: build dist deb clean
