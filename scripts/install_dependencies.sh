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

# Function to install build tools
install_build_tools() {
    log "${BLUE}Installing build tools...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt install -y git gcc g++ make cmake build-essential pkg-config
            ;;
        yum)
            yum groupinstall -y "Development Tools"
            yum install -y git gcc gcc-c++ make cmake pkg-config
            ;;
        pacman)
            pacman -S --noconfirm git gcc make cmake pkg-config base-devel
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} Build tools installed"
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

# Function to install .NET runtime
install_dotnet() {
    log "${BLUE}Installing .NET runtime...${NC}"
    
    # Check if already installed
    if command -v dotnet >/dev/null 2>&1; then
        log "${GREEN}✓${NC} .NET runtime already installed"
        return 0
    fi
    
    case "$PACKAGE_MANAGER" in
        apt)
            # Add Microsoft package repository
            wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
            dpkg -i packages-microsoft-prod.deb
            apt update
            apt install -y dotnet-runtime-6.0 aspnetcore-runtime-6.0
            rm -f packages-microsoft-prod.deb
            ;;
        yum)
            yum install -y dotnet-runtime-6.0 aspnetcore-runtime-6.0
            ;;
        pacman)
            pacman -S --noconfirm dotnet-runtime aspnet-runtime
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} .NET runtime installed"
    else
        log "${YELLOW}!${NC} .NET installation may have failed - will try manual install"
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

# Function to compile and install Direwolf
install_direwolf() {
    log "${BLUE}Compiling and installing Direwolf...${NC}"
    
    # Check if already installed
    if command -v direwolf >/dev/null 2>&1; then
        log "${GREEN}✓${NC} Direwolf already installed"
        return 0
    fi
    
    cd "$DOWNLOAD_DIR"
    
    # Clone or update repository
    if [ -d "direwolf" ]; then
        cd direwolf
        git pull
    else
        git clone https://github.com/wb2osz/direwolf.git
        cd direwolf
    fi
    
    # Build
    mkdir -p build
    cd build
    cmake ..
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        make install
        log "${GREEN}✓${NC} Direwolf compiled and installed"
        
        # Copy to bin directory for easier access
        cp src/direwolf "$BASE_DIR/bin/" 2>/dev/null || true
    else
        log "${RED}✗${NC} Failed to compile Direwolf"
        return 1
    fi
}

# Function to compile and install QSSTV
install_qsstv() {
    log "${BLUE}Compiling and installing QSSTV...${NC}"
    
    # Check if already installed
    if command -v qsstv >/dev/null 2>&1; then
        log "${GREEN}✓${NC} QSSTV already installed"
        return 0
    fi
    
    cd "$DOWNLOAD_DIR"
    
    # Clone or update repository
    if [ -d "QSSTV" ]; then
        cd QSSTV
        git pull
    else
        git clone https://github.com/ON4QZ/QSSTV.git
        cd QSSTV
    fi
    
    # Build
    qmake
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        make install
        log "${GREEN}✓${NC} QSSTV compiled and installed"
        
        # Copy to bin directory for easier access
        cp qsstv "$BASE_DIR/bin/" 2>/dev/null || true
    else
        log "${RED}✗${NC} Failed to compile QSSTV"
        return 1
    fi
}

# Function to create default configuration files
create_configs() {
    log "${BLUE}Creating default configuration files...${NC}"
    
    # Create direwolf configuration template
    cat > "$BASE_DIR/config/direwolf.conf.template" << 'EOF'
# Direwolf Configuration Template
# Copy to direwolf.conf and modify for your setup

ACHANNELS 1
ADEVICE plughw:0,0
CHANNEL 0
MYCALL N0CALL
MODEM 1200

# PTT via GPIO (uncomment and modify for your setup)
# PTT GPIO 17

# APRS Internet Gateway
# IGSERVER noam.aprs2.net
# IGLOGIN N0CALL 12345

# Digipeating
# DIGIPEAT 0 0 ^WIDE[3-7]-[1-7]$|^TEST$ ^WIDE[12]-[12]$ TRACE

# Logging
LOGDIR /tmp
LOGFILE direwolf.log
EOF

    log "${GREEN}✓${NC} Default configurations created"
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
    log "${BLUE}Next steps:${NC}"
    log "1. Configure audio interface for your radio"
    log "2. Edit $BASE_DIR/config/direwolf.conf for your callsign"
    log "3. Test direwolf with: direwolf -c $BASE_DIR/config/direwolf.conf"
    log "4. Launch hamster with: $BASE_DIR/hamster"
    log ""
    log "${GREEN}Installation complete!${NC}"
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
    echo -e "${BLUE}This will install:${NC}"
    echo "  - Build tools (git, gcc, make, cmake)"
    echo "  - Direwolf TNC software"
    echo "  - QSSTV slow-scan TV software"
    echo "  - .NET runtime"
    echo "  - Required libraries and dependencies"
    echo ""
    read -p "Continue with installation? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
    
    # Perform installation steps
    log "\n${BLUE}Starting installation...${NC}\n"
    
    update_repositories || exit 1
    install_build_tools || exit 1
    install_direwolf_deps || exit 1
    install_qsstv_deps || exit 1
    install_dotnet || log "${YELLOW}Warning: .NET installation may have issues${NC}"
    install_direwolf || log "${YELLOW}Warning: Direwolf installation failed${NC}"
    install_qsstv || log "${YELLOW}Warning: QSSTV installation failed${NC}"
    create_configs
    setup_service
    
    show_summary
}

# Run the installer
main "$@"