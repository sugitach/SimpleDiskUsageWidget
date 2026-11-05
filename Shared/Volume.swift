import Foundation
import OSLog

struct Volume: Identifiable, Sendable {
    let id: String
    let name: String
    let isInternal: Bool
    let totalBytes: Int64
    let freeBytes: Int64

    var freeFraction: Double {
        Double(freeBytes) / Double(totalBytes)
    }
}

struct VolumeSnapshot: Sendable {
    let primary: Volume?
    let secondary: Volume?
    let canCycle: Bool
}

actor VolumeReader {
    static let shared = VolumeReader()

    private let selectionKey = "selectedSecondaryVolume"
    private static let logger = Logger(subsystem: "local.diskusage.widget", category: "VolumeReader")
    private static let keys: Set<URLResourceKey> = [
        .volumeLocalizedNameKey,
        .volumeIsInternalKey,
        .volumeIsReadOnlyKey,
        .volumeUUIDStringKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
    ]

    func snapshot() -> VolumeSnapshot {
        let volumes = read()
        let choices = volumes.dropFirst()
        let selected = UserDefaults.standard.string(forKey: selectionKey)
        return VolumeSnapshot(
            primary: volumes.first,
            secondary: choices.first { $0.id == selected } ?? choices.first,
            canCycle: choices.count > 1
        )
    }

    func selectNext() {
        let choices = read().dropFirst()
        guard choices.count > 1 else { return }

        let selected = UserDefaults.standard.string(forKey: selectionKey)
        let current = choices.firstIndex { $0.id == selected } ?? choices.startIndex
        let next = choices.index(after: current)
        let nextVolume = choices[next == choices.endIndex ? choices.startIndex : next]
        UserDefaults.standard.set(nextVolume.id, forKey: selectionKey)
    }

    private func read() -> [Volume] {
        let startup = URL(fileURLWithPath: "/", isDirectory: true)
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(Self.keys),
            options: .skipHiddenVolumes
        ) ?? []

        // The startup volume's writable Data volume is normally hidden.
        let data = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let startupVolume = volume(at: startup) ?? volume(at: data)
        let candidates = mounted
            .filter { $0.path != startup.path }
            .compactMap { volume(at: $0) }
        let sorted = ([startupVolume].compactMap { $0 } + candidates).sorted { lhs, rhs in
            if lhs.isInternal != rhs.isInternal { return lhs.isInternal }
            if let startupVolume, (lhs.id == startupVolume.id) != (rhs.id == startupVolume.id) {
                return lhs.id == startupVolume.id
            }
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            return nameOrder == .orderedSame ? lhs.id < rhs.id : nameOrder == .orderedAscending
        }

        var seen = Set<Volume.ID>()
        let volumes = sorted.filter { seen.insert($0.id).inserted }
        Self.logger.info("Refreshed \(volumes.count, privacy: .public) writable volumes")
        return volumes
    }

    private func volume(at url: URL) -> Volume? {
        guard let values = try? url.resourceValues(forKeys: Self.keys),
              values.volumeIsReadOnly == false,
              let total = values.volumeTotalCapacity, total > 0,
              let free = values.volumeAvailableCapacity else {
            return nil
        }

        return Volume(
            id: values.volumeUUIDString ?? url.path,
            name: values.volumeLocalizedName ?? url.lastPathComponent,
            isInternal: values.volumeIsInternal == true,
            totalBytes: Int64(total),
            freeBytes: Int64(min(max(free, 0), total))
        )
    }
}
