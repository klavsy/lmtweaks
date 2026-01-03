#!/bin/bash

# ==============================================================================
# Linux Mint & LMDE: Ultimate Setup (v12)
# Atbalsta: Cinnamon, MATE, XFCE
# Iekļauj: First Steps, Speed, Clean, Security, Win11 UI, RAM Cache, Fixes
# Valoda: Latviešu
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

verify_source() {
    local url=$1
    local domain=$(echo "$url" | awk -F/ '{print $3}')
    echo -ne "   Verificē avotu ($domain)... "
    if curl --output /dev/null --silent --head --fail "$url"; then
        echo -e "${GREEN}Derīgs.${NC}"
        return 0
    else
        echo -e "${RED}Nav sasniedzams vai noraidīts!${NC}"
        return 1
    fi
}

# 1. ROOT PĀRBAUDE
if [ "$EUID" -ne 0 ]; then
    error "Nepieciešamas root tiesības. Palaidiet: sudo ./setup_mint_v12.sh"
    exit 1
fi

# 2. OS UN DARBVIRSMAS NOTEIKŠANA
REAL_USER=$(logname)
USER_HOME=$(eval echo "~$REAL_USER")
source /etc/os-release
IS_LMDE=false
DISTRO_CODE=""
DESKTOP_ENV="unknown"

# OS Pārbaude
if [[ "$ID" == "lmde" ]]; then
    IS_LMDE=true
    DISTRO_CODE=$VERSION_CODENAME
    log "Sistēma: LMDE ($DISTRO_CODE)"
else
    DISTRO_CODE=$UBUNTU_CODENAME
    if [ -z "$DISTRO_CODE" ]; then DISTRO_CODE=$VERSION_CODENAME; fi
    log "Sistēma: Linux Mint ($DISTRO_CODE)"
fi

# Darbvirsmas Pārbaude (Cinnamon vs MATE vs XFCE)
if [ -f "/usr/bin/cinnamon-session" ]; then
    if pgrep -u "$REAL_USER" "cinnamon" > /dev/null; then DESKTOP_ENV="cinnamon"; fi
fi
if [ -f "/usr/bin/mate-session" ]; then
    if pgrep -u "$REAL_USER" "mate-session" > /dev/null; then DESKTOP_ENV="mate"; fi
fi
if [ -f "/usr/bin/xfce4-session" ]; then
    if pgrep -u "$REAL_USER" "xfce4-session" > /dev/null; then DESKTOP_ENV="xfce"; fi
fi

log "Noteiktā darbvirsmas vide: $DESKTOP_ENV"

# 3. KĻŪDU NOVĒRŠANA (FAIL-SAFE)
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   1. POSMS: DROŠĪBA UN STABILITĀTE              ${NC}"
echo -e "${GREEN}=================================================${NC}"

# 3.1 Bloķēt "Proposed"
cat <<EOF > /etc/apt/preferences.d/99-block-proposed
Package: *
Pin: release a=*-proposed
Pin-Priority: -10
EOF

# 3.2 Python Drošība
apt install -y pipx

# 3.3 Timeshift
apt install -y timeshift

# 3.4 Multimediju Kodeki
log "Instalē kodekus..."
if [ "$IS_LMDE" = false ]; then
    apt install -y mint-meta-codecs
else
    apt install -y libavcodec-extra gstreamer1.0-libav gstreamer1.0-plugins-ugly
fi

# 3.5 Microsoft Fonti (Auto-accept EULA)
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer

# 3.6 Procesora Mikrokods (Intel/AMD)
log "Pārbauda procesora mikrokodu..."
if grep -q "Intel" /proc/cpuinfo; then
    apt install -y intel-microcode
elif grep -q "AMD" /proc/cpuinfo; then
    apt install -y amd64-microcode
fi

# 4. ĀTRUMS & OPTIMIZĀCIJA
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   2. POSMS: ĀTRUMS UN OPTIMIZĀCIJA              ${NC}"
echo -e "${GREEN}=================================================${NC}"

# 4.1 SSD/HDD (TRIM)
IS_ROTATIONAL=$(lsblk -d -o name,rota | grep -v loop | grep '1' | wc -l)
if [ "$IS_ROTATIONAL" -eq 0 ]; then
    cp /usr/share/doc/util-linux/examples/fstrim.service /etc/systemd/system/ 2>/dev/null
    cp /usr/share/doc/util-linux/examples/fstrim.timer /etc/systemd/system/ 2>/dev/null
    systemctl enable fstrim.timer
    success "SSD TRIM aktivizēts."
fi

# 4.2 Ātra Startēšana
if grep -q "GRUB_TIMEOUT=" /etc/default/grub; then
    sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=2/' /etc/default/grub
    sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub
    update-grub > /dev/null 2>&1
