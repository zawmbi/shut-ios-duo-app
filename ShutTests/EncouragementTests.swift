import Foundation
import Testing

@testable import Shut

/// The opt-in encouragement lines: stable within a block, staged by progress,
/// and held to the same rules as the rest of the copy — no emoji, no scolding.
struct EncouragementTests {

    private static let everyMoment: [Encouragement.Moment] = [
        .running(progress: 0.1, openEnded: false),
        .running(progress: 0.6, openEnded: false),
        .running(progress: 0.9, openEnded: false),
        .running(progress: 0, openEnded: true),
        .grace(.fold), .grace(.lock), .kept, .broken,
    ]

    @Test(arguments: everyMoment)
    func noEmoji(_ moment: Encouragement.Moment) {
        for line in Encouragement.pool(for: moment) {
            #expect(!line.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "\(line)")
            #expect(!line.contains("!"), "\(line)")
        }
    }

    @Test func sameBlockSameLine() {
        let start = Date(timeIntervalSince1970: 1_790_000_123)
        let a = Encouragement.line(for: .running(progress: 0.2, openEnded: false), seed: start)
        let b = Encouragement.line(for: .running(progress: 0.3, openEnded: false), seed: start)
        #expect(a == b)
    }

    @Test func stagesByProgress() {
        let seed = Date(timeIntervalSince1970: 0)
        let early = Encouragement.line(for: .running(progress: 0.1, openEnded: false), seed: seed)
        let late = Encouragement.line(for: .running(progress: 0.9, openEnded: false), seed: seed)
        #expect(Encouragement.pool(for: .running(progress: 0.1, openEnded: false)).contains(early))
        #expect(Encouragement.pool(for: .running(progress: 0.9, openEnded: false)).contains(late))
        #expect(early != late)
    }

    @Test func noSeedStillPicksALine() {
        #expect(!Encouragement.line(for: .kept, seed: nil).isEmpty)
    }
}
