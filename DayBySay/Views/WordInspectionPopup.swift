import SwiftUI
import SwiftData

/// An accessible, senior-friendly popup for inspecting tapped words in AI chat.
/// Shows definition and usage case initially, with practical examples and cultural tips revealed upon expanding.
public struct WordInspectionPopup: View {
    public let inspection: WordInspection
    @ObservedObject public var speechSynthesizer: SpeechSynthesizerService
    public let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var savedCards: [VocabularyCard]
    
    @State private var isExpanded: Bool = false
    @State private var justAdded: Bool = false
    
    public init(
        inspection: WordInspection,
        speechSynthesizer: SpeechSynthesizerService,
        onDismiss: @escaping () -> Void
    ) {
        self.inspection = inspection
        self.speechSynthesizer = speechSynthesizer
        self.onDismiss = onDismiss
    }
    
    private var isAlreadyInWordBank: Bool {
        justAdded || savedCards.contains {
            $0.englishTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
            inspection.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Drag indicator bar
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: - Header: Term, IPA, and Audio Pronunciation
                    headerRow
                    
                    Divider()
                    
                    // MARK: - Compact Content: Definition & Usage Case
                    compactContentSection
                    
                    // MARK: - "Add to Word Bank" Action Button
                    addToWordBankButton
                    
                    // MARK: - Expandable Section Toggle Button
                    expandToggleButton
                    
                    // MARK: - Expanded Details (Practical Examples & Cultural Tips)
                    if isExpanded {
                        expandedContentSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Subviews
    
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(inspection.term)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(inspection.partOfSpeech.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                
                Text(inspection.phoneticIpa)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Audio Controls (Normal & Slow "Turtle" speed)
            HStack(spacing: 8) {
                // Slow speech button
                Button {
                    speechSynthesizer.speakSlowly(inspection.term)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 14))
                        Text("Slow")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speak slowly")
                
                // Normal speech button
                Button {
                    speechSynthesizer.speakEnglish(inspection.term)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen to pronunciation")
            }
        }
    }
    
    private var compactContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Meaning / Definition
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("Definition / 释义")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                Text(inspection.definition)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
            }
            
            // 2. Usage Case in this Conversation
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 14))
                    Text("Usage in Conversation / 实际语境")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        speechSynthesizer.speakEnglish(inspection.contextSentence)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\"\(inspection.contextSentence)\"")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .italic()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(12)
            }
        }
    }
    
    private var addToWordBankButton: some View {
        Button {
            addToWordBank()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isAlreadyInWordBank ? "checkmark.circle.fill" : "star.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text(isAlreadyInWordBank ? "Saved in Word Bank / 已加入生词本" : "Add to Word Bank / 收藏到生词本")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(isAlreadyInWordBank ? .green : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isAlreadyInWordBank ? Color.green.opacity(0.15) : Color.blue)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isAlreadyInWordBank ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyInWordBank)
    }
    
    private var expandToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(isExpanded ? "Hide Practical Examples & Tips" : "See Practical Examples & Cultural Tips")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 18))
            }
            .foregroundColor(.indigo)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private var expandedContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Practical Examples
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("Practical Everyday Examples / 实用例句")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                VStack(spacing: 8) {
                    ForEach(inspection.practicalExamples, id: \.self) { example in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                speechSynthesizer.speakEnglish(example)
                            } label: {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)
                            
                            Text(example)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }
            
            // 2. Cultural / Practical Etiquette Tip
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "info.bubble.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 14))
                    Text("Cultural & Etiquette Tip / 文化与背景常识")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                Text(inspection.culturalTip)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.teal.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Actions
    
    private func addToWordBank() {
        guard !isAlreadyInWordBank else { return }
        
        let newCard = VocabularyCard(
            englishTerm: inspection.term,
            phoneticIpa: inspection.phoneticIpa,
            partOfSpeech: inspection.partOfSpeech,
            targetLanguageCode: "zh-Hans",
            translatedMeaning: inspection.definition,
            contextSentence: inspection.contextSentence,
            culturalExplanation: inspection.culturalTip
        )
        
        newCard.repetitionCount = 0
        newCard.intervalDays = 1
        newCard.easeFactor = 2.5
        newCard.nextDueAt = Date()
        
        modelContext.insert(newCard)
        try? modelContext.save()
        
        withAnimation {
            justAdded = true
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
