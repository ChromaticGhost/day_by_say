import Foundation

// MARK: - Extracted Learning Deck (Structured Output)

public struct ExtractionResult: Codable, Equatable {
    public let scenarioCategory: String
    public let scenarioSummary: String
    public let suggestedPoliteReply: String
    public let suggestedPoliteReplyTranslation: String
    public let vocabularyItems: [ExtractedVocabularyItem]
}

public struct ExtractedVocabularyItem: Codable, Identifiable, Equatable {
    public var id: String { englishTerm }
    public let englishTerm: String
    public let phoneticIpa: String
    public let partOfSpeech: String
    public let translatedMeaning: String
    public let contextSentence: String
    public let culturalExplanation: String
}

// MARK: - Gemini REST API Wire Models

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

struct GeminiPart: Encodable {
    let text: String
}

struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
    let temperature: Double
}

struct GeminiAPIResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
}

struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

struct GeminiResponsePart: Decodable {
    let text: String?
}

struct GeminiError: Decodable {
    let code: Int?
    let message: String?
    let status: String?
}
