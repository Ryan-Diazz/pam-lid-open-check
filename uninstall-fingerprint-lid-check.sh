#!/bin/bash
# https://github.com/Ryan-Diazz/fingerprint-lid-check v1.0
# uninstall-fingerprint-lid-check.sh
# Removes the fingerfprint-lid-check PAM rule and script installed by install-fingerprint-lid-check.sh

set -e

PAM_FILE="/etc/pam.d/common-auth"
LID_CHECK_SCRIPT="/usr/local/bin/fingerprint-lid-check"

# ========================================
# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: run this script as root (sudo $0)" >&2
    exit 1
fi

# ========================================
# Backup PAM file before touching it
BACKUP="${PAM_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$PAM_FILE" "$BACKUP"
echo "  OK: PAM backup saved to $BACKUP"

# ========================================
# Remove pam_exec line from PAM if present 
if grep -qF "fingerprint-lid-check" "$PAM_FILE"; then
    sed -i "/fingerprint-lid-check/d" "$PAM_FILE"
    echo "  OK: removed pam_exec line from $PAM_FILE"
else
    echo "  SKIP: pam_exec line not found in $PAM_FILE — already removed?"
fi

# ========================================
# Remove the lid-check script if present
if [[ -f "$LID_CHECK_SCRIPT" ]]; then
    rm "$LID_CHECK_SCRIPT"
    echo "  OK: removed $LID_CHECK_SCRIPT"
else
    echo "  SKIP: $LID_CHECK_SCRIPT not found — already removed?"
fi

# ========================================
# final output
echo "  OK: fingerprint-lid-check uninstalled"
echo ""
echo "Done. Test with: sudo -k && sudo ls"
echo "To re-apply: sudo ./install-fingerprint-lid-check.sh"