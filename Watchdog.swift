import Foundation

guard CommandLine.arguments.count >= 3 else {
    print("Usage: oathkeeper-watchdog <parentPID> <appExecutablePath>")
    exit(1)
}

let parentPID = Int32(CommandLine.arguments[1])!
let appPath = CommandLine.arguments[2]
let stateFileUrl = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".oathkeeper_state.json")

print("Oathkeeper Watchdog: Monitoring PID \(parentPID), Target \(appPath)")

while true {
    // 1. Check if parent PID is still running
    let isRunning = kill(parentPID, 0) == 0
    if !isRunning {
        print("Oathkeeper Watchdog: Parent process died. Checking state...")
        // 2. Read state file to see if block is still active
        if FileManager.default.fileExists(atPath: stateFileUrl.path) {
            do {
                let data = try Data(contentsOf: stateFileUrl)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isActive = json["isActive"] as? Bool {
                    if isActive {
                        print("Oathkeeper Watchdog: Block is active! Relaunching main app at \(appPath)...")
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: appPath)
                        try process.run()
                    } else {
                        print("Oathkeeper Watchdog: Block is inactive. Exiting.")
                    }
                }
            } catch {
                print("Oathkeeper Watchdog: Error reading state file: \(error)")
            }
        }
        // Exit since we either relaunched or block is inactive
        exit(0)
    }
    
    // 3. Periodically check if block became inactive while running
    if FileManager.default.fileExists(atPath: stateFileUrl.path) {
        do {
            let data = try Data(contentsOf: stateFileUrl)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isActive = json["isActive"] as? Bool, !isActive {
                print("Oathkeeper Watchdog: Block is no longer active. Exiting watchdog.")
                exit(0)
            }
        } catch {}
    }
    
    Thread.sleep(forTimeInterval: 0.2)
}
