import AppKit

extension ImportedCursor {
    func image(longestSide: CGFloat) -> NSImage {
        let scale = longestSide / CGFloat(max(width, height))
        let image = NSImage(data: png)!
        image.size = NSSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        return image
    }

    func cursor(longestSide: CGFloat) -> NSCursor {
        let scale = longestSide / CGFloat(max(width, height))
        return NSCursor(image: image(longestSide: longestSide),
                        hotSpot: NSPoint(x: CGFloat(hotspotX) * scale, y: CGFloat(hotspotY) * scale))
    }

    func snapshot(name: String, longestSide: CGFloat) throws -> CursorSnapshot {
        let factor = longestSide / CGFloat(max(width, height))
        let logicalSize = CGSize(width: CGFloat(width) * factor, height: CGFloat(height) * factor)
        let timeline = systemTimeline
        let sourceFrames = try timeline.frames.map { data -> CGImage in
            guard let image = NSBitmapImageRep(data: data)?.cgImage else {
                throw CursorImportError.invalid("An animation frame could not be read. Reimport this cursor.")
            }
            return image
        }
        let images = try [1.0, 2.0, 5.0, 10.0].map { scale -> Data in
            let w = max(1, Int((logicalSize.width * scale).rounded()))
            let h = max(1, Int((logicalSize.height * scale).rounded()))
            guard let context = CGContext(data: nil, width: w,
                    height: h * sourceFrames.count, bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            context.interpolationQuality = .none
            for (index, frame) in sourceFrames.enumerated() {
                context.draw(frame, in: CGRect(x: 0, y: (sourceFrames.count - index - 1) * h, width: w, height: h))
            }
            guard let image = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CursorImportError.invalid("The imported image could not be rendered. Import it again.")
            }
            return data
        }
        return CursorSnapshot(name: name, width: logicalSize.width, height: logicalSize.height,
                              x: CGFloat(hotspotX) * factor, y: CGFloat(hotspotY) * factor,
                              frames: sourceFrames.count, duration: timeline.duration, images: images)
    }

    /// The native backend has a uniform frame interval and a 24-frame limit.
    /// Constant-rate ANI up to 24 steps is exact; other timelines are time-sampled.
    var systemTimeline: (frames: [Data], duration: Double) {
        guard let animation, animation.frames.count > 1 else { return ([png], 0) }
        let total = animation.durations.reduce(0, +)
        let equal = animation.durations.allSatisfy { abs($0 - animation.durations[0]) < 0.000001 }
        if animation.frames.count <= 24 && equal { return (animation.frames, animation.durations[0]) }
        let count = min(24, max(2, animation.frames.count))
        let interval = total / Double(count)
        var output: [Data] = []
        var index = 0
        var end = animation.durations[0]
        for step in 0..<count {
            let time = Double(step) * interval
            while index + 1 < animation.frames.count && time >= end {
                index += 1
                end += animation.durations[index]
            }
            output.append(animation.frames[index])
        }
        return (output, interval)
    }
}
