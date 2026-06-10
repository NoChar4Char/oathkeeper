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

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the app to become a regular active foreground application
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and customize the main window on startup
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.title = "Oathkeeper"
                window.setContentSize(NSSize(width: 500, height: 620))
                
                // Remove resizing and minimizing to keep the UI fixed and minimal
                window.styleMask.remove(.resizable)
                window.styleMask.remove(.miniaturizable)
                
                // Centering and promoting window to frontmost/active input state
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // If a block is active, do not allow closing the window to quit the app easily
        if TimerManager.shared.state.isActive {
            return false
        }
        return true
    }
}
