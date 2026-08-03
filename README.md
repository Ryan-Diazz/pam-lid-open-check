# lid-open-check
Skip fingerprint authentication when your laptop lid is closed

In docked setups with the lid closed, `pam_fprintd` will still prompt for a fingerprint on a sensor you can't reach. This project inserts a small PAM rule that detects the lid state via `/proc/acpi/button/lid/*/state` and bypasses the fingerprint step automatically, going straight to password auth instead.

I run this on my laptop since i like the ergonomics of mounted monitors better than a desk height laptop screen.

The `lid-open-check.so` pam module checks the state of the fist monitor found with a 'state' at authentication time.

- If the lid is closed the PAM Module will signal pam to skip `pam_fprintd`.
- If the lid is open, it falls through to fingerprint as normal

The authentication flow:
```text
Lid open   → lid-open-check → pam_fprintd → pam_unix
Lid closed → lid-open-check → pam_unix
```

## Requirements
- linux system using pam-auth, most debian/ubuntu systems
- Laptops with `/proc/acpi/button/lid/*/state` supported.
- `pam_fprintd` already configured in `/etc/pam.d/common-auth`
- Tested on **Linux Mint 22.3** with `libfprint`

## Checks
```bash
cat /proc/acpi/button/lid/*/state
```
should return something like `state: closed` or `state: open`.
in the script checkes on `closed` and `open` keywords.

## Install

### deb Package

#### 1. Download
Download the latest .deb package from releases.

#### 2. install with dpkg 
```bash
dpkg -i lid-open-check_x.x.x_amd64.deb
```

#### 3. Confirm pam
confirm if `lid-open-check` is enabled in pam by running:
```bash
sudo pam-auth-update
```
there should be a star infront of `lid-open-check`

### Custom build

Please refer to the BUILD.MD file for build steps and repository information

## Test
Bundled in lid-open-check these is a cli where the user can simulate lid open and close functionality.

by running:
```bash
lid-open-check-cli debug enable
```

The module will get the state from the configuration file `/etc/pam-lid-open-check.conf`.

the default 'debug-state' is `closed`, thus the fingerprint should be skipped.

to try `open` state you can run

```bash
lid-open-check-cli state open
```

Now fingerprint shouldn't be skipped.

when you are done testing you can run:
```bash
lid-open-check-cli debug disable
```


## Usage
If you want to disable the module you can use the cli:
```bash
lid-open-check-cli disable
```

And to enable it again
```bash
lid-open-check-cli enable
```

or use pam directly:
```bash
pam-auth-update
```
and uncheck the star infront of lid-open-check.

## Safety notes
- with the way it is setup, it is possible to skip both authentication steps. But all 3 unique linux installs have this pam setup and lets it work.
- Keep a root terminal open while testing PAM changes in case you need to roll back manually:
    ```bash
    sudo apt remove lid-open-check
    ```

## Credits
The core idea for intermediate pam script came from:

https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed

I started with an install script of this very solution, but making it an installable .deb package with pam modules makes it easier to install for people.

## Future
- [x] Make it a contained program that could be installed with a repository manager
- [ ] Support for other distro (currently tested on Mint)
- [ ] Any bugs that arise for people.