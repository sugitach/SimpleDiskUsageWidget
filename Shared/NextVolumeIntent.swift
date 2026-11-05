import AppIntents

struct NextVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "次のボリューム"
    static let isDiscoverable = false
    private let reader: VolumeReader

    init() {
        self.init(reader: .shared)
    }

    init(reader: VolumeReader) {
        self.reader = reader
    }

    func perform() async throws -> some IntentResult {
        await reader.selectNext()
        return .result()
    }
}
