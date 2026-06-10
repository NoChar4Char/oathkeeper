import Cocoa

class AppBlocker {
    private var isBlocking = false
    private var blockedApps: [String] = []
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    
    static let shared = AppBlocker()
    
    private init() {}
    
    /// Starts the application blocking engine.
    /// - Parameter apps: List of app names or bundle identifiers to block.
    func startBlocking(apps: [String]) {
        self.blockedApps = apps.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !blockedApps.isEmpty else { return }
        
        isBlocking = true
        
        // 1. Immediately terminate any blocked apps that are already running
        checkAndTerminateRunningApps()
        
        // 2. Poll running apps periodically (fallback for applications that launch differently)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAndTerminateRunningApps()
        }
        
        // 3. Register launch notifications for real-time, low-latency termination
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
        timer?.invalidate()
        timer = nil
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
    
    private func checkAndTerminateRunningApps() {
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
                if bundleId != Bundle.main.bundleIdentifier?.lowercased() {
                    print("Oathkeeper [AppBlocker]: Force terminating blocked application: \(app.localizedName ?? "Unknown") (\(bundleId))")
                    app.forceTerminate()
                }
            }
        }
    }
}
