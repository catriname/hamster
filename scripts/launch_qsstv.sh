#!/bin/bash
#
# QSSTV Launcher for Hamster Ham Radio Manager
# Checks dependencies and launches QSSTV
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$BASE_DIR/logs/qsstv.log"

# Function to log messages
log() {
    echo "$(date): $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check if QSSTV is installed
check_qsstv() {
    if ! command -v qsstv >/dev/null 2>&1; then
        log "${RED}✗${NC} QSSTV is not installed"
        log "${BLUE}QSSTV (Slow Scan Television) software is required${NC}"
        echo ""
        read -p "Install QSSTV now? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Installing QSSTV...${NC}"
            sudo "$SCRIPT_DIR/install_dependencies.sh"
            
            # Check again after installation
            if ! command -v qsstv >/dev/null 2>&1; then
                log "${RED}✗${NC} QSSTV installation failed"
                return 1
            fi
        else
            log "${YELLOW}QSSTV is required for slow-scan television functionality${NC}"
            return 1
        fi
    fi
    
    log "${GREEN}✓${NC} QSSTV found: $(which qsstv)"
    return 0
}

# Function to check audio system
check_audio() {
    log "${BLUE}Checking audio system...${NC}"
    
    # Check for ALSA
    if ! command -v aplay >/dev/null 2>&1; then
        log "${RED}✗${NC} ALSA utilities not found"
        log "${BLUE}ALSA is required for audio operations${NC}"
        return 1
    fi
    
    # List available audio devices
    local audio_devices=$(aplay -l 2>/dev/null | grep -c "card")
    if [ "$audio_devices" -eq 0 ]; then
        log "${YELLOW}!${NC} No audio devices detected"
        log "${BLUE}Make sure your audio interface is connected${NC}"
    else
        log "${GREEN}✓${NC} Audio system detected ($audio_devices device(s))"
        
        # Show available devices
        log "${BLUE}Available audio devices:${NC}"
        aplay -l 2>/dev/null | grep -E "^card" | while read line; do
            log "  $line"
        done
    fi
    
    return 0
}

# Function to check X11 display
check_display() {
    if [ -z "$DISPLAY" ]; then
        log "${YELLOW}!${NC} X11 DISPLAY not set"
        log "${BLUE}QSSTV requires a graphical display${NC}"
        
        # Try to set common display values
        if [ -f "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=:0
            log "${BLUE}Setting DISPLAY=:0${NC}"
        elif [ -f "/tmp/.X11-unix/X1" ]; then
            export DISPLAY=:1
            log "${BLUE}Setting DISPLAY=:1${NC}"
        else
            log "${RED}✗${NC} No X11 display found"
            return 1
        fi
    fi
    
    # Test X11 connection
    if command -v xdpyinfo >/dev/null 2>&1; then
        if xdpyinfo >/dev/null 2>&1; then
            log "${GREEN}✓${NC} X11 display accessible: $DISPLAY"
        else
            log "${RED}✗${NC} Cannot connect to X11 display: $DISPLAY"
            return 1
        fi
    else
        log "${YELLOW}!${NC} Cannot test X11 connection (xdpyinfo not available)"
        log "${BLUE}Assuming display is working: $DISPLAY${NC}"
    fi
    
    return 0
}

# Function to check hamlib (optional but recommended)
check_hamlib() {
    if command -v rigctl >/dev/null 2>&1; then
        log "${GREEN}✓${NC} Hamlib found: $(rigctl --version | head -1 2>/dev/null || echo 'Unknown version')"
        
        # Show supported rigs
        log "${BLUE}Hamlib supports radio control for various transceivers${NC}"
    else
        log "${YELLOW}!${NC} Hamlib not found (optional)"
        log "${BLUE}Hamlib enables radio control features in QSSTV${NC}"
    fi
    
    return 0
}

# Function to create QSSTV configuration directory
setup_qsstv_config() {
    local config_dir="$HOME/.qsstv"
    
    if [ ! -d "$config_dir" ]; then
        log "${BLUE}Creating QSSTV configuration directory...${NC}"
        mkdir -p "$config_dir"
        
        # Create basic configuration if it doesn't exist
        if [ ! -f "$config_dir/qsstv.ini" ]; then
            log "${BLUE}Creating default QSSTV configuration...${NC}"
            cat > "$config_dir/qsstv.ini" << 'EOF'
[General]
callSign=N0CALL
operatorName=Operator
qth=Unknown
locator=
txMsg=
freqTx=14230000
freqRx=14230000
rigCtrlIcom=false
rigCtrlEnabled=false
rigCtrlCom=1
rigModel=1
rigAddress=1
EOF
            log "${YELLOW}!${NC} Please edit $config_dir/qsstv.ini with your callsign and details"
        fi
    fi
    
    log "${GREEN}✓${NC} QSSTV configuration directory ready: $config_dir"
    return 0
}

# Function to show pre-launch information
show_usage_info() {
    echo ""
    log "${BLUE}QSSTV Usage Information:${NC}"
    log "======================="
    echo ""
    log "${GREEN}About QSSTV:${NC}"
    log "  • Slow-scan television software for amateur radio"
    log "  • Receive and transmit SSTV images"
    log "  • Supports multiple SSTV modes (Scottie, Martin, Robot, etc.)"
    echo ""
    log "${GREEN}Basic Operation:${NC}"
    log "  • Connect radio's audio output to computer's audio input"
    log "  • Connect computer's audio output to radio's microphone input"
    log "  • Use VOX or PTT control for transmission"
    log "  • Select appropriate SSTV mode (Auto mode works well)"
    echo ""
    log "${GREEN}Audio Setup:${NC}"
    log "  • Configure audio devices in QSSTV settings"
    log "  • Adjust audio levels to prevent distortion"
    log "  • Test with audio loopback before connecting radio"
    echo ""
    
    read -p "Press Enter to continue launching QSSTV..."
    echo ""
}

# Function to launch QSSTV
launch_qsstv() {
    log "${BLUE}Launching QSSTV...${NC}"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$BASE_DIR/logs"
    
    # Launch QSSTV
    qsstv > "$BASE_DIR/logs/qsstv.log" 2>&1 &
    QSSTV_PID=$!
    
    # Wait a moment for the application to start
    sleep 2
    
    # Check if QSSTV is still running
    if kill -0 $QSSTV_PID 2>/dev/null; then
        log "${GREEN}✓${NC} QSSTV launched successfully (PID: $QSSTV_PID)"
        echo $QSSTV_PID > "$BASE_DIR/logs/qsstv.pid"
        
        echo ""
        log "${GREEN}QSSTV is now running${NC}"
        log "Application logs: $BASE_DIR/logs/qsstv.log"
        log "Configuration: $HOME/.qsstv/"
        echo ""
        log "${BLUE}Tips:${NC}"
        log "• Configure your callsign in Options > Configuration"
        log "• Set up audio devices in Options > Sound Card"
        log "• Use Auto mode for receiving images"
        log "• Check audio levels before transmitting"
        echo ""
        
        echo "Press Ctrl+C to return to menu (this will not stop QSSTV)"
        echo ""
        
        # Wait for user input
        read -p "Press Enter to return to menu..."
        
    else
        log "${RED}✗${NC} QSSTV failed to start"
        log "${BLUE}Check the log file: $BASE_DIR/logs/qsstv.log${NC}"
        
        # Show error log if available
        if [ -f "$BASE_DIR/logs/qsstv.log" ]; then
            echo ""
            log "${YELLOW}Last few lines from QSSTV log:${NC}"
            tail -n 10 "$BASE_DIR/logs/qsstv.log"
        fi
        
        return 1
    fi
}

# Function to show running processes
show_status() {
    echo ""
    log "${BLUE}QSSTV Status:${NC}"
    
    if [ -f "$BASE_DIR/logs/qsstv.pid" ]; then
        local qsstv_pid=$(cat "$BASE_DIR/logs/qsstv.pid")
        if kill -0 $qsstv_pid 2>/dev/null; then
            log "${GREEN}✓${NC} QSSTV running (PID: $qsstv_pid)"
        else
            log "${YELLOW}!${NC} QSSTV not running"
        fi
    else
        log "${YELLOW}!${NC} QSSTV has not been started by Hamster"
    fi
    
    # Check if any QSSTV process is running
    local qsstv_procs=$(pgrep -x "qsstv" | wc -l)
    if [ "$qsstv_procs" -gt 0 ]; then
        log "${GREEN}✓${NC} $qsstv_procs QSSTV process(es) detected"
    fi
}

# Function to offer to kill running QSSTV processes
offer_kill_qsstv() {
    local qsstv_procs=$(pgrep -x "qsstv")
    if [ -n "$qsstv_procs" ]; then
        echo ""
        log "${YELLOW}QSSTV is already running${NC}"
        echo ""
        read -p "Kill existing QSSTV processes and restart? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Stopping existing QSSTV processes...${NC}"
            pkill -x "qsstv"
            sleep 2
            return 0
        else
            log "${BLUE}Using existing QSSTV instance${NC}"
            return 1
        fi
    fi
    return 0
}

# Main execution
main() {
    clear
    log "${YELLOW}QSSTV Launcher${NC}"
    log "==============="
    echo ""
    
    # Create log directory
    mkdir -p "$BASE_DIR/logs"
    
    # Check if QSSTV is already running
    if ! offer_kill_qsstv; then
        show_status
        echo ""
        read -p "Press Enter to return to menu..."
        return 0
    fi
    
    # Check dependencies
    log "${BLUE}Checking dependencies...${NC}"
    
    if ! check_qsstv; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    if ! check_display; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    check_audio
    check_hamlib
    setup_qsstv_config
    
    echo ""
    log "${GREEN}Dependencies checked${NC}"
    
    # Show usage information
    show_usage_info
    
    # Launch QSSTV
    if launch_qsstv; then
        show_status
    fi
}

# Handle cleanup on exit
cleanup() {
    log "${YELLOW}Exiting QSSTV launcher...${NC}"
    # Note: We don't kill QSSTV here as the user may want it to keep running
}

trap cleanup EXIT

# Run the launcher
main "$@"