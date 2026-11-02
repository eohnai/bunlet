import AppKit
import SessionState
import Testing
@testable import NotchPet

@MainActor
struct ProviderLogoTests {
    private let sourceDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/NotchPet/Resources/Logos")

    private func withApp(logos: [String], _ check: (Bundle, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("notch-pet-logo-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let contents = directory.appendingPathComponent("Fixture.app/Contents")
        let resources = contents.appendingPathComponent("Resources/NotchPet_NotchPet.bundle")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "test.notch-pet.provider-logos", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        for name in logos {
            try FileManager.default.copyItem(at: sourceDirectory.appendingPathComponent(name),
                                             to: resources.appendingPathComponent(name))
        }
        let bundle = try #require(Bundle(url: contents.deletingLastPathComponent()))
        try check(bundle, resources)
    }

    @Test(arguments: [IntegrationAgent.codex, .claude])
    func packagedLogosDecodeWithoutAnAppRootResourceBundle(provider: IntegrationAgent) throws {
        try withApp(logos: ["codex.svg", "claude-code.svg"]) { bundle, _ in
            #expect(!FileManager.default.fileExists(
                atPath: bundle.bundleURL.appendingPathComponent("NotchPet_NotchPet.bundle").path))
            let image = try #require(ProviderLogo.image(for: provider, appBundle: bundle))
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
            #expect(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
        }
    }

    @Test func missingPackagedBundleDoesNotLoadADevelopmentLogo() throws {
        try withApp(logos: []) { bundle, resources in
            try FileManager.default.removeItem(at: resources)
            #expect(ProviderLogo.image(for: .codex, appBundle: bundle) == nil)
            #expect(ProviderLogo.image(for: .claude, appBundle: bundle) == nil)
        }
    }

    @Test func missingProviderLogoDoesNotBorrowTheOtherProvidersLogo() throws {
        try withApp(logos: ["codex.svg"]) { bundle, _ in
            #expect(ProviderLogo.image(for: .codex, appBundle: bundle) != nil)
            #expect(ProviderLogo.image(for: .claude, appBundle: bundle) == nil)
        }
    }

    @Test func invalidLogoReturnsNilForTheTextFallback() throws {
        try withApp(logos: []) { bundle, resources in
            try Data("invalid image".utf8).write(to: resources.appendingPathComponent("codex.svg"))
            #expect(ProviderLogo.image(for: .codex, appBundle: bundle) == nil)
        }
    }
}
