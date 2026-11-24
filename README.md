# Raspberry Pi Xbox Controller Setup

Setup script for using an Xbox controller as a mouse and full on-screen keyboard on Raspberry Pi OS (Pi 5 and others).

## Features

- **Mouse emulation** via `xboxdrv` (starts automatically on boot)
- **Full on-screen keyboard** via [gamepad-osk](https://github.com/0x90shell/gamepad-osk) (user systemd service, starts on boot)
- Optional Bluetooth ERTM disable for better wireless Xbox controller compatibility
- Automatic service setup with restart on failure

## Quick Start

```bash
chmod +x setup-xbox-full.sh
sudo ./setup-xbox-full.sh
```

Then reboot:
```bash
sudo reboot
```

## What it installs

| Service | Type | Purpose |
|---------|------|---------|
| `xbox-mouse.service` | system | Mouse control with left stick + buttons |
| `gamepad-osk.service` | user | Full QWERTY on-screen keyboard navigated with controller |

## gamepad-osk Controls

- **Left stick / D-pad** → navigate keyboard
- **A** → press key
- **X** → Backspace
- **Y** → Space
- **RT** → Enter
- **LT (hold)** → Shift
- **Right stick** → mouse movement
- **RB / R3** → left click
- **Toggle combo** → show/hide keyboard (often Guide+A)

## Notes

- Both services start automatically on boot.
- If the two services conflict over the sticks, you can disable the mouse service:
  ```bash
  sudo systemctl disable --now xbox-mouse.service
  ```
- gamepad-osk starts in daemon mode (hidden). Use its toggle combo to show the keyboard.
- Requires Raspberry Pi OS with internet access for package installation and building gamepad-osk.

## Requirements

- Raspberry Pi OS (Bookworm/Trixie recommended)
- Xbox controller (wired or Bluetooth)
- Internet connection during setup
