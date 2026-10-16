import AppKit

enum PointerArtwork {
    static func cursor(pack: PointerPack, size: CGFloat) -> NSCursor {
        let scale = size / 32
        return NSCursor(
            image: pointerImage(pack: pack, size: size),
            hotSpot: NSPoint(x: 2 * scale, y: 2 * scale)
        )
    }

    static func pointerImage(pack: PointerPack, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let scale = size / 32
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 2 * scale, y: 2 * scale))
            path.line(to: NSPoint(x: 3.4 * scale, y: 24 * scale))
            path.line(to: NSPoint(x: 9.4 * scale, y: 18.8 * scale))
            path.line(to: NSPoint(x: 14.2 * scale, y: 28.5 * scale))
            path.line(to: NSPoint(x: 19 * scale, y: 26.1 * scale))
            path.line(to: NSPoint(x: 14.3 * scale, y: 17 * scale))
            path.line(to: NSPoint(x: 22.5 * scale, y: 16.1 * scale))
            path.close()

            AppPalette.pointerOutline.setStroke()
            path.lineWidth = max(2.8, 3.3 * scale)
            path.lineJoinStyle = .round
            path.stroke()
            pack.color.setFill()
            path.fill()

            let earPath = NSBezierPath()
            earPath.move(to: NSPoint(x: 5.5 * scale, y: 18.5 * scale))
            earPath.line(to: NSPoint(x: 7.4 * scale, y: 14.2 * scale))
            earPath.line(to: NSPoint(x: 10.4 * scale, y: 18.1 * scale))
            earPath.move(to: NSPoint(x: 9.7 * scale, y: 18.6 * scale))
            earPath.line(to: NSPoint(x: 12.1 * scale, y: 14.7 * scale))
            earPath.line(to: NSPoint(x: 14.7 * scale, y: 17.8 * scale))
            earPath.lineWidth = max(1, 1.2 * scale)
            earPath.lineCapStyle = .round
            AppPalette.pointerDetail.setStroke()
            earPath.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    static func companionImage(pack: PointerPack) -> NSImage {
        let size: CGFloat = 30
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let head = NSBezierPath(roundedRect: NSRect(x: 4, y: 7, width: 22, height: 18), xRadius: 9, yRadius: 9)
            let leftEar = NSBezierPath()
            leftEar.move(to: NSPoint(x: 7, y: 10))
            leftEar.line(to: NSPoint(x: 9, y: 3))
            leftEar.line(to: NSPoint(x: 14, y: 8))
            leftEar.close()
            let rightEar = NSBezierPath()
            rightEar.move(to: NSPoint(x: 16, y: 8))
            rightEar.line(to: NSPoint(x: 21, y: 3))
            rightEar.line(to: NSPoint(x: 23, y: 10))
            rightEar.close()
            AppPalette.pointerOutline.setStroke()
            pack.color.setFill()
            for path in [leftEar, rightEar, head] {
                path.lineWidth = 2
                path.stroke()
                path.fill()
            }
            let tentacles = NSBezierPath()
            for x in stride(from: 9.0, through: 21.0, by: 4.0) {
                tentacles.move(to: NSPoint(x: x, y: 23))
                tentacles.curve(to: NSPoint(x: x - 1.5, y: 28), controlPoint1: NSPoint(x: x + 2, y: 25), controlPoint2: NSPoint(x: x + 1, y: 28))
            }
            tentacles.lineWidth = 2.2
            tentacles.lineCapStyle = .round
            pack.color.setStroke()
            tentacles.stroke()
            // A tiny face belongs to the brand mark, never to interaction controls.
            AppPalette.ink.setFill()
            for x in [11.0, 19.0] {
                NSBezierPath(ovalIn: NSRect(x: x - 0.8, y: 13, width: 1.6, height: 2.2)).fill()
            }
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 13, y: 17))
            smile.curve(to: NSPoint(x: 17, y: 17), controlPoint1: NSPoint(x: 14, y: 19), controlPoint2: NSPoint(x: 16, y: 19))
            smile.lineWidth = 0.8
            AppPalette.ink.setStroke()
            smile.stroke()
            return true
        }
        return image
    }
}

/// Owns both the cursor rectangle and native click target; no transparent hit-test overlay.
