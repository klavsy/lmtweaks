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

# ZRAM TĪRĪŠANA (Obligāti pirms Zswap)
log "Noņem ZRAM rīkus (konfliktu novēršana)..."
apt purge -y zram-tools zram-config 2>/dev/null
rm -f /etc/sysctl.d/7-swappiness.conf
rm -f /etc/default/zram-tools
# Noņem vecos pielāgotos failus
rm -f /etc/sysctl.d/8-writing.conf
rm -f /etc/default/cpufrequtils

log "Noņem vecos repozitorijus..."
rm -f /etc/apt/sources.list.d/spotify.list
rm -f /etc/apt/sources.list.d/librewolf.list 
rm -f /etc/apt/sources.list.d/eparaksts.list
rm -f /etc/apt/sources.list.d/signal-desktop.sources

# Noņem dublikātus
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

PACKAGES="spotify-client signal-desktop brave-browser mullvad-browser 1password pipx flatpak curl wget unzip timeshift cpufrequtils picom picom-conf"
log "Instalē: $PACKAGES"
apt install -y $PACKAGES

# Noņem Compiz
apt purge -y compiz-core 2>/dev/null

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

install_flatpak "io.gitlab.librewolf-community"
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

# 6. PYTHON & AI
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

# 7. OPTIMIZĀCIJA (ZSWAP AUTOMATIZĀCIJA)
print_step "Zswap & Kodola Konfigurācija"

# Aprēķina RAM
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
log "Kopējais RAM: ${TOTAL_RAM_GB} GB"

# 1. SWAPPINESS
if [ "$TOTAL_RAM_GB" -le 8 ]; then
    SWAPPINESS_VAL=30
    GRUB_ADD="zswap.enabled=1 zswap.max_pool_percent=40 zswap.zpool=zsmalloc zswap.compressor=lz4"
else
    SWAPPINESS_VAL=60
    GRUB_ADD="zswap.enabled=1 zswap.zpool=zsmalloc zswap.compressor=lz4"
fi

echo "vm.swappiness=$SWAPPINESS_VAL" > /etc/sysctl.d/99-mint-swappiness.conf
sysctl -p /etc/sysctl.d/99-mint-swappiness.conf
log "Swappiness iestatīts uz $SWAPPINESS_VAL"

# 2. GRUB ATJAUNINĀŠANA
GRUB_FILE="/etc/default/grub"
# Mēs aizvietojam 'quiet splash' ar mūsu parametriem, lai nerastos dublikāti
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE"; then
    log "Konfigurē GRUB priekš Zswap..."
    # Izmanto drošu sed komandu, kas aizvieto visu rindu
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash '"$GRUB_ADD"'"/' "$GRUB_FILE"
    
    log "Ģenerē jaunu GRUB konfigurāciju..."
    update-grub
else
    warn "GRUB fails nav atrasts!"
fi

# 3. INITRAMFS (zsmalloc modulis)
MODULES_FILE="/etc/initramfs-tools/modules"
if ! grep -q "zsmalloc" "$MODULES_FILE"; then
    log "Pievieno zsmalloc moduli kodolam..."
    echo "zsmalloc" >> "$MODULES_FILE"
    
    log "Atjaunina initramfs (tas var aizņemt laiku)..."
    update-initramfs -uk all
else
    log "zsmalloc jau ir konfigurēts."
fi

# 8. DISK & CPU
print_step "CPU & Diska Optimizācija"

# CPU Performance
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils 2>/dev/null

# Disk Write Buffers
if [ "$TOTAL_RAM_GB" -gt 4 ]; then
    echo "vm.dirty_bytes=524288000" > /etc/sysctl.d/8-writing.conf
    echo "vm.dirty_background_bytes=262144000" >> /etc/sysctl.d/8-writing.conf
else
    echo "vm.dirty_bytes=314572800" > /etc/sysctl.d/8-writing.conf
    echo "vm.dirty_background_bytes=157286400" >> /etc/sysctl.d/8-writing.conf
fi
sysctl -p /etc/sysctl.d/8-writing.conf

# 9. PĀRLŪKU & UI IESTATĪJUMI
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
    log "Konfigurē Cinnamon (Windows 11 Style + No Effects)..."
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface enable-animations false 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon enable-tiling false 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.muffin unredirect-fullscreen-windows true 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon panels-height "['1:60']" 2>/dev/null
    
    WIN11_LAYOUT="['panel1:center:0:menu@cinnamon.org', 'panel1:center:1:grouped-window-list@cinnamon.org', 'panel1:right:0:systray@cinnamon.org', 'panel1:right:1:xapp-status@cinnamon.org', 'panel1:right:2:notifications@cinnamon.org', 'panel1:right:3:printers@cinnamon.org', 'panel1:right:4:removable-drives@cinnamon.org', 'panel1:right:5:keyboard@cinnamon.org', 'panel1:right:6:network@cinnamon.org', 'panel1:right:7:sound@cinnamon.org', 'panel1:right:8:power@cinnamon.org', 'panel1:right:9:calendar@cinnamon.org', 'panel1:right:10:cornerbar@cinnamon.org']"
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon enabled-applets "$WIN11_LAYOUT" 2>/dev/null

elif [ -f "/usr/bin/mate-session" ]; then
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface enable-animations false 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.Marco.general allow-tiling false 2>/dev/null
fi

print_step "Pabeigts!"
echo -e "${GREEN}Sistēma konfigurēta (v37 - Zswap Native).${NC}"
echo "Zswap: Konfigurēts (GRUB atjaunināts)."
echo "Initramfs: Atjaunināts (zsmalloc)."
echo "ZRAM: Noņemts."
echo -e "${YELLOW}Lai Zswap aktivizētos, OBLIGĀTI PĀRSTARTĒJIET DATORU!${NC}"
exit 0
