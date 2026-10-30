import SwiftUI

/// Main AI Conversation Practice screen.
/// Features starter scenario prompts, interactive word tapping, and expandable word inspection popups.
public struct AIChatPracticeView: View {
    @StateObject private var chatService = GeminiChatService()
    @StateObject private var speechSynthesizer = SpeechSynthesizerService()
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    
    @State private var inputText: String = ""
    @State private var selectedLanguage: TargetLanguage = .simplifiedChinese
    @State private var showingLanguageSheet: Bool = false
    @State private var showingScenarioSheet: Bool = false
    
    // Popup state for tapped word inspection
    @State private var inspectedWord: WordInspection? = nil
    @State private var isInspectingWord: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Scenario Picker Bar
                scenarioSelectorBar
                
                Divider()
                
                // Chat Messages Feed
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Scenario Info Header Card
                            scenarioBannerCard
                            
                            // Message Bubbles
                            ForEach(chatService.messages) { msg in
                                InteractiveMessageBubble(
                                    message: msg,
                                    speechSynthesizer: speechSynthesizer,
                                    onWordTapped: { word, sentence in
                                        handleWordTap(word: word, contextSentence: sentence)
                                    }
                                )
                                .id(msg.id)
                            }
                            
                            // AI Generating indicator
                            if chatService.isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("\(chatService.activeScenario.roleplayPersona) is replying...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatService.messages.count) { _ in
                        if let lastId = chatService.messages.last?.id {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Bottom Input & Voice Bar
                chatInputBar
            }
            .navigationTitle("AI Conversation / 对话练习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingScenarioSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: chatService.activeScenario.icon)
                            Text("Scenarios")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLanguageSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedLanguage.flagEmoji)
                            Text(selectedLanguage.displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            // Word Inspection Popup Sheet
            .sheet(item: $inspectedWord) { item in
                WordInspectionPopup(
                    inspection: item,
                    speechSynthesizer: speechSynthesizer,
                    onDismiss: { inspectedWord = nil }
                )
                .presentationDetents([.height(340), .large])
                .presentationDragIndicator(.visible)
            }
            // Scenario Selection Modal
            .sheet(isPresented: $showingScenarioSheet) {
                scenarioSelectionSheet
            }
            // Language Selection Modal
            .sheet(isPresented: $showingLanguageSheet) {
                languageSelectionSheet
            }
        }
    }
    
    // MARK: - Scenario Selector Bar
    
    private var scenarioSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ChatScenario.defaultScenarios) { scenario in
                    let isSelected = chatService.activeScenario.id == scenario.id
                    Button {
                        withAnimation {
                            chatService.resetScenario(to: scenario)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scenario.icon)
                                .font(.system(size: 14))
                            Text(scenario.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundColor(isSelected ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                        .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private var scenarioBannerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: chatService.activeScenario.icon)
                .font(.system(size: 26))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chatService.activeScenario.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("Roleplaying with: \(chatService.activeScenario.roleplayPersona)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Reset") {
                withAnimation {
                    chatService.resetScenario(to: chatService.activeScenario)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
    
    // MARK: - Bottom Input Bar
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            if speechRecognizer.isRecording {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("Listening to your voice... / 正在聆听...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            HStack(alignment: .center, spacing: 10) {
                // Microphone Voice Input Button
                Button {
                    toggleSpeechInput()
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                        .frame(width: 42, height: 42)
                        .background(speechRecognizer.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Text Field
                TextField("Type or speak your reply...", text: $inputText)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(20)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Send Button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary.opacity(0.5) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Sheets
    
    private var scenarioSelectionSheet: some View {
        NavigationStack {
            List(ChatScenario.defaultScenarios) { scenario in
                Button {
                    chatService.resetScenario(to: scenario)
                    showingScenarioSheet = false
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: scenario.icon)
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(scenario.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(scenario.nativeTitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Text(scenario.roleplayPersona)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if chatService.activeScenario.id == scenario.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Scenario / 选择场景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingScenarioSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var languageSelectionSheet: some View {
        NavigationStack {
            List(TargetLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                    showingLanguageSheet = false
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
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        Task {
            await chatService.sendUserMessage(text, targetLanguage: selectedLanguage)
        }
    }
    
    private func toggleSpeechInput() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            if !speechRecognizer.transcript.isEmpty {
                inputText = speechRecognizer.transcript
            }
        } else {
            Task {
                let granted = await speechRecognizer.requestAuthorization()
                if granted {
                    speechRecognizer.startRecording()
                }
            }
        }
    }
    
    private func handleWordTap(word: String, contextSentence: String) {
        guard !isInspectingWord else { return }
        isInspectingWord = true
        
        Task {
            let result = await chatService.inspectWord(
                term: word,
                in: contextSentence,
                targetLanguage: selectedLanguage
            )
            self.inspectedWord = result
            self.isInspectingWord = false
        }
    }
}
