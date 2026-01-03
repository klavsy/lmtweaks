#!/bin/bash

# ==============================================================================
# Linux Mint & LMDE
# ------------------------------------------------------------------------------
# LABOJUMS: Mullvad Browser repozitorijs atjaunots uz precīzu oficiālo sintaksi.
# Signal: APT | Spotify: APT | LibreWolf: Flatpak | Mullvad: APT (Official)
# ==============================================================================

# Krāsas
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- FUNKCIJAS ---
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[UZMANĪBU]${NC} $1"; }
error() { echo -e "${RED}[KĻŪDA]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

# 1. ROOT PĀRBAUDE
if [ "$EUID" -ne 0 ]; then
    error "Nepieciešamas root tiesības. Palaidiet: sudo ./run.sh"
    exit 1
fi

REAL_USER=$(logname)
USER_HOME=$(eval echo "~$REAL_USER")
source /etc/os-release

# 2. SISTĒMAS NOTEIKŠANA
DISTRO_CODE="jammy" 
if [[ "$ID" == "lmde" ]]; then
    DISTRO_CODE="bookworm"
fi
log "Sistēmas bāze: $DISTRO_CODE"

# 3. TĪRĪŠANA
log "Tīra vecos repozitorijus un konfliktus..."
rm -f /etc/apt/sources.list.d/librewolf.list 
rm -f /etc/apt/sources.list.d/eparaksts.list
# Noņemam Flatpak versijas (lai nebūtu dubultā)
flatpak uninstall -y org.signal.Signal 2>/dev/null
flatpak uninstall -y com.spotify.Client 2>/dev/null

# 4. APT REPOZITORIJU PIEVIENOŠANA

# --- Mullvad Browser (OFICIĀLĀ METODE) ---
log "Pievieno Mullvad (Official)..."
# 1. Lejupielādē atslēgu
curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc
# 2. Pievieno repo (dinamiska arhitektūra)
echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list

# --- Signal (Official) ---
log "Pievieno Signal..."
wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
wget -O- https://updates.signal.org/static/desktop/apt/signal-desktop.sources > /etc/apt/sources.list.d/signal-desktop.sources

# --- Spotify (Official) ---
log "Pievieno Spotify..."
curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /usr/share/keyrings/spotify-client-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/spotify-client-keyring.gpg] http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list

# --- Brave Browser ---
log "Pievieno Brave..."
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# --- 1Password ---
log "Pievieno 1Password..."
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" > /etc/apt/sources.list.d/1password.list
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol > /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# 5. APT INSTALĀCIJA
log "Atjaunina sarakstus un instalē pamatprogrammas..."
apt update

# Fonti
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer

# Programmas
apt install -y signal-desktop || warn "Signal kļūda"
apt install -y spotify-client || warn "Spotify kļūda"
apt install -y brave-browser || warn "Brave kļūda"
apt install -y mullvad-browser || warn "Mullvad kļūda"
apt install -y 1password || warn "1Password kļūda"
apt install -y pipx flatpak curl wget unzip timeshift

# Kodeki
if [ "$ID" == "lmde" ]; then
    apt install -y libavcodec-extra gstreamer1.0-libav gstreamer1.0-plugins-ugly
else
    apt install -y mint-meta-codecs
fi

# 6. FLATPAK INSTALĀCIJA (LibreWolf ir šeit)
log "Konfigurē Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"

install_flatpak() {
    log "Instalē Flatpak: $1"
    flatpak install -y --noninteractive flathub "$1"
}

# LibreWolf (Flatpak)
install_flatpak "io.gitlab.librewolf-community"

# Pārējās lietotnes
install_flatpak "io.ente.auth"
install_flatpak "org.onlyoffice.desktopeditors"
install_flatpak "com.github.micahflee.torbrowser-launcher"
install_flatpak "io.freetubeapp.FreeTube"
install_flatpak "com.rawtherapee.RawTherapee"
install_flatpak "app.drey.Dialect"
install_flatpak "org.openshot.OpenShot"
install_flatpak "com.discordapp.Discord"
install_flatpak "com.valvesoftware.Steam"
install_flatpak "org.inkscape.Inkscape"
install_flatpak "org.videolan.VLC"

# 7. PYTHON (Pipx Force)
log "Instalē LibreTranslate..."
sudo -u "$REAL_USER" pipx install libretranslate --force
sudo -u "$REAL_USER" pipx ensurepath

# 8. SISTĒMAS OPTIMIZĀCIJA (Smart ZRAM)
log "Optimizē atmiņu (ZRAM)..."
apt install -y zram-tools
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -le 16 ]; then
    echo "ALGO=zstd" > /etc/default/zram-tools 2>/dev/null
    echo "PERCENT=60" >> /etc/default/zram-tools 2>/dev/null
    sysctl -w vm.swappiness=100
else
    sysctl -w vm.swappiness=10
fi

if systemctl list-unit-files | grep -q zram-tools.service; then
    systemctl restart zram-tools
else
    apt install -y zram-config
    systemctl restart zram-config 2>/dev/null || true
fi

# DNS (Quad9)
apt install -y systemd-resolved
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 9. PĀRLŪKU CACHE -> RAM
mkdir -p /etc/firefox/policies /usr/lib/firefox/distribution
cat <<EOF > /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "Preferences": {
      "browser.cache.disk.enable": false,
      "browser.cache.memory.enable": true,
      "browser.cache.memory.capacity": -1
    }
  }
}
EOF

# 10. AI (KOBOLDCPP)
log "Pārbauda KoboldCPP..."
KOBOLD_DIR="$USER_HOME/koboldcpp"
mkdir -p "$KOBOLD_DIR"
if [ ! -f "$KOBOLD_DIR/koboldcpp_linux" ]; then
    curl -fLo "$KOBOLD_DIR/koboldcpp_linux" https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
    chmod +x "$KOBOLD_DIR/koboldcpp_linux"
fi
if [ ! -f "$KOBOLD_DIR/llama-3-8b-instruct.gguf" ]; then
    wget -O "$KOBOLD_DIR/llama-3-8b-instruct.gguf" https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
fi
echo "#!/bin/bash
cd $KOBOLD_DIR
./koboldcpp_linux --model llama-3-8b-instruct.gguf --port 5001 --smartcontext" > "$KOBOLD_DIR/start_kobold.sh"
chmod +x "$KOBOLD_DIR/start_kobold.sh"
chown -R "$REAL_USER:$REAL_USER" "$KOBOLD_DIR"

# 11. UI & CLEANUP
log "Pielāgo UI..."
apt install -y papirus-icon-theme fonts-noto-color-emoji
if [ -f "/usr/bin/cinnamon-session" ]; then
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua' 2>/dev/null
fi

log "Tīrīšana..."
apt autoremove --purge -y && apt clean
flatpak uninstall --unused -y

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}           INSTALĀCIJA PABEIGTA (v23)            ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo "1. Mullvad: Oficiālais (Dynamic Arch)."
echo "2. Spotify: Oficiālais (APT)."
echo "3. Signal: Oficiālais (APT)."
echo -e "${YELLOW}Lūdzu, PĀRSTARTĒJIET DATORU!${NC}"
exit 0
