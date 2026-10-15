import AppKit

@main
struct SystemCursorProbe {
    static func main() throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--cursor-read-many" {
            exit(SystemCursorAPI.runReader(names: CommandLine.arguments[2]))
        }
        _ = NSApplication.shared
        let api = try SystemCursorAPI()
        print("Private cursor entry points resolved. Read-only probe; no registration performed.")
        if let visible = NSCursor.currentSystem {
            print("Currently displayed cursor (AppKit): \(visible.image.size.width)x\(visible.image.size.height), hotspot \(visible.hotSpot.x),\(visible.hotSpot.y)")
        }
        for name in ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"] {
            do {
                let snapshot = try api.read(name)
                print("\(name): \(snapshot.width)x\(snapshot.height), hotspot \(snapshot.x),\(snapshot.y), frames \(snapshot.frames), representations \(snapshot.images.count)")
                let journalURL = SystemCursorSession.defaultJournalURL
                if let data = try? Data(contentsOf: journalURL),
                   let journal = try? JSONDecoder().decode(CursorJournal.self, from: data),
                   let baseline = journal.original.first(where: { $0.name == name }) {
                    print("Baseline exact match: \(try snapshot.matches(baseline)); duration \(snapshot.duration)")
                    for (index, png) in snapshot.images.enumerated() where index < baseline.images.count {
                        func pixels(_ data: Data) -> (Int, Int, [UInt8]) {
                            let image = NSBitmapImageRep(data: data)!.cgImage!
                            let context = CGContext(data: nil, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                            return (image.width, image.height, Array(UnsafeRawBufferPointer(start: context.data!, count: image.width * image.height * 4)))
                        }
                        let current = pixels(png), expected = pixels(baseline.images[index])
                        if current.0 == expected.0, current.1 == expected.1 {
                            let deltas = zip(current.2, expected.2).map { abs(Int($0) - Int($1)) }
                            print("Rep \(index) \(current.0)x\(current.1): max delta \(deltas.max() ?? 0), mean \(Double(deltas.reduce(0,+)) / Double(deltas.count))")
                        } else { print("Rep order/dimensions differ") }
                    }
                }
            } catch { print("\(name): \(error.localizedDescription)") }
        }
    }
}
