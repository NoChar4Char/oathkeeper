import Cocoa
import Darwin

let home = FileManager.default.homeDirectoryForCurrentUser
let stateFile = home.appendingPathComponent(".oathkeeper_daemon_state.json")

func getMonotonicTime() -> TimeInterval {
    var timebaseInfo = mach_timebase_info_data_t()
    mach_timebase_info(&timebaseInfo)
    let machTime = mach_continuous_time()
    let nanos = Double(machTime) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
    return nanos / 1_000_000_000.0
}

guard let data = try? Data(contentsOf: stateFile),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let endMonotonic = dict["endMonotonic"] as? Double,
      let blockedApps = dict["blockedApps"] as? [String],
      let blockTerminal = dict["blockTerminal"] as? Bool,
      let blockActivityMonitor = dict["blockActivityMonitor"] as? Bool else {
    exit(0)
}

var allApps = blockedApps
if blockTerminal {
    allApps.append(contentsOf: ["terminal", "iterm", "iterm2", "warp"])
}
if blockActivityMonitor {
    allApps.append("activity monitor")
}
let finalBlockedApps = allApps.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

func forceTerminate(app: NSRunningApplication) {
    let bundleId = app.bundleIdentifier?.lowercased() ?? "unknown"
    let selfBundleId = Bundle.main.bundleIdentifier?.lowercased() ?? "com.nochar4char.oathkeeper.daemon"
    let name = app.localizedName?.lowercased() ?? ""
    
    if bundleId != selfBundleId && name != "oathkeeperdaemon" && !bundleId.contains("oathkeeperdaemon") {
        print("OathkeeperDaemon: Terminating blocked app \(name)")
        app.forceTerminate()
        
        // Also fire a SIGKILL just in case NSRunningApplication fails
        if app.processIdentifier > 0 {
            kill(app.processIdentifier, SIGKILL)
        }
    }
}

// Force-kill running blocked apps immediately
func killBlockedApps() {
    let running = NSWorkspace.shared.runningApplications
    for app in running {
        let name = app.localizedName?.lowercased() ?? ""
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        for blocked in finalBlockedApps {
            if blocked.isEmpty { continue }
            if name == blocked || bundleId == blocked || name.contains(blocked) || bundleId.contains(blocked) {
                forceTerminate(app: app)
            }
        }
    }
}

killBlockedApps()

// Listen for new launches
let observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { notification in
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
        let name = app.localizedName?.lowercased() ?? ""
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        for blocked in finalBlockedApps {
            if blocked.isEmpty { continue }
            if name == blocked || bundleId == blocked || name.contains(blocked) || bundleId.contains(blocked) {
                forceTerminate(app: app)
            }
        }
    }
}

// Watchdog for Oathkeeper termination
let terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { notification in
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        if bundleId == "com.nochar4char.oathkeeper" || name == "oathkeeper" {
            print("OathkeeperDaemon: Oathkeeper was killed! Resurrecting...")
            // It was killed! Re-launch it!
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.nochar4char.oathkeeper") {
                try? NSWorkspace.shared.launchApplication(at: url, options: .withoutActivation, configuration: [:])
            } else {
                // Fallback to searching /Applications
                let fallbackUrl = URL(fileURLWithPath: "/Applications/Oathkeeper.app")
                try? NSWorkspace.shared.launchApplication(at: fallbackUrl, options: .withoutActivation, configuration: [:])
            }
        }
    }
}

// Timer to check expiration
let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { t in
    if getMonotonicTime() >= endMonotonic {
        print("OathkeeperDaemon: Time expired. Exiting.")
        // Unlock plist so we can be unloaded
        let plistPath = home.appendingPathComponent("Library/LaunchAgents/com.nochar4char.oathkeeper.daemon.plist")
        let unlockProcess = Process()
        unlockProcess.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        unlockProcess.arguments = ["nouchg", plistPath.path]
        try? unlockProcess.run()
        unlockProcess.waitUntilExit()
        
        exit(0)
    }
}
timer.tolerance = 5.0
RunLoop.main.add(timer, forMode: .common)

RunLoop.main.run()
