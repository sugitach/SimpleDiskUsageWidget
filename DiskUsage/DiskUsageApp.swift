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
    func applicationDidFinishLaunching(_ notification: Notification) {
        WidgetCenter.shared.reloadTimelines(ofKind: "DiskUsage")
        NSApplication.shared.terminate(nil)
    }
}
