import Foundation

/// Central configuration for API keys and endpoints.
public enum APIConfig {
    /// Fallback key when not provided via Secrets.xcconfig or environment
    private static let fallbackKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    
    /// Reads the Gemini API key from Info.plist, environment, or Secrets.xcconfig
    public static var geminiAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
           !key.isEmpty,
           !key.starts(with: "$(") {
            return key
        }
        return fallbackKey
    }
}
