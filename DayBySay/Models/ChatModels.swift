import Foundation
import SwiftUI

/// Preset real-world scenario for conversational roleplay.
public struct ChatScenario: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let nativeTitle: String
    public let icon: String
    public let roleplayPersona: String
    public let initialGreeting: String
    public let systemInstructions: String
    
    public init(
        id: String,
        title: String,
        nativeTitle: String,
        icon: String,
        roleplayPersona: String,
        initialGreeting: String,
        systemInstructions: String
    ) {
        self.id = id
        self.title = title
        self.nativeTitle = nativeTitle
        self.icon = icon
        self.roleplayPersona = roleplayPersona
        self.initialGreeting = initialGreeting
        self.systemInstructions = systemInstructions
    }
    
    /// Default survival English scenarios tailored for immigrant newcomers and seniors.
    public static let defaultScenarios: [ChatScenario] = [
        ChatScenario(
            id: "grocery",
            title: "Supermarket Checkout",
            nativeTitle: "超市结账",
            icon: "cart.fill",
            roleplayPersona: "Friendly Supermarket Cashier",
            initialGreeting: "Hi there! Did you find everything okay? Paper or plastic bags today?",
            systemInstructions: "You are a friendly supermarket cashier at a US grocery store. Speak simply and clearly. Common topics: paper or plastic bags, store rewards card, receipt, cash back, payment methods."
        ),
        ChatScenario(
            id: "pharmacy",
            title: "Pharmacy Pickup",
            nativeTitle: "药房取药",
            icon: "cross.vial.fill",
            roleplayPersona: "Community Pharmacist",
            initialGreeting: "Hello! Are you picking up a prescription today? What is the patient's name and birth date?",
            systemInstructions: "You are a patient community pharmacist. Common topics: prescription pickup, date of birth verification, insurance copay, side effects, dosage instructions (e.g. with meals)."
        ),
        ChatScenario(
            id: "transit",
            title: "Public Bus & Transit",
            nativeTitle: "乘坐公交",
            icon: "bus.fill",
            roleplayPersona: "Bus Driver / Transit Worker",
            initialGreeting: "Exact fare is $2.75, or you can tap your metro card. Do you need a transfer ticket?",
            systemInstructions: "You are a bus driver on a US city transit system. Common topics: exact fare, tapping contactless cards, requesting transfer tickets, pulling the cord for upcoming stops."
        ),
        ChatScenario(
            id: "clinic",
            title: "Clinic Reception",
            nativeTitle: "诊所前台",
            icon: "stethoscope",
            roleplayPersona: "Clinic Front Desk Receptionist",
            initialGreeting: "Good morning! Do you have an appointment with Dr. Miller? May I see your photo ID and insurance card?",
            systemInstructions: "You are a welcoming medical clinic receptionist. Common topics: check-in, photo ID and insurance card, copay, filling out intake forms, waiting in the lobby."
        ),
        ChatScenario(
            id: "cafe",
            title: "Coffee & Diner",
            nativeTitle: "餐饮点单",
            icon: "cup.and.saucer.fill",
            roleplayPersona: "Cafe Barista / Diner Server",
            initialGreeting: "Good morning! What can I get started for you today? For here or to go?",
            systemInstructions: "You are a cheerful cafe barista. Common topics: coffee orders, size (small/medium/large), room for milk, dine-in vs takeout, receipt."
        ),
        ChatScenario(
            id: "neighbor",
            title: "Neighbor Small Talk",
            nativeTitle: "邻里交流",
            icon: "house.fill",
            roleplayPersona: "Friendly American Neighbor",
            initialGreeting: "Hi there! Beautiful sunny day today, isn't it? Did you see the mail carrier come by?",
            systemInstructions: "You are a warm, friendly neighborhood resident. Common topics: pleasant weather, package delivery, greetings, community news."
        )
    ]
}

/// Message role in the AI conversation.
public enum ChatMessageRole: String, Codable {
    case user
    case assistant
}

/// Represents an individual message in the chat.
public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: ChatMessageRole
    public let content: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), role: ChatMessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Detailed lexical inspection data for a tapped word.
public struct WordInspection: Identifiable, Equatable {
    public let id: UUID
    public let term: String
    public let phoneticIpa: String
    public let partOfSpeech: String
    public let definition: String
    public let contextSentence: String
    public let practicalExamples: [String]
    public let culturalTip: String
    
    public init(
        id: UUID = UUID(),
        term: String,
        phoneticIpa: String,
        partOfSpeech: String,
        definition: String,
        contextSentence: String,
        practicalExamples: [String],
        culturalTip: String
    ) {
        self.id = id
        self.term = term
        self.phoneticIpa = phoneticIpa
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.contextSentence = contextSentence
        self.practicalExamples = practicalExamples
        self.culturalTip = culturalTip
    }
}
