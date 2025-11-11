# Hamster - Ham Radio Manager

A dedicated ham radio application manager for ArkOS Linux systems.

## Overview

Hamster provides a comprehensive menu interface for managing and launching ham radio applications on ArkOS. This is a dedicated ham radio system that replaces the gaming interface with professional amateur radio tools.

## Features

- **Complete Ham Radio Suite**: Dedicated environment for amateur radio operations
- **APRS Chatty X**: APRS messaging client with integrated direwolf TNC
- **QSSTV**: Slow-scan television application for image transmission
- **Dependency Management**: Automatic installation and configuration of all required packages
- **Professional Interface**: Clean, organized menu system designed for radio operators
- **Audio Management**: Integrated audio interface configuration for radio connections

## Supported Applications

- **APRS Chatty X**: APRS messaging client (requires direwolf TNC)
- **QSSTV**: Slow-scan television software
- **Direwolf**: Software TNC (auto-installed as dependency)

## Installation

```bash
# Clone the repository
git clone [repo-url] hamster
cd hamster

# Run the installer
./install.sh

# Launch hamster
./hamster
```

## Requirements

- ArkOS Linux or compatible Linux distribution
- ~10GB available space for complete ham radio suite
- Audio interface for radio operations (USB or built-in)
- Internet connection for dependency installation
- Amateur radio license for transmission operations

## Project Structure

```
hamster/
├── bin/              # Compiled binaries and executables
├── scripts/          # Installation, setup, and launcher scripts
├── config/           # Application configurations and profiles
├── logs/             # Application and system logs
└── docs/             # Documentation and user guides
```

## License

Open source - see LICENSE file for details.