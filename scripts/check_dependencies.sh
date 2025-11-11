#!/bin/bash
#
# Dependency Checker for Hamster Ham Radio Manager
# Checks for required software and dependencies
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a package is installed (apt-based systems)
package_installed() {
    dpkg -l | grep -q "^ii  $1 "
}

# Function to check system architecture
check_architecture() {
    echo -e "${BLUE}System Architecture:${NC}"
    echo "  Architecture: $(uname -m)"
    echo "  Kernel: $(uname -r)"
    echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
    echo ""
}

# Function to check direwolf
check_direwolf() {
    echo -e "${BLUE}Checking Direwolf TNC:${NC}"
    
    if command_exists direwolf; then
        echo -e "  ${GREEN}✓${NC} Direwolf found: $(which direwolf)"
        echo "    Version: $(direwolf -V 2>&1 | head -1 || echo 'Unknown')"
    else
        echo -e "  ${RED}✗${NC} Direwolf not found"
        echo "    Required for APRS Chatty X"
    fi
    echo ""
}

# Function to check QSSTV
check_qsstv() {
    echo -e "${BLUE}Checking QSSTV:${NC}"
    
    if command_exists qsstv; then
        echo -e "  ${GREEN}✓${NC} QSSTV found: $(which qsstv)"
    else
        echo -e "  ${RED}✗${NC} QSSTV not found"
        echo "    Slow-scan television software"
    fi
    echo ""
}

# Function to check .NET runtime
check_dotnet() {
    echo -e "${BLUE}Checking .NET Runtime:${NC}"
    
    if command_exists dotnet; then
        echo -e "  ${GREEN}✓${NC} .NET found: $(which dotnet)"
        echo "    Version: $(dotnet --version 2>/dev/null || echo 'Unknown')"
        echo "    Runtime: $(dotnet --list-runtimes 2>/dev/null | grep 'Microsoft.NETCore.App' | head -1 || echo 'None found')"
    else
        echo -e "  ${RED}✗${NC} .NET runtime not found"
        echo "    Required for APRS Chatty X"
    fi
    echo ""
}

# Function to check build tools
check_build_tools() {
    echo -e "${BLUE}Checking Build Tools:${NC}"
    
    # Git
    if command_exists git; then
        echo -e "  ${GREEN}✓${NC} Git: $(git --version | head -1)"
    else
        echo -e "  ${RED}✗${NC} Git not found"
    fi
    
    # GCC/G++
    if command_exists gcc; then
        echo -e "  ${GREEN}✓${NC} GCC: $(gcc --version | head -1)"
    else
        echo -e "  ${RED}✗${NC} GCC not found"
    fi
    
    if command_exists g++; then
        echo -e "  ${GREEN}✓${NC} G++: $(g++ --version | head -1)"
    else
        echo -e "  ${RED}✗${NC} G++ not found"
    fi
    
    # Make
    if command_exists make; then
        echo -e "  ${GREEN}✓${NC} Make: $(make --version | head -1)"
    else
        echo -e "  ${RED}✗${NC} Make not found"
    fi
    
    # Autotools (alternative to CMake)
    if command_exists autoconf; then
        echo -e "  ${GREEN}✓${NC} Autotools: $(autoconf --version | head -1)"
    else
        echo -e "  ${YELLOW}!${NC} Autotools not found (optional alternative to CMake)"
    fi
    echo ""
}

# Function to check audio systems
check_audio() {
    echo -e "${BLUE}Checking Audio System:${NC}"
    
    # ALSA
    if package_installed alsa-utils || command_exists aplay; then
        echo -e "  ${GREEN}✓${NC} ALSA detected"
    else
        echo -e "  ${RED}✗${NC} ALSA not found"
    fi
    
    # PulseAudio
    if command_exists pulseaudio || command_exists pactl; then
        echo -e "  ${GREEN}✓${NC} PulseAudio detected"
    else
        echo -e "  ${YELLOW}!${NC} PulseAudio not found (optional)"
    fi
    
    # List audio devices
    if command_exists aplay; then
        echo "  Audio devices:"
        aplay -l 2>/dev/null | grep -E "^card" | while read line; do
            echo "    $line"
        done
    fi
    echo ""
}

