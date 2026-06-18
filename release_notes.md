# Oathkeeper Release Notes

## Version 1.4.0 (Latest Publish)
*Compared to version 1.3.0*

### Key Features & Updates
* **Background Auto-Updater**: Implemented a self-contained automatic background update installer. When checking for updates, the app retrieves the latest `.dmg` release from GitHub, downloads it in the background, mounts it, copies the new `.app` bundle dynamically over the current bundle path, re-secures it, and automatically restarts.
* **Separated System Utility Options**: Split the unified "Block System Utilities" setting into two separate, independent configurations: **Block Terminal** (blocks Terminal, iTerm, Warp, etc.) and **Block Activity Monitor**.
* **Clean & Compact Checkboxes**: Redesigned the configuration UI to display the Terminal and Activity Monitor blocking options side-by-side on a single centered row as standard macOS checkboxes, saving vertical space and keeping all buttons fully visible.
* **Refined Active Dashboard**: Split the System Utilities section of the active block dashboard into two independent columns: Terminal and Activity Monitor, allowing irreversible lock-in on each feature independently.

### UI & Safeguard Refinements
* **Polished Layout spacing**: Fixed vertical layouts to ensure no bottom controls (like "Emergency Restore" and "Check for Updates") are clipped on smaller window sizes.
* **Removed Test Controls**: Cleaned up the active block dashboard by removing the "Unblock (Test)" button to prepare the app for production release.

## Version 1.3.0


### Key Bug Fixes & Stability
* **Automatic Unblocking Loop Fix**: Fixed a critical issue where websites remained blocked after the focus timer finished. The unblocking routine now terminates the hosts file kernel monitor before modifying `/etc/hosts` to prevent the anti-tamper system from misinterpreting cleanup as tampering and re-applying the block.
* **Launch-Time Catch-up Guard**: If the focus block duration expires while the Mac is powered off or asleep, Oathkeeper now automatically deactivates the session on launch instead of locking the system.
* **Watchdog System Removal**: Completely removed the watchdog companion daemon to resolve process locking conflicts, reduce power overhead, and simplify stability. The application now relies on user-locked System Utilities configuration and launch agent relaunchers.

### Kernel-Level & Energy Optimization
* **Kernel-Level Hosts Monitor**: Implemented a `DispatchSourceFileSystemObject` file monitor that listens to system file events to detect modifications to `/etc/hosts`. This reduces active disk read loops to zero during standard lock sessions.
* **Fallback Polling Loop Reduction**: Reduced the fallback hosts-file integrity polling frequency by **60x** (from every second to once every 60 seconds), vastly reducing CPU awake time and conserving battery.
* **Automatic Sleep/Wake Catch-up**: Added active listeners for macOS wake events and local time differences to automatically subtract elapsed sleep time when the Mac wakes up.

### User Interface & Safeguards
* **Lockable Active Checkbox**: Relocated the "Block System Utilities" control directly to the active counts dashboard under System Utilities. Once enabled mid-block, it immediately locks in place and cannot be disabled until the focus block expires.
* **Utilities Lock Confirmation**: Added an irreversible action confirmation alert before enabling System Utilities blocking in an active focus session.
* **GitHub Update Checker**: Added a "Check for Updates" button to query latest releases directly from GitHub when the focus blocker is inactive.
* **Enter-to-Submit Websites**: Allowed pressing the **Enter/Return** key in both active and inactive website text fields to add domains instantly.
* **Full Application Sync**: Upgraded the Sync button to perform a complete state sync (re-applying engine blocks, launch agents, permissions, and app locks) and renamed it to **"Sync Application & Time"**.

## Version 1.0.4
*Compared to version 1.0.2*

### Key Bug Fixes
* **App Blocking Lifecycle**: Fixed a severe bug where background observers and poll timers continued running in the background after the block timer ended. Applications in the blocklist now automatically unblock when the focus timer ends without needing manual list removal.
* **Tamper-Resistant State File Integrity**: Enhanced `saveState()` to always dynamically unlock the state file before writing. This resolves issues where background state saves failed due to files being locked with `chflags uchg` under macOS tamper prevention.
* **Robust Watchdog GUI Relaunching**: Configured the watchdog daemon to relaunch the main application bundle using `/usr/bin/open` rather than directly executing the binary inside the bundle. This ensures the relaunched app successfully registers with the macOS window server, restoring the status bar icon and window focus.

### User Interface & Experience
* **Smooth Countdown Time Bar**: Changed the neon colored circular progress ring to transition smoothly and continuously between seconds (using 1.0-second linear animations) instead of jumping discretely.
* **Human-Readable Durations**: The confirmation prompt for starting and extending blocks now formats duration in a friendly way (e.g. `"1 day, 2 hours, 15 minutes"`) instead of converting everything into raw minutes.
* **Numeric-Only Input Formatting & Clamping**: Text fields for block duration (days, hours, minutes) in both locked (active dashboard) and unlocked (inactive configurator) states now only permit integers. Characters, spaces, and decimal points are immediately stripped, and inputs are clamped automatically within valid limits (0–29 for days, 0–23 for hours, 0–59 for minutes).
* **Strict Duration Limits Cap**: Enforced a strict maximum duration limit of 29 days, 23 hours, 59 minutes. Focus blocks cannot exceed this total block time, and attempts to exceed this cap during starting or extending are automatically capped with clear UI notes.
* **Zero Duration Blocker Prevention**: Added a safeguard that disables starting or extending a block if the entered duration is 0 days, 0 hours, and 0 minutes. Pressing the start or extend button in this case has no effect.
* **Interactive Control for Exiting**: Added a **Quit Oathkeeper** button at the bottom of the inactive configurator panel so users can exit the accessory background app easily when not in an active block.
* **Live Configuration Addition Message Relocation**: Relocated the `"Timer extended!"` success text to appear directly under the block extension inputs card instead of under the app/website blocklist input cards.
* **Wording Upgrades**: Clarified system utility lock recommendations from "Recommended" to **"Highly Recommended"**.
* **System Utilities Status Display**: The active dashboard now contains a third status column showing if system utilities are currently locked (`Blocked` or `Allowed`).

### Batch Operations & Safeguards
* **Batch Input Instructions**: Added explicit UI prompts pointing out that multiple domains can be added simultaneously using either space or comma separators.
* **Robust App Exclusion Exclusions**: Enhanced app validation during both active and inactive screens. Attempting to select or add any application containing `"oathkeeper"` case-insensitively will be rejected with an error banner, making it impossible to block the blocker app itself.
