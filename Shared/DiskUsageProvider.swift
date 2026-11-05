import Foundation
import WidgetKit

struct DiskUsageEntry: TimelineEntry {
    let date: Date
    let volumes: VolumeSnapshot

    static var sample: Self {
        let internalDrive = Volume(
            id: "internal", name: "Macintosh HD", isInternal: true,
            totalBytes: 1_000_000_000_000, freeBytes: 460_000_000_000
        )
        let externalDrive = Volume(
            id: "external", name: String(localized: "外付けドライブ"), isInternal: false,
            totalBytes: 2_000_000_000_000, freeBytes: 1_440_000_000_000
        )
        return Self(
            date: .now,
            volumes: VolumeSnapshot(primary: internalDrive, secondary: externalDrive, canCycle: true)
        )
    }
}

struct DiskUsageProvider: TimelineProvider {
    let reader: VolumeReader

    init(reader: VolumeReader = .shared) {
        self.reader = reader
    }

    func placeholder(in context: Context) -> DiskUsageEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DiskUsageEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
        } else {
            Task { completion(await makeEntry()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DiskUsageEntry>) -> Void) {
        Task { completion(await timeline()) }
    }

    func timeline() async -> Timeline<DiskUsageEntry> {
        let entry = await makeEntry()
        let next = entry.date.addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry() async -> DiskUsageEntry {
        let volumes = await reader.snapshot()
        return DiskUsageEntry(date: .now, volumes: volumes)
    }
}
