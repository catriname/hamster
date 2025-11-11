#!/bin/bash
#
# APRS Chatty X Launcher for Hamster Ham Radio Manager
# Checks dependencies and launches APRS Chatty X
#

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$BASE_DIR/logs/aprs_chatty_x.log"

# Path to APRS Chatty X (adjust this path as needed)
APRS_CHATTY_X_PATH="$HOME/APRS-Chatty-X"
APRS_EXECUTABLE="$APRS_CHATTY_X_PATH/APRS-Chatty-X/bin/Release/net6.0/APRS-Chatty-X"

# Function to log messages
log() {
    echo "$(date): $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check if direwolf is installed
check_direwolf() {
    if ! command -v direwolf >/dev/null 2>&1; then
        log "${RED}✗${NC} Direwolf is not installed"
        log "${BLUE}Direwolf is required for APRS Chatty X to function${NC}"
        echo ""
        read -p "Install Direwolf now? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Installing Direwolf...${NC}"
            sudo "$SCRIPT_DIR/install_dependencies.sh"
            
            # Check again after installation
            if ! command -v direwolf >/dev/null 2>&1; then
                log "${RED}✗${NC} Direwolf installation failed"
                return 1
            fi
        else
            log "${YELLOW}Direwolf is required for APRS functionality${NC}"
            return 1
        fi
    fi
    
    log "${GREEN}✓${NC} Direwolf found: $(which direwolf)"
    return 0
}

# Function to check .NET runtime
check_dotnet() {
    if ! command -v dotnet >/dev/null 2>&1; then
        log "${RED}✗${NC} .NET runtime is not installed"
        log "${BLUE}.NET runtime is required to run APRS Chatty X${NC}"
        echo ""
        read -p "Install .NET runtime now? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Installing .NET runtime...${NC}"
            sudo "$SCRIPT_DIR/install_dependencies.sh"
            
            # Check again after installation
            if ! command -v dotnet >/dev/null 2>&1; then
                log "${RED}✗${NC} .NET runtime installation failed"
                return 1
            fi
        else
            log "${YELLOW}.NET runtime is required to run APRS Chatty X${NC}"
            return 1
        fi
    fi
    
    log "${GREEN}✓${NC} .NET runtime found: $(dotnet --version 2>/dev/null || echo 'Unknown version')"
    return 0
}

# Function to check if APRS Chatty X exists
check_aprs_chatty_x() {
    # Check for compiled executable
    if [ -f "$APRS_EXECUTABLE" ]; then
        log "${GREEN}✓${NC} APRS Chatty X found: $APRS_EXECUTABLE"
        return 0
    fi
    
    # Check for source code
    if [ -d "$APRS_CHATTY_X_PATH" ]; then
        log "${YELLOW}!${NC} APRS Chatty X source found but not compiled"
        echo ""
        read -p "Build APRS Chatty X now? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            build_aprs_chatty_x
            return $?
        else
            log "${YELLOW}APRS Chatty X needs to be built before running${NC}"
            return 1
        fi
    fi
    
    log "${RED}✗${NC} APRS Chatty X not found"
    log "${BLUE}Expected location: $APRS_CHATTY_X_PATH${NC}"
    echo ""
    read -p "Try to clone APRS Chatty X repository? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clone_aprs_chatty_x
        return $?
    else
        return 1
    fi
}

# Function to clone APRS Chatty X repository
clone_aprs_chatty_x() {
    log "${BLUE}Cloning APRS Chatty X repository...${NC}"
    
    # Clone the APRS Chatty X repository
    local repo_url="https://github.com/catriname/APRS-Chatty-X.git"
    
    cd "$(dirname "$APRS_CHATTY_X_PATH")"
    git clone "$repo_url" "$(basename "$APRS_CHATTY_X_PATH")"
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} APRS Chatty X repository cloned"
        build_aprs_chatty_x
        return $?
    else
        log "${RED}✗${NC} Failed to clone APRS Chatty X repository"
        log "${YELLOW}Please manually clone or provide the correct repository URL${NC}"
        return 1
    fi
}

# Function to build APRS Chatty X
build_aprs_chatty_x() {
    log "${BLUE}Building APRS Chatty X...${NC}"
    
    if [ ! -d "$APRS_CHATTY_X_PATH" ]; then
        log "${RED}✗${NC} APRS Chatty X source directory not found"
        return 1
    fi
    
    cd "$APRS_CHATTY_X_PATH"
    
    # Build the project
    dotnet build --configuration Release
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✓${NC} APRS Chatty X built successfully"
        
        # Try to find the executable
        local exe_path=$(find . -name "APRS-Chatty-X" -type f -executable | head -1)
        if [ -n "$exe_path" ]; then
            APRS_EXECUTABLE="$APRS_CHATTY_X_PATH/$exe_path"
            log "${GREEN}✓${NC} Executable found: $APRS_EXECUTABLE"
        fi
        
        return 0
    else
        log "${RED}✗${NC} Failed to build APRS Chatty X"
        return 1
    fi
}

