# fingerprint-lid-check

Skip fingerprint authentication when your laptop lid is closed.

In docked setups with the lid closed, `pam_fprintd` will still prompt for a fingerprint on a sensor you can't reach. This project inserts a small PAM rule that detects the lid state via `/proc/acpi/button/lid/` and bypasses the fingerprint step automatically — falling straight through to password auth instead.

I run this on my laptop since i like the ergonomics of mounted monitors better than a desk height laptop screen.

## How it works
A shell script checks `/proc/acpi/button/lid/*/state` at authentication time.

- If the lid is closed, it signals PAM to skip `pam_fprintd`.
- If the lid is open, it falls through to fingerprint as normal.
  The install script patches `/etc/pam.d/common-auth` by inserting a `pam_exec` line directly before the `pam_fprintd` line.

```
Lid open   → pam_exec (skip) → pam_fprintd → pam_unix (fallback)
Lid closed → pam_exec (jump) ────────────→ pam_unix
```

## Requirements
- Linux with `/proc/acpi/button/lid/` support (most laptops)
- `pam_exec.so` available (provided by `libpam-runtime`)
- `pam_fprintd` already configured in `/etc/pam.d/common-auth`
- Tested on **Linux Mint 22.3** with `libfprint`

## Checks
```bash
cat /proc/acpi/button/lid/*/state
```
should return something like `state: closed` or `state: open`.
in the script it is checked on `closed` keyword.


## Install
```bash
sudo bash install.sh
```

update pam, do not allow changes to the common-auth file.
```bash
sudo pam-auth-update
```

Then verify it works in seperate terminal window with the lid open:
```bash
sudo -k && sudo ls
```
You should be prompted for a fingerprint.

Close the lid and repeat, you should not be prompted for a fingerprint.

## Uninstall
```bash
sudo bash uninstall.sh
```

This removes the `pam_exec` line from `common-auth` and deletes `/usr/local/bin/fingerprint-lid-check`. A timestamped backup of the PAM file is saved before any changes either way.

## Files
| File                                   | Description                                       |
| -------------------------------------- | ------------------------------------------------- |
| `install.sh`                           | Installs the lid-check script and patches PAM     |
| `uninstall.sh`                         | Reverses all changes made by the install script   |
| `/usr/local/bin/fingerprint-lid-check` | Created by install — checked by PAM at auth time  |

## Safety notes
- Both scripts back up `/etc/pam.d/common-auth` with a timestamp before modifying it
- The install is idempotent (safe to run more than once)
- Keep a root terminal open while testing PAM changes in case you need to roll back manually:
  ```bash
  sudo cp /etc/pam.d/common-auth.bak.<timestamp> /etc/pam.d/common-auth
  ```