import Foundation
import SwiftData
import StudyCore

struct RecordService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func playerState() throws -> PlayerState {
        if let state = try context.fetch(FetchDescriptor<PlayerState>()).first {
            return state
        }
        let state = PlayerState()
        context.insert(state)
        return state
    }

    func save(startedAt: Date, minutes: Int, tag: Tag?, memo: String,
              source: SessionSource) throws -> RecordOutcome {
        let existing = try context.fetch(FetchDescriptor<StudySession>()).map(\.record)
        let state = try playerState()
        let record = SessionRecord(startedAt: startedAt, minutes: minutes, tagID: tag?.id)
        let outcome = RecordEvaluator.outcome(existing: existing, new: record,
                                              bonusXP: state.bonusXP, today: .now, calendar: .current)
        let session = StudySession(startedAt: startedAt, minutes: minutes, memo: memo, source: source, tag: nil)
        context.insert(session)
        session.tag = tag
        state.gachaTickets += outcome.ticketsAwarded
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return outcome
    }

    func drawGacha() throws -> GachaResult? {
        let state = try playerState()
        guard state.gachaTickets > 0 else { return nil }
        let owned = Set(try context.fetch(FetchDescriptor<OwnedReward>()).map(\.rewardID))
        var rng = SystemRandomNumberGenerator()
        let result = Gacha.draw(owned: owned, using: &rng)
        state.gachaTickets -= 1
        if result.isDuplicate {
            state.bonusXP += result.bonusXP
        } else {
            context.insert(OwnedReward(rewardID: result.reward.id))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return result
    }
}
