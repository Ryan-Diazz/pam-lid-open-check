# fingerprint-lid-check
Skip fingerprint authentication when your laptop lid is closed.

In docked setups with the lid closed, `pam_fprintd` will still prompt for a fingerprint on a sensor you can't reach. This project inserts a small PAM rule that detects the lid state via `/proc/acpi/button/lid/` and bypasses the fingerprint step automatically, going straight to password auth instead.

I run this on my laptop since i like the ergonomics of mounted monitors better than a desk height laptop screen.

## How it works
A shell script checks `/proc/acpi/button/lid/*/state` at authentication time.

- If the lid is closed, it signals PAM to skip `pam_fprintd`.
- If the lid is open, it falls through to fingerprint as normal.
  The install script patches `/etc/pam.d/common-auth` by inserting a `pam_exec` line directly before the `pam_fprintd` line.

```text
Lid open   → pam_exec → pam_fprintd → pam_unix (fallback)
Lid closed → pam_exec → pam_unix
```

## Requirements
- debian/ubuntu based linux system using common-autth pam file
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

#### Download repository zip or clone using
```bash
git clone https://github.com/Ryan-Diazz/fingerprint-lid-check.git
```
and go to the directory

```bash
cd fingerprint-lid-check
```

#### Run the install script
```bash
sudo bash install-fingerprint-lid-check.sh
```

#### Update PAM
do not allow changes to the common-auth file.
```bash
sudo pam-auth-update
```

#### Verify
run this in a seperate terminal window with the lid open
```bash
sudo -k && sudo ls
```
You should be prompted for a fingerprint.

Close the lid and repeat, you should not be prompted for a fingerprint.

## Uninstall
```bash
sudo bash uninstall-fingerprint-lid-check.sh
```

This removes the `pam_exec` line from `common-auth` and deletes `/usr/local/bin/fingerprint-lid-check`. A timestamped backup of the PAM file is saved before any changes either way.

## Files
| File                                   | Description                                       |
| -------------------------------------- | ------------------------------------------------- |
| `install-fingerprint-lid-check.sh`     | Installs the lid-check script and patches PAM     |
| `uninstall-fingerprint-lid-check.sh`   | Reverses all changes made by the install script   |
| `/usr/local/bin/fingerprint-lid-check` | Created by install — checked by PAM at auth time  |

## Safety notes
- Both scripts back up `/etc/pam.d/common-auth` with a timestamp before modifying it
- The install is idempotent (safe to run more than once)
- Keep a root terminal open while testing PAM changes in case you need to roll back manually:
  ```bash
  sudo cp /etc/pam.d/common-auth.bak.<timestamp> /etc/pam.d/common-auth
  ```


## Credits
The core idea for intermediate pam script came from:

https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed

I just made it a easy script for future use when i reinstall linux and i would have needed to do the research again.

And for other people to run. In the hope it works for them.

## Future
- [ ] Make it a contained program that could be installed with a repository manager
  - [ ] integrated script (should make supporting other distros easier)
  - [ ] integrated enable command
  - [ ] integrated disable command
- [ ] Support for other distro (currently tested on Mint)
- [ ] Any bugs that arise for people.