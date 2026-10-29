import Foundation
import SwiftData

@Model
public final class VocabularyCard: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var englishTerm: String
    public var phoneticIpa: String
    public var partOfSpeech: String
    public var targetLanguageCode: String
    public var translatedMeaning: String
    public var contextSentence: String
    public var culturalExplanation: String
    
    // Spaced Repetition Parameters (SuperMemo-2)
    public var repetitionCount: Int
    public var intervalDays: Int
    public var easeFactor: Double
    public var lastReviewedAt: Date?
    public var nextDueAt: Date
    public var isMastered: Bool
    
    public var session: ConversationSession?
    
    public init(
        englishTerm: String,
        phoneticIpa: String,
        partOfSpeech: String,
        targetLanguageCode: String = "zh-Hans",
        translatedMeaning: String,
        contextSentence: String,
        culturalExplanation: String
    ) {
        self.id = UUID()
        self.englishTerm = englishTerm
        self.phoneticIpa = phoneticIpa
        self.partOfSpeech = partOfSpeech
        self.targetLanguageCode = targetLanguageCode
        self.translatedMeaning = translatedMeaning
        self.contextSentence = contextSentence
        self.culturalExplanation = culturalExplanation
        self.repetitionCount = 0
        self.intervalDays = 1
        self.easeFactor = 2.5
        self.lastReviewedAt = nil
        self.nextDueAt = Date()
        self.isMastered = false
    }
}
