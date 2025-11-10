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
    echo -e "${BLUE}              Installation for Ark OS Gaming Console${NC}"
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
Comment=Ham Radio Manager for Ark OS
Exec=$SCRIPT_DIR/hamster
Icon=$SCRIPT_DIR/docs/hamster-icon.png
Terminal=true
Type=Application
Categories=AudioVideo;HamRadio;
Keywords=ham;radio;aprs;sstv;direwolf;qsstv;
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
    echo "This will replace the default gaming interface with the Hamster menu."
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
EOF
        
        echo -e "${GREEN}✓${NC} Auto-start configured"
        echo -e "${BLUE}Hamster will start automatically on next boot${NC}"
        
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
    fi
}

# Function to show installation summary
show_summary() {
    echo ""
    echo -e "${GREEN}Installation Complete!${NC}"
    echo "====================="
    echo ""
    echo -e "${BLUE}What was installed:${NC}"
    echo "  ✓ Hamster Ham Radio Manager"
    echo "  ✓ Menu system for application launcher"
    echo "  ✓ Dependency check and installation scripts"
    echo "  ✓ APRS Chatty X launcher"
    echo "  ✓ QSSTV launcher"
    echo "  ✓ Desktop integration"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Run dependency installer: sudo $SCRIPT_DIR/scripts/install_dependencies.sh"
    echo "  2. Configure your amateur radio callsign in application settings"
    echo "  3. Set up audio interface for radio connection"
    echo "  4. Launch Hamster: hamster"
    echo ""
    echo -e "${BLUE}Quick start:${NC}"
    echo "  • Run 'hamster' to start the menu system"
    echo "  • Choose 'Ham Radio Manager' to access applications"
    echo "  • Install dependencies when prompted"
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo "  • README: $SCRIPT_DIR/README.md"
    echo "  • Logs: $SCRIPT_DIR/logs/"
    echo "  • Config: $SCRIPT_DIR/config/"
    echo ""
}

# Main installation function
main() {
    show_header
    
    echo -e "${BLUE}This installer will set up Hamster Ham Radio Manager${NC}"
    echo -e "${BLUE}for your Linux gaming console running Ark OS.${NC}"
    echo ""
    echo -e "${YELLOW}Features to be installed:${NC}"
    echo "  • Boot menu for Games vs Ham Radio"
    echo "  • APRS Chatty X launcher with direwolf integration"
    echo "  • QSSTV slow-scan television launcher"
    echo "  • Automatic dependency management"
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