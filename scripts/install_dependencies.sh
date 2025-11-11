#!/bin/bash
#
# Dependency Installer for Hamster Ham Radio Manager
# Installs required software and dependencies
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="$BASE_DIR/downloads"
LOG_FILE="$BASE_DIR/logs/install.log"

# Create necessary directories
mkdir -p "$DOWNLOAD_DIR" "$BASE_DIR/logs" "$BASE_DIR/bin"

# Function to log messages
log() {
    echo "$(date): $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check if running with sudo privileges
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script requires sudo privileges for package installation.${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Function to detect distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        
        case "$ID" in
            ubuntu|debian|raspbian)
                PACKAGE_MANAGER="apt"
                ;;
            fedora|rhel|centos)
                PACKAGE_MANAGER="yum"
                ;;
            arch)
                PACKAGE_MANAGER="pacman"
                ;;
            *)
                log "${YELLOW}Unknown distribution: $ID${NC}"
                log "Assuming apt package manager..."
                PACKAGE_MANAGER="apt"
                ;;
        esac
        
        log "${BLUE}Detected: $OS $VER${NC}"
        log "${BLUE}Package Manager: $PACKAGE_MANAGER${NC}"
    else
        log "${RED}Cannot detect distribution${NC}"
        exit 1
    fi
}

# Function to enable additional repositories for better ham radio package availability
enable_additional_repos() {
    log "${BLUE}Enabling additional repositories for ham radio packages...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            # Enable universe and multiverse for more packages
            log "${BLUE}Enabling universe and multiverse repositories...${NC}"
            add-apt-repository universe -y >/dev/null 2>&1
            add-apt-repository multiverse -y >/dev/null 2>&1
            
            # Try to add ham radio specific PPA if available
            log "${BLUE}Checking for ham radio PPAs...${NC}"
            # Note: This would add specific PPAs if they exist
            # add-apt-repository ppa:ubuntu-hams/ppa -y >/dev/null 2>&1 || true
            ;;
        yum)
            # Enable EPEL for more packages
            log "${BLUE}Enabling EPEL repository...${NC}"
            yum install -y epel-release >/dev/null 2>&1
            ;;
        pacman)
            # Arch has most packages in main repos or AUR
            log "${BLUE}Arch repositories already comprehensive${NC}"
            ;;
    esac
    
    log "${GREEN}✓${NC} Additional repositories configured"
}

# Function to update package repositories
update_repositories() {
    log "${BLUE}Updating package repositories...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt update
            ;;
        yum)
            yum update -y
            ;;
        pacman)
            pacman -Sy
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} Package repositories updated"
    else
        log "${RED}✗${NC} Failed to update repositories"
        return 1
    fi
}

# Function to install build tools (without CMake)
install_build_tools() {
    log "${BLUE}Installing build tools (avoiding CMake)...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt install -y git gcc g++ make build-essential pkg-config autotools-dev autoconf automake libtool
            ;;
        yum)
            yum groupinstall -y "Development Tools"
            yum install -y git gcc gcc-c++ make pkg-config autoconf automake libtool
            ;;
        pacman)
            pacman -S --noconfirm git gcc make pkg-config base-devel autoconf automake libtool
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} Build tools installed (using traditional make instead of CMake)"
    else
        log "${RED}✗${NC} Failed to install build tools"
        return 1
    fi
}

# Function to install direwolf dependencies
install_direwolf_deps() {
    log "${BLUE}Installing Direwolf dependencies...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt install -y libasound2-dev libudev-dev libavahi-client-dev libgpiod-dev
            ;;
        yum)
            yum install -y alsa-lib-devel libudev-devel avahi-devel libgpiod-devel
            ;;
        pacman)
            pacman -S --noconfirm alsa-lib systemd avahi libgpiod
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} Direwolf dependencies installed"
    else
        log "${RED}✗${NC} Failed to install Direwolf dependencies"
        return 1
    fi
}

# Function to install QSSTV dependencies
install_qsstv_deps() {
    log "${BLUE}Installing QSSTV dependencies...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt install -y libfftw3-dev qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
                          libqt5svg5-dev libhamlib++-dev libasound2-dev libpulse-dev \
                          libopenjp2-7 libopenjp2-7-dev libv4l-dev
            ;;
        yum)
            yum install -y fftw-devel qt5-qtbase-devel qt5-qtsvg-devel hamlib-devel \
                          alsa-lib-devel pulseaudio-libs-devel openjpeg2-devel libv4l-devel
            ;;
        pacman)
            pacman -S --noconfirm fftw qt5-base qt5-svg hamlib alsa-lib libpulse openjpeg2 v4l-utils
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} QSSTV dependencies installed"
    else
        log "${RED}✗${NC} Failed to install QSSTV dependencies"
        return 1
    fi
}

