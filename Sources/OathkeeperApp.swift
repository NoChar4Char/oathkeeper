import SwiftUI
import AppKit

@main
struct OathkeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("Oathkeeper", id: "main") {
            MainView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusBarItem: NSStatusItem?
    var window: NSWindow?
    
    override init() {
        super.init()
        // Prevent duplicate instances early (before SwiftUI instantiates any windows)
        let runningApps = NSWorkspace.shared.runningApplications
        let currentApp = NSRunningApplication.current
        let duplicates = runningApps.filter { app in
            if let currentId = currentApp.bundleIdentifier, let appId = app.bundleIdentifier {
                return currentId == appId && app.processIdentifier != currentApp.processIdentifier
            } else {
                return app.executableURL?.lastPathComponent == currentApp.executableURL?.lastPathComponent && 
                       app.processIdentifier != currentApp.processIdentifier
            }
        }
        if !duplicates.isEmpty {
            exit(0)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Force the app to become an accessory background agent application
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and customize the main window on startup
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                self.window = window
                window.delegate = self
                window.title = "Oathkeeper"
                window.setContentSize(NSSize(width: 500, height: 620))
                
                // Keep the UI fixed but allow closing (to hide) and minimizing
                window.styleMask.remove(.resizable)
                window.styleMask.insert(.miniaturizable)
                window.styleMask.insert(.closable)
                
                // Centering and promoting window to frontmost/active input state
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
            
            self.setupStatusBar()
        }
    }
    
    func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            // Configure a premium, clean menu bar status icon
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let image = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "Oathkeeper")?.withSymbolConfiguration(config) {
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Oathkeeper")
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: Any?) {
        toggleWindow()
    }
    
    func toggleWindow() {
        guard let window = self.window else { return }
        
        if window.isMiniaturized {
            window.deminiaturize(nil as Any?)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of closing/destroying it
        sender.orderOut(nil)
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If a block is active, do not allow terminating the application (e.g. via Cmd+Q)
        if TimerManager.shared.state.isActive {
            NSSound.beep()
            return .terminateCancel
        }
        return .terminateNow
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Run in the background via the status bar menu, do not quit when closed
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let window = self.window else { return true }
        if window.isMiniaturized {
            window.deminiaturize(nil as Any?)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
}
