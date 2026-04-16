import Foundation

enum EntryType: String, Codable {
    case word
    case phrase
}

struct PolishEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var english: String
    var polish: String
    var type: EntryType
    var createdAt: Date
    var audioData: Data?

    init(english: String, polish: String, type: EntryType) {
        self.id = UUID()
        self.english = english
        self.polish = polish
        self.type = type
        self.createdAt = Date()
        self.audioData = nil
    }
}
