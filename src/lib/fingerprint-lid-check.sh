#!/bin/bash
# https://github.com/Ryan-Diazz/fingerprint-lid-check v1.0
# Returns success (0) if lid is closed (to skip fingerprint),
# failure (1) if lid is open (to proceed to fingerprint).

LID_STATE_FILE=$(find /proc/acpi/button/lid/*/state 2>/dev/null | head -1)
if [ -z "$LID_STATE_FILE" ]; then
    # No lid found, desktop?: treat as open, allow fingerprint
    exit 1
fi

STATE=$(cat "$LID_STATE_FILE" 2>/dev/null)

if echo "$STATE" | grep -q "closed"; then
    exit 0  # Lid closed, skip fingerprint
else
    exit 1  # Lid open, proceed to fingerprint
fi