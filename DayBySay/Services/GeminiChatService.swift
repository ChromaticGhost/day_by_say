import Foundation

/// Service orchestrating AI conversation roleplay and on-demand lexical word inspection.
@MainActor
public final class GeminiChatService: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var isSending: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeScenario: ChatScenario
    
    private let session: URLSession
    
    public init(scenario: ChatScenario = ChatScenario.defaultScenarios[0], session: URLSession = .shared) {
        self.activeScenario = scenario
        self.session = session
        resetScenario(to: scenario)
    }
    
    /// Resets the conversation to a new scenario and seeds the initial greeting.
    public func resetScenario(to scenario: ChatScenario) {
        self.activeScenario = scenario
        self.messages = [
            ChatMessage(role: .assistant, content: scenario.initialGreeting)
        ]
        self.errorMessage = nil
    }
    
    /// Sends a user message and fetches the AI's roleplay response.
    public func sendUserMessage(
        _ text: String,
        targetLanguage: TargetLanguage = .simplifiedChinese
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        
        do {
            let reply = try await callGeminiForReply(
                history: messages,
                scenario: activeScenario,
                targetLanguage: targetLanguage
            )
            let assistantMessage = ChatMessage(role: .assistant, content: reply)
            messages.append(assistantMessage)
        } catch {
            print("Gemini chat error: \(error.localizedDescription)")
            self.errorMessage = "Could not connect to AI. Please check your internet or API key."
        }
    }
    
    /// Inspects a tapped word to provide definition, usage, examples, and cultural etiquette.
    public func inspectWord(
        term: String,
        in contextSentence: String,
        targetLanguage: TargetLanguage = .simplifiedChinese
    ) async -> WordInspection {
        let cleanTerm = term
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check instant local dictionary for immediate zero-latency presentation
        if let cached = localInspectionLookup(for: cleanTerm, context: contextSentence, language: targetLanguage) {
            return cached
        }
        
        // 2. Fetch rich contextual analysis from Gemini API
        if let online = try? await callGeminiForWordInspection(term: cleanTerm, context: contextSentence, targetLanguage: targetLanguage) {
            return online
        }
        
        // 3. Graceful fallback
        return WordInspection(
            term: cleanTerm,
            phoneticIpa: "/\(cleanTerm.lowercased())/",
            partOfSpeech: "term",
            definition: "Common spoken phrase in daily errands",
            contextSentence: contextSentence,
            practicalExamples: [
                "Please listen carefully when this word is spoken.",
                "You can repeat: 'Could you say that again, please?'"
            ],
            culturalTip: "In American daily life, polite phrases and conversational tokens make interactions smoother."
        )
    }
    
    // MARK: - Private Gemini API Calls
    
    private func callGeminiForReply(
        history: [ChatMessage],
        scenario: ChatScenario,
        targetLanguage: TargetLanguage
    ) async throws -> String {
        let apiKey = APIConfig.geminiAPIKey
        let activeModels = ["gemini-2.5-flash", "gemini-1.5-flash", "gemini-2.0-flash"]
        
        let systemPrompt = """
        You are DayBySay AI, a kind, patient, and warm American roleplay conversation partner assisting immigrant elders and language learners practice survival English.
        
        Roleplay Scenario: "\(scenario.title)"
        Your Persona: \(scenario.roleplayPersona)
        Guidelines:
        1. Speak in natural, spoken American English suitable for daily community errands.
        2. Keep your answers brief (1 to 2 clear sentences) so it is easy to read and understand.
        3. Do not overwhelm the user with long paragraphs.
        4. When the user responds, react realistically and naturally to their order, request, or question.
        5. \(scenario.systemInstructions)
        """
        
        // Format contents history
        var contents: [[String: Any]] = []
        for msg in history {
            contents.append([
                "role": msg.role == .user ? "user" : "model",
                "parts": [["text": msg.content]]
            ])
        }
        
        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 150
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        for modelName in activeModels {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = root["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let contentObj = first["content"] as? [String: Any],
                       let parts = contentObj["parts"] as? [[String: Any]],
                       let text = parts.first?["text"] as? String {
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                continue
            }
        }
        
        // Offline / Simulation fallback if API limit or offline
        return generateOfflineFallbackReply(for: history.last?.content ?? "", scenario: scenario)
    }
    
    private func callGeminiForWordInspection(
        term: String,
        context: String,
        targetLanguage: TargetLanguage
    ) async throws -> WordInspection {
        let apiKey = APIConfig.geminiAPIKey
        guard !apiKey.isEmpty else { throw NSError(domain: "DayBySay", code: 401) }
        
        let prompt = """
        Analyze this English word/phrase used in a conversation: "\(term)"
        Spoken in sentence: "\(context)"
        Target native language for definition: \(targetLanguage.displayName)
        
        Return ONLY valid JSON matching this schema:
        {
          "phoneticIpa": "/.../",
          "partOfSpeech": "noun/verb/phrase",
          "definition": "Clear concise translation in \(targetLanguage.displayName)",
          "practicalExamples": ["Example sentence 1", "Example sentence 2"],
          "culturalTip": "1-2 sentences in \(targetLanguage.displayName) explaining why Americans use this word and practical etiquette."
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw NSError(domain: "DayBySay", code: 400)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "DayBySay", code: 500)
        }
        
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let contentObj = first["content"] as? [String: Any],
              let parts = contentObj["parts"] as? [[String: Any]],
              let jsonText = parts.first?["text"] as? String,
              let parsedData = jsonText.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: parsedData) as? [String: Any] else {
            throw NSError(domain: "DayBySay", code: 502)
        }
        
        return WordInspection(
            term: term,
            phoneticIpa: dict["phoneticIpa"] as? String ?? "/\(term.lowercased())/",
            partOfSpeech: dict["partOfSpeech"] as? String ?? "phrase",
            definition: dict["definition"] as? String ?? term,
            contextSentence: context,
            practicalExamples: dict["practicalExamples"] as? [String] ?? ["Please use this word in daily life."],
            culturalTip: dict["culturalTip"] as? String ?? "Common American spoken expression."
        )
    }
    
    // MARK: - Instant Local Dictionary (Instant zero-wait popup)
    
    private func localInspectionLookup(for term: String, context: String, language: TargetLanguage) -> WordInspection? {
        let key = term.lowercased()
        
        let dict: [String: (ipa: String, pos: String, defZh: String, defEs: String, examples: [String], tipZh: String, tipEs: String)] = [
            "copay": (
                "/ˈkoʊpeɪ/",
                "noun",
                "共付额 (就医门诊自付定额)",
                "Copago (pago fijo de consulta)",
                [
                    "Do you have a $20 copay for today's doctor visit?",
                    "Your insurance covers the prescription after the copay."
                ],
                "在美国看医生或拿药时，医保通常要求患者在诊所前台先支付一笔固定的现金或刷卡费用，称为 Copay。",
                "En el sistema médico de EE.UU., el copago es una tarifa fija que se paga en recepción antes de ver al médico."
            ),
            "prescription": (
                "/prɪˈskrɪpʃən/",
                "noun",
                "处方药",
                "Receta médica",
                [
                    "I am here to pick up my prescription.",
                    "The doctor sent the prescription directly to the pharmacy."
                ],
                "在美国，大部分药物必须有执照医生的处方才能在 CVS 或 Walgreens 药房调剂配药，不能在货架上直接拿。",
                "En EE.UU., la mayoría de los medicamentos requieren una receta de un médico antes de recogerlos en la farmacia."
            ),
            "transfer": (
                "/ˈtrænsfər/",
                "noun / verb",
                "换乘票 / 转乘",
                "Boleto de transferencia / Transbordo",
                [
                    "Can I get a transfer ticket for the next bus?",
                    "This transfer is valid for two hours across the subway."
                ],
                "乘坐公交时向司机索要 'transfer'，可以在规定时限（通常2小时）内免费或优惠换乘另一辆公交或地铁。",
                "Al subir al autobús, pedir un 'transfer' le permite cambiar a otra ruta de autobús o tren dentro de 2 horas sin pagar pasaje completo."
            ),
            "exact": (
                "/ɪɡˈzækt/",
                "adjective",
                "准确的 / 刚刚好的 (零钱)",
                "Exacto / Cambio justo",
                [
                    "Buses require exact fare because drivers carry no cash.",
                    "Please have the exact change ready before boarding."
                ],
                "美国城市公交车司机出于安全规定随身不携带找零现金，必须准备刚好数额的纸币或硬币投币（Exact Fare）。",
                "Los conductores de autobuses en EE.UU. no llevan cambio; se debe pagar la cantidad exacta al abordar."
            ),
            "plastic": (
                "/ˈplæstɪk/",
                "noun / adj",
                "塑料袋",
                "Bolsa de plástico",
                [
                    "Would you like paper or plastic bags?",
                    "Many states now charge a 5-cent fee for plastic bags."
                ],
                "超市收银员常问 'Paper or plastic?'。很多州为环保开始收取塑料袋费用，鼓励自备购物袋（Reusable bags）。",
                "Los cajeros suelen preguntar '¿Papel o plástico?'. Varios estados cobran por las bolsas de plástico para promover bolsas reutilizables."
            ),
            "cash back": (
                "/kæʃ bæk/",
                "noun phrase",
                "借记卡结账取现",
                "Retiro de efectivo en caja",
                [
                    "Would you like any cash back from your debit card?",
                    "I took $20 cash back at the grocery checkout."
                ],
                "在超市刷借记卡（Debit Card）付款时，刷卡机常会询问是否需要 Cash Back，也就是顺便免费从银行账户取现金，免去找 ATM 的麻烦。",
                "Al pagar con tarjeta de débito en el supermercado, puede retirar efectivo gratis de su cuenta sin ir a un cajero automático."
            ),
            "to go": (
                "/tuː ɡoʊ/",
                "phrase",
                "打包带走 (外带)",
                "Para llevar",
                [
                    "Is your order for here or to go?",
                    "I would like two coffees to go, please."
                ],
                "在餐馆或咖啡馆点餐时，服务员必问 'For here or to go?'，回答 'To go' 即可打包带走。",
                "En cafeterías y restaurantes siempre preguntan '¿Para comer aquí o para llevar?'. Responda 'To go' si desea llevárselo."
            ),
            "appointment": (
                "/əˈpɔɪntmənt/",
                "noun",
                "预约 / 门诊挂号",
                "Cita previa",
                [
                    "I have an appointment at 10:30 AM with Dr. Miller.",
                    "Please call 24 hours in advance to cancel your appointment."
                ],
                "在美国看病绝大部分必须提前预约（Appointment），无预约直接去普通诊所通常无法接诊，只能去急诊（Urgent Care 或 ER）。",
                "En EE.UU. casi todas las consultas médicas requieren cita previa; presentarse sin cita suele no ser admitido."
            )
        ]
        
        guard let entry = dict[key] else { return nil }
        
        let isZh = language == .simplifiedChinese || language == .traditionalChinese
        return WordInspection(
            term: term,
            phoneticIpa: entry.ipa,
            partOfSpeech: entry.pos,
            definition: isZh ? entry.defZh : entry.defEs,
            contextSentence: context,
            practicalExamples: entry.examples,
            culturalTip: isZh ? entry.tipZh : entry.tipEs
        )
    }
    
    private func generateOfflineFallbackReply(for input: String, scenario: ChatScenario) -> String {
        switch scenario.id {
        case "grocery":
            return "Sure thing! Do you have our store loyalty rewards card with you today?"
        case "pharmacy":
            return "Thank you. Let me look that up in the pharmacy system. It will be ready in just a few minutes."
        case "transit":
            return "You got it. Hold onto your transfer ticket, it's good for the next two hours."
        case "clinic":
            return "Thank you! Please have a seat in the lobby, and the nurse will call your name shortly."
        case "cafe":
            return "Got it! That will be $4.50. You can tap your card on the terminal right there."
        default:
            return "That sounds wonderful. Have a very pleasant day ahead!"
        }
    }
}
