#if DEBUG
import AppKit
import SwiftUI
import WidgetKit

@MainActor
enum WidgetTestWindow {
    static func makeIfRequested() -> NSWindow? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--widget-ui-test"),
              let size = arguments.dropFirst(flag + 1).first else { return nil }

        let family: WidgetFamily = size == "small" ? .systemSmall : .systemMedium
        let width: CGFloat = family == .systemSmall ? 164 : 344
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 164),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Widget Preview"
        window.level = .floating
        window.contentView = NSHostingView(rootView: WidgetTestView(family: family)
            .frame(width: width, height: 164))
        window.center()
        return window
    }
}

private struct WidgetTestView: View {
    let family: WidgetFamily
    @State private var entry: DiskUsageEntry?
    private let reader = VolumeReader(
        loadVolumes: {
            [
                Volume(id: "startup", name: "Macintosh HD", isInternal: true,
                       isReadOnly: false, totalBytes: 1_000_000_000_000, freeBytes: 460_000_000_000),
                Volume(id: "archive", name: "Archive", isInternal: false,
                       isReadOnly: false, totalBytes: 2_000_000_000_000, freeBytes: 140_000_000_000),
                Volume(id: "backup", name: "Backup", isInternal: false,
                       isReadOnly: false, totalBytes: 3_000_000_000_000, freeBytes: 900_000_000_000),
                Volume(id: "installer", name: "Installer", isInternal: false,
                       isReadOnly: true, totalBytes: 1_000_000_000, freeBytes: 0),
            ].compactMap { $0 }
        },
        selectionSuite: "local.diskusage.widget.ui-tests.\(UUID())"
    )

    var body: some View {
        Group {
            if let entry {
                DiskUsageView(entry: entry, family: family) {
                    Task {
                        _ = try await NextVolumeIntent(reader: reader).perform()
                        await refresh()
                    }
                }
                .padding(16)
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        entry = await DiskUsageProvider(reader: reader).timeline().entries.first
    }
}
#endif
