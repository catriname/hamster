# Hamster - Ham Radio Manager

A console wrapper for launching ham radio applications on Linux gaming consoles running Ark OS.

## Overview

Hamster provides a simple menu interface to boot into either:
- Your games (default Ark OS behavior)
- Ham Radio Manager (launches ham radio applications)

## Features

- **APRS Chatty X Launcher**: Automatically checks for and installs direwolf dependency
- **QSSTV Launcher**: Slow-scan television application
- **Dependency Management**: Automatic installation of required packages
- **Lightweight Design**: Minimal footprint (~50MB total)

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

- Linux (Ark OS or compatible)
- ~30GB available space (plenty of headroom)
- Audio interface for radio operations
- Git and basic build tools

## Project Structure

```
hamster/
├── bin/              # Compiled binaries and executables
├── scripts/          # Installation and setup scripts
├── config/           # Default configurations
├── menu/             # Menu system implementation
├── deps/             # Dependency management
└── docs/             # Documentation
```

## License

Open source - see LICENSE file for details.