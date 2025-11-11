#!/bin/bash
#
# Hamster Installation Script
# Sets up the Ham Radio Manager on Linux gaming consoles
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display header
show_header() {
    clear
    echo -e "${BLUE}"
    echo "    ██╗  ██╗ █████╗ ███╗   ███╗███████╗████████╗███████╗██████╗ "
    echo "    ██║  ██║██╔══██╗████╗ ████║██╔════╝╚══██╔══╝██╔════╝██╔══██╗"
    echo "    ███████║███████║██╔████╔██║███████╗   ██║   █████╗  ██████╔╝"
    echo "    ██╔══██║██╔══██║██║╚██╔╝██║╚════██║   ██║   ██╔══╝  ██╔══██╗"
    echo "    ██║  ██║██║  ██║██║ ╚═╝ ██║███████║   ██║   ███████╗██║  ██║"
    echo "    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}                    Ham Radio Manager${NC}"
    echo -e "${BLUE}              Professional Amateur Radio Suite Installer${NC}"
    echo ""
}

# Function to check system requirements
check_system() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    # Check Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo -e "${RED}✗${NC} This installer is designed for Linux systems"
        echo -e "${BLUE}Detected OS type: $OSTYPE${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Linux system detected"
    
    # Check available space
    local available=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    
    echo -e "${BLUE}Available disk space: ${available_gb}GB${NC}"
    
    if [ $available_gb -lt 5 ]; then
        echo -e "${RED}✗${NC} Insufficient disk space (need at least 5GB)"
        return 1
    elif [ $available_gb -lt 10 ]; then
        echo -e "${YELLOW}!${NC} Limited disk space (recommended: 10GB+)"
        echo -e "${BLUE}Continue anyway? [y/N]${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        echo -e "${GREEN}✓${NC} Sufficient disk space available"
    fi
    
    # Check if git is available
    if command -v git >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Git is available"
    else
        echo -e "${YELLOW}!${NC} Git not found - will be installed with dependencies"
    fi
    
    return 0
}

# Function to create desktop entry
create_desktop_entry() {
    echo -e "${BLUE}Creating desktop entry...${NC}"
    
    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"
    
    cat > "$desktop_dir/hamster.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=Hamster Ham Radio Manager
Comment=Professional Amateur Radio Suite for ArkOS
Exec=$SCRIPT_DIR/hamster
Icon=$SCRIPT_DIR/docs/hamster-icon.png
Terminal=true
Type=Application
Categories=AudioVideo;HamRadio;Network;
Keywords=ham;radio;aprs;sstv;direwolf;qsstv;amateur;
EOF
    
    # Make it executable
    chmod +x "$desktop_dir/hamster.desktop"
    
    echo -e "${GREEN}✓${NC} Desktop entry created"
}

# Function to create symbolic links
create_symlinks() {
    echo -e "${BLUE}Creating system links...${NC}"
    
    # Create symlink in /usr/local/bin if possible
    if [ -w "/usr/local/bin" ] || sudo -n true 2>/dev/null; then
        if [ -w "/usr/local/bin" ]; then
            ln -sf "$SCRIPT_DIR/hamster" /usr/local/bin/hamster
        else
            sudo ln -sf "$SCRIPT_DIR/hamster" /usr/local/bin/hamster
        fi
        echo -e "${GREEN}✓${NC} System-wide hamster command available"
    else
        echo -e "${YELLOW}!${NC} Cannot create system-wide link (no sudo access)"
        
        # Create user bin directory and add to PATH
        mkdir -p "$HOME/.local/bin"
        ln -sf "$SCRIPT_DIR/hamster" "$HOME/.local/bin/hamster"
        
        # Add to PATH in bashrc if not already there
        if ! grep -q "$HOME/.local/bin" "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            echo -e "${BLUE}Added $HOME/.local/bin to PATH in .bashrc${NC}"
        fi
        
        echo -e "${GREEN}✓${NC} User-local hamster command available"
    fi
}

