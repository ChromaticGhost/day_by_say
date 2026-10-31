import Foundation
import Speech
import AVFoundation

/// Manages live microphone recording and real-time speech transcription using Apple's Speech and AVFoundation frameworks.
/// Focuses purely on capturing real-world spoken conversations without injecting mock prompt scripts.
@MainActor
public final class SpeechRecognizerService: ObservableObject {
    @Published public var transcript: String = ""
    @Published public var isRecording: Bool = false
    @Published public var audioLevel: Float = 0.0
    @Published public var errorMessage: String? = nil
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    /// Requests microphone and speech recognition authorization.
    public func requestAuthorization() async -> Bool {
        // 1. Check Speech Recognition Authorization
        let speechCurrent = SFSpeechRecognizer.authorizationStatus()
        var speechGranted = (speechCurrent == .authorized)
        
        if speechCurrent == .notDetermined {
            speechGranted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
        
        // 2. Check Microphone Authorization
        var micGranted = false
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                micGranted = true
            case .denied:
                micGranted = false
            case .undetermined:
                micGranted = await AVAudioApplication.requestRecordPermission()
            @unknown default:
                micGranted = true
            }
        } else {
            let micCurrent = AVAudioSession.sharedInstance().recordPermission
            if micCurrent == .granted {
                micGranted = true
            } else if micCurrent == .undetermined {
                micGranted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        
        if !micGranted {
            self.errorMessage = "Microphone access denied. Please enable in Settings -> Privacy."
            return false
        }
        
        return speechGranted || micGranted
    }
    
    /// Starts live audio capture and streaming speech-to-text from the physical or simulator microphone.
    public func startRecording() {
        transcript = ""
        errorMessage = nil
        
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognizer is not configured for English (en-US)."
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to initialize speech recognition request."
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self?.recognitionRequest?.append(buffer)
                
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frames = buffer.frameLength
                var sum: Float = 0
                for i in 0..<Int(frames) {
                    sum += abs(channelData[i])
                }
                let avg = sum / Float(frames)
                let normalized = min(max(avg * 8.0, 0.0), 1.0)
                
                Task { @MainActor in
                    self?.audioLevel = normalized
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
            if speechRecognizer.isAvailable {
                recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if let result = result {
                        Task { @MainActor in
                            self.transcript = result.bestTranscription.formattedString
                        }
                    }
                    
                    if error != nil || (result?.isFinal ?? false) {
                        Task { @MainActor in
                            self.stopRecording()
                        }
                    }
                }
            } else {
                // Audio is recording but on-device dictation is offline
                self.transcript = ""
            }
            
        } catch {
            errorMessage = "Microphone capture error: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    /// Stops live recording and ends the audio session.
    public func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        isRecording = false
        audioLevel = 0.0
    }
}
