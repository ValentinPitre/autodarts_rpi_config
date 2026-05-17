#!/bin/bash

set -e

echo "=== AUTODARTS WIFI SETUP ==="

# =========================
# Update system
# =========================
echo "[1/8] Updating system..."
sudo apt update

# =========================
# Install packages
# =========================
echo "[2/8] Installing packages..."
sudo apt install -y python3-flask dnsmasq iptables iptables-persistent

# =========================
# Allow nmcli without password
# =========================
echo "[3/8] Configuring sudo for nmcli..."
if ! sudo grep -q "autodarts ALL=(ALL) NOPASSWD: /usr/bin/nmcli" /etc/sudoers; then
    echo "autodarts ALL=(ALL) NOPASSWD: /usr/bin/nmcli" | sudo tee -a /etc/sudoers
fi

# =========================
# Configure dnsmasq
# =========================
echo "[4/8] Configuring dnsmasq..."

sudo systemctl stop dnsmasq || true

sudo bash -c 'cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=10.42.0.10,10.42.0.100,12h
address=/#/10.42.0.1
EOF'

sudo systemctl restart dnsmasq

# =========================
# Configure iptables
# =========================
echo "[5/8] Configuring iptables..."

sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 10.42.0.1:80 || true
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination 10.42.0.1:80 || true
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE || true

sudo netfilter-persistent save

# =========================
# Install wifi fallback script
# =========================
echo "[6/8] Installing wifi fallback script..."

sudo bash -c 'cat > /usr/local/bin/wifi-fallback.sh <<EOF
#!/bin/bash

INTERFACE="wlan0"
HOTSPOT_NAME="hotspot"

# bring up interface if down
sudo ip link set "$INTERFACE" up 2>/dev/null

# fetch known wifi
KNOWN_SSIDS=$(nmcli -t -f NAME,TYPE connection show | awk -F: '"'"'$2=="802-11-wireless"{print $1}'"'"' | grep -v "^hotspot\$")

VISIBLE_SSIDS=$(nmcli -t -f SSID dev wifi list)

CURRENT=$(nmcli -t -f ACTIVE,SSID dev wifi | grep ^yes | cut -d: -f2)

FOUND=""

for SSID in $KNOWN_SSIDS; do
    if echo "$VISIBLE_SSIDS" | grep -Fxq "$SSID"; then
        FOUND="$SSID"
        break
    fi
done

if [ -n "$FOUND" ]; then
    if [ "$CURRENT" != "$FOUND" ]; then
        sudo nmcli con down "$HOTSPOT_NAME" 2>/dev/null
        sudo nmcli con up "$FOUND"
    fi
else
    if [ "$CURRENT" != "$HOTSPOT_NAME" ]; then
        sudo nmcli con up "$HOTSPOT_NAME"
    fi
fi
EOF'

sudo chmod +x /usr/local/bin/wifi-fallback.sh

# =========================
# Setup systemd fallback
# =========================
echo "[7/8] Creating systemd services..."

sudo bash -c 'cat > /etc/systemd/system/wifi-fallback.service <<EOF
[Unit]
Description=WiFi fallback
After=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/local/bin/wifi-fallback.sh

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat > /etc/systemd/system/wifi-fallback.timer <<EOF
[Unit]
Description=WiFi fallback timer

[Timer]
OnBootSec=10
OnUnitActiveSec=30

[Install]
WantedBy=timers.target
EOF'

# =========================
# Setup wifi portal service
# =========================
echo "[8/8] Creating Flask service..."

sudo bash -c 'cat > /etc/systemd/system/wifi-portal.service <<EOF
[Unit]
Description=WiFi Config Portal
After=NetworkManager.service

[Service]
ExecStart=/usr/bin/python3 /home/autodarts/wifi-portal.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# =========================
# Enable everything
# =========================
echo "Enabling services..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload

sudo systemctl enable wifi-fallback.timer
sudo systemctl start wifi-fallback.timer

sudo systemctl enable wifi-portal
sudo systemctl start wifi-portal

echo ""
echo "✅ INSTALLATION COMPLETE"
echo "Hotspot: Autodarts-AP"
echo "Portal: http://10.42.0.1"