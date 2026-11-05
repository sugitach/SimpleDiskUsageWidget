import AppKit
import WidgetKit

@main
enum DiskUsageApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = RegistrationDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

private final class RegistrationDelegate: NSObject, NSApplicationDelegate {
    #if DEBUG
    private var testWindow: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let window = WidgetTestWindow.makeIfRequested() {
            testWindow = window
            NSApplication.shared.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate()
            return
        }
        if NSClassFromString("XCTestCase") != nil {
            return
        }
        #endif
        WidgetCenter.shared.reloadTimelines(ofKind: "DiskUsage")
        NSApplication.shared.terminate(nil)
    }
}
