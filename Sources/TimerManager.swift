import Foundation
import Combine
import AppKit

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
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil)
                return
            }
            
            let dateStr: String?
            if #available(macOS 10.15, iOS 13.0, *) {
                dateStr = httpResponse.value(forHTTPHeaderField: "Date")
            } else {
                dateStr = (httpResponse.allHeaderFields["Date"] as? String) ?? (httpResponse.allHeaderFields["date"] as? String)
            }
            
            guard let validDateStr = dateStr else {
                completion(nil)
                return
            }
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let date = formatter.date(from: validDateStr) {
                completion(date)
                return
            }
            
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            if let date = formatter.date(from: validDateStr) {
                completion(date)
                return
            }
            
            formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
            if let date = formatter.date(from: validDateStr) {
                completion(date)
                return
            }
            
            completion(nil)
        }
        task.resume()
    }
}

struct ScheduleRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = "Untitled Schedule"
    var isEnabled: Bool = true
    var activeDays: Set<Int> = [2, 3, 4, 5, 6] // Monday-Friday (Sunday = 1, Monday = 2, ...)
    var startHour: Int = 10
    var startMinute: Int = 0
    var endHour: Int = 21
    var endMinute: Int = 0
    
    func isActive(at date: Date) -> Bool {
        guard isEnabled else { return false }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentSecond = calendar.component(.second, from: date)
        
        let startTotalSeconds = startHour * 3600 + startMinute * 60
        let endTotalSeconds = endHour * 3600 + endMinute * 60
        let currentTotalSeconds = currentHour * 3600 + currentMinute * 60 + currentSecond
        
        if startTotalSeconds <= endTotalSeconds {
            // Same-day block: current day must be in activeDays
            guard activeDays.contains(weekday) else { return false }
            return currentTotalSeconds >= startTotalSeconds && currentTotalSeconds <= endTotalSeconds
        } else {
            // Overnight block:
            // Case A: we are in the starting portion of the block (from start time to midnight)
            if currentTotalSeconds >= startTotalSeconds {
                return activeDays.contains(weekday)
            }
            // Case B: we are in the ending portion of the block (from midnight to end time)
            if currentTotalSeconds <= endTotalSeconds {
                let previousWeekday = weekday == 1 ? 7 : weekday - 1
                return activeDays.contains(previousWeekday)
            }
            return false
        }
    }
    
    static func == (lhs: ScheduleRule, rhs: ScheduleRule) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.activeDays == rhs.activeDays &&
               lhs.startHour == rhs.startHour &&
               lhs.startMinute == rhs.startMinute &&
               lhs.endHour == rhs.endHour &&
               lhs.endMinute == rhs.endMinute
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
    
    var blockSystemUtilities: Bool = true // User preference to block Terminal/Activity Monitor
    var blockTerminal: Bool = true
    var blockActivityMonitor: Bool = true
    
    var bypassMethod: String = "typing" // default to typing (challenge), timer is removed
    var bypassDuration: TimeInterval = 1200 // default 20 minutes (1200 seconds)
    
    // For emergency bypass tracking
    var bypassIsTriggered: Bool = false
    var bypassRemainingSeconds: TimeInterval = 0
    var bypassStartNetworkTime: Date? = nil
    var lastBypassSavedSystemTime: Date = Date()
    
    // Recurring schedules configuration
    var schedules: [ScheduleRule] = []
    var lastBypassCompletedTime: Date? = nil
    var use24HourMode: Bool = false
    
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
        case blockSystemUtilities
        case blockTerminal
        case blockActivityMonitor
        case bypassMethod
        case bypassDuration
        case bypassIsTriggered
        case bypassRemainingSeconds
        case bypassStartNetworkTime
        case lastBypassSavedSystemTime
        case schedules
        case lastBypassCompletedTime
        case use24HourMode
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
        blockSystemUtilities = try container.decodeIfPresent(Bool.self, forKey: .blockSystemUtilities) ?? true
        blockTerminal = try container.decodeIfPresent(Bool.self, forKey: .blockTerminal) ?? true
        blockActivityMonitor = try container.decodeIfPresent(Bool.self, forKey: .blockActivityMonitor) ?? true
        let methodDecoded = try container.decodeIfPresent(String.self, forKey: .bypassMethod) ?? "typing"
        bypassMethod = methodDecoded == "timer" ? "typing" : methodDecoded
        bypassDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .bypassDuration) ?? 1200
        bypassIsTriggered = try container.decodeIfPresent(Bool.self, forKey: .bypassIsTriggered) ?? false
        bypassRemainingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .bypassRemainingSeconds) ?? 0
        bypassStartNetworkTime = try container.decodeIfPresent(Date.self, forKey: .bypassStartNetworkTime)
        lastBypassSavedSystemTime = try container.decodeIfPresent(Date.self, forKey: .lastBypassSavedSystemTime) ?? Date()
        schedules = try container.decodeIfPresent([ScheduleRule].self, forKey: .schedules) ?? []
        lastBypassCompletedTime = try container.decodeIfPresent(Date.self, forKey: .lastBypassCompletedTime)
        use24HourMode = try container.decodeIfPresent(Bool.self, forKey: .use24HourMode) ?? false
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
        try container.encode(blockSystemUtilities, forKey: .blockSystemUtilities)
        try container.encode(blockTerminal, forKey: .blockTerminal)
        try container.encode(blockActivityMonitor, forKey: .blockActivityMonitor)
        try container.encode(bypassMethod, forKey: .bypassMethod)
        try container.encode(bypassDuration, forKey: .bypassDuration)
        try container.encode(bypassIsTriggered, forKey: .bypassIsTriggered)
        try container.encode(bypassRemainingSeconds, forKey: .bypassRemainingSeconds)
        try container.encode(bypassStartNetworkTime, forKey: .bypassStartNetworkTime)
        try container.encode(lastBypassSavedSystemTime, forKey: .lastBypassSavedSystemTime)
        try container.encode(schedules, forKey: .schedules)
        try container.encode(lastBypassCompletedTime, forKey: .lastBypassCompletedTime)
        try container.encode(use24HourMode, forKey: .use24HourMode)
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
    @Published var pendingScheduleConfirmation: ScheduleRule? = nil
    var confirmedActiveSchedules: Set<UUID> = []
    @Published var blockStartTimestamp: Date? = nil
    
    private var isEngineRunning = false
    
    var isBlockingActive: Bool {
        if state.isActive && state.remainingSeconds > 0 {
            return true
        }
        
        // If the emergency bypass has voided today's schedules, then no schedules are active
        if isTodayVoided() {
            return false
        }
        
        let now = Date()
        for rule in state.schedules {
            if rule.isActive(at: now) {
                if let pending = pendingScheduleConfirmation, pending.id == rule.id {
                    continue
                }
                return true
            }
        }
        
        return false
    }
    
    func isTodayVoided() -> Bool {
        guard let bypassTime = state.lastBypassCompletedTime else { return false }
        guard state.schedules.contains(where: { $0.isEnabled }) else { return false }
        return Calendar.current.isDate(bypassTime, inSameDayAs: Date())
    }
    
    func remainingSecondsForActiveSchedule() -> TimeInterval {
        let now = Date()
        var maxRemaining: TimeInterval = 0
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentSecond = calendar.component(.second, from: now)
        let currentTotalSeconds = currentHour * 3600 + currentMinute * 60 + currentSecond
        
        for rule in state.schedules {
            if rule.isActive(at: now) {
                let startTotalSeconds = rule.startHour * 3600 + rule.startMinute * 60
                let endTotalSeconds = rule.endHour * 3600 + rule.endMinute * 60
                
                var remaining: TimeInterval = 0
                if startTotalSeconds <= endTotalSeconds {
                    remaining = TimeInterval(endTotalSeconds - currentTotalSeconds)
                } else {
                    // Crosses midnight
                    if currentTotalSeconds >= startTotalSeconds {
                        remaining = TimeInterval((24 * 3600 - currentTotalSeconds) + endTotalSeconds)
                    } else {
                        remaining = TimeInterval(endTotalSeconds - currentTotalSeconds)
                    }
                }
                maxRemaining = max(maxRemaining, remaining)
            }
        }
        return maxRemaining
    }
    
    func totalDurationForActiveSchedule() -> TimeInterval {
        let now = Date()
        var maxDuration: TimeInterval = 1
        for rule in state.schedules {
            if rule.isActive(at: now) {
                let startTotalSeconds = rule.startHour * 3600 + rule.startMinute * 60
                let endTotalSeconds = rule.endHour * 3600 + rule.endMinute * 60
                
                var duration: TimeInterval = 0
                if startTotalSeconds <= endTotalSeconds {
                    duration = TimeInterval(endTotalSeconds - startTotalSeconds)
                } else {
                    duration = TimeInterval((24 * 3600 - startTotalSeconds) + endTotalSeconds)
                }
                maxDuration = max(maxDuration, duration)
            }
        }
        return maxDuration
    }
    
    func checkSchedulesStartingSoon() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentSecond = calendar.component(.second, from: now)
        let currentTotalSeconds = currentHour * 3600 + currentMinute * 60 + currentSecond
        
        for rule in state.schedules {
            guard rule.isEnabled else { continue }
            
            if rule.isActive(at: now) {
                if isTodayVoided() {
                    return "Active schedule '\(rule.name)' is suspended (bypassed today)."
                } else {
                    return "Schedule '\(rule.name)' is active now!"
                }
            }
            
            guard rule.activeDays.contains(weekday) else { continue }
            
            let startTotalSeconds = rule.startHour * 3600 + rule.startMinute * 60
            let diff = startTotalSeconds - currentTotalSeconds
            
            if diff > 0 && diff <= 300 {
                let mins = Int(ceil(Double(diff) / 60.0))
                return "Block '\(rule.name)' starts in \(mins) minute\(mins == 1 ? "" : "s")!"
            }
        }
        return nil
    }
    
    func addSchedule() {
        unlockStateFile()
        let newRule = ScheduleRule()
        state.schedules.append(newRule)
        saveState()
        
        if isBlockingActive {
            lockStateFile()
        }
    }
    
    func deleteSchedule(_ id: UUID) {
        unlockStateFile()
        state.schedules.removeAll { $0.id == id }
        saveState()
        
        if isBlockingActive {
            lockStateFile()
        }
    }
    
    func resumeScheduleBlock() {
        unlockStateFile()
        state.lastBypassCompletedTime = nil
        saveState()
        
        if isBlockingActive {
            lockStateFile()
        }
    }
    
    func confirmPendingSchedule() {
        if let pending = pendingScheduleConfirmation {
            confirmedActiveSchedules.insert(pending.id)
        }
        pendingScheduleConfirmation = nil
        state.lastBypassCompletedTime = nil
        saveState()
    }
    
    func remainingGraceSeconds() -> Int {
        guard let start = blockStartTimestamp else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, Int(ceil(5.0 - elapsed)))
    }
    
    func instantUnblock() {
        print("Oathkeeper: Instant unblock triggered during 5-second grace period.")
        unlockStateFile()
        state.isActive = false
        state.remainingSeconds = 0
        state.lastBypassCompletedTime = Date() // voids schedules for today
        saveState()
        
        // Deactivate engine immediately
        unlockLaunchAgent()
        unlockAppBundle()
        unregisterLaunchAgent()
        stopBlockingEngine()
        isEngineRunning = false
        blockStartTimestamp = nil
    }
    
    func formatDurationDescription(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        var parts: [String] = []
        if days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 || parts.isEmpty {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
    

    
    private var timer: Timer?
    private var lastTickMonotonic: TimeInterval = 0
    
    private var hostsFileMonitor: DispatchSourceFileSystemObject?
    private var hostsDescriptor: Int32 = -1
    private var hostsTickCount = 0
    
    private init() {
        loadState()
        for rule in state.schedules {
            confirmedActiveSchedules.insert(rule.id)
        }
        lastTickMonotonic = getMonotonicTime()
        
        setupTimer()
        
        // Always lock the app bundle on startup to prevent trashing while open
        lockAppBundle()
        
        // 1. Catch up manual block timer if active
        if state.isActive {
            let localElapsed = Date().timeIntervalSince(state.lastSavedSystemTime)
            if localElapsed > 0 && state.remainingSeconds - localElapsed <= 0 {
                print("Oathkeeper [TimerManager]: Block expired while app was inactive. Cleaning up.")
                state.isActive = false
                state.remainingSeconds = 0
            } else if localElapsed > 0 {
                state.remainingSeconds = max(0, state.remainingSeconds - localElapsed)
            }
        }
        
        // 2. Set the engine state correctly based on initial blocking status
        let currentlyBlocking = isBlockingActive
        if currentlyBlocking {
            print("Oathkeeper [TimerManager]: Startup detected active block. Activating engine.")
            startBlockingEngine()
            if state.isActive {
                syncWithNetworkTime()
            }
            registerLaunchAgent()
            lockLaunchAgent()
            isEngineRunning = true
        } else {
            print("Oathkeeper [TimerManager]: Startup detected inactive block. Ensuring engine is stopped.")
            unlockLaunchAgent()
            unlockAppBundle()
            unregisterLaunchAgent()
            stopBlockingEngine()
            isEngineRunning = false
        }
        
        saveState()
        
        // Register sleep/wake notification observer to automatically catch up and sync the timer
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("Oathkeeper [TimerManager]: didWakeNotification received. Catching up timer...")
            self.catchUpTimerLocal()
            self.syncWithNetworkTime()
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
        let maxSeconds = (29.0 * 24.0 * 3600.0) + (23.0 * 3600.0) + (59.0 * 60.0)
        let finalDuration = min(maxSeconds, duration)
        
        let currentMonotonic = getMonotonicTime()
        state.isActive = true
        state.remainingSeconds = finalDuration
        state.totalDuration = finalDuration
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
        blockStartTimestamp = Date()
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
        
        // Register launch agent to auto-restart on force quits
        registerLaunchAgent()
        
        // Lock app bundle and launch agent plist to prevent deletion
        lockAppBundle()
        lockLaunchAgent()
    }
    
    /// Extends the active block session by a given duration.
    func extendBlock(by duration: TimeInterval) {
        guard state.isActive else { return }
        
        // Unlock state file briefly to save
        unlockStateFile()
        
        let maxSeconds = (29.0 * 24.0 * 3600.0) + (23.0 * 3600.0) + (59.0 * 60.0)
        let newRemaining = min(maxSeconds, state.remainingSeconds + duration)
        let addedAmount = newRemaining - state.remainingSeconds
        
        state.remainingSeconds = newRemaining
        state.totalDuration += addedAmount
        saveState()
        
        // Re-lock
        lockStateFile()
    }
    
    /// Stops the active block session.
    func stopBlock() {
        state.isActive = false
        state.remainingSeconds = 0
        state.lastSavedNetworkTime = nil
        state.bypassIsTriggered = false
        state.bypassRemainingSeconds = 0
        state.bypassStartNetworkTime = nil
        
        // Unlock state file first so we can save the inactive state and keep it unlocked
        unlockStateFile()
        
        saveState()
        stopBlockingEngine()
        
        // Unlock files to allow deletion of launch agent
        unlockLaunchAgent()
        unlockAppBundle()
        
        // Clean up launch agent registration
        unregisterLaunchAgent()
        
        // Re-lock app bundle since the app process is still running
        lockAppBundle()
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
    
    func completeBypass() {
        if state.isActive {
            stopBlock()
        } else {
            // Suspends schedules for the rest of the day
            unlockStateFile()
            state.lastBypassCompletedTime = Date()
            saveState()
            
            if !isBlockingActive {
                print("Oathkeeper [TimerManager]: Schedule block voided via emergency bypass. Deactivating engine.")
                unlockLaunchAgent()
                unlockAppBundle()
                unregisterLaunchAgent()
                stopBlockingEngine()
                isEngineRunning = false
            }
        }
    }
    
    /// Enable strict blocklist locking. (Legacy support, unused)
    func enableLockLists() {
        state.lockLists = true
        saveState()
    }
    
    /// Toggles the Terminal blocking state dynamically.
    func toggleTerminalBlocking() {
        state.blockTerminal.toggle()
        saveState()
        
        if isBlockingActive {
            AppBlocker.shared.startBlocking(apps: state.blockedApps, blockTerminal: state.blockTerminal, blockActivityMonitor: state.blockActivityMonitor)
        }
    }
    
    /// Toggles the Activity Monitor blocking state dynamically.
    func toggleActivityMonitorBlocking() {
        state.blockActivityMonitor.toggle()
        saveState()
        
        if isBlockingActive {
            AppBlocker.shared.startBlocking(apps: state.blockedApps, blockTerminal: state.blockTerminal, blockActivityMonitor: state.blockActivityMonitor)
        }
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
        
        // Prevent adding our own app
        let lower = trimmed.lowercased()
        if lower == "oathkeeper" || lower.contains("oathkeeper") { return }
        
        if !state.blockedApps.contains(trimmed) {
            state.blockedApps.append(trimmed)
            saveState()
            
            // If block is currently active, immediately block the new app
            if isBlockingActive {
                AppBlocker.shared.startBlocking(apps: state.blockedApps, blockTerminal: state.blockTerminal, blockActivityMonitor: state.blockActivityMonitor)
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
        AppBlocker.shared.startBlocking(apps: state.blockedApps, blockTerminal: state.blockTerminal, blockActivityMonitor: state.blockActivityMonitor)
        
        // Hosts-file website blocking (requires write permission or root)
        if HostsHelper.hasWritePermission() {
            try? HostsHelper.applyBlock(domains: state.blockedDomains)
            startMonitoringHostsFile()
        } else {
            print("Oathkeeper [TimerManager]: hosts file is not writable. Running in app-block-only mode.")
        }
    }
    
    private func stopBlockingEngine() {
        AppBlocker.shared.stopBlocking()
        stopMonitoringHostsFile()
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
        
        if let start = blockStartTimestamp {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= 5.0 {
                blockStartTimestamp = nil
            } else {
                objectWillChange.send()
            }
        }
        
        // 1. Process standard manual block countdown
        if state.isActive && state.remainingSeconds > 0 {
            let localElapsed = Date().timeIntervalSince(state.lastSavedSystemTime)
            if localElapsed > 3.0 {
                print("Oathkeeper [TimerManager]: Gap of \(localElapsed)s detected in tick. Catching up local timer...")
                state.remainingSeconds = max(0, state.remainingSeconds - localElapsed)
                syncWithNetworkTime()
            } else {
                let validDelta = max(0, min(delta, 10.0))
                state.remainingSeconds -= validDelta
            }
            
            if state.remainingSeconds <= 0 {
                state.remainingSeconds = 0
                state.isActive = false
            }
        }
        
        // 2. Anti-Tampering Check: Re-verify hosts file contents every 60 seconds as a slow fallback check
        if isBlockingActive {
            hostsTickCount += 1
            if hostsTickCount >= 60 {
                hostsTickCount = 0
                verifyAndReapplyHostsBlock()
            }
        } else {
            hostsTickCount = 0
        }
        
        // 3. Unified engine state transition check
        let currentlyBlocking = isBlockingActive
        if currentlyBlocking != isEngineRunning {
            if currentlyBlocking {
                print("Oathkeeper [TimerManager]: Scheduled/Manual block started. Activating engine.")
                if blockStartTimestamp == nil {
                    blockStartTimestamp = Date()
                }
                startBlockingEngine()
                registerLaunchAgent()
                lockAppBundle()
                lockLaunchAgent()
                isEngineRunning = true
            } else {
                print("Oathkeeper [TimerManager]: Block ended. Deactivating engine.")
                blockStartTimestamp = nil
                unlockLaunchAgent()
                unlockAppBundle()
                unregisterLaunchAgent()
                stopBlockingEngine()
                isEngineRunning = false
            }
            saveState()
        }
        
        if state.isActive {
            state.lastSavedSystemTime = Date()
            state.lastSavedMonotonicTime = currentMonotonic
            // Save state during active manual blocks only occasionally to persist remaining time
            hostsTickCount += 1
            if hostsTickCount % 30 == 0 {
                saveState()
            }
        }
    }
    
    /// Re-verifies hosts file contents and re-applies domain blocks if missing.
    func verifyAndReapplyHostsBlock() {
        guard HostsHelper.hasWritePermission() else { return }
        let blockedDomains = state.blockedDomains
        DispatchQueue.global(qos: .utility).async {
            do {
                let currentHosts = try String(contentsOfFile: HostsHelper.hostsPath, encoding: .utf8)
                var needsReapply = !currentHosts.contains(HostsHelper.startMarker)
                
                if !needsReapply {
                    for domain in blockedDomains {
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
                    try HostsHelper.applyBlock(domains: blockedDomains)
                    print("Oathkeeper [Anti-Tamper]: Re-applied blocked domains to /etc/hosts.")
                }
            } catch {
                print("Oathkeeper [Anti-Tamper Warning]: Error verifying hosts file: \(error)")
            }
        }
    }
    
    /// Start monitoring the /etc/hosts file for real-time change notifications
    func startMonitoringHostsFile() {
        stopMonitoringHostsFile()
        
        let path = HostsHelper.hostsPath
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("Oathkeeper [HostsMonitor]: Failed to open /etc/hosts for monitoring.")
            return
        }
        self.hostsDescriptor = fd
        
        let queue = DispatchQueue.global(qos: .utility)
        let monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )
        
        monitor.setEventHandler { [weak self] in
            guard let self = self else { return }
            print("Oathkeeper [HostsMonitor]: Change event detected in /etc/hosts!")
            self.verifyAndReapplyHostsBlock()
            
            // Read event data to see if deleted or renamed
            let flags = monitor.data
            if flags.contains(.delete) || flags.contains(.rename) {
                print("Oathkeeper [HostsMonitor]: Hosts file was replaced, recreating monitor...")
                DispatchQueue.main.async {
                    self.startMonitoringHostsFile()
                }
            }
        }
        
        monitor.setCancelHandler {
            close(fd)
        }
        
        monitor.resume()
        self.hostsFileMonitor = monitor
        print("Oathkeeper [HostsMonitor]: Started monitoring /etc/hosts.")
    }
    
    /// Stop monitoring the /etc/hosts file
    func stopMonitoringHostsFile() {
        if hostsFileMonitor != nil {
            hostsFileMonitor?.cancel()
            hostsFileMonitor = nil
            print("Oathkeeper [HostsMonitor]: Stopped monitoring /etc/hosts.")
        }
        hostsDescriptor = -1
    }
    
    private func catchUpTimerLocal() {
        guard state.isActive, state.remainingSeconds > 0 else { return }
        let localElapsed = Date().timeIntervalSince(state.lastSavedSystemTime)
        if localElapsed > 3.0 {
            print("Oathkeeper [TimerManager]: Catching up local timer on wake event: \(localElapsed)s")
            state.remainingSeconds = max(0, state.remainingSeconds - localElapsed)
            state.lastSavedSystemTime = Date()
            saveState()
        }
    }
    
    /// Syncs block progress with network time to account for system shut-down/sleep intervals securely.
    func syncWithNetworkTime() {
        guard state.isActive, state.remainingSeconds > 0 else { return }
        
        print("Oathkeeper [TimerManager]: Starting network time synchronization...")
        startBlockingEngine()
        registerLaunchAgent()
        lockAppBundle()
        lockLaunchAgent()
        
        NetworkTime.fetchUTC { [weak self] currentDate in
            guard let self = self else { return }
            guard let networkDate = currentDate else {
                print("Oathkeeper [TimerManager]: Network time synchronization failed (could not fetch UTC date).")
                return
            }
            
            DispatchQueue.main.async {
                print("Oathkeeper [TimerManager]: Network UTC date fetched: \(networkDate). Current local: \(Date())")
                
                // 1. Sync primary block timer
                if let startNet = self.state.startNetworkTime {
                    let elapsed = networkDate.timeIntervalSince(startNet)
                    print("Oathkeeper [TimerManager]: startNetworkTime exists. Elapsed: \(elapsed)s. Total duration: \(self.state.totalDuration)s.")
                    if elapsed > 0 {
                        self.state.remainingSeconds = max(0, self.state.totalDuration - elapsed)
                    }
                } else {
                    let rebooted = self.getMonotonicTime() < self.state.startMonotonicTime || self.getMonotonicTime() < self.state.lastSavedMonotonicTime
                    let elapsed: TimeInterval
                    if !rebooted {
                        elapsed = self.getMonotonicTime() - self.state.startMonotonicTime
                        print("Oathkeeper [TimerManager]: Retrospective alignment using monotonic elapsed: \(elapsed)s.")
                    } else {
                        elapsed = Date().timeIntervalSince(self.state.startSystemTime)
                        print("Oathkeeper [TimerManager]: Retrospective alignment using local system elapsed (reboot detected): \(elapsed)s.")
                    }
                    
                    let alignedStart = networkDate.addingTimeInterval(-elapsed)
                    self.state.startNetworkTime = alignedStart
                    
                    if elapsed > 0 {
                        self.state.remainingSeconds = max(0, self.state.totalDuration - elapsed)
                    }
                }
                
                self.state.lastSavedNetworkTime = networkDate
                self.state.lastSavedSystemTime = Date()
                
                print("Oathkeeper [TimerManager]: Synced remainingSeconds: \(self.state.remainingSeconds)s")
                
                if self.state.remainingSeconds <= 0 {
                    print("Oathkeeper [TimerManager]: Remaining seconds reached 0 during sync. Stopping block.")
                    self.stopBlock()
                } else {
                    self.saveState()
                }
            }
        }
    }
    
    func saveState() {
        let stateCopy = self.state // Thread-safe copy for asynchronous background writing
        let shouldLock = self.isBlockingActive // computed on main thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            do {
                // Always unlock the state file before writing, as it could have been locked previously
                self.unlockStateFile()
                
                let data = try JSONEncoder().encode(stateCopy)
                try data.write(to: self.stateFileUrl, options: .atomic)
                
                if shouldLock {
                    self.lockStateFile()
                }
            } catch {
                print("Oathkeeper [TimerManager]: Error saving state: \(error)")
            }
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
    
    /// Registers the launch agent to automatically keep the application running.
    func registerLaunchAgent() {
        guard let exePath = Bundle.main.executablePath else { return }
        
        // Do not register/load if we are running as a CLI tool or outside a .app bundle (e.g. swift run)
        // because launchd plists require a stable path to execute, and running inside .app bundle is target.
        guard exePath.contains(".app/Contents/MacOS/") else {
            print("Oathkeeper [LaunchAgent]: Skipped registering launch agent since we are running outside a .app bundle.")
            return
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let agentsDir = home.appendingPathComponent("Library/LaunchAgents")
        let plistUrl = agentsDir.appendingPathComponent("com.nochar4char.oathkeeper.plist")
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.nochar4char.oathkeeper</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(exePath)</string>
            </array>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>ThrottleInterval</key>
            <integer>1</integer>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        
        do {
            try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true, attributes: nil)
            try plistContent.write(to: plistUrl, atomically: true, encoding: .utf8)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", "-w", plistUrl.path]
            try process.run()
            process.waitUntilExit()
            print("Oathkeeper [LaunchAgent]: Registered launch agent successfully.")
        } catch {
            print("Oathkeeper [LaunchAgent]: Error registering launch agent: \(error)")
        }
    }
    
    /// Unregisters the launch agent to stop automatic relaunching.
    func unregisterLaunchAgent() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plistUrl = home.appendingPathComponent("Library/LaunchAgents/com.nochar4char.oathkeeper.plist")
        
        guard FileManager.default.fileExists(atPath: plistUrl.path) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistUrl.path]
        try? process.run()
        process.waitUntilExit()
        
        try? FileManager.default.removeItem(at: plistUrl)
        print("Oathkeeper [LaunchAgent]: Unregistered launch agent successfully.")
    }
    

    
    /// Lock the application bundle synchronously using chflags uchg.
    func lockAppBundle() {
        let appPath = Bundle.main.bundlePath
        guard appPath.contains(".app") else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["-R", "uchg", appPath]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Locked app bundle at \(appPath)")
    }
    
    /// Unlock the application bundle synchronously using chflags nouchg.
    func unlockAppBundle() {
        let appPath = Bundle.main.bundlePath
        guard appPath.contains(".app") else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["-R", "nouchg", appPath]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Unlocked app bundle at \(appPath)")
    }
    
    /// Lock the launch agent plist synchronously using chflags uchg.
    func lockLaunchAgent() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plistPath = home.appendingPathComponent("Library/LaunchAgents/com.nochar4char.oathkeeper.plist").path
        guard FileManager.default.fileExists(atPath: plistPath) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["uchg", plistPath]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Locked launch agent plist at \(plistPath)")
    }
    
    /// Unlock the launch agent plist synchronously using chflags nouchg.
    func unlockLaunchAgent() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let plistPath = home.appendingPathComponent("Library/LaunchAgents/com.nochar4char.oathkeeper.plist").path
        guard FileManager.default.fileExists(atPath: plistPath) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["nouchg", plistPath]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Unlocked launch agent plist at \(plistPath)")
    }
    
    /// Lock the state file.
    func lockStateFile() {
        let path = stateFileUrl.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["uchg", path]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Locked state file at \(path)")
    }
    
    /// Unlock the state file.
    func unlockStateFile() {
        let path = stateFileUrl.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = ["nouchg", path]
        try? process.run()
        process.waitUntilExit()
        print("Oathkeeper [App Lock]: Unlocked state file at \(path)")
    }
}
