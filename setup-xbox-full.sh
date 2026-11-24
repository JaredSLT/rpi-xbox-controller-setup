#!/bin/bash
# setup-xbox-full.sh
# Complete setup for Xbox controller on Raspberry Pi OS:
# - Mouse emulation via xboxdrv (systemd service)
# - Full on-screen keyboard via gamepad-osk (user systemd service)
# Both start automatically on boot/login.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Xbox Controller Full Setup (Mouse + gamepad-osk) ===${NC}"
echo

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo).${NC}"
   exit 1
fi

# Detect the regular user (the one who ran sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~"$REAL_USER")

echo -e "${YELLOW}Setting up for user: $REAL_USER${NC}"

# ---------- Package updates & dependencies ----------
echo -e "${YELLOW}Updating packages and installing dependencies...${NC}"
apt update
apt install -y xboxdrv joystick golang git \
  libsdl3-dev libsdl3-ttf-dev libwayland-dev wayland-protocols libx11-dev \
  build-essential

# ---------- uinput module ----------
echo -e "${YELLOW}Configuring uinput...${NC}"
modprobe uinput || true
if ! grep -q "^uinput$" /etc/modules 2>/dev/null; then
    echo "uinput" >> /etc/modules
fi

# Optional Bluetooth ERTM disable
echo
read -p "Disable Bluetooth ERTM for better Xbox wireless compatibility? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth.conf
    echo "ERTM disabled (reboot required)."
fi

# ---------- xboxdrv mouse service ----------
echo -e "${YELLOW}Creating xboxdrv mouse systemd service...${NC}"
cat > /etc/systemd/system/xbox-mouse.service << 'EOF'
[Unit]
Description=Xbox Controller Mouse Emulation
After=multi-user.target bluetooth.service
Wants=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/xboxdrv --detach-kernel-driver --silent --mouse
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# ---------- gamepad-osk build & install ----------
echo -e "${YELLOW}Building and installing gamepad-osk...${NC}"
OSK_DIR="/opt/gamepad-osk"
rm -rf "$OSK_DIR"
git clone --depth 1 https://github.com/0x90shell/gamepad-osk.git "$OSK_DIR"
cd "$OSK_DIR"
go build -o gamepad-osk .
install -Dm755 gamepad-osk /usr/bin/gamepad-osk

# Install udev rules if present
if [[ -f gamepad-osk.udev ]]; then
    install -Dm644 gamepad-osk.udev /etc/udev/rules.d/80-gamepad-osk.rules
    udevadm control --reload-rules
    udevadm trigger
fi

# ---------- User systemd service for gamepad-osk ----------
echo -e "${YELLOW}Creating user systemd service for gamepad-osk...${NC}"
USER_SYSTEMD_DIR="$REAL_HOME/.config/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"

cat > "$USER_SYSTEMD_DIR/gamepad-osk.service" << 'EOF'
[Unit]
Description=Gamepad On-Screen Keyboard
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/gamepad-osk --daemon
Restart=on-failure
RestartSec=5
Environment=XDG_RUNTIME_DIR=/run/user/%U

[Install]
WantedBy=default.target
EOF

chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/systemd"

# Enable lingering so user services start at boot without login
loginctl enable-linger "$REAL_USER" || true

# ---------- Enable services ----------
echo -e "${YELLOW}Enabling services...${NC}"
systemctl daemon-reload
systemctl enable xbox-mouse.service
systemctl start xbox-mouse.service || true

# Enable and start the user service as the real user
sudo -u "$REAL_USER" systemctl --user daemon-reload
sudo -u "$REAL_USER" systemctl --user enable gamepad-osk.service
sudo -u "$REAL_USER" systemctl --user start gamepad-osk.service || true

# Add user to input group if needed
usermod -aG input "$REAL_USER" || true

echo
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo
echo "Services installed:"
echo "  • xbox-mouse.service     (system, mouse mode)"
echo "  • gamepad-osk.service    (user, full on-screen keyboard)"
echo
echo "Status:"
systemctl status xbox-mouse.service --no-pager -l || true
sudo -u "$REAL_USER" systemctl --user status gamepad-osk.service --no-pager -l || true
echo
echo -e "${GREEN}Both will start automatically on boot.${NC}"
echo
echo "gamepad-osk controls (once running):"
echo "  Left stick / D-pad → navigate keyboard"
echo "  A                  → press key"
echo "  X                  → Backspace"
echo "  Y                  → Space"
echo "  RT                 → Enter"
echo "  LT (hold)          → Shift"
echo "  Right stick        → mouse"
echo "  RB / R3            → left click"
echo "  Toggle combo       → show/hide (default often Guide+A or configurable)"
echo
echo "Useful commands:"
echo "  systemctl status xbox-mouse.service"
echo "  sudo -u $REAL_USER systemctl --user status gamepad-osk.service"
echo "  sudo -u $REAL_USER systemctl --user restart gamepad-osk.service"
echo
echo -e "${YELLOW}Reboot recommended for full effect (especially if you disabled ERTM):${NC}"
echo "  sudo reboot"
echo
echo -e "${GREEN}Done!${NC}"
