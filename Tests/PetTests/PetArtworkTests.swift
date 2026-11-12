import AppKit
import Foundation
import Testing
@testable import Pet

struct PetArtworkTests {
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