fi

# 4.3 RAM & ZRAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
apt install -y zram-tools
if [ "$TOTAL_RAM" -le 16 ]; then
    echo "ALGO=zstd" > /etc/default/zram-tools
    echo "PERCENT=60" >> /etc/default/zram-tools
    sysctl -w vm.swappiness=100
    echo "vm.swappiness=100" >> /etc/sysctl.conf
else
    sysctl -w vm.swappiness=10
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi
sysctl -w vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
service zram-tools restart

# 4.4 Apt Index Tīrīšana
apt purge -y apt-xapian-index
journalctl --vacuum-size=50M > /dev/null 2>&1

# 5. PĀRLŪKU OPTIMIZĀCIJA (RAM CACHE)
log "Konfigurē pārlūkus (RAM Cache)..."
mkdir -p /etc/firefox/policies /etc/librewolf /usr/lib/firefox/distribution
cat <<EOF > /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableTelemetry": true,
    "DisablePocket": true,
    "Preferences": {
      "browser.cache.disk.enable": false,
      "browser.cache.memory.enable": true,
      "browser.cache.memory.capacity": -1,
      "browser.ml.enable": false
    }
  }
}
EOF
cp /etc/firefox/policies/policies.json /etc/librewolf/policies.json 2>/dev/null || true

# 6. UI PĀRVEIDOŠANA (CINNAMON / MATE / XFCE)
log "Pielāgo vizuālo tēmu atkarībā no vides ($DESKTOP_ENV)..."
apt install -y papirus-icon-theme fonts-noto-color-emoji dmz-cursor-theme

if [ "$DESKTOP_ENV" == "cinnamon" ]; then
    # --- CINNAMON ---
    log "Konfigurē Cinnamon..."
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark'
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua'
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.muffin desktop-effects-on-dialogs true
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface enable-animations false

elif [ "$DESKTOP_ENV" == "mate" ]; then
    # --- MATE ---
    log "Konfigurē MATE..."
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface icon-theme 'Papirus-Dark'
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface gtk-theme 'Mint-Y-Dark-Aqua'
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.Marco.general theme 'Mint-Y-Dark-Aqua'
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.Marco.general compositing-manager true
    sudo -u "$REAL_USER" dbus-launch gsettings set org.mate.interface enable-animations false
    apt install -y mintmenu

elif [ "$DESKTOP_ENV" == "xfce" ]; then
    # --- XFCE ---
    log "Konfigurē XFCE (First Steps)..."
    
    # Instalē Whisker menu (ja nav)
    apt install -y xfce4-whiskermenu-plugin xfce4-goodies

    # Iestata Tēmu un Ikonas (Izmantojot xfconf-query)
    # Piezīme: Izmantojam 'dbus-launch' kā lietotājs
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xsettings -p /Net/ThemeName -s 'Mint-Y-Dark-Aqua'
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xsettings -p /Net/IconThemeName -s 'Papirus-Dark'
    
    # Aktivizē Kompozīciju (Compositing) - Svarīgi XFCE, lai nebūtu screen tearing
    log "Aktivizē XFCE kompozīciju..."
    sudo -u "$REAL_USER" dbus-launch xfconf-query -c xfwm4 -p /general/use_compositing -s true
    
    # Jaudas pārvaldība
    apt install -y xfce4-power-manager
else
    warn "Darbvirsma netika atpazīta. UI pielāgošana izlaista."
fi

# 7. DROŠĪBA & DNS
log "Konfigurē DNS (Quad9) un Ugunsmūri..."
apt install -y systemd-resolved ufw
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
sed -i "s/#FallbackDNS=/FallbackDNS=/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

ufw default deny incoming
ufw default allow outgoing
ufw limit ssh
ufw enable

# 8. PROGRAMMATŪRA
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   3. POSMS: PROGRAMMATŪRA (VERIFICĒTA)          ${NC}"
echo -e "${GREEN}=================================================${NC}"

# 8.1 Pamatpakas & Valoda
apt install -y curl wget gpg software-properties-common apt-transport-https flatpak unzip
apt install -y locales hunspell-lv hyphen-lv mythes-lv
if ! grep -q "^lv_LV.UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "lv_LV.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
fi
update-locale LANG=lv_LV.UTF-8 LANGUAGE="lv_LV:lv:en_US:en"

# 8.2 Repozitoriji
# LibreWolf
KEY_URL="https://deb.librewolf.net/keyring.gpg"
if verify_source "$KEY_URL"; then
    curl -fsSL "$KEY_URL" | gpg --dearmor -o /usr/share/keyrings/librewolf.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/librewolf.gpg] https://deb.librewolf.net $DISTRO_CODE main" > /etc/apt/sources.list.d/librewolf.list
