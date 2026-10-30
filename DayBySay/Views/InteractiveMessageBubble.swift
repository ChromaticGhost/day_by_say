import SwiftUI

/// Renders individual chat messages. Assistant messages have interactive, clickable words for vocabulary inspection.
public struct InteractiveMessageBubble: View {
    public let message: ChatMessage
    @ObservedObject public var speechSynthesizer: SpeechSynthesizerService
    public let onWordTapped: (String, String) -> Void
    
    public init(
        message: ChatMessage,
        speechSynthesizer: SpeechSynthesizerService,
        onWordTapped: @escaping (String, String) -> Void
    ) {
        self.message = message
        self.speechSynthesizer = speechSynthesizer
        self.onWordTapped = onWordTapped
    }
    
    private var isUser: Bool {
        message.role == .user
    }
    
    private var isSpeakingThisMessage: Bool {
        speechSynthesizer.currentlySpeakingText == message.content
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                // Assistant Avatar
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if isUser {
                    userBubble
                } else {
                    assistantInteractiveBubble
                }
            }
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
    
    // MARK: - User Bubble
    
    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Assistant Interactive Bubble
    
    private var assistantInteractiveBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Interactive Tokenized Words
            tokenizedFlowView
            
            // Audio Listen & Tip Bar
            HStack(spacing: 12) {
                Button {
                    speechSynthesizer.speakEnglish(message.content)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSpeakingThisMessage ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isSpeakingThisMessage ? "Playing..." : "Listen")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Text("Tap any word to inspect / 点击单词看释义")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Tokenized Layout
    
    private var tokenizedFlowView: some View {
        let tokens = tokenize(text: message.content)
        
        // Wrapping layout using modern iOS 16+ Flow Layout
        return FlowLayout(spacing: 4) {
            ForEach(tokens.indices, id: \.self) { idx in
                let token = tokens[idx]
                if token.isInteractiveWord {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onWordTapped(token.cleanWord, message.content)
                    } label: {
                        Text(token.rawText)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .underline(color: Color.blue.opacity(0.4))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(token.rawText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Tokenizer
    
    private struct WordToken: Identifiable {
        let id = UUID()
        let rawText: String
        let cleanWord: String
        let isInteractiveWord: Bool
    }
    
    private func tokenize(text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        let words = text.components(separatedBy: .whitespaces)
        
        for (index, word) in words.enumerated() {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            let isWord = cleaned.count > 0 && cleaned.rangeOfCharacter(from: .letters) != nil
            
            tokens.append(WordToken(
                rawText: word + (index < words.count - 1 ? " " : ""),
                cleanWord: cleaned,
                isInteractiveWord: isWord
            ))
        }
        
        return tokens
    }
}

/// Simple flexible flow layout for wrapping words onto multiple lines.
public struct FlowLayout: Layout {
    public var spacing: CGFloat = 4
    
    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
