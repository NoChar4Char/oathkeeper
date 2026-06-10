import Foundation

struct HostsHelper {
    static let hostsPath = "/etc/hosts"
    static let startMarker = "# OATHKEEPER START"
    static let endMarker = "# OATHKEEPER END"
    
    /// Checks if the process currently has write permissions to /etc/hosts.
    static func hasWritePermission() -> Bool {
        return FileManager.default.isWritableFile(atPath: hostsPath)
    }
    
    /// Reads the hosts file and strips out any previous Oathkeeper blocks.
    static func readAndCleanHosts() throws -> String {
        let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var cleanLines: [String] = []
        var insideBlock = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == startMarker {
                insideBlock = true
                continue
            }
            if trimmed == endMarker {
                insideBlock = false
                continue
            }
            if !insideBlock {
                cleanLines.append(line)
            }
        }
        
        // Remove trailing empty lines to keep it clean, but keep one at the end
        while cleanLines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            cleanLines.removeLast()
        }
        
        return cleanLines.joined(separator: "\n") + "\n"
    }
    
    /// Appends the blocked domains to the hosts file under our custom marker block.
    static func applyBlock(domains: [String]) throws {
        var cleanContent = try readAndCleanHosts()
        
        if !domains.isEmpty {
            cleanContent += "\(startMarker)\n"
            for domain in domains {
                let cleanedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "https://", with: "")
                
                if !cleanedDomain.isEmpty {
                    cleanContent += "127.0.0.1 \(cleanedDomain)\n"
                    // If it's a domain without www., also block the www. version
                    if !cleanedDomain.hasPrefix("www.") && cleanedDomain.components(separatedBy: ".").count >= 2 {
                        cleanContent += "127.0.0.1 www.\(cleanedDomain)\n"
                    }
                }
            }
            cleanContent += "\(endMarker)\n"
        }
        
        try cleanContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        flushDNS()
    }
    
    /// Removes the Oathkeeper block section entirely from the hosts file.
    static func removeBlock() throws {
        let cleanContent = try readAndCleanHosts()
        try cleanContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        flushDNS()
    }
    
    /// Flushes the DNS cache on macOS so hosts changes take effect immediately.
    static func flushDNS() {
        let process1 = Process()
        process1.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        process1.arguments = ["-flushcache"]
        try? process1.run()
        process1.waitUntilExit()
        
        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process2.arguments = ["-HUP", "mDNSResponder"]
        try? process2.run()
        process2.waitUntilExit()
    }
}
