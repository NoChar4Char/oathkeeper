import Cocoa

class AppBlocker {
    private var isBlocking = false
    private var blockedApps: [String] = []
    private var observer: NSObjectProtocol?
    
    static let shared = AppBlocker()
    
    private init() {}
    
    /// Starts the application blocking engine.
    /// - Parameter apps: List of app names or bundle identifiers to block.
    func startBlocking(apps: [String], blockTerminal: Bool = true, blockActivityMonitor: Bool = true) {
        stopBlocking() // Clean up any existing active block/timer/observer first
        
        var allApps = apps
        
        // Auto-block Terminal and standard terminals to prevent force-killing or tampering
        if blockTerminal {
            let terminalApps = ["terminal", "iterm", "iterm2", "warp"]
            for sysApp in terminalApps {
                if !allApps.contains(where: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == sysApp }) {
                    allApps.append(sysApp)
                }
            }
        }
        
        // Auto-block Activity Monitor
        if blockActivityMonitor {
            let monitorApp = "activity monitor"
            if !allApps.contains(where: { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == monitorApp }) {
                allApps.append(monitorApp)
            }
        }
        
        self.blockedApps = allApps.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !blockedApps.isEmpty else { return }
        
        isBlocking = true
        
        // 1. Immediately terminate any blocked apps that are already running
        checkAndTerminateRunningApps()
        
        // 2. Register launch notifications for real-time, low-latency termination
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isBlocking else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.checkAndTerminate(app: app)
            }
        }
    }
    
    /// Stops the application blocking engine.
    func stopBlocking() {
        isBlocking = false
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
    
    private func checkAndTerminateRunningApps() {
        guard isBlocking else { return }
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            checkAndTerminate(app: app)
        }
    }
    
    private func checkAndTerminate(app: NSRunningApplication) {
        let name = app.localizedName?.lowercased() ?? ""
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        
        for blocked in blockedApps {
            if blocked.isEmpty { continue }
            // Match against localized app name, bundle ID, or partial name matches
            if name == blocked || bundleId == blocked || name.contains(blocked) || bundleId.contains(blocked) {
                // Ensure we do not accidentally force-terminate our own app process
                let selfBundleId = Bundle.main.bundleIdentifier?.lowercased() ?? "com.nochar4char.oathkeeper"
                if bundleId != selfBundleId && name != "oathkeeper" && !bundleId.contains("oathkeeper") {
                    print("Oathkeeper [AppBlocker]: Force terminating blocked application: \(app.localizedName ?? "Unknown") (\(bundleId))")
                    app.forceTerminate()
                }
            }
        }
    }
}
