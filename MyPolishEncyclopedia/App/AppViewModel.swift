import Foundation
import Observation

@Observable
@MainActor
class AppViewModel {
    var words: [PolishEntry] = []
    var phrases: [PolishEntry] = []
    var isTranslating = false
    var errorMessage: String?
    var loadingAudioIDs: Set<UUID> = []

    private let storage = StorageService()
    private let translator = TranslationService()
    private let elevenLabs = ElevenLabsService()

    func loadEntries() {
        do {
            let all = try storage.load()
            words   = all.filter { $0.type == .word  }.sorted { $0.createdAt > $1.createdAt }
            phrases = all.filter { $0.type == .phrase }.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load entries: \(error.localizedDescription)"
        }
    }

    func addEntry(english: String, type: EntryType) async {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isTranslating = true
        errorMessage = nil
        defer { isTranslating = false }

        do {
            let polish = try await translator.translate(english: trimmed)
            let entryType: EntryType = extractedWords(from: trimmed).count > 1 ? .phrase : type
            let entry = PolishEntry(english: trimmed, polish: polish, type: entryType)

            switch entryType {
            case .word:   words.insert(entry, at: 0)
            case .phrase: phrases.insert(entry, at: 0)
            }

            var wordError: Error?
            if entryType == .phrase {
                do {
                    try await addWords(from: trimmed)
                } catch {
                    wordError = error
                }
            }

            try storage.save(allEntries)
            if let wordError {
                errorMessage = "Phrase saved, but words could not be added: \(wordError.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playAudio(for entry: PolishEntry) async {
        loadingAudioIDs.insert(entry.id)
        defer { loadingAudioIDs.remove(entry.id) }

        do {
            // Use cached audio if available
            if let cached = entry.audioData {
                await elevenLabs.play(audio: cached)
                return
            }

            // Fetch, cache, play
            let audio = try await elevenLabs.fetchAudio(polish: entry.polish)
            updateAudioCache(for: entry.id, data: audio)
            try storage.save(allEntries)
            await elevenLabs.play(audio: audio)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: PolishEntry) {
        words.removeAll   { $0.id == entry.id }
        phrases.removeAll { $0.id == entry.id }
        do {
            try storage.save(allEntries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private

    private var allEntries: [PolishEntry] {
        (words + phrases).sorted { $0.createdAt < $1.createdAt }
    }

    private func addWords(from phrase: String) async throws {
        let phraseWords = extractedWords(from: phrase)
        let existingWords = Set(words.map { $0.english.lowercased() })
        let missingWords = phraseWords.filter { !existingWords.contains($0.lowercased()) }
        guard !missingWords.isEmpty else { return }

        let translations = try await translator.translateWords(missingWords)
        for english in missingWords.reversed() {
            let polish = translations[english.lowercased()] ?? translations[english] ?? english
            words.insert(PolishEntry(english: english, polish: polish, type: .word), at: 0)
        }
    }

    private func extractedWords(from text: String) -> [String] {
        let pattern = #"[A-Za-z]+(?:['-][A-Za-z]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen: Set<String> = []

        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let word = String(text[matchRange]).lowercased()
            guard seen.insert(word).inserted else { return nil }
            return word
        }
    }

    private func updateAudioCache(for id: UUID, data: Data) {
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].audioData = data
        } else if let i = phrases.firstIndex(where: { $0.id == id }) {
            phrases[i].audioData = data
        }
    }
}
