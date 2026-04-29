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
    var dailySession = DailySession.empty

    private let storage = StorageService()
    private let translator = TranslationService()
    private let elevenLabs = ElevenLabsService()
    private let dailySessionKey = "dailySession"

    func loadEntries() {
        do {
            let all = try storage.load()
            words   = all.filter { $0.type == .word  }.sorted { $0.createdAt > $1.createdAt }
            phrases = all.filter { $0.type == .phrase }.sorted { $0.createdAt > $1.createdAt }
            prepareDailySession()
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
            case .phrase:
                phrases.insert(entry, at: 0)
                prepareDailySession()
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
        prepareDailySession()
        do {
            try storage.save(allEntries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    var dailyEntries: [PolishEntry] {
        dailySession.phraseIDs.compactMap { id in
            phrases.first { $0.id == id }
        }
    }

    var currentDailyEntry: PolishEntry? {
        let entries = dailyEntries
        guard dailySession.currentIndex < entries.count else { return nil }
        return entries[dailySession.currentIndex]
    }

    var dailyScore: Int {
        dailySession.results.filter { $0.grade == .gotIt }.count
    }

    var dailyIsComplete: Bool {
        !dailyEntries.isEmpty && dailySession.currentIndex >= dailyEntries.count
    }

    func revealDailyAnswer() {
        dailySession.isAnswerRevealed = true
        saveDailySession()
    }

    func gradeDailyAnswer(_ grade: DailyGrade) {
        guard dailySession.currentIndex < dailyEntries.count else { return }
        let phraseID = dailyEntries[dailySession.currentIndex].id
        dailySession.results.removeAll { $0.phraseID == phraseID }
        dailySession.results.append(DailyResult(phraseID: phraseID, grade: grade))
        dailySession.currentIndex += 1
        dailySession.isAnswerRevealed = false
        saveDailySession()
    }

    func restartDailySession() {
        dailySession = makeDailySession()
        saveDailySession()
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

    private func prepareDailySession() {
        let today = Self.dayKey(for: Date())
        dailySession = loadDailySession() ?? makeDailySession()

        if dailySession.dayKey != today {
            dailySession = makeDailySession()
        } else {
            let availablePhraseIDs = Set(phrases.map(\.id))
            dailySession.phraseIDs = dailySession.phraseIDs.filter { availablePhraseIDs.contains($0) }
            dailySession.results = dailySession.results.filter { availablePhraseIDs.contains($0.phraseID) }
            if dailySession.phraseIDs.isEmpty && !phrases.isEmpty {
                dailySession = makeDailySession()
            } else if dailySession.currentIndex > dailySession.phraseIDs.count {
                dailySession.currentIndex = dailySession.phraseIDs.count
            }
        }

        saveDailySession()
    }

    private func makeDailySession() -> DailySession {
        DailySession(
            dayKey: Self.dayKey(for: Date()),
            phraseIDs: Array(phrases.shuffled().prefix(5).map(\.id)),
            currentIndex: 0,
            isAnswerRevealed: false,
            results: []
        )
    }

    private func loadDailySession() -> DailySession? {
        guard let data = UserDefaults.standard.data(forKey: dailySessionKey) else { return nil }
        return try? JSONDecoder().decode(DailySession.self, from: data)
    }

    private func saveDailySession() {
        guard let data = try? JSONEncoder().encode(dailySession) else { return }
        UserDefaults.standard.set(data, forKey: dailySessionKey)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum DailyGrade: String, Codable {
    case gotIt
    case almost
    case missed

    var label: String {
        switch self {
        case .gotIt: return "Got it"
        case .almost: return "Almost"
        case .missed: return "Missed"
        }
    }
}

struct DailyResult: Codable, Equatable {
    var phraseID: UUID
    var grade: DailyGrade
}

struct DailySession: Codable, Equatable {
    var dayKey: String
    var phraseIDs: [UUID]
    var currentIndex: Int
    var isAnswerRevealed: Bool
    var results: [DailyResult]

    static let empty = DailySession(
        dayKey: "",
        phraseIDs: [],
        currentIndex: 0,
        isAnswerRevealed: false,
        results: []
    )
}
