import SwiftUI
import SwiftData

/// Word Bank screen displaying all vocabulary cards collected from AI Chat and Live Listen.
/// Integrates with the SuperMemo-2 (SM-2) Spaced Repetition engine for study and review.
public struct WordBankDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyCard.nextDueAt, order: .forward) private var cards: [VocabularyCard]
    @StateObject private var speechSynthesizer = SpeechSynthesizerService()
    
    @State private var searchText: String = ""
    @State private var filterDueOnly: Bool = false
    
    public init() {}
    
    private var filteredCards: [VocabularyCard] {
        cards.filter { card in
            let matchesSearch = searchText.isEmpty ||
                card.englishTerm.localizedCaseInsensitiveContains(searchText) ||
                card.translatedMeaning.localizedCaseInsensitiveContains(searchText)
            
            if filterDueOnly {
                return matchesSearch && card.nextDueAt <= Date()
            }
            return matchesSearch
        }
    }
    
    private var dueCount: Int {
        cards.filter { $0.nextDueAt <= Date() }.count
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Statistics Card
                statsHeader
                
                // Filter and Search
                filterBar
                
                Divider()
                
                // Card List
                if filteredCards.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredCards) { card in
                            cardRow(card)
                        }
                        .onDelete(perform: deleteCards)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Word Bank / 我的生词本")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search saved words / 搜索单词")
        }
    }
    
    // MARK: - Header Stats
    
    private var statsHeader: some View {
        HStack(spacing: 12) {
            statBadge(
                title: "Total Saved",
                chineseTitle: "生词总数",
                count: "\(cards.count)",
                icon: "character.book.closed.fill",
                color: .blue
            )
            
            statBadge(
                title: "Due for Review",
                chineseTitle: "待复习",
                count: "\(dueCount)",
                icon: "clock.arrow.circlepath",
                color: .orange
            )
            
            statBadge(
                title: "Mastered",
                chineseTitle: "已掌握",
                count: "\(cards.filter { $0.isMastered }.count)",
                icon: "checkmark.seal.fill",
                color: .green
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }
    
    private func statBadge(title: String, chineseTitle: String, count: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Spacer()
                Text(count)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(chineseTitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack {
            Toggle(isOn: $filterDueOnly) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.orange)
                    Text("Show Due for Review Only")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .toggleStyle(.button)
            .tint(.orange)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - Card Row
    
    private func cardRow(_ card: VocabularyCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(card.englishTerm)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(card.partOfSpeech.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(card.phoneticIpa)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Pronunciation Audio Button
                Button {
                    speechSynthesizer.speakEnglish(card.englishTerm)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 38, height: 38)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Definition
            Text(card.translatedMeaning)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            // Context sentence
            if !card.contextSentence.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("Context:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\"\(card.contextSentence)\"")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Cultural note
            if !card.culturalExplanation.isEmpty {
                Text(card.culturalExplanation)
                    .font(.system(size: 12))
                    .foregroundColor(.teal)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.teal.opacity(0.08))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "star.bubble")
                .font(.system(size: 54))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Words in Word Bank Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Practice with AI Chat or Ambient Live Listen,\nthen tap any word to save it here!")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Delete
    
    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            let card = filteredCards[index]
            modelContext.delete(card)
        }
        try? modelContext.save()
    }
}
