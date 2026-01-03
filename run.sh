#!/bin/bash

# ==============================================================================
# Linux Mint & LMDE: Ultimate Setup (v28 - AMD Support Edition)
# ------------------------------------------------------------------------------
# JAUNUMS:
# 1. Pievienots AMD Radeon atbalsts (Vulkan) AI modelim.
# 2. Saglabāta "Self-Repair" un "Secure Repo" loģika.
# ==============================================================================

# --- KONFIGURĀCIJA & KRĀSAS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- FUNKCIJAS ---
print_step() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[UZMANĪBU]${NC} $1"; }
error() { echo -e "${RED}[KĻŪDA]${NC} $1"; }

# 1. PIRMS-STARTA PĀRBAUDES
print_step "Sistēmas Pārbaude"

if [ "$EUID" -ne 0 ]; then
    error "Nepieciešamas root tiesības. Palaidiet: sudo ./run.sh"
    exit 1
fi

log "Pārbauda interneta savienojumu..."
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "Nav interneta savienojuma! Skripts apturēts."
    exit 1
fi

REAL_USER=$(logname)
USER_HOME=$(eval echo "~$REAL_USER")
source /etc/os-release

DISTRO_CODE="jammy" 
if [[ "$ID" == "lmde" ]]; then
    DISTRO_CODE="bookworm"
fi
log "Detektētā bāze: $ID ($DISTRO_CODE)"

# Self-Repair
log "Veic sistēmas paš-diagnostiku..."
dpkg --configure -a || warn "Mēģināja salabot dpkg..."
apt install -f -y || warn "Mēģināja salabot atkarības..."

# 2. TĪRĪŠANA
print_step "Tīrīšana"
log "Noņem vecos repozitorijus..."
rm -f /etc/apt/sources.list.d/spotify.list
rm -f /etc/apt/sources.list.d/librewolf.list 
rm -f /etc/apt/sources.list.d/eparaksts.list
rm -f /etc/apt/sources.list.d/signal-desktop.sources

# Noņem RawTherapee un dublikātus
flatpak uninstall -y com.rawtherapee.RawTherapee 2>/dev/null
flatpak uninstall -y org.signal.Signal 2>/dev/null
flatpak uninstall -y com.spotify.Client 2>/dev/null

# 3. APT REPOZITORIJU PIEVIENOŠANA
print_step "Repozitoriju Konfigurācija"

add_repo_key() {
    local url=$1
    local path=$2
    log "Atslēga: $(basename "$path")"
    if curl -fsSL "$url" | gpg --dearmor -o "$path"; then
        chmod 644 "$path"
    else
        warn "Neizdevās: $url"
    fi
}

# --- Spotify ---
add_repo_key "https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg" "/usr/share/keyrings/spotify-client-keyring.gpg"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/spotify-client-keyring.gpg] http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list

# --- Mullvad ---
add_repo_key "https://repository.mullvad.net/deb/mullvad-keyring.asc" "/usr/share/keyrings/mullvad-keyring.asc"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mullvad-keyring.asc] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list

# --- Signal ---
add_repo_key "https://updates.signal.org/desktop/apt/keys.asc" "/usr/share/keyrings/signal-desktop-keyring.gpg"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal-desktop.sources

# --- Brave ---
add_repo_key "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" "/usr/share/keyrings/brave-browser-archive-keyring.gpg"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# --- 1Password ---
add_repo_key "https://downloads.1password.com/linux/keys/1password.asc" "/usr/share/keyrings/1password-archive-keyring.gpg"
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" > /etc/apt/sources.list.d/1password.list
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol > /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# 4. INSTALĀCIJA
print_step "Programmatūras Instalācija"

log "Atjaunina sarakstus..."
apt update

echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer

PACKAGES="spotify-client signal-desktop brave-browser mullvad-browser 1password pipx flatpak curl wget unzip timeshift"
log "Instalē: $PACKAGES"
apt install -y $PACKAGES

