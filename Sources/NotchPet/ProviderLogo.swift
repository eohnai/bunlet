import EventBridge
import AppKit

@MainActor
enum ProviderLogo {
    // Decode once rather than reading artwork on every countdown update.
    static let bundled: [Agent: NSImage] = {
        var images: [Agent: NSImage] = [:]
        for provider in [Agent.codex, .claude] {
            images[provider] = image(for: provider)
        }
        return images
    }()

    static func image(for provider: Agent, appBundle: Bundle = .main) -> NSImage? {
        let directory: URL?
        if appBundle.bundleURL.pathExtension == "app" {
            // SwiftPM toolchains emit both flat and Contents/Resources layouts.
            // Resolve only this app's bundle; missing artwork still uses text.
            directory = (appBundle.resourceURL?.appendingPathComponent("NotchPet_NotchPet.bundle"))
                .flatMap { Bundle(url: $0)?.resourceURL ?? $0 }
        } else {
            directory = Bundle.module.resourceURL
        }
        let name = provider == .codex ? "codex.svg" : "claude-code.svg"
        guard let url = directory?.appendingPathComponent(name),
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        return image
    }
}
