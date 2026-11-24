import AppKit
import Foundation
import Testing
@testable import Pet

struct PetArtworkTests {
    private let sourceDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/Pet/Resources")

    /// Builds an app with the release layout: resource bundles only in Contents/Resources.
    private func withApp(artwork: Bool, _ check: (Bundle) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("notch-pet-artwork-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let contents = directory.appendingPathComponent("Fixture.app/Contents")
        let resources = contents.appendingPathComponent("Resources/NotchPet_Pet.bundle")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"),
                                                withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "test.notch-pet.artwork", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        if artwork {
            try FileManager.default.copyItem(at: sourceDirectory, to: resources)
        }
        try check(try #require(Bundle(url: contents.deletingLastPathComponent())))
    }

    @Test func packagedAppLoadsArtworkFromContentsResources() throws {
        try withApp(artwork: true) { app in
            #expect(!FileManager.default.fileExists(
                atPath: app.bundleURL.appendingPathComponent("NotchPet_Pet.bundle").path))
            let directory = AppResourceDirectory.locate("NotchPet_Pet.bundle", in: app, otherwise: nil)
            let presentation = try #require(PetArtwork.load(from: directory))
            let frame = presentation.animation(for: .idle).frames[0]
            let url = try #require(PetArtwork.url(for: frame, in: directory))
            #expect(url.path.hasSuffix("Fixture.app/Contents/Resources/NotchPet_Pet.bundle/\(frame).png"))
        }
    }

    @Test func packagedAppWithoutArtworkReturnsNilInsteadOfUsingTheBuildFolder() throws {
        try withApp(artwork: false) { app in
            let directory = AppResourceDirectory.locate("NotchPet_Pet.bundle", in: app,
                                                        otherwise: Bundle.module.resourceURL)
            #expect(PetArtwork.load(from: directory) == nil)
            #expect(PetArtwork.url(for: "white-lionhead-idle", in: directory) == nil)
        }
    }

    @Test func nonAppBundleUsesTheFallbackLocation() {
        let fallback = URL(fileURLWithPath: "/fallback")
        #expect(AppResourceDirectory.locate("NotchPet_Pet.bundle", in: Bundle(for: Marker.self),
                                            otherwise: fallback) == fallback)
    }

    @Test func bundledManifestAndResourceResolve() throws {
        let presentation = try #require(PetArtwork.presentation())
        let idle = presentation.animation(for: .idle)
        #expect(idle.frames == ["white-lionhead-idle"])
        for pose in PetPose.allCases {
            #expect(presentation.animation(for: pose) == idle)
        }
        let url = try #require(PetArtwork.url(for: idle.frames[0]))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.path.contains(".bundle/"))
        #expect(PetArtwork.url(for: "../outside") == nil)
        #expect(PetArtwork.url(for: "missing") == nil)
    }

    @Test func packagedRabbitDecodesToVisibleTransparentArtwork() throws {
        let url = try #require(PetArtwork.url(for: "white-lionhead-idle"))
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        #expect(bitmap.hasAlpha)
        #expect(bitmap.pixelsWide == bitmap.pixelsHigh)
        #expect(bitmap.pixelsWide >= 120)
        var transparent = false
        var visible = false
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 8) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 8) {
                let alpha = try #require(bitmap.colorAt(x: x, y: y)).alphaComponent
                transparent = transparent || alpha == 0
                visible = visible || alpha > 0
            }
        }
        #expect(transparent && visible)
    }
}

private final class Marker {}
