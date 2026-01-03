#!/bin/bash

# ==============================================================================
# Linux Mint & LMDE: Ultimate Setup
# ------------------------------------------------------------------------------
# JAUNUMS:
# 1. Precīza 'Codename' noteikšana (Ubuntu vs Debian bāze).
# 2. Oficiālā LibreWolf instalācijas metode.
# 3. ZRAM un Flatpak labojumi saglabāti.
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

# 2. GUDRĀ DISTRO NOTEIKŠANA
# Šis ir kritiskais solis, lai repozitoriji strādātu pareizi.
source /etc/os-release

TARGET_DISTRO=""

if [[ "$ID" == "lmde" ]]; then
    # LMDE izmanto Debian (piem., bookworm)
    TARGET_DISTRO="$VERSION_CODENAME"
    log "Konstatēts LMDE. Bāze: $TARGET_DISTRO (Debian)"
else
    # Standard Mint izmanto Ubuntu bāzi. 
    # Mums jāizmanto UBUNTU_CODENAME (piem., jammy, noble), nevis Mint nosaukums (wilma).
    if [ -n "$UBUNTU_CODENAME" ]; then
        TARGET_DISTRO="$UBUNTU_CODENAME"
    else
        TARGET_DISTRO="jammy" # Fallback, ja nevar noteikt
    fi
    log "Konstatēts Linux Mint. Bāze: $TARGET_DISTRO (Ubuntu)"
fi

# 3. TĪRĪŠANA
log "Tīra vecos repozitorijus..."
rm -f /etc/apt/sources.list.d/eparaksts.list
rm -f /etc/apt/sources.list.d/librewolf.list
rm -f /etc/apt/sources.list.d/brave-browser-release.list
rm -f /etc/apt/sources.list.d/mullvad.list
rm -f /etc/apt/sources.list.d/1password.list

# 4. REPOZITORIJU PIEVIENOŠANA (Ar pareizo $TARGET_DISTRO)

# --- LibreWolf (Oficiālā metode) ---
log "Pievieno LibreWolf ($TARGET_DISTRO)..."
curl -fsSL https://deb.librewolf.net/keyring.gpg | gpg --dearmor -o /usr/share/keyrings/librewolf.gpg
# Izmantojam pareizo bāzes nosaukumu
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/librewolf.gpg] https://deb.librewolf.net $TARGET_DISTRO main" > /etc/apt/sources.list.d/librewolf.list

# --- Brave Browser ---
log "Pievieno Brave ($TARGET_DISTRO)..."
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# --- Mullvad Browser ---
log "Pievieno Mullvad..."
curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mullvad-keyring.asc] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list

# --- 1Password ---
log "Pievieno 1Password..."
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" > /etc/apt/sources.list.d/1password.list
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol > /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# 5. INSTALĀCIJA (APT)
log "Atjaunina pakotņu sarakstus..."
apt update

log "Instalē pamatprogrammas..."
# Auto-Accept Microsoft Fonts EULA
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer

# Instalē pārlūkus (ar kļūdu ignorēšanu, ja fails)
apt install -y librewolf || warn "LibreWolf kļūda (iespējams tīkls)"
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

# 6. FLATPAK INSTALĀCIJA
log "Konfigurē Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"

install_flatpak() {
    log "-> $1"
    flatpak install -y --noninteractive flathub "$1"
}

log "Instalē Flatpak lietotnes..."
install_flatpak "io.ente.auth"
install_flatpak "org.onlyoffice.desktopeditors"
install_flatpak "com.github.micahflee.torbrowser-launcher"
install_flatpak "io.freetubeapp.FreeTube"
install_flatpak "com.rawtherapee.RawTherapee"
install_flatpak "app.drey.Dialect"
install_flatpak "org.openshot.OpenShot"
install_flatpak "com.spotify.Client"
install_flatpak "com.discordapp.Discord"
install_flatpak "org.signal.Signal"
install_flatpak "com.valvesoftware.Steam"
install_flatpak "org.inkscape.Inkscape"
install_flatpak "org.videolan.VLC"

# 7. PYTHON (Pipx Force)
log "Instalē LibreTranslate..."
sudo -u "$REAL_USER" pipx install libretranslate --force
sudo -u "$REAL_USER" pipx ensurepath

# 8. SISTĒMAS OPTIMIZĀCIJA (ZRAM Smart Fix)
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

# Restartējam servisu tikai tad, ja tas eksistē
if systemctl list-unit-files | grep -q zram-tools.service; then
    systemctl restart zram-tools
else
    # Ja nav zram-tools, mēģinām zram-config (alternatīva dažos distro)
    apt install -y zram-config
    systemctl restart zram-config 2>/dev/null || true
fi

# DNS
apt install -y systemd-resolved
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 9. PĀRLŪKU CACHE -> RAM
mkdir -p /etc/firefox/policies /etc/librewolf /usr/lib/firefox/distribution
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
cp /etc/firefox/policies/policies.json /etc/librewolf/policies.json 2>/dev/null || true

# 10. AI & UI
log "Konfigurē UI un AI..."
apt install -y papirus-icon-theme fonts-noto-color-emoji

DESKTOP_ENV="unknown"
if [ -f "/usr/bin/cinnamon-session" ] && pgrep -u "$REAL_USER" "cinnamon" > /dev/null; then DESKTOP_ENV="cinnamon"; fi
if [ -f "/usr/bin/mate-session" ] && pgrep -u "$REAL_USER" "mate-session" > /dev/null; then DESKTOP_ENV="mate"; fi
if [ -f "/usr/bin/xfce4-session" ] && pgrep -u "$REAL_USER" "xfce4-session" > /dev/null; then DESKTOP_ENV="xfce"; fi

if [ "$DESKTOP_ENV" == "cinnamon" ]; then
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface enable-animations false 2>/dev/null
elif [ "$DESKTOP_ENV" == "mate" ]; then
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface gtk-theme 'Mint-Y-Dark-Aqua' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.Marco.general compositing-manager true 2>/dev/null
elif [ "$DESKTOP_ENV" == "xfce" ]; then
    apt install -y xfce4-whiskermenu-plugin xfce4-goodies
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xsettings -p /Net/ThemeName -s 'Mint-Y-Dark-Aqua' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xsettings -p /Net/IconThemeName -s 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/use_compositing -s true 2>/dev/null
fi

# KoboldCPP
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

# 11. TĪRĪŠANA
log "Tīrīšana..."
apt autoremove --purge -y && apt clean
flatpak uninstall --unused -y

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}           INSTALĀCIJA PABEIGTA (v19)            ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo "1. Distro Bāze: $TARGET_DISTRO (Pareizi detektēta)."
echo "2. LibreWolf/Brave: Repozitoriji salaboti."
echo "3. ZRAM: Aktivizēts."
echo -e "${YELLOW}Lūdzu, PĀRSTARTĒJIET DATORU!${NC}"
exit 0
