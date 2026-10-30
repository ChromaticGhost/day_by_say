import SwiftUI
import SwiftData

@main
struct DayBySayApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ConversationSession.self,
            VocabularyCard.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                LiveListenView()
                    .tabItem {
                        Label("Live Listen", systemImage: "mic.fill")
                    }
                
                AIChatPracticeView()
                    .tabItem {
                        Label("AI Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                
                WordBankDeckView()
                    .tabItem {
                        Label("Word Bank", systemImage: "star.fill")
                    }
            }
            .tint(.blue)
        }
        .modelContainer(sharedModelContainer)
    }
}
