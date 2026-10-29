import Foundation
import SwiftData

@Model
public final class ConversationSession: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var audioDurationSeconds: Double
    public var rawTranscript: String
    public var scenarioCategory: String
    public var scenarioSummary: String
    public var suggestedPoliteReply: String
    public var suggestedPoliteReplyTranslation: String
    
    @Relationship(deleteRule: .cascade, inverse: \VocabularyCard.session)
    public var cards: [VocabularyCard]
    
    public init(
        rawTranscript: String,
        scenarioCategory: String,
        scenarioSummary: String,
        suggestedPoliteReply: String,
        suggestedPoliteReplyTranslation: String,
        durationSeconds: Double = 0.0
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.audioDurationSeconds = durationSeconds
        self.rawTranscript = rawTranscript
        self.scenarioCategory = scenarioCategory
        self.scenarioSummary = scenarioSummary
        self.suggestedPoliteReply = suggestedPoliteReply
        self.suggestedPoliteReplyTranslation = suggestedPoliteReplyTranslation
        self.cards = []
    }
}
