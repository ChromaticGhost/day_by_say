# DayBySay 🎙️
> **"Learning English, day by say."**  
> Turn today’s live conversations into tomorrow’s confidence.

DayBySay is an accessible, senior-friendly iOS application built for immigrant families and non-native English speakers. It captures real-world spoken conversations (at grocery stores, pharmacies, bus stops, and doctor offices) and automatically transforms them into personalized, audio-first English study decks powered by Gemini AI.

---

## ✨ Features

- **🎙️ One-Tap Live Ambient Audio Capture**: Record real-world conversations effortlessly with large, accessible buttons.
- **🗣️ On-Device & Cloud Speech Recognition**: Transcribes spoken English accurately, breaking the barrier of not knowing how to spell heard words.
- **🤖 Intelligent Card Generation (Gemini AI)**: Automatically extracts key vocabulary, natural idioms, context, and dual-language translations (Simplified Chinese & English).
- **🔊 Native High-Fidelity Audio Playback**: High-contrast, tactile flashcards with crystal-clear spoken pronunciation at customizable speeds.
- **🧠 Spaced Repetition System (SM-2)**: Scientifically scheduled review intervals to retain daily spoken English effortlessly.
- **👴 Senior-Centric UX / Silver Economy Accessibility**: High-contrast colors, dynamic type sizing, large touch targets, and haptic feedback.

---

## 🛠️ Tech Stack & Architecture

- **Language:** Swift 5.10 / Swift 6
- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData & CoreData
- **Speech & Audio:** AVFoundation, Speech (`SFSpeechRecognizer`)
- **AI Backend:** Google Gemini 1.5 Flash API
- **Design System:** Accessible High-Contrast Palette with SF Symbols & Haptics

---

## 🚀 Getting Started

### Prerequisites

- Mac running macOS Sonoma 14.0 or newer
- Xcode 15.0+ installed
- iOS 17.0+ Simulator or physical device

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/day_by_say.git
   cd day_by_say
   ```

2. **Configure API Secrets:**
   Copy the example secrets file to create your local `Secrets.xcconfig`:
   ```bash
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
   Open `Secrets.xcconfig` in any text editor and paste your free Google Gemini API key:
   ```xcconfig
   GEMINI_API_KEY = your_gemini_api_key_here
   ```
   *(Get your free key at [Google AI Studio](https://aistudio.google.com/app/apikey))*

   > 🔒 `Secrets.xcconfig` is ignored by `.gitignore` and will never be committed to Git.

3. **Open and Run the Project:**
   - Double-click `DayBySay.xcodeproj` to open it in Xcode.
   - Select your target device or simulator (e.g., iPhone 15 Pro).
   - Press **⌘R** (Command + R) to build and run.

---

## 📄 Documentation

- [Project Overview & Brand Identity](overview.md)
- [System Architecture & Technical Design Doc](design_doc.md)

---

## 🏆 Congressional App Challenge

DayBySay was designed and developed for the **Congressional App Challenge (CAC)**, addressing immigrant integration, educational equity, and senior independence through innovative mobile and AI technology.
