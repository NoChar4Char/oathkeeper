import Foundation
import Combine

struct NetworkTime {
    /// Fetches the current UTC time from a highly available server using HTTP response headers.
    static func fetchUTC(completion: @escaping (Date?) -> Void) {
        guard let url = URL(string: "https://www.google.com") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3.0
        
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            guard let httpResponse = response as? HTTPURLResponse,
                  let dateStr = httpResponse.allHeaderFields["Date"] as? String else {
                completion(nil)
                return
            }
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = formatter.date(from: dateStr) {
                completion(date)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
}

struct BlockState: Codable {
    var isActive: Bool = false
    var remainingSeconds: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    
    var startNetworkTime: Date? = nil
    var startSystemTime: Date = Date()
    var startMonotonicTime: TimeInterval = 0
    
    var lastSavedSystemTime: Date = Date()
    var lastSavedMonotonicTime: TimeInterval = 0
    var lastSavedNetworkTime: Date? = nil
    
    // Persistent configuration list
    var blockedDomains: [String] = ["facebook.com", "youtube.com", "twitter.com", "reddit.com", "instagram.com"]
    var blockedApps: [String] = []
    
    // Kept for JSON backward compatibility, but unused
    var lockLists: Bool = false
    
    var bypassMethod: String = "typing" // default to typing (challenge), timer is removed
    var bypassDuration: TimeInterval = 1200 // default 20 minutes (1200 seconds)
    
    // For emergency bypass tracking
    var bypassIsTriggered: Bool = false
    var bypassRemainingSeconds: TimeInterval = 0
    var bypassStartNetworkTime: Date? = nil
    var lastBypassSavedSystemTime: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case isActive
        case remainingSeconds
        case totalDuration
        case startNetworkTime
        case startSystemTime
        case startMonotonicTime
        case lastSavedSystemTime
        case lastSavedMonotonicTime
        case lastSavedNetworkTime
        case blockedDomains
        case blockedApps
        case lockLists
        case bypassMethod
        case bypassDuration
        case bypassIsTriggered
        case bypassRemainingSeconds
        case bypassStartNetworkTime
        case lastBypassSavedSystemTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        remainingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .remainingSeconds) ?? 0
        totalDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalDuration) ?? 0
        startNetworkTime = try container.decodeIfPresent(Date.self, forKey: .startNetworkTime)
        startSystemTime = try container.decodeIfPresent(Date.self, forKey: .startSystemTime) ?? Date()
        startMonotonicTime = try container.decodeIfPresent(TimeInterval.self, forKey: .startMonotonicTime) ?? 0
        lastSavedSystemTime = try container.decodeIfPresent(Date.self, forKey: .lastSavedSystemTime) ?? Date()
        lastSavedMonotonicTime = try container.decodeIfPresent(TimeInterval.self, forKey: .lastSavedMonotonicTime) ?? 0
        lastSavedNetworkTime = try container.decodeIfPresent(Date.self, forKey: .lastSavedNetworkTime)
        blockedDomains = try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? ["facebook.com", "youtube.com", "twitter.com", "reddit.com", "instagram.com"]
        blockedApps = try container.decodeIfPresent([String].self, forKey: .blockedApps) ?? []
        lockLists = try container.decodeIfPresent(Bool.self, forKey: .lockLists) ?? false
        let methodDecoded = try container.decodeIfPresent(String.self, forKey: .bypassMethod) ?? "typing"
        bypassMethod = methodDecoded == "timer" ? "typing" : methodDecoded
        bypassDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .bypassDuration) ?? 1200
        bypassIsTriggered = try container.decodeIfPresent(Bool.self, forKey: .bypassIsTriggered) ?? false
        bypassRemainingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .bypassRemainingSeconds) ?? 0
        bypassStartNetworkTime = try container.decodeIfPresent(Date.self, forKey: .bypassStartNetworkTime)
        lastBypassSavedSystemTime = try container.decodeIfPresent(Date.self, forKey: .lastBypassSavedSystemTime) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(remainingSeconds, forKey: .remainingSeconds)
        try container.encode(totalDuration, forKey: .totalDuration)
        try container.encode(startNetworkTime, forKey: .startNetworkTime)
        try container.encode(startSystemTime, forKey: .startSystemTime)
        try container.encode(startMonotonicTime, forKey: .startMonotonicTime)
        try container.encode(lastSavedSystemTime, forKey: .lastSavedSystemTime)
        try container.encode(lastSavedMonotonicTime, forKey: .lastSavedMonotonicTime)
        try container.encode(lastSavedNetworkTime, forKey: .lastSavedNetworkTime)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encode(blockedApps, forKey: .blockedApps)
        try container.encode(lockLists, forKey: .lockLists)
        try container.encode(bypassMethod, forKey: .bypassMethod)
        try container.encode(bypassDuration, forKey: .bypassDuration)
        try container.encode(bypassIsTriggered, forKey: .bypassIsTriggered)
        try container.encode(bypassRemainingSeconds, forKey: .bypassRemainingSeconds)
        try container.encode(bypassStartNetworkTime, forKey: .bypassStartNetworkTime)
        try container.encode(lastBypassSavedSystemTime, forKey: .lastBypassSavedSystemTime)
    }
    
    init() {}
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    private let stateFileUrl: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".oathkeeper_state.json")
    }()
    
    @Published var state = BlockState()
    
    private var timer: Timer?
    private var lastTickMonotonic: TimeInterval = 0
    
    private init() {
        loadState()
        lastTickMonotonic = getMonotonicTime()
        
        setupTimer()
        
        if state.isActive {
            startBlockingEngine()
            syncWithNetworkTime()
        }
    }
    
    /// Get the monotonic time (seconds since boot).
    func getMonotonicTime() -> TimeInterval {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1_000_000_000.0
    }
    
    /// Initiates a block session.
    func startBlock(duration: TimeInterval, bypassMethod: String, bypassDuration: TimeInterval) {
        let currentMonotonic = getMonotonicTime()
        state.isActive = true
        state.remainingSeconds = duration
        state.totalDuration = duration
        state.startSystemTime = Date()
        state.startMonotonicTime = currentMonotonic
        state.startNetworkTime = nil
        
        state.lastSavedSystemTime = Date()
        state.lastSavedMonotonicTime = currentMonotonic
        state.lastSavedNetworkTime = nil
        
        state.bypassMethod = bypassMethod
        state.bypassDuration = bypassDuration
        
        state.bypassIsTriggered = false
        state.bypassRemainingSeconds = 0
        state.bypassStartNetworkTime = nil
        
        saveState()
        startBlockingEngine()
        
        // Attempt immediate network time fetch to set starting anchor
        NetworkTime.fetchUTC { [weak self] date in
            guard let self = self, let date = date else { return }
            DispatchQueue.main.async {
                self.state.startNetworkTime = date
                self.state.lastSavedNetworkTime = date
                self.saveState()
            }
        }
    }
    
    /// Stops the active block session.
    func stopBlock() {
        state.isActive = false
        state.remainingSeconds = 0
        state.lastSavedNetworkTime = nil
        state.bypassIsTriggered = false
        state.bypassRemainingSeconds = 0
        state.bypassStartNetworkTime = nil
        
        saveState()
        stopBlockingEngine()
    }
    
    /// Triggers the emergency bypass unlock process.
    func triggerBypass() {
        guard state.isActive else { return }
        state.bypassIsTriggered = true
        saveState()
    }
    
    /// Resets the bypass state completely.
    func resetBypass() {
        state.bypassIsTriggered = false
        state.bypassRemainingSeconds = 0
        state.bypassStartNetworkTime = nil
        saveState()
    }
    
    /// Complete bypass challenge and release block immediately.
    func completeBypass() {
        stopBlock()
    }
    
    /// Enable strict blocklist locking. (Legacy support, unused)
    func enableLockLists() {
        state.lockLists = true
        saveState()
    }
    
    /// Persistently add a domain (immediately applies if active).
    func addDomain(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !state.blockedDomains.contains(trimmed) {
            state.blockedDomains.append(trimmed)
            saveState()
            
            // If block is currently active, immediately block the new website
            if state.isActive && HostsHelper.hasWritePermission() {
                try? HostsHelper.applyBlock(domains: state.blockedDomains)
            }
        }
    }
    
    /// Persistently remove a domain.
    func removeDomain(_ domain: String) {
        state.blockedDomains.removeAll { $0 == domain }
        saveState()
    }
    
    /// Persistently add an app name (immediately applies if active).
    func addApp(_ app: String) {
        let trimmed = app.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !state.blockedApps.contains(trimmed) {
            state.blockedApps.append(trimmed)
            saveState()
            
            // If block is currently active, immediately block the new app
            if state.isActive {
                AppBlocker.shared.startBlocking(apps: state.blockedApps)
            }
        }
    }
    
    /// Persistently remove an app name.
    func removeApp(_ app: String) {
        state.blockedApps.removeAll { $0 == app }
        saveState()
    }
    
    private func startBlockingEngine() {
        // App blocking (user space)
        AppBlocker.shared.startBlocking(apps: state.blockedApps)
        
        // Hosts-file website blocking (requires write permission or root)
        if HostsHelper.hasWritePermission() {
            try? HostsHelper.applyBlock(domains: state.blockedDomains)
        } else {
            print("Oathkeeper [TimerManager]: hosts file is not writable. Running in app-block-only mode.")
        }
    }
    
    private func stopBlockingEngine() {
        AppBlocker.shared.stopBlocking()
        try? HostsHelper.removeBlock()
    }
    
    private func setupTimer() {
        // Build the timer on the Main thread asynchronously to ensure the run loop is active
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            
            let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            // Add timer to the Main Run Loop with .common mode to survive modal sheets/events
            RunLoop.main.add(t, forMode: .common)
            self.timer = t
        }
    }
    
    private func tick() {
        let currentMonotonic = getMonotonicTime()
        let delta = currentMonotonic - lastTickMonotonic
        lastTickMonotonic = currentMonotonic
        
        guard state.isActive else { return }
        
        // Anti-Tampering Check: Re-verify hosts file contents every second
        if HostsHelper.hasWritePermission() {
            do {
                let currentHosts = try String(contentsOfFile: HostsHelper.hostsPath, encoding: .utf8)
                var needsReapply = !currentHosts.contains(HostsHelper.startMarker)
                
                if !needsReapply {
                    for domain in state.blockedDomains {
                        let cleaned = domain.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "http://", with: "")
                            .replacingOccurrences(of: "https://", with: "")
                        
                        if !cleaned.isEmpty {
                            let blockLine = "127.0.0.1 \(cleaned)"
                            if !currentHosts.contains(blockLine) {
                                needsReapply = true
                                break
                            }
                        }
                    }
                }
                
                if needsReapply {
                    try HostsHelper.applyBlock(domains: state.blockedDomains)
                    print("Oathkeeper [Anti-Tamper]: Re-applied blocked domains to /etc/hosts.")
                }
            } catch {
                print("Oathkeeper [Anti-Tamper Warning]: Error verifying hosts file: \(error)")
            }
        }
        
        // 1. Process standard block countdown
        if state.remainingSeconds > 0 {
            let validDelta = max(0, min(delta, 10.0))
            state.remainingSeconds -= validDelta
            
            if state.remainingSeconds <= 0 {
                state.remainingSeconds = 0
                stopBlock()
                return
            }
        }
        
        state.lastSavedSystemTime = Date()
        state.lastSavedMonotonicTime = currentMonotonic
        saveState()
    }
    
    /// Syncs block progress with network time to account for system shut-down/sleep intervals securely.
    func syncWithNetworkTime() {
        guard state.isActive, state.remainingSeconds > 0 else { return }
        
        NetworkTime.fetchUTC { [weak self] currentDate in
            guard let self = self, let networkDate = currentDate else { return }
            
            DispatchQueue.main.async {
                // 1. Sync primary block timer
                if let startNet = self.state.startNetworkTime {
                    let elapsed = networkDate.timeIntervalSince(startNet)
                    if elapsed > 0 {
                        self.state.remainingSeconds = max(0, self.state.totalDuration - elapsed)
                    }
                } else {
                    // Align startNetworkTime retrospectively if started offline
                    let elapsedLocal = Date().timeIntervalSince(self.state.startSystemTime)
                    self.state.startNetworkTime = networkDate.addingTimeInterval(-elapsedLocal)
                }
                
                self.state.lastSavedNetworkTime = networkDate
                self.state.lastSavedSystemTime = Date()
                
                if self.state.remainingSeconds <= 0 {
                    self.stopBlock()
                } else {
                    self.saveState()
                }
            }
        }
    }
    
    func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateFileUrl)
        } catch {
            print("Oathkeeper [TimerManager]: Error saving state: \(error)")
        }
    }
    
    private func loadState() {
        guard FileManager.default.fileExists(atPath: stateFileUrl.path) else { return }
        do {
            let data = try Data(contentsOf: stateFileUrl)
            let loadedState = try JSONDecoder().decode(BlockState.self, from: data)
            self.state = loadedState
            
            // Check if local system clock is behind the saved time (possible time rollback)
            if Date() < state.lastSavedSystemTime {
                print("Oathkeeper [Warning]: Clock tampering detected. Block remains locked.")
            }
        } catch {
            print("Oathkeeper [TimerManager]: Error loading state: \(error)")
        }
    }
}
