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

extension Volume {
    init?(id: String, name: String, isInternal: Bool, isReadOnly: Bool?, totalBytes: Int?, freeBytes: Int?) {
        guard isReadOnly == false, let totalBytes, totalBytes > 0, let freeBytes else { return nil }
        self.init(
            id: id, name: name, isInternal: isInternal,
            totalBytes: Int64(totalBytes), freeBytes: Int64(min(max(freeBytes, 0), totalBytes))
        )
    }
}

struct VolumeSnapshot: Sendable {
    let primary: Volume?
    let secondary: Volume?
    let canCycle: Bool
}

actor VolumeReader {
    static let shared = VolumeReader()

    private let loadVolumes: @Sendable () -> [Volume]
    private let defaults: UserDefaults
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

    init(loadVolumes: (@Sendable () -> [Volume])? = nil, selectionSuite: String? = nil) {
        self.loadVolumes = loadVolumes ?? Self.readMountedVolumes
        self.defaults = selectionSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func snapshot() -> VolumeSnapshot {
        let volumes = loadVolumes()
        let choices = volumes.dropFirst()
        let selected = defaults.string(forKey: selectionKey)
        return VolumeSnapshot(
            primary: volumes.first,
            secondary: choices.first { $0.id == selected } ?? choices.first,
            canCycle: choices.count > 1
        )
    }

    func selectNext() {
        let choices = loadVolumes().dropFirst()
        guard choices.count > 1 else { return }

        let selected = defaults.string(forKey: selectionKey)
        let current = choices.firstIndex { $0.id == selected } ?? choices.startIndex
        let next = choices.index(after: current)
        let nextVolume = choices[next == choices.endIndex ? choices.startIndex : next]
        defaults.set(nextVolume.id, forKey: selectionKey)
    }

    private static func readMountedVolumes() -> [Volume] {
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

    private static func volume(at url: URL) -> Volume? {
        guard let values = try? url.resourceValues(forKeys: Self.keys) else {
            return nil
        }

        return Volume(
            id: values.volumeUUIDString ?? url.path,
            name: values.volumeLocalizedName ?? url.lastPathComponent,
            isInternal: values.volumeIsInternal == true,
            isReadOnly: values.volumeIsReadOnly,
            totalBytes: values.volumeTotalCapacity,
            freeBytes: values.volumeAvailableCapacity
        )
    }
}
