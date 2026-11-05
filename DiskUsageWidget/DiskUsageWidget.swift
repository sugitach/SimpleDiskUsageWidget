import SwiftUI
import WidgetKit

@main
struct DiskUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DiskUsage", provider: DiskUsageProvider()) { entry in
            WidgetContent(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("ディスク容量")
        .description("ボリュームの空き容量を表示します。下段の矢印ボタンで表示先を切り替えます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WidgetContent: View {
    @Environment(\.widgetFamily) private var family
    let entry: DiskUsageEntry

    var body: some View {
        DiskUsageView(entry: entry, family: family)
    }
}
