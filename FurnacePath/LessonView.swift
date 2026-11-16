import SwiftUI

struct LessonView: View {
    let round: Round
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var index = 0
    @State private var answers: [RoundAnswer] = []
    @State private var given: Double?
    @State private var numeric = ""
    @State private var reasoning = ""
    @State private var confidence = ""
    @State private var saving = false
    @State private var saved = false
    @State private var error: String?
    var correctCount: Int { answers.filter(\.correct).count }
    var xp: Int { correctCount * 10 + (correctCount == answers.count && !answers.isEmpty ? 50 : 0) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if saved {
                        Text("Round complete").font(.largeTitle.bold())
                        Text("\(correctCount * 100 / max(1, answers.count))% accuracy · +\(xp) XP").font(.title2)
                        Text("Weak spots").font(.headline)
                        if answers.allSatisfy(\.correct) { Text("Perfect round. Keep practicing to stay sharp.") }
                        ForEach(round.questions.filter { q in answers.contains { $0.questionId == q.id && !$0.correct } }) { q in
                            VStack(alignment: .leading) { Text(q.prompt).bold(); Text(q.explanation) }.card()
                        }
                        Text("Thinking answers are queued for tutor review. Find feedback in Review and Coach notes in Mastery.")
                        Button("Back to learning") { dismiss() }.buttonStyle(.borderedProminent)
                    } else if index < round.questions.count {
                        let q = round.questions[index]
                        ProgressView(value: Double(index), total: Double(round.questions.count)).tint(.steel)
                        Text("Question \(index + 1) of \(round.questions.count) · \(q.category)").font(.caption)
                        Text(q.prompt).font(.title2.bold())
                        if let job = q.jobCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("JOB CARD · PRACTICE").font(.caption.bold())
                                ForEach(job.keys.sorted(), id: \.self) { key in Text("\(key): \(job[key]?.text ?? "")") }
                            }.card()
                        }
                        if q.type == "mc" {
                            ForEach(Array((q.choices ?? []).enumerated()), id: \.offset) { choice, text in
                                Button { given = Double(choice) } label: {
                                    HStack { Text(text); Spacer(); if given == Double(choice) { Image(systemName: "checkmark.circle.fill") } }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.bordered).disabled(given != nil)
                            }
                        } else {
                            TextField("Enter your answer", text: $numeric).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).disabled(given != nil)
                            Button("Check") { if let number = Double(numeric), number.isFinite { given = number } }.disabled(given != nil || Double(numeric) == nil)
                        }
                        if let value = given {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(q.isCorrect(value) ? "✓ Correct" : "Not quite").font(.headline).foregroundStyle(q.isCorrect(value) ? Color.steel : Color.orangeAccent)
                                Text(q.explanation)
                            }.card()
                            if q.thinking == true || q.scenario == true {
                                Text("Show your work (optional)").font(.headline)
                                TextField("How did you decide?", text: $reasoning, axis: .vertical).lineLimit(3...8).textFieldStyle(.roundedBorder)
                                Picker("Confidence", selection: $confidence) {
                                    Text("Optional").tag(""); Text("Sure").tag("sure"); Text("Unsure").tag("unsure"); Text("Guessing").tag("guessing")
                                }.pickerStyle(.menu)
                            }
                            Button(index == round.questions.count - 1 ? "See results" : "Continue") { advance(q, value) }.buttonStyle(.borderedProminent)
                        }
                        Text("Practice numbers from the venture model · not a real quote.").font(.caption)
                    } else {
                        if saving { ProgressView("Saving round…") }
                        if let error { Text(error); Button("Retry save") { Task { await save() } }.disabled(saving) }
                    }
                }.padding()
            }.background(Color.paper).navigationTitle(round.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(saving) } }
        }.interactiveDismissDisabled(saving)
    }
    func advance(_ q: Question, _ value: Double) {
        answers.append(RoundAnswer(questionId: q.id, correct: q.isCorrect(value), givenAnswer: value, reasoning: reasoning.isEmpty ? nil : String(reasoning.prefix(4000)), confidence: confidence.isEmpty ? nil : confidence))
        index += 1; given = nil; numeric = ""; reasoning = ""; confidence = ""
        if index == round.questions.count { Task { await save() } }
    }
    func save() async {
        saving = true; error = nil
        defer { saving = false }
        do {
            let payload = RoundPayload(mode: round.mode, answers: answers, xpEarned: xp)
            let result: SaveResult = try await API.request("api/complete-round", body: JSONEncoder().encode(payload))
            guard result.ok else { throw URLError(.badServerResponse) }
            saved = true
            await store.refresh()
        } catch { self.error = "Couldn't confirm the save. Check Tailscale. If the connection dropped after saving, check progress before retrying to avoid a duplicate round." }
    }
}
