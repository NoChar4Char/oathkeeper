# Oathkeeper

Oathkeeper is a premium, tamper-resistant focus booster and workspace locking application for macOS. It helps you guard your attention by locking away distracting websites and applications, reinforcing your commitment with an interactive emergency challenge, and preventing accidental or intentional override.

---

## Key Features

- **Dynamic Website Blocking**: Block specific domains system-wide by securely writing mappings to the macOS `/etc/hosts` file.
- **Process Blocking & Termination**: Force-terminates customizable lists of distracting applications (e.g., Slack, Discord, Twitter) as well as development tools (e.g., Terminal, Activity Monitor, iTerm2, Warp) if chosen.
- **Self-Locking Anti-Tamper System**: 
  - Prevents app deletion by recursively marking the `.app` bundle and its launch agents as system immutable (`chflags uchg`).
  - Automatically re-applies and verifies domain blocks in `/etc/hosts` if any manual changes are detected.
  - Spawns a background `oathkeeper-watchdog` companion process to automatically relaunch the main window focus system if the app is force quit or killed.
- **Dynamic & Clean Dashboard**:
  - Continuous, smooth linear countdown progress ring.
  - Numeric-only keyboard filtering and clamping limits.
  - Set blocks and extensions up to **29 days, 23 hours, 59 minutes**.
- **Interactive Emergency Challenge**: A typing marathon mini-game allowing up to 5 strikes to abort active focus sessions in absolute emergencies.

---

## How It Works

### 1. Website Blocking (/etc/hosts)
When a block is activated, Oathkeeper writes entries like `127.0.0.1 blocked-domain.com` into the system `/etc/hosts` file. Since editing `/etc/hosts` requires root privileges, the app prompts you for administrator permission using macOS authentication.

### 2. Application Monitoring
The app monitors running processes via `NSWorkspace` notifications. If a monitored application name or bundle identifier matching your blocked list launches, Oathkeeper sends a force-termination signal to that PID immediately.

### 3. Companion Watchdog
During active blocks, a helper companion executable `oathkeeper-watchdog` tracks the main process ID. If the parent process is closed via Activity Monitor or terminal commands, the watchdog immediately uses `/usr/bin/open` to relaunch the application bundle and restore focus state.

---

## Build & Installation

### Requirements
- **macOS**: 13.0 (Ventura) or newer
- **Swift**: 5.7+ / Swift Package Manager (SPM)

### Building and Packaging
To build the release application bundle and package it into a distribution DMG volume:
1. Open the terminal and navigate to the project directory.
2. Ensure you have executable rights on the packaging scripts:
   ```bash
   chmod +x package.sh create_dmg.sh
   ```
3. Run the packaging script:
   ```bash
   ./package.sh
   ```
4. The output will be located in:
   - Compiled Bundle: `Oathkeeper.app`
   - Distribution Installer: `Oathkeeper.dmg`