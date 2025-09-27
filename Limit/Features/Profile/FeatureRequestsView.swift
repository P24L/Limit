import Foundation
import SwiftUI
import WishKit

struct FeatureRequestsView: View {
    init() {
        WishKitConfigurator.configureIfNeeded()
    }

    var body: some View {
        WishKit.FeedbackListView()
            .navigationTitle("Feature Requests")
    }
}

private enum WishKitConfigurator {
    static private var isConfigured = false

    static func configureIfNeeded() {
        guard !isConfigured else { return }

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "WishKitAPIKey") as? String,
              isValid(apiKey: apiKey) else {
            DevLogger.shared.log("WishKitConfigurator - API key missing or placeholder, skipping WishKit configuration")
            return
        }

        WishKit.configure(with: apiKey)
        WishKit.config.buttons.addButton.location = .navigationBar
        DevLogger.shared.log("WishKitConfigurator - WishKit configured")
        isConfigured = true
    }

    static private func isValid(apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed == "REPLACE_WITH_WISHKIT_KEY" { return false }
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return false }
        return true
    }
}
