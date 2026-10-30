import Foundation
import AVFoundation

/// Provides zero-latency, offline native speech synthesis for vocabulary terms and sentences.
@MainActor
public final class SpeechSynthesizerService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published public var isSpeaking: Bool = false
    @Published public var currentlySpeakingText: String? = nil
    
    private let synthesizer = AVSpeechSynthesizer()
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speaks English text at a senior-friendly, slightly slower pace for clear phonetic comprehension.
    public func speakEnglish(_ text: String, rate: Float = 0.44) {
        speak(text: text, languageCode: "en-US", rate: rate)
    }
    
    /// Speaks English text at an ultra-slow pace for learners analyzing syllables.
    public func speakSlowly(_ text: String) {
        speak(text: text, languageCode: "en-US", rate: 0.28)
    }
    
    /// Speaks text in the specified target language locale.
    public func speak(text: String, languageCode: String, rate: Float = 0.46) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Stop any current utterance
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session for TTS: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        
        currentlySpeakingText = text
        isSpeaking = true
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentlySpeakingText = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentlySpeakingText = nil
        }
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentlySpeakingText = nil
        }
    }
}
