import AppKit
import Pet
import SwiftUI

@MainActor
final class PetPanelController: AppFeatureService {
    private let panel: NSPanel

    init?(size: Double) {
        guard let presentation = PetArtwork.presentation() else { return nil }
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "White lionhead rabbit"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PetWindowPlayback(window: panel) { visible, sleeping in
            PetView(presentation: presentation, isVisible: visible, isSleeping: sleeping)
        })
        if let screen = NSScreen.main {
            panel.setFrame(Self.desktopFrame(screen: screen.visibleFrame, size: size), display: false)
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func start() { show() }

    func stop() { panel.close() }

    static func desktopFrame(screen: CGRect, size: Double) -> CGRect {
        let safe = size.isFinite && PetPreferences.sizeRange.contains(size) ? size : PetPreferences.defaultSize
        return CGRect(x: max(screen.minX, screen.maxX - safe - 16),
                      y: min(screen.minY + 16, max(screen.minY, screen.maxY - safe)), width: safe, height: safe)
    }

    func setSize(_ size: Double) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        panel.setFrame(Self.desktopFrame(screen: screen.visibleFrame, size: size), display: true)
    }

    /// Opt-in verification observes this same production panel, never a demo view.
    func writeEvidence(phase: String, agentsEnabled: Bool, focusBefore: pid_t) {
        guard let path = ProcessInfo.processInfo.environment["NOTCH_PET_EVIDENCE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let roots = ["/private/tmp", NSTemporaryDirectory()].map {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        }
        guard roots.contains(where: { directory.path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }) else { return }
        let counts = Dictionary(uniqueKeysWithValues: AgentServiceKind.allCases.map {
            ($0.rawValue, ServiceStartLedger.starts[$0, default: 0])
        })
        let payload: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "executable": Bundle.main.executableURL?.path ?? "",
            "phase": phase,
            "presentation": "pet",
            "petVisible": panel.isVisible,
            "artworkLoaded": PetArtwork.url(for: "white-lionhead-idle").flatMap(NSImage.init(contentsOf:)) != nil,
            "size": panel.frame.width,
            "windowNumber": panel.windowNumber,
            "agentServicesEnabled": agentsEnabled,
            "serviceStarts": counts,
            "focusBefore": focusBefore,
            "focusAfter": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("pet.json"), options: .atomic)
        } catch {
            fputs("Pet verification evidence could not be written.\n", stderr)
        }
    }
}
