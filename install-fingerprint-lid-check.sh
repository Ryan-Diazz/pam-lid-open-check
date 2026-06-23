#!/bin/bash
# https://github.com/Ryan-Diazz/fingerprint-lid-check v1.0
# install.sh
# Installs the fingerprint-lid-check PAM rule to skip fingerprint when laptop lid is closed

set -e

PAM_FILE="/etc/pam.d/common-auth"
LID_CHECK_SCRIPT="/usr/local/bin/fingerprint-lid-check"
PAM_EXEC_LINE='auth    [success=1 default=ignore]    pam_exec.so quiet /usr/local/bin/fingerprint-lid-check'
FPRINTD_PATTERN='pam_fprintd.so'
SRC_SCRIPT="$(dirname "$0")/src/fingerprint-lid-check.sh"

# ========================================
# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: run this script as root (sudo $0)" >&2
    exit 1
fi

# ========================================
# Check src/fingerprint-lid-check exists
if [[ ! -f "$SRC_SCRIPT" ]]; then
    echo "Error: src/fingerprint-lid-check.sh not found at $SRC_SCRIPT" >&2
    echo "Make sure you are running this script from the repo root." >&2
    exit 1
fi

# ========================================
# Check pam_exec is available
if ! find /lib /usr/lib -name "pam_exec.so" 2>/dev/null | grep -q .; then
    echo "Error: pam_exec.so not found. Install libpam-runtime." >&2
    exit 1
fi

# ========================================
# Install the fingerprint-lid-check script
echo "Installing $LID_CHECK_SCRIPT..."
cp "$SRC_SCRIPT" "$LID_CHECK_SCRIPT"
chmod +x "$LID_CHECK_SCRIPT"
echo "  OK: $LID_CHECK_SCRIPT"

# ========================================
# Backup PAM file
BACKUP="${PAM_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$PAM_FILE" "$BACKUP"
echo "  OK: PAM backup saved to $BACKUP"

# ========================================
# Idempotency: skip if already patched
if grep -qF "fingerprint-lid-check" "$PAM_FILE"; then
    echo "PAM already patched — nothing to do."
    exit 0
fi

# ========================================
# Check the fprintd line exists to insert before
if ! grep -q "$FPRINTD_PATTERN" "$PAM_FILE"; then
    echo "Error: could not find pam_fprintd.so line in $PAM_FILE — is fingerprint configured?" >&2
    exit 1
fi

# ========================================
# Insert pam_exec line directly before pam_fprintd
sed -i "/$FPRINTD_PATTERN/i\\$PAM_EXEC_LINE" "$PAM_FILE"

echo "  OK: fingerprint-lid-check installed"
echo ""
echo "Done. Test with: sudo -k && sudo ls"
echo "To undo: sudo ./uninstall-fingerprint-lid-check.sh"
echo "Or manually: sudo cp $BACKUP $PAM_FILE && sudo rm $LID_CHECK_SCRIPT"