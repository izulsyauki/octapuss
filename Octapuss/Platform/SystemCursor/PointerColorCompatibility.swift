import Foundation

enum PointerColorCompatibility {
    static func hasOverride(in defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.universalaccess")) -> Bool {
        func differs(_ key: String, expected: Double) -> Bool {
            guard let color = defaults?.dictionary(forKey: key) else { return false }
            func component(_ key: String, fallback: Double) -> Double {
                if let number = color[key] as? NSNumber { return number.doubleValue }
                if let text = color[key] as? String, let number = Double(text) { return number }
                return fallback
            }
            return ["red", "green", "blue"].contains {
                abs(component($0, fallback: expected) - expected) > 0.001
            } || abs(component("alpha", fallback: 1) - 1) > 0.001
        }
        return differs("cursorFill", expected: 0) || differs("cursorOutline", expected: 1)
    }
}
