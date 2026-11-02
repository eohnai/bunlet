import AppKit
import SessionState

@MainActor
enum ProviderLogo {
    // Decode once rather than reading artwork on every countdown update.
    static let bundled: [IntegrationAgent: NSImage] = {
        var images: [IntegrationAgent: NSImage] = [:]
        for provider in [IntegrationAgent.codex, .claude] {
            images[provider] = image(for: provider)
        }
        return images
    }()

    static func image(for provider: IntegrationAgent, appBundle: Bundle = .main) -> NSImage? {
        let directory: URL?
        if appBundle.bundleURL.pathExtension == "app" {
            // SwiftPM's generated accessor does not search Contents/Resources.
            // Missing packaged artwork must use text, not a build-machine path.
            directory = appBundle.resourceURL?.appendingPathComponent("NotchPet_NotchPet.bundle")
        } else {
            directory = Bundle.module.resourceURL
        }
        let name = provider == .codex ? "codex.svg" : "claude-code.svg"
        guard let url = directory?.appendingPathComponent(name),
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        return image
    }
}