# Function to setup auto-start (optional)
setup_autostart() {
    echo ""
    echo -e "${BLUE}Auto-start Configuration${NC}"
    echo -e "${YELLOW}Would you like Hamster to auto-start at boot?${NC}"
    echo "This will make Hamster the primary interface on this ArkOS system."
    echo "Perfect for dedicated ham radio stations."
    echo ""
    read -p "Enable auto-start? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Setting up auto-start...${NC}"
        
        # Create autostart entry
        local autostart_dir="$HOME/.config/autostart"
        mkdir -p "$autostart_dir"
        
        cat > "$autostart_dir/hamster.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Hamster Ham Radio Manager
Exec=$SCRIPT_DIR/hamster
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Professional Amateur Radio Suite
EOF
        
        echo -e "${GREEN}✓${NC} Auto-start configured"
        echo -e "${BLUE}Hamster will start automatically on next boot${NC}"
        echo -e "${BLUE}This system is now configured as a dedicated ham radio station${NC}"
        
        # Offer to start now
        echo ""
        read -p "Start Hamster now? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            exec "$SCRIPT_DIR/hamster"
        fi
    else
        echo -e "${BLUE}Auto-start not configured${NC}"
        echo -e "${YELLOW}You can run Hamster manually with: hamster${NC}"
        echo -e "${BLUE}To set as default later, run the installer again${NC}"
    fi
}

# Function to show installation summary
show_summary() {
    echo ""
    echo -e "${GREEN}Ham Radio Station Installation Complete!${NC}"
    echo "========================================"
    echo ""
    echo -e "${BLUE}What was installed:${NC}"
    echo "  ✓ Hamster Ham Radio Manager (Professional Suite)"
    echo "  ✓ Integrated application launcher system"
    echo "  ✓ Comprehensive dependency management"
    echo "  ✓ APRS Chatty X launcher with direwolf"
    echo "  ✓ QSSTV slow-scan television launcher"
    echo "  ✓ Desktop and system integration"
    echo ""
    echo -e "${BLUE}Essential next steps:${NC}"
    echo "  1. Install ham radio applications: hamster → option 4"
    echo "  2. Configure your amateur radio callsign and settings"
    echo "  3. Set up audio interface for radio connection"
    echo "  4. Test applications with your radio equipment"
    echo ""
    echo -e "${BLUE}Quick start guide:${NC}"
    echo "  • Run 'hamster' to access the ham radio suite"
    echo "  • Use option 3 to check current dependencies"
    echo "  • Use option 4 to install missing applications"
    echo "  • Configure audio settings for your radio interface"
    echo ""
    echo -e "${YELLOW}Important files and directories:${NC}"
    echo "  • Main application: $SCRIPT_DIR/hamster"
    echo "  • Configuration: $SCRIPT_DIR/config/"
    echo "  • System logs: $SCRIPT_DIR/logs/"
    echo "  • Documentation: $SCRIPT_DIR/README.md"
    echo ""
    echo -e "${GREEN}Your ArkOS system is now ready for amateur radio operations!${NC}"
    echo ""
}

# Main installation function
main() {
    show_header
    
    echo -e "${BLUE}This installer will set up Hamster Ham Radio Manager${NC}"
    echo -e "${BLUE}for your ArkOS Linux system as a dedicated ham radio station.${NC}"
    echo ""
    echo -e "${YELLOW}Professional ham radio features to be installed:${NC}"
    echo "  • APRS Chatty X launcher with direwolf integration"
    echo "  • QSSTV slow-scan television launcher"
    echo "  • Comprehensive dependency management"
    echo "  • Audio interface configuration tools"
    echo "  • Amateur radio station settings"
    echo ""
    
    read -p "Continue with installation? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
    
    # Perform installation steps
    echo ""
    echo -e "${BLUE}Starting installation...${NC}"
    echo ""
    
    if ! check_system; then
        echo -e "${RED}System requirements not met${NC}"
        exit 1
    fi
    
    echo ""
    
    # Create necessary directories
    mkdir -p "$SCRIPT_DIR"/{logs,config,bin}
    
    # Set up desktop integration
    create_desktop_entry
    create_symlinks
    
    echo ""
    
    # Optional auto-start setup
    setup_autostart
    
    # Show completion summary
    show_summary
    
    echo -e "${GREEN}Installation successful!${NC}"
}

# Run the installer
main "$@"