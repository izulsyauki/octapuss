import AppKit

extension CursorApplicationRequest {
    func arrowSnapshots() throws -> [CursorSnapshot] {
        var arrows: [CursorSnapshot] = []
        if plan == nil {
            for name in CursorRole.arrow.slotNames.filter({ $0.hasPrefix("com.apple.coregraphics.") }) {
                if let imported {
                    arrows.append(try imported.snapshot(name: name, longestSide: size.points))
                } else {
                    let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
                        let image = PointerArtwork.pointerImage(pack: pack, size: size.points * scale)
                        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                            throw CursorSystemError.invalidBaseline
                        }
                        return png
                    }
                    arrows.append(CursorSnapshot(name: name, width: size.points, height: size.points,
                        x: size.points / 16, y: size.points / 16, frames: 1, duration: 0, images: images))
                }
            }
        }
        return arrows
    }
}
