import SwiftUI
import WidgetKit

struct DiskUsageView: View {
    let entry: DiskUsageEntry
    let family: WidgetFamily
    var onNextVolume: (() -> Void)? = nil

    var body: some View {
        let isSmall = family == .systemSmall

        if let primary = entry.volumes.primary {
            VStack(spacing: isSmall ? 5 : 8) {
                VolumeRow(volume: primary, isSmall: isSmall)

                if let secondary = entry.volumes.secondary {
                    Divider()
                    VolumeRow(
                        volume: secondary, isSmall: isSmall, canCycle: entry.volumes.canCycle,
                        onNextVolume: onNextVolume
                    )
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
    var onNextVolume: (() -> Void)? = nil

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
                    Group {
                        if let onNextVolume {
                            Button(action: onNextVolume) { cycleIcon }
                        } else {
                            Button(intent: NextVolumeIntent()) { cycleIcon }
                        }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("使用済み \(usedFraction.formatted(.percent.precision(.fractionLength(1))))"))
        }
        .contentTransition(.identity)
    }

    private var cycleIcon: some View {
        Image(systemName: "arrow.trianglehead.clockwise")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 18)
            .contentShape(Rectangle())
    }

    private func capacity(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
