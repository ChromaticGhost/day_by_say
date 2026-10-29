import Foundation

/// Represents the user's native language for bilingual explanations and translations.
public enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case spanish = "es"
    case vietnamese = "vi"
    case korean = "ko"
    case tagalog = "tl"
    case arabic = "ar"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文 (Chinese Simplified)"
        case .traditionalChinese: return "繁體中文 (Chinese Traditional)"
        case .spanish: return "Español (Spanish)"
        case .vietnamese: return "Tiếng Việt (Vietnamese)"
        case .korean: return "한국어 (Korean)"
        case .tagalog: return "Tagalog (Filipino)"
        case .arabic: return "العربية (Arabic)"
        }
    }
    
    public var flagEmoji: String {
        switch self {
        case .simplifiedChinese, .traditionalChinese: return "🇨🇳"
        case .spanish: return "🇲🇽"
        case .vietnamese: return "🇻🇳"
        case .korean: return "🇰🇷"
        case .tagalog: return "🇵🇭"
        case .arabic: return "🇸🇦"
        }
    }
    
    /// BCP-47 identifier used by AVSpeechSynthesisVoice
    public var ttsLocale: String {
        switch self {
        case .simplifiedChinese: return "zh-CN"
        case .traditionalChinese: return "zh-TW"
        case .spanish: return "es-US"
        case .vietnamese: return "vi-VN"
        case .korean: return "ko-KR"
        case .tagalog: return "fil-PH"
        case .arabic: return "ar-SA"
        }
    }
}
