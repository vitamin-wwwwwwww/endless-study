import Foundation

public struct SessionRecord: Equatable, Sendable {
    public let startedAt: Date
    public let minutes: Int
    public let tagID: UUID?

    public init(startedAt: Date, minutes: Int, tagID: UUID? = nil) {
        self.startedAt = startedAt
        self.minutes = minutes
        self.tagID = tagID
    }
}
