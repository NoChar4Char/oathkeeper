# Oathkeeper Release Notes

## Version 1.0.4 (Latest Publish)
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
