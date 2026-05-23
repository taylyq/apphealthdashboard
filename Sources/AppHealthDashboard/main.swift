import Cocoa
import SwiftUI

// 1. Initialize NSApplication
let app = NSApplication.shared

// 2. Set activation policy to regular (shows Dock icon, menu bar, etc.)
app.setActivationPolicy(.regular)

// 3. Define App Delegate to handle startup and SwiftUI window loading
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load environmental config
        EnvReader.load()
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = MainView()

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("App Health Dashboard")
        window.title = "App Health Dashboard"
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// 4. Create the delegate instance and assign it
let delegate = AppDelegate()
app.delegate = delegate

// 5. Run the application loop
app.run()
