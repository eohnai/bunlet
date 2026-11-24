import Foundation
import Observation
#if canImport(Sparkle)
import Sparkle
#endif

/// Owns the updater for the app's lifetime. Sparkle presents the download and installation controls.
@MainActor
@Observable
final class BunletUpdater {
    private(set) var canCheck = false

    #if canImport(Sparkle)
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var availability: NSKeyValueObservation?
    #endif

    var isConfigured: Bool {
        #if canImport(Sparkle)
        controller != nil
        #else
        false
        #endif
    }

    func start() {
        #if canImport(Sparkle)
        guard controller == nil,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String, !feed.isEmpty,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        availability = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            guard let enabled = change.newValue else { return }
            DispatchQueue.main.async { [weak self] in self?.canCheck = enabled }
        }
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        guard canCheck else { return }
        controller?.checkForUpdates(nil)
        #endif
    }
}
