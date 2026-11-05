import Foundation
import WidgetKit
import XCTest
@testable import DiskUsage

@MainActor
final class VolumeReaderTests: XCTestCase {
    private let startup = Volume(id: "startup", name: "Macintosh HD", isInternal: true,
                                 totalBytes: 1_000, freeBytes: 460)
    private let first = Volume(id: "first", name: "Archive", isInternal: false,
                               totalBytes: 2_000, freeBytes: 140)
    private let second = Volume(id: "second", name: "Backup", isInternal: false,
                                totalBytes: 3_000, freeBytes: 900)

    func testWritableVolumeReportsFreeFractionAndRejectsReadOnlyMounts() throws {
        let volume = try XCTUnwrap(Volume(
            id: "first", name: "Archive", isInternal: false,
            isReadOnly: false, totalBytes: 2_000, freeBytes: 140
        ))
        XCTAssertEqual(volume.freeFraction, 0.07, accuracy: 0.000_001)
        XCTAssertNil(Volume(id: "installer", name: "Installer", isInternal: false,
                            isReadOnly: true, totalBytes: 1_000, freeBytes: 0))
        XCTAssertNil(Volume(id: "unknown", name: "Unknown", isInternal: false,
                            isReadOnly: false, totalBytes: 0, freeBytes: 0))
    }

    func testSnapshotHandlesZeroOneAndTwoVolumes() async {
        let empty = await VolumeReader(loadVolumes: { [] }).snapshot()
        XCTAssertNil(empty.primary)
        XCTAssertNil(empty.secondary)
        XCTAssertFalse(empty.canCycle)

        let startup = startup
        let first = first
        let single = await VolumeReader(loadVolumes: { [startup] }).snapshot()
        XCTAssertEqual(single.primary?.id, startup.id)
        XCTAssertNil(single.secondary)
        XCTAssertFalse(single.canCycle)

        let pair = await VolumeReader(loadVolumes: { [startup, first] }).snapshot()
        XCTAssertEqual(pair.primary?.id, startup.id)
        XCTAssertEqual(pair.secondary?.id, first.id)
        XCTAssertFalse(pair.canCycle)
    }

    func testCycleKeepsPrimaryAndWrapsAround() async {
        let volumes = [startup, first, second]
        let suite = UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let reader = VolumeReader(loadVolumes: { volumes }, selectionSuite: suite)

        let initial = await reader.snapshot()
        XCTAssertEqual(initial.secondary?.id, first.id)
        XCTAssertTrue(initial.canCycle)

        await reader.selectNext()
        let afterClick = await reader.snapshot()
        XCTAssertEqual(afterClick.primary?.id, startup.id)
        XCTAssertEqual(afterClick.secondary?.id, second.id)

        await reader.selectNext()
        let wrapped = await reader.snapshot()
        XCTAssertEqual(wrapped.primary?.id, startup.id)
        XCTAssertEqual(wrapped.secondary?.id, first.id)
    }

    func testIntentPersistsSelectionAndMissingVolumeFallsBack() async throws {
        let volumes = [startup, first, second]
        let suite = UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let reader = VolumeReader(loadVolumes: { volumes }, selectionSuite: suite)
        _ = try await NextVolumeIntent(reader: reader).perform()

        let relaunched = await VolumeReader(loadVolumes: { volumes }, selectionSuite: suite).snapshot()
        XCTAssertEqual(relaunched.secondary?.id, second.id)

        let remaining = [startup, first]
        let disconnected = await VolumeReader(loadVolumes: { remaining }, selectionSuite: suite).snapshot()
        XCTAssertEqual(disconnected.secondary?.id, first.id)
        XCTAssertFalse(disconnected.canCycle)
    }

    func testTimelineReadsCurrentVolumesAndRequestsReload() async throws {
        let volumes = [startup, first]
        let provider = DiskUsageProvider(reader: VolumeReader(loadVolumes: { volumes }))
        let timeline = await provider.timeline()
        XCTAssertEqual(timeline.entries.count, 1)
        let entry = try XCTUnwrap(timeline.entries.first)
        XCTAssertEqual(entry.volumes.primary?.id, startup.id)
        XCTAssertEqual(entry.volumes.secondary?.freeBytes, first.freeBytes)
        XCTAssertEqual(timeline.policy, .after(entry.date.addingTimeInterval(300)))
    }
}
