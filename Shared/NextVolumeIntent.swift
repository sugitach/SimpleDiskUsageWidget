import AppIntents

struct NextVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "次のボリューム"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await VolumeReader.shared.selectNext()
        return .result()
    }
}
