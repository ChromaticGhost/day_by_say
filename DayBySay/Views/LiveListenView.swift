import SwiftUI

/// Primary Live Listen MVP screen for DayBySay.
public struct LiveListenView: View {
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    @StateObject private var geminiService = GeminiService()
    @StateObject private var speechSynthesizer = SpeechSynthesizerService()
    
    @State private var selectedLanguage: TargetLanguage = .simplifiedChinese
    @State private var extractionResult: ExtractionResult? = nil
    @State private var showingLanguageSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Top App Header
                        headerSection
                        
                        // Error / Status Notice
                        if let error = speechRecognizer.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button {
                                    speechRecognizer.errorMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(14)
                        }
                        
                        // Main Microphone & Audio Capture Box
                        captureCard(scrollProxy: scrollProxy)
                        
                        // Referral banner to separate AI Chat practice space
                        aiChatReferralCard
                        
                        // Processing Indicator
                        if geminiService.isAnalyzing {
                            analyzingView
                        }
                        
                        // Extracted Results Deck
                        if let result = extractionResult {
                            resultsSection(result, scrollProxy: scrollProxy)
                                .id("resultsSection")
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .onChange(of: extractionResult) { _, newResult in
                    if newResult != nil {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                scrollProxy.scrollTo("resultsSection", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLanguageSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedLanguage.flagEmoji)
                            Text(selectedLanguage.displayName.split(separator: " ").first ?? "")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showingLanguageSheet) {
                languageSelectionSheet
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("DayBySay")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("MVP")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Text("“Learning English, day by say.”")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .italic()
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .id("topHeader")
    }
    
    // MARK: - Live Capture Card
    
    private func captureCard(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 20) {
            // Large Tactile Record Button
            ZStack {
                // Animated Pulsing Outer Ring
                if speechRecognizer.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 10)
                        .frame(width: 120 + CGFloat(speechRecognizer.audioLevel * 40),
                               height: 120 + CGFloat(speechRecognizer.audioLevel * 40))
                        .animation(.easeInOut(duration: 0.15), value: speechRecognizer.audioLevel)
                }
                
                Button {
                    toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                            .frame(width: 88, height: 88)
                            .shadow(color: (speechRecognizer.isRecording ? Color.red : Color.blue).opacity(0.35),
                                    radius: 10, x: 0, y: 5)
                        
                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speechRecognizer.isRecording ? "Stop Listening" : "Start Listening")
            }
            .padding(.top, 10)
            
            // Status Label
            Text(speechRecognizer.isRecording ? "RECORDING AMBIENT SPEECH... / 正在录音" : "TAP TO RECORD SPEECH / 点击开始录音")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(speechRecognizer.isRecording ? .red : .secondary)
                .tracking(0.5)
            
            // Live Transcript Bubble
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    Text("LIVE TRANSCRIPT / 现场转写")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if speechRecognizer.transcript.isEmpty {
                    if speechRecognizer.isRecording {
                        Text("Listening to microphone... Speak clearly in English or record conversations around you.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.vertical, 4)
                    } else {
                        Text("Tap the microphone to capture real-world English (at grocery stores, clinics, transit), then tap generate to create study flashcards.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.8))
                            .italic()
                            .padding(.vertical, 4)
                    }
                } else {
                    Text(speechRecognizer.transcript)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            // Action Buttons when transcript is available
            if !speechRecognizer.transcript.isEmpty && !speechRecognizer.isRecording {
                HStack(spacing: 12) {
                    Button {
                        speechRecognizer.transcript = ""
                        extractionResult = nil
                    } label: {
                        Text("Clear / 清空")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        processTranscript()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                            Text("Create English Deck / 生成卡片")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green)
                        .cornerRadius(14)
                        .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Quick Jump to Cards button if already generated
            if let result = extractionResult {
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("resultsSection", anchor: .top)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("View Generated Deck (\(result.vocabularyItems.count) Cards) ↓")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Referral to AI Chat Space
    
    private var aiChatReferralCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 42, height: 42)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Looking for conversation practice with prompts?")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text("Switch to the **AI Chat** tab to practice scenarios & roleplay!")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        HStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing with Gemini AI...")
                    .font(.system(size: 16, weight: .bold))
                Text("Extracting survival vocab & polite reply")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.blue.opacity(0.12))
        .cornerRadius(16)
    }
    
    // MARK: - Results Section
    
    private func resultsSection(_ result: ExtractionResult, scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Scenario Badge Header
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text(result.scenarioCategory.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // "Next Time Say This" Golden Callout Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.orange)
                    Text("NEXT TIME SAY THIS / 下次你可以这样回答")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.orange)
                    Spacer()
                    
                    Button {
                        speechSynthesizer.speakEnglish(result.suggestedPoliteReply)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                Text("“\(result.suggestedPoliteReply)”")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(result.suggestedPoliteReplyTranslation)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(18)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
            )
            
            // Vocabulary Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S SURVIVAL VOCABULARY / 今日核心词汇")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                ForEach(result.vocabularyItems) { item in
                    VocabularyCardView(item: item, speechSynthesizer: speechSynthesizer)
                }
            }
            
            // Back to Top Button
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scrollProxy.scrollTo("topHeader", anchor: .top)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Back to Top / 返回顶部")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Language Selection Sheet
    
    private var languageSelectionSheet: some View {
        NavigationStack {
            List(TargetLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                    showingLanguageSheet = false
                    if !speechRecognizer.transcript.isEmpty {
                        processTranscript()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(language.flagEmoji)
                            .font(.system(size: 24))
                        Text(language.displayName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Native Language / 母语设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingLanguageSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Actions
    
    private func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            if !speechRecognizer.transcript.isEmpty {
                processTranscript()
            }
        } else {
            Task {
                let granted = await speechRecognizer.requestAuthorization()
                if granted {
                    extractionResult = nil
                    speechRecognizer.startRecording()
                }
            }
        }
    }
    
    private func processTranscript() {
        guard !speechRecognizer.transcript.isEmpty else { return }
        
        Task {
            do {
                let result = try await geminiService.extractLearningDeck(
                    from: speechRecognizer.transcript,
                    targetLanguage: selectedLanguage
                )
                self.extractionResult = result
            } catch {
                print("Failed to extract deck: \(error.localizedDescription)")
            }
        }
    }
}
