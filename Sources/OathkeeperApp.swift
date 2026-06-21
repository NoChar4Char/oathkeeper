import SwiftUI
import AppKit
import Darwin

class ProcessLock {
    private var fileDescriptor: Int32 = -1
    private let lockPath: String
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.lockPath = home.appendingPathComponent(".oathkeeper.lock").path
    }
    
    func acquire() -> Bool {
        fileDescriptor = open(lockPath, O_CREAT | O_WRONLY, 0o644)
        if fileDescriptor == -1 {
            return false
        }
        
        let result = flock(fileDescriptor, LOCK_EX | LOCK_NB)
        if result == -1 {
            close(fileDescriptor)
            fileDescriptor = -1
            return false
        }
        
        return true
    }
    
    deinit {
        if fileDescriptor != -1 {
            flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
        }
    }
}

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
    static let sharedLock = ProcessLock()
    var statusBarItem: NSStatusItem?
    var window: NSWindow?
    private var windowObserver: Any?
    
    override init() {
        super.init()
        // Prevent duplicate processes atomically using a lockfile
        if !AppDelegate.sharedLock.acquire() {
            exit(0)
        }
        
        // Fallback: standard workspace-based duplicate prevention
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
        
        setupWindowObserver()
        self.setupStatusBar()
    }
    
    func getMainWindow() -> NSWindow? {
        if let w = self.window {
            return w
        }
        
        // Scan for the main SwiftUI window
        for w in NSApplication.shared.windows {
            if w.title == "Oathkeeper" || w.identifier?.rawValue == "main" {
                self.window = w
                w.delegate = self
                
                // Configure window styles and size
                w.title = "Oathkeeper"
                w.setContentSize(NSSize(width: 500, height: 680))
                w.styleMask.remove(.resizable)
                w.styleMask.insert(.miniaturizable)
                w.styleMask.insert(.closable)
                return w
            }
        }
        return nil
    }
    
    func setupWindowObserver() {
        // Try to capture the window immediately if it exists
        if let w = getMainWindow() {
            w.makeKeyAndOrderFront(nil)
            w.center()
            NSApp.activate(ignoringOtherApps: true)
            setupOcclusionObserver(for: w)
            return
        }
        
        // Listen dynamically for when SwiftUI finishes instantiating the window scene
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let w = self.getMainWindow() {
                if let obs = self.windowObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self.windowObserver = nil
                }
                w.makeKeyAndOrderFront(nil)
                w.center()
                NSApp.activate(ignoringOtherApps: true)
                self.setupOcclusionObserver(for: w)
            }
        }
    }
    
    func setupOcclusionObserver(for window: NSWindow) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { notification in
            if let w = notification.object as? NSWindow {
                let isVisible = w.occlusionState.contains(.visible)
                TimerManager.shared.setWindowVisibility(isVisible)
            }
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
        guard let window = getMainWindow() else { return }
        
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
        if !TimerManager.shared.isBlockingActive {
            NSApplication.shared.terminate(nil)
            return true
        }
        // Hide the window instead of closing/destroying it
        sender.orderOut(nil)
        return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If a block is active, do not allow terminating the application (e.g. via Cmd+Q)
        if TimerManager.shared.isBlockingActive {
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
        guard let window = getMainWindow() else { return true }
        if window.isMiniaturized {
            window.deminiaturize(nil as Any?)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Unlock files synchronously on exit so the application can be managed or deleted when not running
        TimerManager.shared.unlockAppBundle()
    }
}
