import Foundation

struct Bank: Decodable { let units: [LearningUnit]; let questions: [Question] }
struct LearningUnit: Decodable, Identifiable { let id: Int; let title: String; let subtitle: String; let totalLessons: Int }
struct Question: Decodable, Identifiable {
    let id: String; let unit: Int; let lesson: Int?; let category: String; let type: String; let prompt: String
    let choices: [String]?; let correct: Int?; let expected: Double?; let tolerance: Double?; let explanation: String
    let thinking: Bool?; let scenario: Bool?; let generated: Bool?; let misconception: String?; let jobCard: [String: JSONValue]?
    func isCorrect(_ value: Double) -> Bool { type == "mc" ? value == Double(correct ?? -1) : abs(value - (expected ?? .infinity)) <= (tolerance ?? 0) }
}
struct ProgressState: Decodable {
    let xp: Int; let streak: Int; let currentUnit: Int; let reviewDueCount: Int
    let units: [UnitProgress]; let categoryStats: [String: CategoryStat]
}
struct UnitProgress: Decodable { let unitId: Int; let lessonsCompleted: Int }
struct CategoryStat: Decodable { let total: Int; let correct: Int; let pct: Int }
struct ReviewItem: Decodable { let question_id: String; let times_missed: Int }
struct Tutor: Decodable { let pending: Int; let coach: Coach?; let reviews: [TutorReview] }
struct Coach: Decodable { let text: String; let top_misconception: String }
struct TutorReview: Decodable { let question_json: String; let reasoning: String?; let verdict: String?; let feedback: String? }
struct RoundAnswer: Encodable {
    let questionId: String; let correct: Bool; let givenAnswer: Double; let reasoning: String?; let confidence: String?
}
struct RoundPayload: Encodable { let mode: String; let answers: [RoundAnswer]; let xpEarned: Int }
struct SaveResult: Decodable { let ok: Bool; let xp: Int; let streak: Int }

// MARK: - Auth models
struct AuthResponse: Decodable { let sessionToken: String; let isDemo: Bool? }
struct ClaimResponse: Decodable { let dryRun: Bool; let claimEnabled: Bool; let dataset: ClaimDataset }
struct ClaimUnit: Decodable { let unitId: Int; let lessonsCompleted: Int }
struct ClaimDataset: Decodable {
    let xp: Int; let streak: Int; let currentUnit: Int
    let units: [ClaimUnit]; let answerCount: Int; let reviewQueueCount: Int
    let simHistoryCount: Int; let roundCount: Int
}
struct PairResponse: Decodable { let code: String; let expiresIn: Int? }
struct UserInfo: Codable {
    let name: String?; let email: String?
    static let key = "fp_user_info"
    static func save(_ info: UserInfo) { if let d = try? JSONEncoder().encode(info) { UserDefaults.standard.set(d, forKey: key) } }
    static func load() -> UserInfo? { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(UserInfo.self, from: $0) } }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool), other
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s) }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else { self = .other }
    }
    var text: String { switch self { case .string(let s): return s; case .number(let n): return String(n); case .bool(let b): return b ? "Yes" : "No"; case .other: return "" } }
}