if [ "$ID" == "lmde" ]; then
    apt install -y libavcodec-extra gstreamer1.0-libav gstreamer1.0-plugins-ugly
else
    apt install -y mint-meta-codecs
fi

# 5. FLATPAK
print_step "Flatpak Konfigurācija"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"
export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

install_flatpak() {
    log "-> $1"
    flatpak install -y --noninteractive flathub "$1"
}

install_flatpak "io.gitlab.librewolf-community" # LibreWolf
install_flatpak "io.ente.auth"
install_flatpak "org.onlyoffice.desktopeditors"
install_flatpak "com.github.micahflee.torbrowser-launcher"
install_flatpak "io.freetubeapp.FreeTube"
install_flatpak "app.drey.Dialect"
install_flatpak "org.openshot.OpenShot"
install_flatpak "com.discordapp.Discord"
install_flatpak "com.valvesoftware.Steam"
install_flatpak "org.inkscape.Inkscape"
install_flatpak "org.videolan.VLC"

# 6. PYTHON & AI (AMD SUPPORT ADDED)
print_step "AI & Tulkošana"

sudo -u "$REAL_USER" pipx install libretranslate --force
sudo -u "$REAL_USER" pipx ensurepath

KOBOLD_DIR="$USER_HOME/koboldcpp"
mkdir -p "$KOBOLD_DIR"

if [ ! -f "$KOBOLD_DIR/koboldcpp" ]; then
    log "Lejupielādē KoboldCPP..."
    curl -fLo "$KOBOLD_DIR/koboldcpp" https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
    chmod +x "$KOBOLD_DIR/koboldcpp"
fi

if [ ! -f "$KOBOLD_DIR/llama-3-8b-instruct.gguf" ]; then
    log "Lejupielādē AI modeli..."
    wget -O "$KOBOLD_DIR/llama-3-8b-instruct.gguf" https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
fi

# SMART LAUNCHER (AMD/NVIDIA/CPU)
cat <<EOF > "$KOBOLD_DIR/start_kobold.sh"
#!/bin/bash
cd $KOBOLD_DIR

# 1. Pārbauda Nvidia
if lspci | grep -i nvidia > /dev/null; then
    echo "Nvidia GPU atrasts! Izmanto CUDA..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --usecublas --gpulayers 99 --port 5001 --smartcontext --contextsize 8192

# 2. Pārbauda AMD (Radeon)
elif lspci | grep -i -E "amd|ati|radeon" > /dev/null; then
    echo "AMD Radeon GPU atrasts! Izmanto Vulkan..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --usevulkan --gpulayers 99 --port 5001 --smartcontext --contextsize 8192

# 3. Fallback uz CPU
else
    echo "GPU nav atrasts. Izmanto CPU..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --port 5001 --smartcontext --contextsize 8192
fi
EOF
chmod +x "$KOBOLD_DIR/start_kobold.sh"
chown -R "$REAL_USER:$REAL_USER" "$KOBOLD_DIR"

# 7. OPTIMIZĀCIJA & UI
print_step "Sistēmas Optimizācija"

apt install -y zram-tools
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -le 16 ]; then
    echo "ALGO=zstd" > /etc/default/zram-tools 2>/dev/null
    echo "PERCENT=60" >> /etc/default/zram-tools 2>/dev/null
    sysctl -w vm.swappiness=100
else
    sysctl -w vm.swappiness=10
fi
systemctl restart zram-tools 2>/dev/null || systemctl restart zram-config 2>/dev/null || true

apt install -y systemd-resolved
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Browser RAM Cache
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

apt install -y papirus-icon-theme fonts-noto-color-emoji
update-icon-caches /usr/share/icons/* 2>/dev/null

print_step "Pabeigts!"
echo -e "${GREEN}Sistēma konfigurēta (v28 - AMD/Nvidia Support).${NC}"
echo -e "${YELLOW}Lūdzu, PĀRSTARTĒJIET DATORU!${NC}"
exit 0
