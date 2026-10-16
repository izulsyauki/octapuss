import AppKit

extension CursorSnapshot {
    /// Compare decoded pixels, not PNG encoding, to detect another utility taking ownership.
    func matches(_ other: CursorSnapshot) throws -> Bool {
        // WindowServer stores geometry as floats; decoded pixel identity below
        // still provides the ownership check for subpixel-rounding differences.
        guard name == other.name, abs(width - other.width) < 0.00001, abs(height - other.height) < 0.00001,
              abs(x - other.x) < 0.00001, abs(y - other.y) < 0.00001, frames == other.frames,
              abs(duration - other.duration) < 0.000001 else { return false }
        func hashes(_ data: [Data]) throws -> [String] {
            try data.map { png in
                guard let image = NSBitmapImageRep(data: png)?.cgImage,
                      let context = CGContext(data: nil, width: image.width, height: image.height,
                                              bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                      let bytes = context.data else { throw CursorSystemError.invalidBaseline }
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                var hash: UInt64 = 14695981039346656037
                for byte in UnsafeRawBufferPointer(start: bytes, count: image.width * image.height * 4) {
                    hash = (hash ^ UInt64(byte)) &* 1099511628211
                }
                return "\(image.width)x\(image.height):\(hash)"
            }.sorted()
        }
        return try hashes(images) == hashes(other.images)
    }
}
