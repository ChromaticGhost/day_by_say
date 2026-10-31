import SwiftUI
import SwiftData

/// A high-contrast, senior-friendly flashcard component designed for clear readability and one-tap audio.
public struct VocabularyCardView: View {
    public let item: ExtractedVocabularyItem
    @ObservedObject public var speechSynthesizer: SpeechSynthesizerService
    
    @Environment(\.modelContext) private var modelContext
    @Query private var savedCards: [VocabularyCard]
    @State private var justAdded: Bool = false
    
    public init(item: ExtractedVocabularyItem, speechSynthesizer: SpeechSynthesizerService) {
        self.item = item
        self.speechSynthesizer = speechSynthesizer
    }
    
    private var isAlreadyInWordBank: Bool {
        justAdded || savedCards.contains {
            $0.englishTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
            item.englishTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
    
    private var isPlayingThisWord: Bool {
        speechSynthesizer.currentlySpeakingText == item.englishTerm
    }
    
    private var isPlayingThisSentence: Bool {
        speechSynthesizer.currentlySpeakingText == item.contextSentence
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Row: English Term, Phonetics, and Pronounce Button
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.englishTerm)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(item.partOfSpeech.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(item.phoneticIpa)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Big Tactile Audio Button
                Button {
                    speechSynthesizer.speakEnglish(item.englishTerm)
                } label: {
                    Image(systemName: isPlayingThisWord ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(isPlayingThisWord ? Color.green : Color.blue)
                        .clipShape(Circle())
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen to pronunciation of \(item.englishTerm)")
            }
            
            Divider()
            
            // Native Language Translation (Large, clear typography)
            Text(item.translatedMeaning)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.indigo)
            
            // Real-World Context Sentence with Listen Button
            VStack(alignment: .leading, spacing: 6) {
                Text("REAL CONVERSATION / 场景例句")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                HStack(alignment: .top, spacing: 10) {
                    Text("“\(item.contextSentence)”")
                        .font(.system(size: 17, weight: .regular))
                        .italic()
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        speechSynthesizer.speakEnglish(item.contextSentence)
                    } label: {
                        Image(systemName: isPlayingThisSentence ? "speaker.wave.2.fill" : "speaker.wave.1")
                            .font(.system(size: 16))
                            .foregroundColor(isPlayingThisSentence ? .green : .secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Cultural / Practical American Life Tip
            if !item.culturalExplanation.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    
                    Text(item.culturalExplanation)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
            
            // Add to Word Bank Action Button
            Button {
                addToWordBank()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAlreadyInWordBank ? "checkmark.circle.fill" : "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isAlreadyInWordBank ? "Saved in Word Bank / 已收藏" : "Add to Word Bank / 收藏到生词本")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(isAlreadyInWordBank ? .green : .blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isAlreadyInWordBank ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isAlreadyInWordBank)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    private func addToWordBank() {
        guard !isAlreadyInWordBank else { return }
        
        let newCard = VocabularyCard(
            englishTerm: item.englishTerm,
            phoneticIpa: item.phoneticIpa,
            partOfSpeech: item.partOfSpeech,
            targetLanguageCode: "zh-Hans",
            translatedMeaning: item.translatedMeaning,
            contextSentence: item.contextSentence,
            culturalExplanation: item.culturalExplanation
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
