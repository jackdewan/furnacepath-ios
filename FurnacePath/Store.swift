import Foundation
import SwiftUI

struct API {
    static let base = URL(string: "http://100.87.179.24:3011")!
    static func request<T: Decodable>(_ path: String, body: Data? = nil) async throws -> T {
        if Verification.screen != nil { return try Verification.response(path, body: body) }
        var request = URLRequest(url: base.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func updateReview(questionId: String, correct: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["questionId": questionId, "correct": correct])
        let _: [String: Bool] = try await request("api/update-review", body: body)
    }
}
@MainActor final class Store: ObservableObject {
    @Published var state: ProgressState?
    @Published var bank: Bank?
    @Published var queue: [ReviewItem]?
    @Published var tutor: Tutor?
    @Published var failed = false
    @Published var loading = false
    @Published var tutorFailed = false
    func refresh() async {
        guard !loading else { return }; loading = true
        defer { loading = false }
        do {
            let progress: ProgressState = try await API.request("api/state")
            state = progress
            let content: Bank = try await API.request("data/questions.json")
            bank = content
            let reviews: [ReviewItem] = try await API.request("api/review-queue")
            queue = reviews; failed = false
        } catch { failed = true }
        do { tutor = try await API.request("api/tutor"); tutorFailed = false } catch { tutorFailed = true }
    }
    var questions: [Question] { bank?.questions ?? [] }
    var reviewQuestions: [Question] { (queue ?? []).compactMap { item in questions.first { $0.id == item.question_id } } }
}
