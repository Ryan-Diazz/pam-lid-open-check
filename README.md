# lid-open-check  
**Skip fingerprint authentication when your laptop lid is closed**


![lid-open-check logo](assets/logo.svg)

In docked setups with the lid closed, `pam_fprintd` can still prompt for a fingerprint on a sensor you can't reach. This project provides a small PAM module that checks the laptop's lid state via `/proc/acpi/button/lid/*/state` and skips fingerprint authentication when the lid is closed, allowing authentication to continue with a password instead.

After reinstalling my laptop, I found myself having to manually implement [the original workaround](https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed) again. Rather than manually repeating the same fix after every reinstall, I decided to turn it into a small, standalone PAM module that handles the lid state automatically.

The module checks the state of the first lid device it finds with a state file at authentication time:  
```text
Lid open   : lidcheck → fingerprint → password
Lid closed : lidcheck → password
```

## Requirements
- Linux system using PAM for authentication
- A laptop exposing its lid state through `/proc/acpi/button/lid/*/state`.
- `pam_fprintd` already configured in `/etc/pam.d/*` (* file for authentication differs between operating systems)

### Check lid state
You can check whether your system exposes the lid state with:
```bash
cat /proc/acpi/button/lid/*/state
```
Should return something similar to:  
>`state: closed`  
> or  
> `state: open`

This module checks for the `closed` and `open` keywords.

## Installation

### Debian/Ubuntu

#### 1. Download
Download the latest `pam-lidcheck_x.x.x_amd64.deb` from the releases page.

#### 2. Install
```bash
sudo apt install ./pam-lidcheck_x.x.x_amd64.deb
```
(`sudo dpkg -i pam-lidcheck_x.x.x_amd64.deb` works too, but won't pull in missing dependencies.)

#### 3. Check that the module is enabled
The package enables the module automatically through `pam-auth-update`, placing it directly above `pam_fprintd`. No manual edits are needed.

To check or toggle it, run:
```bash
sudo pam-auth-update
```
and look for *Lid Open Check - Fingerprint Authentication Control*.

#### Removal
```bash
sudo apt remove pam-lidcheck
```
This also removes the module from the PAM configuration.

### Arch Linux

#### 1. Download
Download the latest `pam_lidcheck-x.x.x-1-x86_64.pkg.tar.gz` from the releases page, or [build it yourself](#build-from-source).

#### 2. Install
```bash
sudo pacman -U pam_lidcheck-x.x.x-1-x86_64.pkg.tar.gz
```
This installs the module to `/usr/lib/security/pam_lidcheck.so`.

#### 3. Enable the PAM module
Arch has no `pam-auth-update`, so the module has to be added to the PAM configuration manually.

Find the files where `pam_fprintd` is configured:
```bash
grep -l pam_fprintd /etc/pam.d/*
```
In each of these files, add the following line **directly above** the `pam_fprintd.so` line:
```text
auth    [success=1 default=ignore]    pam_lidcheck.so
```
For example, `/etc/pam.d/sudo`:
```text
auth    [success=1 default=ignore]    pam_lidcheck.so
auth    sufficient                    pam_fprintd.so
auth    include                       system-auth
```
`success=1` tells PAM to skip the next line (`pam_fprintd`) when the lid is closed. If there are other lines between `pam_lidcheck.so` and `pam_fprintd.so`, increase the `success=x` number accordingly.

#### Removal
First remove the `pam_lidcheck.so` lines from `/etc/pam.d/*`, then uninstall the package:
```bash
sudo pacman -R pam_lidcheck
```
> **Warning:** Do this in this order. If the package is removed while `/etc/pam.d/*` still references `pam_lidcheck.so`, authentication for those services can fail.

### Build from source
```bash
make deb    # .output/pam-lidcheck_x.x.x_amd64.deb
make arch   # .output/pam_lidcheck-x.x.x-1-x86_64.pkg.tar.gz
```
See [BUILD.md](BUILD.md) for prerequisites and details.

## Safety notes
- Keep a root terminal open while testing PAM changes in case authentication stops working.
- Test the module before closing your existing root session. (`sudo -k && sudo ls`)
- Make sure password authentication remains available before relying on the module.

## How it works
At authentication time, the `pam_lidcheck.so` PAM module checks the first lid device it finds containing a state file with the pattern:
```text
/proc/acpi/button/lid/*/state
```

The module then changes the PAM control flow depending on the detected state:

Lid closed: the module tells PAM to skip the pam_fprintd module.
Lid open: the module falls through normally, allowing fingerprint authentication to proceed.

The resulting authentication flow is:
```text
Lid open   : pam_lidcheck → fingerprint → password
Lid closed : pam_lidcheck → password
```

## Credits
The original idea for this workaround came from [this](https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed) Unix & Linux Stack Exchange

I initially implemented the solution as an installation script based on that workaround, which I later rewrote as a native PAM module and packaged it as a .deb, making installation and configuration easier.

## Future
- [x] ~~Make it a contained program that could be installed with a repository manager~~
- [x] ~~Support for Arch Linux~~
- [ ] Support for other distros (currently tested on Mint)
