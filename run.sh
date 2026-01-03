#!/bin/bash

# ==============================================================================
# Linux Mint & LMDE: Ultimate Setup (v15 - Force Install)
# Labojums: Noņemtas agresīvās tīkla pārbaudes, kas bloķēja instalāciju.
# ==============================================================================

# Krāsas
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- FUNKCIJAS ---
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
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

# OS Noteikšana
DISTRO_CODE=$UBUNTU_CODENAME
if [ -z "$DISTRO_CODE" ]; then DISTRO_CODE=$VERSION_CODENAME; fi # Fallback LMDE
if [ -z "$DISTRO_CODE" ]; then DISTRO_CODE="focal"; fi # Fallback if empty

log "Sākam piespiedu instalāciju uz: $NAME ($DISTRO_CODE)..."

# 2. SAGATAVOŠANĀS
log "Instalē atkarības..."
apt update
apt install -y curl wget gpg software-properties-common apt-transport-https flatpak unzip

# 3. REPOZITORIJU PIEVIENOŠANA (BEZ FILTRIEM)

# --- LibreWolf ---
log "Pievieno LibreWolf..."
rm -f /usr/share/keyrings/librewolf.gpg
curl -fsSL https://deb.librewolf.net/keyring.gpg | gpg --dearmor -o /usr/share/keyrings/librewolf.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/librewolf.gpg] https://deb.librewolf.net $DISTRO_CODE main" > /etc/apt/sources.list.d/librewolf.list

# --- Brave Browser ---
log "Pievieno Brave..."
rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# --- Mullvad Browser ---
log "Pievieno Mullvad..."
rm -f /usr/share/keyrings/mullvad-keyring.asc
curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list

# --- 1Password ---
log "Pievieno 1Password..."
rm -f /usr/share/keyrings/1password-archive-keyring.gpg
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" > /etc/apt/sources.list.d/1password.list
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol > /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

# 4. INSTALĀCIJA (APT)
log "Atjaunina sarakstus un instalē programmas..."
apt update

# Instalējam pa vienam, lai redzētu kļūdas
log "Instalē LibreWolf..."
apt install -y librewolf || error "Neizdevās instalēt LibreWolf"

log "Instalē Brave..."
apt install -y brave-browser || error "Neizdevās instalēt Brave"

log "Instalē Mullvad..."
apt install -y mullvad-browser || error "Neizdevās instalēt Mullvad"

log "Instalē 1Password..."
apt install -y 1password || error "Neizdevās instalēt 1Password"

# 5. FLATPAK INSTALĀCIJA
log "Konfigurē Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak config --set languages "lv;en"

# Funkcija drošai instalācijai
install_flatpak() {
    log "Instalē Flatpak: $1"
    flatpak install -y --noninteractive flathub "$1"
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

# 6. PYTHON (Pipx)
log "Instalē LibreTranslate (Pipx)..."
apt install -y pipx
sudo -u "$REAL_USER" pipx install libretranslate
sudo -u "$REAL_USER" pipx ensurepath

# 7. KONFIGURĀCIJAS (Speed & Clean)
log "Pielieto sistēmas uzlabojumus..."

# Swap/ZRAM
apt install -y zram-tools
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -le 16 ]; then
    echo "ALGO=zstd" > /etc/default/zram-tools
    echo "PERCENT=60" >> /etc/default/zram-tools
    sysctl -w vm.swappiness=100
else
    sysctl -w vm.swappiness=10
fi
service zram-tools restart

# DNS
apt install -y systemd-resolved
sed -i "s/#DNS=/DNS=9.9.9.9 149.112.112.112/" /etc/systemd/resolved.conf
systemctl restart systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# UI Tēmas
apt install -y papirus-icon-theme fonts-noto-color-emoji
# Mēģinām uzminēt vidi un pielietot tēmu (tikai Cinnamon/MATE)
if [ -f "/usr/bin/gsettings" ]; then
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.cinnamon.theme-name 'Mint-Y-Dark-Aqua' 2>/dev/null
fi

# 8. KOBOLDCPP
log "Pārbauda KoboldCPP..."
KOBOLD_DIR="$USER_HOME/koboldcpp"
if [ ! -f "$KOBOLD_DIR/koboldcpp_linux" ]; then
    mkdir -p "$KOBOLD_DIR"
    curl -fLo "$KOBOLD_DIR/koboldcpp_linux" https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
    chmod +x "$KOBOLD_DIR/koboldcpp_linux"
    
    # Modelis
    wget -O "$KOBOLD_DIR/llama-3-8b-instruct.gguf" https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf
    
    # Launcher
    echo "#!/bin/bash
    cd $KOBOLD_DIR
    ./koboldcpp_linux --model llama-3-8b-instruct.gguf --port 5001 --smartcontext" > "$KOBOLD_DIR/start_kobold.sh"
    chmod +x "$KOBOLD_DIR/start_kobold.sh"
    chown -R "$REAL_USER:$REAL_USER" "$KOBOLD_DIR"
fi

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}           INSTALĀCIJA PABEIGTA (v15)            ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo "Pārbaudi, vai izvēlnē ir parādījies Brave, LibreWolf un citas programmas."
exit 0
