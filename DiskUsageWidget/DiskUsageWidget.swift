import AppIntents
import SwiftUI
import WidgetKit

@main
struct DiskUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DiskUsage", provider: DiskUsageProvider()) { entry in
            DiskUsageView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("ディスク容量")
        .description("ボリュームの空き容量を表示します。下段の矢印ボタンで表示先を切り替えます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

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
        Task {
            let entry = await makeEntry()
            let next = entry.date.addingTimeInterval(5 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func makeEntry() async -> DiskUsageEntry {
        let volumes = await VolumeReader.shared.snapshot()
        return DiskUsageEntry(date: .now, volumes: volumes)
    }
}

private struct DiskUsageView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DiskUsageEntry

    var body: some View {
        let isSmall = family == .systemSmall

        if let primary = entry.volumes.primary {
            VStack(spacing: isSmall ? 5 : 8) {
                VolumeRow(volume: primary, isSmall: isSmall)

                if let secondary = entry.volumes.secondary {
                    Divider()
                    VolumeRow(volume: secondary, isSmall: isSmall, canCycle: entry.volumes.canCycle)
                        .transition(.identity)
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            Text("書き込み可能なボリュームがありません")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VolumeRow: View {
    let volume: Volume
    let isSmall: Bool
    var canCycle = false

    var body: some View {
        let freeFraction = volume.freeFraction
        let freePercent = freeFraction.formatted(.percent.precision(.fractionLength(1)))
        let usedFraction = 1 - freeFraction

        VStack(alignment: .leading, spacing: isSmall ? 2 : 4) {
            HStack(spacing: 6) {
                if !isSmall {
                    Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(volume.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isSmall {
                    Spacer(minLength: 0)
                }
                if canCycle {
                    Button(intent: NextVolumeIntent()) {
                        Image(systemName: "arrow.trianglehead.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("次のボリューム")
                }
                if !isSmall {
                    Spacer(minLength: 0)
                    Text("空き \(freePercent)")
                        .monospacedDigit()
                        .fixedSize()
                }
            }
            .font(.subheadline.weight(.semibold))

            Group {
                if isSmall {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("全容量 \(capacity(volume.totalBytes))")
                        Text("空き \(capacity(volume.freeBytes))（\(freePercent)）")
                    }
                    .minimumScaleFactor(0.8)
                } else {
                    HStack(spacing: 10) {
                        Text("全容量 \(capacity(volume.totalBytes))")
                        Spacer(minLength: 0)
                        Text("空き容量 \(capacity(volume.freeBytes))")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)

            GeometryReader { geometry in
                Capsule()
                    .fill(.quaternary)
                    .overlay {
                        LinearGradient(
                            colors: [.blue, .green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width * usedFraction)
                        }
                    }
                    .clipShape(Capsule())
            }
            .frame(height: isSmall ? 4 : 6)
            .accessibilityHidden(true)
        }
        .contentTransition(.identity)
    }

    private func capacity(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
