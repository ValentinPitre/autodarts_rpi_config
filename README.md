# 📡 Autodarts Raspberry Pi Network Config

Configuration complète d’un Raspberry Pi pour :

- 🔁 fallback automatique WiFi ↔ hotspot  
- 🌐 portail captif pour config réseau  
- 📡 gestion via NetworkManager (`nmcli`)  
- 🧠 comportement type produit IoT  

---

## 🔐 Connexion SSH

```bash
ssh autodarts@autodartspi
```

---

# 🔁 WiFi Fallback (Client ↔ Hotspot)

## 📄 Script

```bash
sudo nano /usr/local/bin/wifi-fallback.sh
sudo chmod +x /usr/local/bin/wifi-fallback.sh
```

---

## ⚙️ Service systemd

```bash
sudo nano /etc/systemd/system/wifi-fallback.service
```

```ini
[Unit]
Description=WiFi fallback (client <-> hotspot)
After=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/local/bin/wifi-fallback.sh

[Install]
WantedBy=multi-user.target
```

---

## ⏱ Timer

```bash
sudo nano /etc/systemd/system/wifi-fallback.timer
```

```ini
[Unit]
Description=Check WiFi fallback every 30 sec

[Timer]
OnBootSec=10
OnUnitActiveSec=30

[Install]
WantedBy=timers.target
```

---

## ▶️ Activation

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

sudo systemctl enable wifi-fallback.timer
sudo systemctl start wifi-fallback.timer
```

---

# 🌐 WiFi Config Portal (Flask)

## 📦 Installation

```bash
sudo apt update
sudo apt install python3-flask
```

---

## 📄 Code serveur

```bash
nano ~/wifi-portal.py
```

---

# 🔁 Captive Portal (Redirection Automatique)

## 📦 Installer dnsmasq

```bash
sudo apt install dnsmasq
```

---

## ⚙️ Configuration DNS

```bash
sudo nano /etc/dnsmasq.conf
```

Ajouter :

```conf
interface=wlan0
dhcp-range=10.42.0.10,10.42.0.100,12h
address=/#/10.42.0.1
```

---

## 🔀 Redirection HTTP

```bash
sudo apt install iptables
```

```bash
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 10.42.0.1:80
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination 10.42.0.1:80
```

---

## 🌍 NAT Internet (optionnel)

```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

---

## 💾 Sauvegarde règles

```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

## 🔄 Redémarrage

```bash
sudo systemctl restart dnsmasq
```

---

# 🚀 Service Flask Auto

## 📄 Configuration

```bash
sudo nano /etc/systemd/system/wifi-portal.service
```

```ini
[Unit]
Description=WiFi Config Portal
After=NetworkManager.service

[Service]
ExecStart=/usr/bin/python3 /home/autodarts/wifi-portal.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

---

## ▶️ Lancement

```bash
sudo systemctl daemon-reload
sudo systemctl enable wifi-portal
sudo systemctl start wifi-portal
```

---

## ✅ Vérification

```bash
sudo systemctl status wifi-portal
```

---

# 📊 Logs

## 🔍 Portail

```bash
sudo journalctl -u wifi-portal -f
```

## 📡 NetworkManager

```bash
sudo journalctl -u NetworkManager -f
```

## 📄 Logs fichier

```bash
tail -f /var/log/wifi-portal.log
```

---

# 🧪 Debug

## Stop fallback

```bash
sudo systemctl stop wifi-fallback.service
sudo systemctl stop wifi-fallback.timer
```

---

## Vérification réseau

```bash
ip a
nmcli dev status
nmcli dev wifi list
```

---

# 🔐 Autorisation nmcli sans mot de passe

```bash
sudo visudo
```

Ajouter :

```bash
autodarts ALL=(ALL) NOPASSWD: /usr/bin/nmcli
```

---

# ✅ Fonctionnement final

👉 Le Raspberry Pi :

- 🔁 bascule automatiquement WiFi ↔ hotspot  
- 🌐 expose un portail captif sur `10.42.0.1`  
- 📡 permet configuration WiFi via navigateur  
- 🧠 choisit automatiquement un réseau connu disponible  
- 🔎 fournit logs détaillés  

---

# 🏁 Conclusion

👉 Setup complet type **produit IoT / box WiFi / firmware embarqué**