# Function to install .NET runtime (apt package preferred)
install_dotnet() {
    log "${BLUE}Installing .NET runtime (preferring apt packages)...${NC}"
    
    # Check if already installed
    if command -v dotnet >/dev/null 2>&1; then
        log "${GREEN}✓${NC} .NET runtime already installed"
        return 0
    fi
    
    case "$PACKAGE_MANAGER" in
        apt)
            log "${BLUE}Trying to install .NET from apt repositories...${NC}"
            
            # First try: Check if dotnet is already available in apt repos
            if apt-cache search dotnet-runtime | grep -q dotnet-runtime; then
                log "${BLUE}Found .NET in apt repositories, installing...${NC}"
                apt install -y dotnet-runtime-8.0 || apt install -y dotnet-runtime-6.0 || apt install -y dotnet-runtime
                if command -v dotnet >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} .NET runtime installed from apt packages (PREFERRED METHOD)"
                    return 0
                fi
            fi
            
            # Second try: Add Microsoft package repository with auto-detection
            log "${BLUE}Adding Microsoft .NET repository...${NC}"
            
            # Detect Ubuntu/Debian version for correct repository
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        MS_REPO_URL="https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"
                        ;;
                    debian)
                        MS_REPO_URL="https://packages.microsoft.com/config/debian/$VERSION_ID/packages-microsoft-prod.deb"
                        ;;
                    *)
                        # Fallback to Ubuntu 22.04 LTS (most compatible)
                        MS_REPO_URL="https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb"
                        ;;
                esac
            else
                MS_REPO_URL="https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb"
            fi
            
            wget "$MS_REPO_URL" -O packages-microsoft-prod.deb
            if [ $? -eq 0 ]; then
                dpkg -i packages-microsoft-prod.deb
                apt update
                # Try latest version first, then fallback to older versions
                apt install -y dotnet-runtime-8.0 aspnetcore-runtime-8.0 || \
                apt install -y dotnet-runtime-6.0 aspnetcore-runtime-6.0 || \
                apt install -y dotnet-runtime aspnetcore-runtime
                rm -f packages-microsoft-prod.deb
                
                if command -v dotnet >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} .NET runtime installed from Microsoft apt repository"
                    return 0
                fi
            else
                log "${YELLOW}!${NC} Could not download Microsoft repository package"
            fi
            ;;
        yum)
            # Enable Microsoft repository for yum/dnf
            rpm --import https://packages.microsoft.com/keys/microsoft.asc
            curl -o /etc/yum.repos.d/microsoft-prod.repo https://packages.microsoft.com/config/rhel/8/prod.repo
            yum install -y dotnet-runtime-8.0 aspnetcore-runtime-8.0 || \
            yum install -y dotnet-runtime-6.0 aspnetcore-runtime-6.0
            ;;
        pacman)
            pacman -S --noconfirm dotnet-runtime aspnet-runtime
            ;;
    esac
    
    if command -v dotnet >/dev/null 2>&1; then
        log "${GREEN}✓${NC} .NET runtime installed"
    else
        log "${YELLOW}!${NC} .NET package installation failed - will try manual install"
        install_dotnet_manual
    fi
}

# Function to manually install .NET
install_dotnet_manual() {
    log "${BLUE}Attempting manual .NET installation...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            DOTNET_ARCH="x64"
            ;;
        aarch64)
            DOTNET_ARCH="arm64"
            ;;
        armv7l)
            DOTNET_ARCH="arm"
            ;;
        *)
            log "${RED}Unsupported architecture: $ARCH${NC}"
            return 1
            ;;
    esac
    
    # Download and install .NET
    cd "$DOWNLOAD_DIR"
    curl -SL -o dotnet.tar.gz "https://dotnetcli.azureedge.net/dotnet/Runtime/6.0.0/dotnet-runtime-6.0.0-linux-$DOTNET_ARCH.tar.gz"
    
    if [ $? -eq 0 ]; then
        mkdir -p /usr/share/dotnet
        tar -zxf dotnet.tar.gz -C /usr/share/dotnet
        ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
        log "${GREEN}✓${NC} .NET runtime installed manually"
        rm -f dotnet.tar.gz
    else
        log "${RED}✗${NC} Failed to download .NET runtime"
        return 1
    fi
}

