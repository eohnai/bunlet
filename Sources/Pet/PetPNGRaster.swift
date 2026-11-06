import CoreGraphics
import Foundation
import ImageIO

/// A bounded, canonical RGBA raster, used only by an import worker.
final class PetPNGRaster {
    struct Coverage {
        let bounds: CGRect?
        let hasTransparency: Bool
    }

    let image: CGImage
    private let context: CGContext
    var width: Int { image.width }
    var height: Int { image.height }

    private init(image: CGImage, context: CGContext) {
        self.image = image
        self.context = context
    }

    static func decode(_ data: Data, byteLimit: Int, dimensionLimit: Int, decodedLimit: Int) throws -> PetPNGRaster {
        try Task.checkCancellation()
        guard data.count <= byteLimit else { throw PetPackFailure.resourceLimit }
        guard data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(source) as String? == "public.png", CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              (1...dimensionLimit).contains(width), (1...dimensionLimit).contains(height) else { throw PetPackFailure.invalidPNG }
        // Bounds are checked before ImageIO or CoreGraphics allocates decoded pixels.
        let depth = (properties[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? 16
        guard (1...16).contains(depth) else { throw PetPackFailure.invalidPNG }
        let sourceBytesPerPixel = depth > 8 ? 8 : 4
        guard width <= decodedLimit / sourceBytesPerPixel / height else { throw PetPackFailure.resourceLimit }
        guard let original = CGImageSourceCreateImageAtIndex(source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              original.width == width, original.height == height,
              [CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(original.alphaInfo) else {
            throw PetPackFailure.invalidPNG
        }
        let context = try makeContext(width: width, height: height)
        context.draw(original, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let image = context.makeImage() else { throw PetPackFailure.invalidPNG }
        try Task.checkCancellation()
        return PetPNGRaster(image: image, context: context)
    }

    static func makeContext(width: Int, height: Int) throws -> CGContext {
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              width <= PetPackManifest.decodedLimit / 4 / height,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else {
            throw PetPackFailure.resourceLimit
        }
        context.clear(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        context.interpolationQuality = .high
        return context
    }

    /// Every alpha value is inspected, so a sparse feature cannot be mistaken for padding.
    func coverage(in rect: CGRect? = nil) throws -> Coverage {
        let rect = rect ?? CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        let x0 = Int(rect.minX)
        let y0 = Int(rect.minY)
        let x1 = Int(rect.maxX)
        let y1 = Int(rect.maxY)
        guard x0 >= 0, y0 >= 0, x1 <= width, y1 <= height, x0 < x1, y0 < y1,
              let raw = context.data else { throw PetPackFailure.invalidPNG }
        let pixels = raw.assumingMemoryBound(to: UInt8.self)
        var minX = x1
        var minY = y1
        var maxX = x0 - 1
        var maxY = y0 - 1
        var hasTransparency = false
        for y in y0..<y1 {
            try Task.checkCancellation()
            for x in x0..<x1 {
                let alpha = pixels[y * context.bytesPerRow + x * 4 + 3]
                if alpha < 255 { hasTransparency = true }
                if alpha > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        let bounds = maxX < minX ? nil : CGRect(x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
        return Coverage(bounds: bounds, hasTransparency: hasTransparency)
    }

    static func encode(_ image: CGImage) throws -> Data {
        try Task.checkCancellation()
        guard image.width <= 1024, image.height <= 1024 else { throw PetPackFailure.resourceLimit }
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil) else {
            throw PetPackFailure.invalidPNG
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PetPackFailure.invalidPNG }
        guard bytes.length <= PetPackManifest.imageByteLimit else { throw PetPackFailure.resourceLimit }
        try Task.checkCancellation()
        return bytes as Data
    }
}
