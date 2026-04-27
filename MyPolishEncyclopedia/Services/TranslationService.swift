import Foundation

enum TranslationError: Error, LocalizedError {
    case badResponse(Int)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "Translation API returned status \(code)"
        case .emptyResult: return "Translation returned an empty result"
        }
    }
}

actor TranslationService {
    func translate(english: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": APIConfig.claudeModel,
            "max_tokens": 100,
            "messages": [
                [
                    "role": "user",
                    "content": "Translate the following English word or phrase into Polish. Reply with only the Polish translation, nothing else: \(english)"
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard httpResponse.statusCode == 200 else {
            throw TranslationError.badResponse(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let text = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TranslationError.emptyResult }
        return text
    }

    func translateWords(_ words: [String]) async throws -> [String: String] {
        let uniqueWords = Array(Set(words.map { $0.lowercased() })).sorted()
        guard !uniqueWords.isEmpty else { return [:] }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": APIConfig.claudeModel,
            "max_tokens": 400,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Translate each English word into Polish. Reply with only a JSON object whose keys are the exact English words and whose values are the Polish translations. No markdown, no explanation.

                    Words: \(uniqueWords.joined(separator: ", "))
                    """
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard httpResponse.statusCode == 200 else {
            throw TranslationError.badResponse(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let text = decoded.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TranslationError.emptyResult }

        guard let jsonData = text.data(using: .utf8) else {
            throw TranslationError.emptyResult
        }
        return try JSONDecoder().decode([String: String].self, from: jsonData)
    }
}

// MARK: - Response types

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let text: String
}
