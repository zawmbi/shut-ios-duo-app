import Foundation
import SwiftUI

enum PrefKey {
    static let graceSeconds  = "grace.seconds"
    static let lastTarget    = "target.last"
    static let faceStyle     = "face.style"
    static let soundOnFinish = "finish.sound"
    static let hasOnboarded  = "onboarded"
}

enum FaceStyle: String, CaseIterable, Identifiable {
    case ring, digits, bar
    var id: String { rawValue }
    var display: String {
        switch self {
        case .ring:   "Ring"
        case .digits: "Digits"
        case .bar:    "Bar"
        }
    }
    /// Free tier gets the ring only.
    var isPro: Bool { self != .ring }
}

/// Preset block lengths, in seconds. Zero is the open-ended block.
enum Presets {
    static let all: [Int] = [15 * 60, 25 * 60, 45 * 60, 60 * 60, 90 * 60, 0]

    static func label(_ seconds: Int) -> String {
        guard seconds > 0 else { return "Open" }
        let m = seconds / 60
        return m % 60 == 0 && m >= 60 ? "\(m / 60)h" : "\(m)m"
    }
}
