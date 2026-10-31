import Foundation

/// Service orchestrating dynamic AI conversation roleplay, real-time grammar feedback,
/// and on-demand lexical word inspection.
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
    
    /// Sends a user message and fetches the AI's roleplay response with grammar feedback.
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
            let result = try await callGeminiForReply(
                history: messages,
                scenario: activeScenario,
                targetLanguage: targetLanguage
            )
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.reply,
                grammarFeedback: result.grammarFeedback,
                nativeTranslation: result.nativeTranslation
            )
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
    
    private struct GeminiChatResult {
        let reply: String
        let grammarFeedback: String?
        let nativeTranslation: String?
    }
    
    private func callGeminiForReply(
        history: [ChatMessage],
        scenario: ChatScenario,
        targetLanguage: TargetLanguage
    ) async throws -> GeminiChatResult {
        let apiKey = APIConfig.geminiAPIKey
        let activeModels = ["gemini-3.6-flash", "gemini-3.5-flash-lite"]
        
        let systemPrompt = """
        You are DayBySay AI, an empathetic, supportive, and dynamic conversation practice partner for non-English speaking immigrant elders and newcomers learning practical American survival English.
        
        Current Scenario: "\(scenario.title)"
        Your Roleplay Persona: \(scenario.roleplayPersona)
        Target Learner's Native Language: \(targetLanguage.displayName)
        
        You must respond in strict JSON matching this exact schema:
        {
          "roleplayReply": "Spoken English in-character reply (1 to 3 clear, natural sentences)",
          "grammarFeedback": "Optional string or null. If user made a grammar, vocabulary, or phrasing error, provide a gentle friendly tip with the natural way to say it in English (e.g. 'Instead of ..., you can say: ...'). If their input was good and natural, set to null.",
          "nativeTranslation": "Concise translation of roleplayReply in \(targetLanguage.displayName)"
        }
        
        CRITICAL TEACHING RULES:
        1. DYNAMIC & CONTEXTUAL: NEVER give canned or repetitive answers. React directly and specifically to what the user just said or ordered.
        2. OFF-TOPIC HANDLING: If the user shifts the topic (e.g. asks about the weather, movies, personal questions, or jokes), do NOT ignore them. React naturally and warmly in character (e.g. answer briefly or laugh) and conversationally tie it back.
        3. GRAMMAR COACHING: Non-native seniors often make word order or tense errors. When you detect one, provide constructive, positive feedback in grammarFeedback.
        4. ACCESSIBILITY: Keep roleplayReply concise (1-3 sentences) so the learner is not overwhelmed.
        5. \(scenario.systemInstructions)
        """
        
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
                "responseMimeType": "application/json",
                "temperature": 0.7,
                "maxOutputTokens": 300
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
            request.timeoutInterval = 12.0
            
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = root["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let contentObj = first["content"] as? [String: Any],
                       let parts = contentObj["parts"] as? [[String: Any]],
                       let jsonString = parts.first?["text"] as? String,
                       let parsedData = jsonString.data(using: .utf8),
                       let parsedDict = try? JSONSerialization.jsonObject(with: parsedData) as? [String: Any] {
                        
                        let reply = (parsedDict["roleplayReply"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let grammar = parsedDict["grammarFeedback"] as? String
                        let translation = parsedDict["nativeTranslation"] as? String
                        
                        if !reply.isEmpty {
                            return GeminiChatResult(
                                reply: reply,
                                grammarFeedback: grammar,
                                nativeTranslation: translation
                            )
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        // Intelligent dynamic local fallback if internet is completely disconnected
        return generateDynamicLocalFallback(for: history.last?.content ?? "", scenario: scenario)
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
        
        for modelName in ["gemini-3.6-flash", "gemini-3.5-flash-lite"] {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 8.0
            
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = root["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let contentObj = first["content"] as? [String: Any],
                   let parts = contentObj["parts"] as? [[String: Any]],
                   let jsonText = parts.first?["text"] as? String,
                   let parsedData = jsonText.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: parsedData) as? [String: Any] {
                    
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
            } catch {
                continue
            }
        }
        
        throw NSError(domain: "DayBySay", code: 500)
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
    
    /// Intelligent dynamic local fallback that responds specifically to user keywords
    private func generateDynamicLocalFallback(for input: String, scenario: ChatScenario) -> GeminiChatResult {
        let lower = input.lowercased()
        
        // Grammar heuristics
        var grammarTip: String? = nil
        if lower.contains("i wants") || lower.contains("he want ") {
            grammarTip = "Instead of 'I wants', try saying: 'I would like' or 'I want'."
        } else if lower.contains("me no") {
            grammarTip = "Instead of 'Me no...', try saying: 'I don't...' (e.g. 'I don't need a bag')."
        } else if lower.contains("how much it") {
            grammarTip = "Instead of 'how much it', try saying: 'How much is it?'"
        }
        
        // Dynamic contextual reply based on user content
        if lower.contains("paper") {
            return GeminiChatResult(
                reply: "Paper bags it is! Would you like your receipt in the bag or with you?",
                grammarFeedback: grammarTip,
                nativeTranslation: "好的，给您用纸袋！您想要收据放在袋子里还是直接拿给您？"
            )
        } else if lower.contains("plastic") {
            return GeminiChatResult(
                reply: "Sure thing, plastic bags ready! Do you have our rewards card today?",
                grammarFeedback: grammarTip,
                nativeTranslation: "没问题，塑料袋准备好了！您今天有会员积分卡吗？"
            )
        } else if lower.contains("weather") || lower.contains("rain") {
            return GeminiChatResult(
                reply: "Oh yeah, it definitely looks like rain out there! Stay dry on your way home.",
                grammarFeedback: grammarTip,
                nativeTranslation: "噢是啊，外面看起来确实要下雨了！回家路上注意别淋湿了。"
            )
        } else if lower.contains("movie") || lower.contains("film") {
            return GeminiChatResult(
                reply: "Haha, I love talking about movies! That's a great one. Anything else I can ring up for you today?",
                grammarFeedback: grammarTip,
                nativeTranslation: "哈哈，我也很喜欢聊电影！那部很棒。今天还有别的需要我结账的吗？"
            )
        } else if lower.contains("refill") || lower.contains("copay") {
            return GeminiChatResult(
                reply: "Let me check the pharmacy records for your prescription right now. It looks like you have two refills remaining.",
                grammarFeedback: grammarTip,
                nativeTranslation: "我现在就为您在药房系统里查询处方记录。看起来您还剩下两次续药额度。"
            )
        }
        
        return GeminiChatResult(
            reply: "Got it! \"\(input)\". I've got that noted for you. How else can I help today?",
            grammarFeedback: grammarTip,
            nativeTranslation: "明白了！我已经帮您记下了。今天还有什么我可以帮您的吗？"
        )
    }
}
