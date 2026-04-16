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
            let entry = PolishEntry(english: trimmed, polish: polish, type: type)

            switch type {
            case .word:   words.insert(entry, at: 0)
            case .phrase: phrases.insert(entry, at: 0)
            }

            try storage.save(allEntries)
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

    // MARK: - Private

    private var allEntries: [PolishEntry] {
        (words + phrases).sorted { $0.createdAt < $1.createdAt }
    }

    private func updateAudioCache(for id: UUID, data: Data) {
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].audioData = data
        } else if let i = phrases.firstIndex(where: { $0.id == id }) {
            phrases[i].audioData = data
        }
    }
}