# Function to start direwolf if not running
start_direwolf() {
    # Check if direwolf is already running
    if pgrep -x "direwolf" > /dev/null; then
        log "${GREEN}✓${NC} Direwolf is already running"
        return 0
    fi
    
    log "${BLUE}Starting Direwolf...${NC}"
    
    # Look for configuration file
    local config_file=""
    if [ -f "$BASE_DIR/config/direwolf.conf" ]; then
        config_file="$BASE_DIR/config/direwolf.conf"
    elif [ -f "$HOME/.direwolf.conf" ]; then
        config_file="$HOME/.direwolf.conf"
    elif [ -f "$APRS_CHATTY_X_PATH/Sample/direwolf.conf" ]; then
        config_file="$APRS_CHATTY_X_PATH/Sample/direwolf.conf"
    else
        log "${YELLOW}!${NC} No direwolf configuration found"
        log "${BLUE}Creating default configuration...${NC}"
        
        # Create a basic configuration
        mkdir -p "$BASE_DIR/config"
        cat > "$BASE_DIR/config/direwolf.conf" << EOF
# Basic Direwolf Configuration
ACHANNELS 1
ADEVICE plughw:0,0
CHANNEL 0
MYCALL N0CALL-1
MODEM 1200

# Adjust these settings for your setup:
# MYCALL - Your amateur radio callsign
# ADEVICE - Your audio interface
# PTT - Push-to-talk method if needed

LOGDIR /tmp
EOF
        config_file="$BASE_DIR/config/direwolf.conf"
        
        log "${YELLOW}!${NC} Please edit $config_file with your callsign and audio settings"
        echo ""
        read -p "Press Enter to continue with default settings or Ctrl+C to exit and configure..."
    fi
    
    # Start direwolf in background
    log "${BLUE}Starting direwolf with config: $config_file${NC}"
    direwolf -c "$config_file" > "$BASE_DIR/logs/direwolf.log" 2>&1 &
    DIREWOLF_PID=$!
    
    # Wait a moment for direwolf to start
    sleep 3
    
    # Check if it's still running
    if kill -0 $DIREWOLF_PID 2>/dev/null; then
        log "${GREEN}✓${NC} Direwolf started successfully (PID: $DIREWOLF_PID)"
        echo $DIREWOLF_PID > "$BASE_DIR/logs/direwolf.pid"
        return 0
    else
        log "${RED}✗${NC} Direwolf failed to start"
        log "${BLUE}Check the log: $BASE_DIR/logs/direwolf.log${NC}"
        return 1
    fi
}

# Function to launch APRS Chatty X
launch_aprs_chatty_x() {
    log "${BLUE}Launching APRS Chatty X...${NC}"
    
    cd "$APRS_CHATTY_X_PATH"
    
    # Launch the application
    if [ -f "$APRS_EXECUTABLE" ]; then
        dotnet "$APRS_EXECUTABLE" > "$BASE_DIR/logs/aprs_chatty_x.log" 2>&1 &
        APRS_PID=$!
        
        log "${GREEN}✓${NC} APRS Chatty X launched (PID: $APRS_PID)"
        echo $APRS_PID > "$BASE_DIR/logs/aprs_chatty_x.pid"
        
        echo ""
        log "${BLUE}APRS Chatty X is now running${NC}"
        log "Logs: $BASE_DIR/logs/aprs_chatty_x.log"
        log "Press Ctrl+C to return to menu (this will not stop APRS Chatty X)"
        echo ""
        
        # Wait for user input or application to exit
        read -p "Press Enter to return to menu..."
        
    else
        log "${RED}✗${NC} Cannot find APRS Chatty X executable"
        return 1
    fi
}

# Function to show running processes
show_status() {
    echo ""
    log "${BLUE}Process Status:${NC}"
    
    if pgrep -x "direwolf" > /dev/null; then
        local direwolf_pid=$(pgrep -x "direwolf")
        log "${GREEN}✓${NC} Direwolf running (PID: $direwolf_pid)"
    else
        log "${YELLOW}!${NC} Direwolf not running"
    fi
    
    if [ -f "$BASE_DIR/logs/aprs_chatty_x.pid" ]; then
        local aprs_pid=$(cat "$BASE_DIR/logs/aprs_chatty_x.pid")
        if kill -0 $aprs_pid 2>/dev/null; then
            log "${GREEN}✓${NC} APRS Chatty X running (PID: $aprs_pid)"
        else
            log "${YELLOW}!${NC} APRS Chatty X not running"
        fi
    fi
}

# Main execution
main() {
    clear
    log "${YELLOW}APRS Chatty X Launcher${NC}"
    log "========================"
    echo ""
    
    # Create log directory
    mkdir -p "$BASE_DIR/logs"
    
    # Check dependencies
    log "${BLUE}Checking dependencies...${NC}"
    
    if ! check_dotnet; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    if ! check_direwolf; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    if ! check_aprs_chatty_x; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    echo ""
    log "${GREEN}All dependencies satisfied${NC}"
    echo ""
    
    # Start direwolf
    if ! start_direwolf; then
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    echo ""
    
    # Launch APRS Chatty X
    launch_aprs_chatty_x
    
    # Show final status
    show_status
}

# Handle cleanup on exit
cleanup() {
    log "${YELLOW}Cleaning up...${NC}"
    # Note: We don't kill direwolf or APRS Chatty X here as they may need to keep running
}

trap cleanup EXIT

# Run the launcher
main "$@"