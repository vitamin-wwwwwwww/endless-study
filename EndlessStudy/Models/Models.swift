import Foundation
import SwiftData
import StudyCore

enum SessionSource: String {
    case timer, manual
}

@Model
final class StudySession {
    var id: UUID
    var startedAt: Date
    var minutes: Int
    var memo: String
    var sourceRaw: String
    var tag: Tag?

    init(startedAt: Date, minutes: Int, memo: String, source: SessionSource, tag: Tag?) {
        self.id = UUID()
        self.startedAt = startedAt
        self.minutes = minutes
        self.memo = memo
        self.sourceRaw = source.rawValue
        self.tag = tag
    }

    var record: SessionRecord {
        SessionRecord(startedAt: startedAt, minutes: minutes, tagID: tag?.id)
    }
}

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \StudySession.tag)
    var sessions: [StudySession] = []

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
    }
}

@Model
final class OwnedReward {
    var rewardID: String
    var obtainedAt: Date

    init(rewardID: String) {
        self.rewardID = rewardID
        self.obtainedAt = .now
    }
}

@Model
final class PlayerState {
    var gachaTickets: Int
    var bonusXP: Int
    var equippedTitleID: String?
    var equippedThemeID: String?

    init() {
        self.gachaTickets = 0
        self.bonusXP = 0
    }
}
