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
}

// MARK: - Response types

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let text: String
}