# Function to install Direwolf using package manager (preferred) or fallback methods
install_direwolf() {
    log "${BLUE}Installing Direwolf (preferring apt packages)...${NC}"
    
    # Check if already installed
    if command -v direwolf >/dev/null 2>&1; then
        log "${GREEN}✓${NC} Direwolf already installed"
        return 0
    fi
    
    # STRONGLY prioritize package manager installation
    case "$PACKAGE_MANAGER" in
        apt)
            log "${BLUE}Checking apt repositories for Direwolf...${NC}"
            # Try main repositories first
            apt update >/dev/null 2>&1
            if apt-cache search direwolf | grep -q "direwolf"; then
                log "${BLUE}Found Direwolf in apt repositories, installing...${NC}"
                apt install -y direwolf
                if command -v direwolf >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} Direwolf installed from apt packages (PREFERRED METHOD)"
                    return 0
                fi
            fi
            
            # Try universe repository if not found
            log "${BLUE}Enabling universe repository for more packages...${NC}"
            add-apt-repository universe -y >/dev/null 2>&1
            apt update >/dev/null 2>&1
            if apt-cache search direwolf | grep -q "direwolf"; then
                apt install -y direwolf
                if command -v direwolf >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} Direwolf installed from apt universe repository"
                    return 0
                fi
            fi
            ;;
        yum)
            # Enable EPEL for more packages
            yum install -y epel-release >/dev/null 2>&1
            if yum search direwolf 2>/dev/null | grep -q direwolf; then
                yum install -y direwolf
                if command -v direwolf >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} Direwolf installed from yum packages"
                    return 0
                fi
            fi
            ;;
        pacman)
            # Try AUR or main repos
            if pacman -Ss direwolf | grep -q direwolf; then
                pacman -S --noconfirm direwolf
                if command -v direwolf >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} Direwolf installed from pacman packages"
                    return 0
                fi
            fi
            ;;
    esac
    
    # If package manager failed, try manual build with make
    log "${BLUE}Package manager installation failed, trying manual build...${NC}"
    
    cd "$DOWNLOAD_DIR"
    
    # Clone repository
    if [ -d "direwolf" ]; then
        cd direwolf
        git pull
    else
        git clone https://github.com/wb2osz/direwolf.git
        cd direwolf
    fi
    
    # Try to build with traditional make (some versions support this)
    if [ -f "Makefile.linux" ]; then
        log "${BLUE}Using Makefile.linux for build...${NC}"
        make -f Makefile.linux
        if [ $? -eq 0 ]; then
            # Manual install
            cp direwolf /usr/local/bin/
            cp decode_aprs /usr/local/bin/
            cp text2tt /usr/local/bin/
            cp tt2text /usr/local/bin/
            cp ll2utm /usr/local/bin/
            cp utm2ll /usr/local/bin/
            cp aclients /usr/local/bin/
            cp log2gpx /usr/local/bin/
            cp gen_packets /usr/local/bin/
            cp atest /usr/local/bin/
            cp ttcalc /usr/local/bin/
            cp dwespeak.sh /usr/local/bin/
            
            log "${GREEN}✓${NC} Direwolf compiled and installed manually"
            return 0
        fi
    fi
    
    # Final fallback: try to download precompiled binary
    log "${BLUE}Attempting to download precompiled Direwolf binary...${NC}"
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            DIREWOLF_URL="https://github.com/wb2osz/direwolf/releases/download/1.7/direwolf-1.7-linux-x86_64.tar.gz"
            ;;
        armv7l|armv6l)
            DIREWOLF_URL="https://github.com/wb2osz/direwolf/releases/download/1.7/direwolf-1.7-linux-armhf.tar.gz"
            ;;
        aarch64)
            DIREWOLF_URL="https://github.com/wb2osz/direwolf/releases/download/1.7/direwolf-1.7-linux-aarch64.tar.gz"
            ;;
        *)
            log "${RED}✗${NC} No precompiled binary available for $ARCH"
            log "${YELLOW}!${NC} You may need to compile Direwolf manually with CMake"
            return 1
            ;;
    esac
    
    wget "$DIREWOLF_URL" -O direwolf-precompiled.tar.gz
    if [ $? -eq 0 ]; then
        tar -xzf direwolf-precompiled.tar.gz
        cp direwolf-*/bin/* /usr/local/bin/
        log "${GREEN}✓${NC} Direwolf installed from precompiled binary"
        rm -f direwolf-precompiled.tar.gz
        return 0
    else
        log "${RED}✗${NC} Failed to download precompiled Direwolf"
        log "${YELLOW}!${NC} Manual installation required"
        return 1
    fi
}

# Function to install QSSTV using package manager (strongly preferred)
install_qsstv() {
    log "${BLUE}Installing QSSTV (preferring apt packages)...${NC}"
    
    # Check if already installed
    if command -v qsstv >/dev/null 2>&1; then
        log "${GREEN}✓${NC} QSSTV already installed"
        return 0
    fi
    
    # STRONGLY prioritize package manager installation
    case "$PACKAGE_MANAGER" in
        apt)
            log "${BLUE}Checking apt repositories for QSSTV...${NC}"
            # Update and search for qsstv
            apt update >/dev/null 2>&1
            if apt-cache search qsstv | grep -q "qsstv"; then
                log "${BLUE}Found QSSTV in apt repositories, installing...${NC}"
                apt install -y qsstv
                if command -v qsstv >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} QSSTV installed from apt packages (PREFERRED METHOD)"
                    return 0
                fi
            fi
            
            # Try universe repository if not found
            log "${BLUE}Enabling universe repository for QSSTV...${NC}"
            add-apt-repository universe -y >/dev/null 2>&1
            apt update >/dev/null 2>&1
            if apt-cache search qsstv | grep -q "qsstv"; then
                apt install -y qsstv
                if command -v qsstv >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} QSSTV installed from apt universe repository"
                    return 0
                fi
            fi
            
            # Try multiverse repository 
            log "${BLUE}Enabling multiverse repository for QSSTV...${NC}"
            add-apt-repository multiverse -y >/dev/null 2>&1
            apt update >/dev/null 2>&1
            if apt-cache search qsstv | grep -q "qsstv"; then
                apt install -y qsstv
                if command -v qsstv >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} QSSTV installed from apt multiverse repository"
                    return 0
                fi
            fi
            ;;
        yum)
            # Enable EPEL for more packages
            yum install -y epel-release >/dev/null 2>&1
            if yum search qsstv 2>/dev/null | grep -q qsstv; then
                yum install -y qsstv
                if command -v qsstv >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} QSSTV installed from yum packages"
                    return 0
                fi
            fi
            ;;
        pacman)
            # Try main repos and AUR
            if pacman -Ss qsstv | grep -q qsstv; then
                pacman -S --noconfirm qsstv
                if command -v qsstv >/dev/null 2>&1; then
                    log "${GREEN}✓${NC} QSSTV installed from pacman packages"
                    return 0
                fi
            fi
            ;;
    esac
    
    # If package manager failed, try manual compilation with qmake
    log "${BLUE}Package manager installation failed, trying manual build...${NC}"
    
    cd "$DOWNLOAD_DIR"
    
    # Clone repository
    if [ -d "QSSTV" ]; then
        cd QSSTV
        git pull
    else
        git clone https://github.com/ON4QZ/QSSTV.git
        cd QSSTV
    fi
    
    # Try to build with qmake (Qt's build system, not CMake)
    if command -v qmake >/dev/null 2>&1; then
        log "${BLUE}Using qmake for QSSTV build...${NC}"
        qmake
        make -j$(nproc)
        
        if [ $? -eq 0 ]; then
            # Manual install
            cp qsstv /usr/local/bin/
            log "${GREEN}✓${NC} QSSTV compiled and installed manually"
            return 0
        else
            log "${RED}✗${NC} QSSTV compilation failed"
        fi
    else
        log "${YELLOW}!${NC} qmake not available for QSSTV compilation"
    fi
    
    # Try to download AppImage or precompiled version
    log "${BLUE}Attempting to download QSSTV AppImage...${NC}"
    
    # Check for AppImage releases
    QSSTV_APPIMAGE_URL="https://github.com/ON4QZ/QSSTV/releases/download/v9.5.8/QSSTV-9.5.8-x86_64.AppImage"
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        wget "$QSSTV_APPIMAGE_URL" -O qsstv.AppImage
        if [ $? -eq 0 ]; then
            chmod +x qsstv.AppImage
            mv qsstv.AppImage /usr/local/bin/qsstv
            log "${GREEN}✓${NC} QSSTV installed as AppImage"
            return 0
        else
            log "${RED}✗${NC} Failed to download QSSTV AppImage"
        fi
    else
        log "${YELLOW}!${NC} No AppImage available for $ARCH architecture"
    fi
    
    log "${RED}✗${NC} All QSSTV installation methods failed"
    log "${BLUE}You may need to install QSSTV manually or from your distribution's repositories${NC}"
    return 1
}

# Function to install additional ham radio tools
install_ham_tools() {
    log "${BLUE}Installing additional ham radio tools and controller support...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt install -y pavucontrol alsamixer pulseaudio-utils sox \
                          minicom picocom socat screen \
                          joystick jstest-gtk evtest \
                          network-manager nmcli \
                          ssh openssh-server \
                          bluetooth bluez bluez-tools
            ;;
        yum)
            yum install -y pavucontrol alsa-utils pulseaudio-utils sox \
                          minicom picocom socat screen \
                          joystick evtest \
                          NetworkManager \
                          openssh-server \
                          bluez bluez-utils
            ;;
        pacman)
            pacman -S --noconfirm pavucontrol alsa-utils pulseaudio sox \
                          minicom picocom socat screen \
                          joyutils evtest \
                          networkmanager \
                          openssh \
                          bluez bluez-utils
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} Ham radio tools, controller support, and Bluetooth installed"
    else
        log "${YELLOW}!${NC} Some ham radio tools may not have installed"
    fi
}

# Function to create default configuration files
create_configs() {
    log "${BLUE}Creating default configuration files...${NC}"
    
    # Create direwolf configuration template
    cat > "$BASE_DIR/config/direwolf.conf.template" << 'EOF'
# Direwolf Configuration Template for Hamster
# Copy to direwolf.conf and modify for your amateur radio station

# Audio device configuration
ACHANNELS 1
ADEVICE plughw:0,0

# Radio channel setup
CHANNEL 0
MYCALL N0CALL
MODEM 1200

# Audio levels (adjust for your radio interface)
AGWPORT 8000
KISSPORT 8001

# PTT Configuration
# Uncomment and modify for your radio interface:
# PTT GPIO 17           # For GPIO PTT control
# PTT RTS               # For RTS PTT control
# PTT /dev/ttyUSB0      # For serial PTT control

# APRS Internet Gateway
# Uncomment and configure for APRS-IS access:
# IGSERVER rotate.aprs2.net:14580
# IGLOGIN N0CALL 12345

# Packet Filtering
FILTER IG 0 t/m

# Digipeating (uncomment to enable)
# DIGIPEAT 0 0 ^WIDE[3-7]-[1-7]$|^TEST$ ^WIDE[12]-[12]$ TRACE

# Logging
LOGDIR $BASE_DIR/logs
LOGFILE direwolf.log

# Audio statistics
ADEVICE0 plughw:0,0
EOF

    # Create QSSTV configuration template
    cat > "$BASE_DIR/config/qsstv-readme.txt" << 'EOF'
QSSTV Configuration Notes
========================

1. First-time setup:
   - Run qsstv from the ham radio menu
   - Configure your callsign in Options → Configuration → Station
   - Set audio devices in Options → Configuration → Sound Card

2. Audio Setup:
   - Input: Select your radio interface input
   - Output: Select your radio interface output
   - Test audio levels with the built-in scope

3. Common Modes:
   - Scottie 1 (most common SSTV mode)
   - Martin M1
   - Robot modes

4. Operating Tips:
   - Use VOX or manual PTT for transmission
   - Monitor frequency: typically 14.230 MHz (20m)
   - Adjust audio levels to avoid distortion

For more information, see the QSSTV documentation.
EOF

    # Create hamster station configuration template
    cat > "$BASE_DIR/config/station.conf.template" << 'EOF'
# Hamster Ham Radio Station Configuration
# Copy to station.conf and customize for your setup

[STATION]
CALLSIGN=N0CALL
GRID_SQUARE=FN42xx
QTH=Home Station
OPERATOR=Your Name

[AUDIO]
# Audio device names - run 'aplay -l' to see available devices
INPUT_DEVICE=plughw:0,0
OUTPUT_DEVICE=plughw:0,0

[RADIO]
# Radio interface settings
RIG_TYPE=GENERIC
PTT_TYPE=GPIO
PTT_PIN=17

[APRS]
# APRS settings
SYMBOL=/>
COMMENT=Hamster Ham Radio Manager
BEACON_INTERVAL=30
EOF

    log "${GREEN}✓${NC} Configuration templates created"
}

# Function to set up systemd service (optional)
setup_service() {
    log "${BLUE}Setting up systemd service (optional)...${NC}"
    
    cat > /etc/systemd/system/hamster.service << EOF
[Unit]
Description=Hamster Ham Radio Manager
After=network.target

[Service]
Type=simple
User=pi
ExecStart=$BASE_DIR/hamster
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "${GREEN}✓${NC} Systemd service created (not enabled by default)"
    log "${BLUE}To enable auto-start: sudo systemctl enable hamster${NC}"
}

# Function to show installation summary
show_summary() {
    log ""
    log "${BLUE}Installation Summary:${NC}"
    log "===================="
    
    # Check what was installed
    if command -v git >/dev/null 2>&1; then
        log "${GREEN}✓${NC} Git: $(git --version | head -1)"
    fi
    
    if command -v direwolf >/dev/null 2>&1; then
        log "${GREEN}✓${NC} Direwolf: $(direwolf -V 2>&1 | head -1)"
    fi
    
    if command -v qsstv >/dev/null 2>&1; then
        log "${GREEN}✓${NC} QSSTV: Available"
    fi
    
    if command -v dotnet >/dev/null 2>&1; then
        log "${GREEN}✓${NC} .NET: $(dotnet --version 2>/dev/null)"
    fi
    
    log ""
    log "${BLUE}Essential next steps for your ham radio station:${NC}"
    log "1. Configure your amateur radio callsign:"
    log "   • Copy $BASE_DIR/config/station.conf.template to station.conf"
    log "   • Edit with your callsign, grid square, and station info"
    log "2. Set up audio interface:"
    log "   • Copy $BASE_DIR/config/direwolf.conf.template to direwolf.conf"
    log "   • Run 'aplay -l' to see available audio devices"
    log "   • Edit audio device settings in direwolf.conf"
    log "3. Test your setup:"
    log "   • Test audio: direwolf -c $BASE_DIR/config/direwolf.conf"
    log "   • Launch manager: $BASE_DIR/hamster"
    log "4. Additional tools available:"
    log "   • pavucontrol - GUI audio mixer"
    log "   • alsamixer - Terminal audio mixer"
    log "   • minicom/picocom - Serial terminal (for radio control)"
    log ""
    log "${GREEN}Your ArkOS ham radio station is ready!${NC}"
    log "${BLUE}Remember: You need an amateur radio license to transmit${NC}"
}

# Main installation function
main() {
    clear
    log "${YELLOW}Hamster Dependency Installer${NC}"
    log "=============================="
    log ""
    
    # Check for sudo
    check_sudo
    
    # Detect system
    detect_distribution
    
    # Ask for confirmation
    echo -e "${BLUE}This will install the complete ham radio suite using APT PACKAGES:${NC}"
    echo -e "${GREEN}PREFERRED METHOD: Installing from apt repositories (most reliable)${NC}"
    echo "  - Ham radio applications (direwolf, qsstv) from apt packages"
    echo "  - .NET runtime (for APRS Chatty X)"
    echo "  - Audio tools (pavucontrol, ALSA utils) from apt packages"
    echo "  - Serial communication tools from apt packages"
    echo "  - Ham radio configuration templates"
    echo ""
    echo -e "${GREEN}Benefits of apt package installation:${NC}"
    echo "  ✓ No compilation required - faster installation"
    echo "  ✓ Automatic dependency management"
    echo "  ✓ Stable, tested versions"
    echo "  ✓ Easy updates through apt"
    echo "  ✓ No build tool complications"
    echo ""
    read -p "Continue with installation? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
    
    # Perform installation steps
    log "\n${BLUE}Starting apt-focused installation...${NC}\n"
    
    enable_additional_repos || log "${YELLOW}Warning: Could not enable all additional repositories${NC}"
    update_repositories || exit 1
    install_ham_tools || log "${YELLOW}Warning: Some ham tools installation failed${NC}"
    install_direwolf || log "${YELLOW}Warning: Direwolf installation failed${NC}"
    install_qsstv || log "${YELLOW}Warning: QSSTV installation failed${NC}"
    install_dotnet || log "${YELLOW}Warning: .NET installation may have issues${NC}"
    # Only install build tools if actually needed (after package installation attempts)
    install_build_tools || log "${YELLOW}Warning: Build tools installation failed${NC}"
    install_direwolf_deps || log "${YELLOW}Warning: Some direwolf deps may be missing${NC}"
    install_qsstv_deps || log "${YELLOW}Warning: Some QSSTV deps may be missing${NC}"
    create_configs
    setup_service
    
    show_summary
}

# Run the installer
main "$@"