# Function to check specific package dependencies
check_packages() {
    echo -e "${BLUE}Checking Package Dependencies:${NC}"
    
    # Direwolf dependencies
    echo "  Direwolf build dependencies:"
    local direwolf_deps=("libasound2-dev" "libudev-dev" "libavahi-client-dev" "libgpiod-dev")
    for pkg in "${direwolf_deps[@]}"; do
        if package_installed "$pkg"; then
            echo -e "    ${GREEN}✓${NC} $pkg"
        else
            echo -e "    ${RED}✗${NC} $pkg"
        fi
    done
    
    echo ""
    
    # QSSTV dependencies
    echo "  QSSTV build dependencies:"
    local qsstv_deps=("libfftw3-dev" "qtbase5-dev" "libhamlib++-dev" "libasound2-dev" "libpulse-dev")
    for pkg in "${qsstv_deps[@]}"; do
        if package_installed "$pkg"; then
            echo -e "    ${GREEN}✓${NC} $pkg"
        else
            echo -e "    ${RED}✗${NC} $pkg"
        fi
    done
    echo ""
}

# Function to check disk space
check_disk_space() {
    echo -e "${BLUE}Checking Disk Space:${NC}"
    
    local available=$(df . | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    
    echo "  Available space: ${available_gb}GB"
    
    if [ $available_gb -gt 10 ]; then
        echo -e "  ${GREEN}✓${NC} Sufficient space for installation"
    elif [ $available_gb -gt 5 ]; then
        echo -e "  ${YELLOW}!${NC} Limited space - may be sufficient"
    else
        echo -e "  ${RED}✗${NC} Insufficient space for installation"
    fi
    echo ""
}

# Function to generate summary
show_summary() {
    echo -e "${BLUE}Summary:${NC}"
    
    local missing_critical=""
    local missing_optional=""
    
    # Check critical dependencies
    if ! command_exists git; then
        missing_critical="$missing_critical git"
    fi
    if ! command_exists gcc; then
        missing_critical="$missing_critical gcc"
    fi
    if ! command_exists make; then
        missing_critical="$missing_critical make"
    fi
    # Note: CMake is no longer required - we use alternative build methods
    
    # Check applications
    if ! command_exists direwolf; then
        missing_optional="$missing_optional direwolf"
    fi
    if ! command_exists qsstv; then
        missing_optional="$missing_optional qsstv"
    fi
    if ! command_exists dotnet; then
        missing_optional="$missing_optional dotnet"
    fi
    
    if [ -z "$missing_critical" ] && [ -z "$missing_optional" ]; then
        echo -e "  ${GREEN}✓${NC} All dependencies satisfied"
        echo -e "  ${GREEN}✓${NC} Ready to run ham radio applications"
    elif [ -z "$missing_critical" ]; then
        echo -e "  ${YELLOW}!${NC} Build tools available"
        echo -e "  ${YELLOW}!${NC} Missing applications:$missing_optional"
        echo -e "  ${BLUE}→${NC} Run 'install_dependencies.sh' to install missing components"
    else
        echo -e "  ${RED}✗${NC} Missing critical build tools:$missing_critical"
        echo -e "  ${RED}✗${NC} Missing applications:$missing_optional"
        echo -e "  ${BLUE}→${NC} Run 'install_dependencies.sh' to install all components"
    fi
}

# Main execution
main() {
    clear
    echo -e "${YELLOW}Hamster Dependency Checker${NC}"
    echo "==============================="
    echo ""
    
    check_architecture
    check_build_tools
    check_direwolf
    check_qsstv
    check_dotnet
    check_audio
    check_packages
    check_disk_space
    show_summary
}

# Run the checks
main "$@"