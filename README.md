# lid-open-check  
**Skip fingerprint authentication when your laptop lid is closed**


![lid-open-check logo](assets/logo.svg)

In docked setups with the lid closed, `pam_fprintd` can still prompt for a fingerprint on a sensor you can't reach. This project provides a small PAM module that checks the laptop's lid state via `/proc/acpi/button/lid/*/state` and skips fingerprint authentication when the lid is closed, allowing authentication to continue with a password instead.

After reinstalling my laptop, I found myself having to manually implement [the original workaround](https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed) again. Rather than manually repeating the same fix after every reinstall, I decided to turn it into a small, standalone PAM module that handles the lid state automatically.

The module checks the state of the first lid device it finds with a state file at authentication time:  
```text
Lid open   : lid-open-check → fingerprint → password
Lid closed : lid-open-check → password
```

## Requirements
- Linux system using PAM, such as Debian or Ubuntu-based distributions
- A laptop exposing its lid state through `/proc/acpi/button/lid/*/state`.
- `pam_fprintd` already configured in `/etc/pam.d/common-auth`
- Tested on **Linux Mint 22.3** with `libfprint`

### Check lid-state
You can check whether your system exposes the lid state with:
```bash
cat /proc/acpi/button/lid/*/state
```
Should return something similar to:  
>`state: closed`  
> or  
> `state: open`

The module checks for the `closed` and `open` keywords.

## Installation

### Debian package

#### 1. Download
Download the latest `.deb` package from the releases page.

#### 2. install with `dpkg` 
```bash
sudo dpkg -i lid-open-check_x.x.x_amd64.deb
```

#### 3. Enable the PAM module
Run:
```bash
sudo pam-auth-update
```
Enable `lid-open-check` by selecting it in the PAM configuration menu.

### Custom build

Please refer to the *BUILD.MD* file for build steps and repository information

## Testing
lid-open-check includes a CLI that can simulate different lid states for testing.

First, enable debug mode:
```bash
lid-open-check-cli debug enable
```
When debug mode is enabled, the module uses the state from: `/etc/pam-lid-open-check.conf`.

the default 'debug-state' is `closed`, so fingerprint should be skipped.

To simulate an open lid:

```bash
lid-open-check-cli state open
```

Now the fingerprint authentication step shouldn't be skipped.

When you are finished testing, disable debug mode:
```bash
lid-open-check-cli debug disable
```

### Test Command
While developing i used `sudo -k && sudo ls`.  
This forces `sudo` to authenticate again and provides a simple way to test the PAM authentication flow.

## Usage
To disable the module:

```bash
sudo lid-open-check-cli disable
```
To enable it again:

```bash
sudo lid-open-check-cli enable
```
The module can also be enabled or disabled through:

```bash
sudo pam-auth-update
```

## Removal
When installed using the .deb package run:
```bash
sudo apt remove lid-open-check
```

## Safety notes
- Keep a root terminal open while testing PAM changes in case authentication stops working.
- Test the module before closing your existing root session.
- Make sure password authentication remains available before relying on the module.

## How it works
At authentication time, the `lid-open-check.so` PAM module checks the first lid device it finds containing a state file under:
```text
/proc/acpi/button/lid/*/state
```

The module then changes the PAM control flow depending on the detected state:

Lid closed: the module tells PAM to skip the pam_fprintd module.
Lid open: the module falls through normally, allowing fingerprint authentication to proceed.

The resulting authentication flow is:
```text
Lid open   : lid-open-check → fingerprint → password
Lid closed : lid-open-check → password
```

## Credits
he original idea for this workaround came from [this](https://unix.stackexchange.com/questions/678609/how-to-disable-fingerprint-authentication-when-laptop-lid-is-closed) Unix & Linux Stack Exchange

I initially implemented the solution as an installation script based on that workaround, which I later rewrote as a native PAM module and packaged it as a .deb, making installation and configuration easier.

## Future
- [x] ~~Make it a contained program that could be installed with a repository manager~~
- [ ] Support for other distro (currently tested on Mint)
