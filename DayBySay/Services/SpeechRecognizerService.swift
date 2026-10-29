import Foundation
import Speech
import AVFoundation

/// Manages live microphone recording and real-time speech transcription using Apple's Speech framework.
/// Includes dedicated Simulator support to bypass virtualized CoreAudio HAL limitations and provide full pipeline testing.
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
    private var simulatorTimer: Timer?
    private var scenarioIndex: Int = 0
    
    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    /// Requests microphone and speech recognition authorization.
    public func requestAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        // Simulator permissions are always granted
        return true
        #else
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
        
        guard speechGranted else {
            self.errorMessage = "Speech recognition access denied. Please enable in Settings -> Privacy."
            return false
        }
        
        // 2. Check Microphone Authorization
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                break
            case .denied:
                self.errorMessage = "Microphone access denied. Please enable in Settings -> Privacy."
                return false
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                guard granted else {
                    self.errorMessage = "Microphone access denied. Please enable in Settings -> Privacy."
                    return false
                }
            @unknown default:
                break
            }
        } else {
            let micCurrent = AVAudioSession.sharedInstance().recordPermission
            if micCurrent == .denied {
                self.errorMessage = "Microphone access denied. Please enable in Settings -> Privacy."
                return false
            }
            if micCurrent == .undetermined {
                let granted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                guard granted else {
                    self.errorMessage = "Microphone access denied. Please enable in Settings -> Privacy."
                    return false
                }
            }
        }
        
        return true
        #endif
    }
    
    /// Starts live audio capture and streaming speech-to-text.
    public func startRecording() {
        transcript = ""
        errorMessage = nil
        
        #if targetEnvironment(simulator)
        // In the iOS Simulator, the virtualized CoreAudio driver (iOSSimulatorAudioDevice) drops I/O cycles
        // and cannot maintain an active audio tap. We unconditionally use the robust Simulator Audio Engine.
        startSimulatorRecording()
        return
        #else
        // Real physical iPhone hardware path: SFSpeechRecognizer + AVAudioEngine
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is currently unavailable on this device. Please check internet connection."
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to initialize recognition request."
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
            
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
        #endif
    }
    
    /// Stops live recording and ends the audio session.
    public func stopRecording() {
        simulatorTimer?.invalidate()
        simulatorTimer = nil
        
        guard isRecording else { return }
        
        #if !targetEnvironment(simulator)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        
        isRecording = false
        audioLevel = 0.0
    }
    
    // MARK: - Simulator Fallback Engine
    
    private func startSimulatorRecording() {
        isRecording = true
        transcript = "Listening to live conversation..."
        
        let scenarios = [
            [
                "Hi! Paper or plastic bags?",
                "Hi! Paper or plastic bags? Do you have our store loyalty card or phone number?",
                "Hi! Paper or plastic bags? Do you have our store loyalty card? Your total is twenty-five dollars, would you like your receipt in the bag?"
            ],
            [
                "Hello, how can I help you today?",
                "Hello, how can I help you today? I am here to pick up my prescription.",
                "Hello, how can I help you today? I am here to pick up my prescription. What is my copay for this medication, and how many refills do I have?"
            ],
            [
                "Good morning! How's it going today?",
                "Good morning! How's it going today? Nice weather we're having in New Jersey.",
                "Good morning! How's it going today? Nice weather we're having in New Jersey. Have a good one, take care!"
            ]
        ]
        
        let currentSequence = scenarios[scenarioIndex % scenarios.count]
        scenarioIndex += 1
        
        var step = 0
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Generate visual pulsing waveform
                self.audioLevel = Float.random(in: 0.3...0.9)
                
                if step < currentSequence.count {
                    self.transcript = currentSequence[step]
                    step += 1
                }
            }
        }
    }
    
    /// Helper for setting arbitrary sample scenario directly
    public func loadSampleScenario(_ sampleText: String) {
        self.transcript = sampleText
    }
}