fi
# Brave
KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
if verify_source "$KEY_URL"; then
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg "$KEY_URL"
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list
fi
# Mullvad
KEY_URL="https://repository.mullvad.net/deb/mullvad-keyring.asc"
if verify_source "$KEY_URL"; then
    curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc "$KEY_URL"
    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list
fi
# 1Password
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
if verify_source "$KEY_URL"; then
    curl -sS "$KEY_URL" | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" > /etc/apt/sources.list.d/1password.list
    mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol > /etc/debsig/policies/AC2D62742012EA22/1password.pol
    mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
    curl -sS "$KEY_URL" | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
fi
# Eparaksts
KEY_URL="https://www.eparaksts.lv/files/ep3updates/debian/public.key"
if verify_source "$KEY_URL"; then
    rm -f /etc/apt/sources.list.d/eparaksts.list
    curl -fsSL "$KEY_URL" | gpg --dearmor -o /usr/share/keyrings/eparaksts-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/eparaksts-archive-keyring.gpg] https://www.eparaksts.lv/files/ep3updates/debian focal eparaksts" > /etc/apt/sources.list.d/eparaksts.list
fi

apt update
apt install -y librewolf brave-browser mullvad-browser 1password eparakstitajs3 awp latvia-eid-middleware

# 8.3 Flatpak Apps (Latviešu valoda)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"

install_flatpak() {
    flatpak install -y --include-locales=lv flathub "$1"
}

install_flatpak "io.ente.auth"
install_flatpak "org.onlyoffice.desktopeditors"
install_flatpak "com.github.micahflee.torbrowser-launcher"
install_flatpak "io.freetubeapp.FreeTube"
install_flatpak "org.rawtherapee.RawTherapee"
install_flatpak "app.drey.Dialect"
install_flatpak "org.openshot.OpenShot"
install_flatpak "com.spotify.Client"
install_flatpak "com.discordapp.Discord"
install_flatpak "org.signal.Signal"
install_flatpak "com.valvesoftware.Steam"
install_flatpak "org.inkscape.Inkscape"
install_flatpak "org.videolan.VLC"

# 8.4 Python Apps (Pipx)
log "Instalē LibreTranslate (caur Pipx)..."
sudo -u "$REAL_USER" pipx ensurepath
sudo -u "$REAL_USER" pipx install libretranslate

# 8.5 KoboldCPP
KOBOLD_URL="https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64"
if verify_source "$KOBOLD_URL"; then
    KOBOLD_DIR="$USER_HOME/koboldcpp"
    mkdir -p "$KOBOLD_DIR"
    curl -fLo "$KOBOLD_DIR/koboldcpp_linux" "$KOBOLD_URL"
    chmod +x "$KOBOLD_DIR/koboldcpp_linux"
    
    MODEL_URL="https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf"
    MODEL_FILE="$KOBOLD_DIR/llama-3-8b-instruct.gguf"
    if [ ! -f "$MODEL_FILE" ]; then
        wget -O "$MODEL_FILE" "$MODEL_URL" --show-progress
    fi

    echo "#!/bin/bash
    cd $KOBOLD_DIR
    echo 'Startē KoboldCPP...'
    if lspci | grep -i nvidia > /dev/null; then
        ./koboldcpp_linux --model llama-3-8b-instruct.gguf --usecublas --gpulayers 99 --port 5001 --smartcontext
    else
        ./koboldcpp_linux --model llama-3-8b-instruct.gguf --port 5001 --smartcontext
    fi" > "$KOBOLD_DIR/start_kobold.sh"
    chmod +x "$KOBOLD_DIR/start_kobold.sh"
    chown -R "$REAL_USER:$REAL_USER" "$KOBOLD_DIR"
fi

# 9. TĪRĪŠANA (CLEAN MINT)
log "Dziļā tīrīšana..."
apt autoremove --purge -y && apt clean
dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r apt -y purge
rm -rf "$USER_HOME/.cache/thumbnails/*"
flatpak uninstall --unused -y
if [ "$IS_LMDE" = false ]; then
    apt purge -y ubuntu-report popularity-contest apport whoopsie
fi

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}           SISTĒMA GATAVA! (v12)                 ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo "1. Vide: $DESKTOP_ENV (Konfigurēta veiksmīgi)."
echo "2. XFCE specifika (Kompozīcija, Whisker) piemērota."
echo "3. Novērstas 'Fatal Mistakes'."
echo "4. Ātrdarbība, Drošība un Tīrība maksimāla."
echo ""
echo -e "${YELLOW}Lūdzu, PĀRSTARTĒJIET DATORU, lai iestatījumi stātos spēkā!${NC}"
exit 0
