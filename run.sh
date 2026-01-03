#!/bin/bash

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
print_step "Sistēmas Diagnostika"

if [ "$EUID" -ne 0 ]; then
    error "Nepieciešamas root tiesības. Palaidiet: sudo ./run.sh"
    exit 1
fi

log "Pārbauda interneta savienojumu..."
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "Nav interneta savienojuma! Skripts apturēts."
    exit 1
fi

# 2. OS DETEKTĒŠANA
source /etc/os-release
if [[ -n "$DEBIAN_CODENAME" ]]; then
    IS_LMDE=true
    log "Sistēma: LMDE ($DEBIAN_CODENAME)"
else
    log "Sistēma: $NAME ($VERSION_CODENAME)"
fi

# 3. AGRESĪVĀ TĪRĪŠANA (REPOZITORIJI)
print_step "Bojāto Repozitoriju Dzēšana"

log "Dzēš visu, kas varētu izraisīt konfliktus..."

# 1. Signal (Galvenais vaininieks 'Malformed stanza')
rm -f /etc/apt/sources.list.d/signal-desktop.sources
rm -f /etc/apt/sources.list.d/signal-desktop.list
rm -f /etc/apt/sources.list.d/*signal*.list
rm -f /etc/apt/sources.list.d/*signal*.sources

# 2. Spotify (NO_PUBKEY fix)
rm -f /etc/apt/sources.list.d/spotify.list
rm -f /etc/apt/sources.list.d/*spotify*.list

# 3. Mullvad (NO_PUBKEY fix)
rm -f /etc/apt/sources.list.d/mullvad.list

# 4. Citi
rm -f /etc/apt/sources.list.d/brave-browser-release.list
rm -f /etc/apt/sources.list.d/1password.list

# Dzēšam vecās atslēgas, lai lejupielādētu svaigas
rm -f /usr/share/keyrings/signal-desktop-keyring.gpg
rm -f /usr/share/keyrings/spotify-client-keyring.gpg
rm -f /usr/share/keyrings/mullvad-keyring.asc
rm -f /usr/share/keyrings/mullvad-keyring.gpg

# Self-Repair (Pēc failu dzēšanas)
log "Mēģina salabot apt..."
apt clean
apt install -f -y
apt install -y curl wget gpg software-properties-common

# 4. REPOZITORIJU KONFIGURĀCIJA (CLEAN INSTALL)
print_step "Repozitoriju Atjaunošana"

# Funkcija drošai atslēgu pievienošanai
add_key_and_repo() {
    local key_url=$1
    local keyring_path=$2
    local repo_line=$3
    local list_file=$4

    log "Konfigurē: $(basename "$list_file")"
    
    # Lejupielādē atslēgu (wget -> gpg dearmor)
    wget -qO- "$key_url" | gpg --dearmor --yes -o "$keyring_path"
    chmod 644 "$keyring_path"
    
    # Izveido repo failu
    echo "$repo_line" > "$list_file"
}

# --- Spotify ---
# Izmantojam oficiālo metodi
wget -qO- "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x6224F9941A8AA6D1" | gpg --dearmor --yes -o /usr/share/keyrings/spotify-client-keyring.gpg
chmod 644 /usr/share/keyrings/spotify-client-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/spotify-client-keyring.gpg] http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list

# --- Mullvad ---
wget -qO- https://repository.mullvad.net/deb/mullvad-keyring.asc | gpg --dearmor --yes -o /usr/share/keyrings/mullvad-keyring.gpg
chmod 644 /usr/share/keyrings/mullvad-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mullvad-keyring.gpg] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list

# --- Signal (Xenial repo works for all) ---
add_key_and_repo \
    "https://updates.signal.org/desktop/apt/keys.asc" \
    "/usr/share/keyrings/signal-desktop-keyring.gpg" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" \
    "/etc/apt/sources.list.d/signal-desktop.list"

# --- Brave ---
add_key_and_repo \
    "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
    "/usr/share/keyrings/brave-browser-archive-keyring.gpg" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    "/etc/apt/sources.list.d/brave-browser-release.list"

# --- 1Password ---
add_key_and_repo \
    "https://downloads.1password.com/linux/keys/1password.asc" \
    "/usr/share/keyrings/1password-archive-keyring.gpg" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" \
    "/etc/apt/sources.list.d/1password.list"
    
# 1Password Policies
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
wget -qO /etc/debsig/policies/AC2D62742012EA22/1password.pol https://downloads.1password.com/linux/debian/debsig/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
wget -qO- https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --yes -o /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# --- Mozilla Firefox Official ---
wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null
echo 'Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000' | tee /etc/apt/preferences.d/mozilla > /dev/null

# 5. INSTALĀCIJA
print_step "Programmatūras Instalācija"

log "Atjaunina sarakstus (Pēc labojumiem)..."
apt update

echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer

PACKAGES="firefox spotify-client signal-desktop brave-browser mullvad-browser 1password pipx flatpak curl wget unzip timeshift cpufrequtils ufw"
log "Instalē pamatprogrammas: $PACKAGES"
apt install -y $PACKAGES

# KODEKI
log "Instalē kodekus..."
if [[ "$ID" == "linuxmint" ]] || [[ "$IS_LMDE" == true ]]; then
    apt install -y mint-meta-codecs
elif [[ "$ID" == "ubuntu" ]]; then
    apt install -y ubuntu-restricted-extras
else
    apt install -y libavcodec-extra gstreamer1.0-libav gstreamer1.0-plugins-ugly
fi

# 6. FLATPAK
print_step "Flatpak Konfigurācija"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"
export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

install_flatpak() {
    log "-> $1"
    flatpak install -y --noninteractive flathub "$1"
}

install_flatpak "io.gitlab.librewolf-community"
install_flatpak "io.ente.auth"
install_flatpak "org.onlyoffice.desktopeditors"
install_flatpak "org.torproject.torbrowser-launcher"
install_flatpak "io.freetubeapp.FreeTube"
install_flatpak "app.drey.Dialect"
install_flatpak "org.openshot.OpenShot"
install_flatpak "com.discordapp.Discord"
install_flatpak "com.valvesoftware.Steam"
install_flatpak "org.inkscape.Inkscape"
install_flatpak "org.videolan.VLC"

# 7. PYTHON & AI
print_step "AI & Tulkošana"

REAL_USER=$(logname)
USER_HOME=$(eval echo "~$REAL_USER")

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

# SMART LAUNCHER
cat <<EOF > "$KOBOLD_DIR/start_kobold.sh"
#!/bin/bash
cd $KOBOLD_DIR
if lspci | grep -i nvidia > /dev/null; then
    echo "Nvidia GPU atrasts! Izmanto CUDA..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --usecublas --gpulayers 99 --port 5001 --smartcontext --contextsize 8192
elif lspci | grep -i -E "amd|ati|radeon" > /dev/null; then
    echo "AMD Radeon GPU atrasts! Izmanto Vulkan..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --usevulkan --gpulayers 99 --port 5001 --smartcontext --contextsize 8192
else
    echo "GPU nav atrasts. Izmanto CPU..."
    ./koboldcpp --model llama-3-8b-instruct.gguf --port 5001 --smartcontext --contextsize 8192
fi
EOF
chmod +x "$KOBOLD_DIR/start_kobold.sh"
chown -R "$REAL_USER:$REAL_USER" "$KOBOLD_DIR"

# 8. DROŠĪBAS & KODOLA HARDENING
print_step "Drošības Hardening"

# UFW (Firewall)
log "Konfigurē UFW Ugunsmūri..."
ufw enable
ufw logging off

# Kernel Hardening (Restrict dmesg)
echo "kernel.dmesg_restrict=1" > /etc/sysctl.d/6-dmesg-sudo.conf
sysctl -p /etc/sysctl.d/6-dmesg-sudo.conf 2>/dev/null

# 9. CPU & DISK
print_step "CPU & Diska Optimizācija"

# CPU Performance
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils 2>/dev/null

# Zswap & Swappiness & Dirty Bytes
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

if [ "$TOTAL_RAM_GB" -le 8 ]; then
    SWAPPINESS_VAL=30
    GRUB_ADD="zswap.enabled=1 zswap.max_pool_percent=40 zswap.zpool=zsmalloc zswap.compressor=lz4"
    DIRTY_BYTES=314572800
    DIRTY_BG_BYTES=157286400
else
    SWAPPINESS_VAL=60
    GRUB_ADD="zswap.enabled=1 zswap.zpool=zsmalloc zswap.compressor=lz4"
    DIRTY_BYTES=524288000
    DIRTY_BG_BYTES=262144000
fi

echo "vm.swappiness=$SWAPPINESS_VAL" > /etc/sysctl.d/99-mint-swappiness.conf
echo "vm.dirty_bytes=$DIRTY_BYTES" > /etc/sysctl.d/8-writing.conf
echo "vm.dirty_background_bytes=$DIRTY_BG_BYTES" >> /etc/sysctl.d/8-writing.conf
sysctl -p /etc/sysctl.d/99-mint-swappiness.conf

# GRUB & Initramfs
GRUB_FILE="/etc/default/grub"
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE"; then
    log "Atjaunina GRUB..."
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash '"$GRUB_ADD"'"/' "$GRUB_FILE"
    update-grub
fi
MODULES_FILE="/etc/initramfs-tools/modules"
if [ -f "$MODULES_FILE" ] && ! grep -q "zsmalloc" "$MODULES_FILE"; then
    echo "zsmalloc" >> "$MODULES_FILE"
    update-initramfs -uk all
fi

# 10. PĀRLŪKU & UI IESTATĪJUMI
print_step "UI & Privātums"

# DNS
apt install -y systemd-resolved
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Browser Policies
mkdir -p /etc/firefox/policies /usr/lib/firefox/distribution
cat <<EOF > /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "Preferences": {
      "browser.cache.disk.enable": false,
      "browser.cache.memory.enable": true,
      "browser.cache.memory.capacity": 1048576,
      "browser.sessionstore.interval": 150000000,
      "browser.ml.enable": false,
      "browser.ml.chat.enabled": false,
      "dom.webnotifications.enabled": false,
      "browser.quicksuggest.enabled": false,
      "browser.urlbar.suggest.quicksuggest.nonsponsored": false,
      "browser.urlbar.suggest.quicksuggest.sponsored": false
    }
  }
}
EOF

# UI Ikonas
apt install -y papirus-icon-theme fonts-noto-color-emoji
update-icon-caches /usr/share/icons/* 2>/dev/null

# UI: VIZUĀLO EFEKTU ATSLĒGŠANA
if [ -f "/usr/bin/cinnamon-session" ]; then
    log "Konfigurē Cinnamon (Windows 11 Style)..."
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface enable-animations false 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon enable-tiling false 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.muffin unredirect-fullscreen-windows true 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon panels-height "['1:60']" 2>/dev/null
    WIN11_LAYOUT="['panel1:center:0:menu@cinnamon.org', 'panel1:center:1:grouped-window-list@cinnamon.org', 'panel1:right:0:systray@cinnamon.org', 'panel1:right:1:xapp-status@cinnamon.org', 'panel1:right:2:notifications@cinnamon.org', 'panel1:right:3:printers@cinnamon.org', 'panel1:right:4:removable-drives@cinnamon.org', 'panel1:right:5:keyboard@cinnamon.org', 'panel1:right:6:network@cinnamon.org', 'panel1:right:7:sound@cinnamon.org', 'panel1:right:8:power@cinnamon.org', 'panel1:right:9:calendar@cinnamon.org', 'panel1:right:10:cornerbar@cinnamon.org']"
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon enabled-applets "$WIN11_LAYOUT" 2>/dev/null
fi

print_step "Pabeigts!"
echo -e "${GREEN}Sistēma konfigurēta (v43 - Repo Rescue).${NC}"
echo "Repozitoriji: Pilnībā pārinstalēti un iztīrīti."
echo -e "${YELLOW}Lūdzu, PĀRSTARTĒJIET DATORU!${NC}"
exit 0
