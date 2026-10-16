import Foundation

extension SystemCursorAccess {
    func readAvailable(_ names: [String]) throws -> [CursorSnapshot] { names.compactMap { try? read($0) } }
    func readMany(_ names: [String]) throws -> [CursorSnapshot] { try names.map { try read($0) } }
    func verify(_ expected: CursorSnapshot) throws {
        try verifyAll([expected])
    }
    func verifyAll(_ expected: [CursorSnapshot]) throws {
        for attempt in 0..<4 {
            let actual = try readMany(expected.map(\.name))
            if actual.count == expected.count,
               zip(actual, expected).allSatisfy({ (try? $0.matches($1)) == true }) { return }
            if attempt < 3 { Thread.sleep(forTimeInterval: 0.02) }
        }
        throw CursorSystemError.call("Verify registered cursor images", -1)
    }
}
