import EventBridge
import AppKit
import Pet

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
        // Missing artwork still uses text.
        let directory = AppResourceDirectory.locate("NotchPet_NotchPet.bundle", in: appBundle,
                                                    otherwise: Bundle.module.resourceURL)
        let file: String? = switch provider {
        case .codex: "codex.svg"
        case .claude: "claude-code.svg"
        case .cursor: nil // No bundled artwork; the name is shown as text.
        }
        guard let name = file, let url = directory?.appendingPathComponent(name),
              let image = NSImage(contentsOf: url), image.isValid else { return nil }
        return image
    }
}
