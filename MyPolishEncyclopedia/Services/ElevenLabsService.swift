import AVFoundation
import Foundation

enum ElevenLabsError: Error, LocalizedError {
    case badResponse(Int, String)
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .badResponse(let code, let message):
            if message.isEmpty {
                return "ElevenLabs API returned status \(code)"
            }
            return "ElevenLabs API returned status \(code): \(message)"
        case .noAudioData:
            return "No audio data received"
        }
    }
}

actor ElevenLabsService {
    private var audioPlayer: AVAudioPlayer?

    func fetchAudio(polish: String) async throws -> Data {
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(APIConfig.elevenLabsVoiceID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": polish,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ElevenLabsError.badResponse(httpResponse.statusCode, message)
        }
        guard !data.isEmpty else { throw ElevenLabsError.noAudioData }
        return data
    }

    func play(audio: Data) async {
        await playOnMain(audio: audio)
    }

    @MainActor
    private func playOnMain(audio: Data) {
        do {
            let player = try AVAudioPlayer(data: audio)
            // Store on the actor to keep it alive during playback
            Task { await self.storePlayer(player) }
            player.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }

    private func storePlayer(_ player: AVAudioPlayer) {
        self.audioPlayer = player
    }
}
