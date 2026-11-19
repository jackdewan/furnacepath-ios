import SwiftUI

struct LessonView: View {
    let round: Round
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var index = 0
    @State private var answers: [RoundAnswer] = []
    @State private var selected: Int?       // MC choice index
    @State private var checked = false       // has "Check answer" been tapped
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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if saved {
                            resultsView
                        } else if index < round.questions.count {
                            questionView(round.questions[index])
                        } else {
                            if saving { ProgressView("Saving round…") }
                            if let error { Text(error).font(.subheadline); Button("Retry save") { Task { await save() } }.disabled(saving) }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, checked ? 240 : 100)
                }
                .background(Color.paper)

                // Bottom area: "Check answer" button or feedback sheet
                if !saved && index < round.questions.count {
                    let q = round.questions[index]
                    if checked {
                        feedbackSheet(q)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        checkAnswerButton(q)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: checked)
            .toolbar(.hidden, for: .navigationBar)
        }
        .furnaceTheme()
        .interactiveDismissDisabled(saving)
        .onAppear { handleVerification() }
    }

    // MARK: - Top bar

    func topBar(_ q: Question) -> some View {
        HStack(spacing: 14) {
            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Color.lineBorder))
            }.disabled(saving)

            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999).fill(Color.trackBg)
                    RoundedRectangle(cornerRadius: 999).fill(Color.orangeAccent)
                        .frame(width: geo.size.width * CGFloat(index) / CGFloat(max(1, round.questions.count)))
                }
            }.frame(height: 6)

            // XP chip
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(Color.amber)
                Text("+10 XP").font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 11).frame(height: 32)
            .background(.white, in: Capsule()).overlay(Capsule().strokeBorder(Color.lineBorder))
        }
    }

    // MARK: - Question view

    @ViewBuilder func questionView(_ q: Question) -> some View {
        topBar(q)

        // Eyebrow
        HStack {
            Text(round.title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.0).foregroundStyle(Color.ink.opacity(0.4))
            Spacer()
            Text("\(index + 1) of \(round.questions.count)").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink.opacity(0.55))
        }.padding(.top, 4)

        // Prompt with accent-colored figures
        accentPrompt(q.prompt).font(.system(size: 24, weight: .bold)).tracking(-0.3)

        // Job card if present
        if let job = q.jobCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("JOB CARD · PRACTICE").font(.system(size: 11, weight: .bold)).tracking(1.0).foregroundStyle(Color.ink.opacity(0.4))
                ForEach(job.keys.sorted(), id: \.self) { key in Text("\(key): \(job[key]?.text ?? "")").font(.subheadline) }
            }.instrumentCard()
        }

        // Multiple choice
        if q.type == "mc" {
            let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
            ForEach(Array((q.choices ?? []).enumerated()), id: \.offset) { choiceIndex, text in
                let isSelected = selected == choiceIndex
                let isCorrectChoice = choiceIndex == q.correct
                Button {
                    if !checked { selected = choiceIndex }
                } label: {
                    HStack(spacing: 12) {
                        // Letter chip
                        Text(letters[safe: choiceIndex] ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(chipTextColor(isSelected: isSelected, isCorrect: isCorrectChoice, checked: checked))
                            .frame(width: 30, height: 30)
                            .background(chipBgColor(isSelected: isSelected, isCorrect: isCorrectChoice, checked: checked),
                                       in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(text).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Checkmark only after grading, only on correct answer
                        if checked && isCorrectChoice {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22)).foregroundStyle(Color.successGreen)
                        }
                        // X mark on wrong selected answer
                        if checked && isSelected && !isCorrectChoice {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22)).foregroundStyle(Color.danger)
                        }
                    }
                    .padding(16)
                    .background(cardBgColor(isSelected: isSelected, isCorrect: isCorrectChoice, checked: checked),
                               in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(cardBorderColor(isSelected: isSelected, isCorrect: isCorrectChoice, checked: checked),
                                     lineWidth: isSelected || (checked && isCorrectChoice) ? 2 : 1))
                }
                .buttonStyle(.plain).disabled(checked)
            }
        } else {
            // Numeric input
            TextField("Enter your answer", text: $numeric)
                .keyboardType(.decimalPad)
                .font(.system(size: 18, weight: .medium))
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.lineBorder))
                .disabled(checked)
        }

        // Thinking question reasoning (shown after checking)
        if checked && (q.thinking == true || q.scenario == true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Show your work (optional)").font(.subheadline.bold())
                TextField("How did you decide?", text: $reasoning, axis: .vertical)
                    .lineLimit(3...8).font(.subheadline)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lineBorder))
                Picker("Confidence", selection: $confidence) {
                    Text("Optional").tag(""); Text("Sure").tag("sure"); Text("Unsure").tag("unsure"); Text("Guessing").tag("guessing")
                }.pickerStyle(.menu)
            }
        }

        // Footer
        Text("Practice numbers from the venture model · not a real quote.")
            .font(.caption).foregroundStyle(Color.ink.opacity(0.4))
    }

    // MARK: - Check answer button (bottom)

    func checkAnswerButton(_ q: Question) -> some View {
        let canCheck: Bool = {
            if q.type == "mc" { return selected != nil }
            return Double(numeric) != nil
        }()
        return VStack(spacing: 0) {
            Divider()
            Button {
                if q.type == "mc" {
                    withAnimation { checked = true }
                } else if let number = Double(numeric), number.isFinite {
                    selected = 0
                    withAnimation { checked = true }
                }
            } label: {
                Text("Check answer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(canCheck ? Color.orangeAccent : Color.orangeAccent.opacity(0.4),
                               in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canCheck)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Color.paper)
    }

    // MARK: - Feedback sheet (Duolingo bottom sheet pattern)

    func feedbackSheet(_ q: Question) -> some View {
        let isCorrect: Bool = {
            if q.type == "mc" { return selected == q.correct }
            if let number = Double(numeric) { return q.isCorrect(number) }
            return false
        }()
        let isLast = index == round.questions.count - 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(isCorrect ? Color.successGreen : Color.danger)
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(isCorrect ? Color.successGreen : Color.danger)
            }
            Text(q.explanation).font(.subheadline).foregroundStyle(Color.ink.opacity(0.8))

            Button {
                advance(q)
            } label: {
                Text(isLast ? "See results" : "Continue")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(isCorrect ? Color.successGreen : Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(20).padding(.bottom, 8)
        .background((isCorrect ? Color.greenTint : Color.danger.opacity(0.08)), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Results view

    var resultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Round complete").font(.system(size: 28, weight: .bold)).tracking(-0.5)
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(correctCount * 100 / max(1, answers.count))%").font(.system(size: 32, weight: .bold).monospacedDigit()).foregroundStyle(Color.accentInk)
                    Text("accuracy").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                }
                VStack(spacing: 4) {
                    Text("+\(xp)").font(.system(size: 32, weight: .bold).monospacedDigit()).foregroundStyle(Color.successGreen)
                    Text("XP earned").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                }
            }

            if !answers.allSatisfy(\.correct) {
                Text("Review these").font(.headline).padding(.top, 8)
                ForEach(round.questions.filter { q in answers.contains { $0.questionId == q.id && !$0.correct } }) { q in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(q.prompt).font(.subheadline.weight(.medium))
                        Text(q.explanation).font(.caption).foregroundStyle(Color.ink.opacity(0.65))
                    }.instrumentCard()
                }
            } else {
                Text("Perfect round. Keep practicing to stay sharp.").font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
            }

            if round.questions.contains(where: { $0.thinking == true || $0.scenario == true }) {
                Text("Thinking answers are queued for tutor review.").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }

            Button { dismiss() } label: {
                Text("Back to learning").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Logic

    func advance(_ q: Question) {
        let value: Double
        if q.type == "mc" { value = Double(selected ?? -1) }
        else { value = Double(numeric) ?? -999 }

        answers.append(RoundAnswer(
            questionId: q.id, correct: q.isCorrect(value), givenAnswer: value,
            reasoning: reasoning.isEmpty ? nil : String(reasoning.prefix(4000)),
            confidence: confidence.isEmpty ? nil : confidence))

        index += 1; selected = nil; checked = false; numeric = ""; reasoning = ""; confidence = ""
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

    // MARK: - Verification auto-state

    func handleVerification() {
        #if DEBUG && targetEnvironment(simulator)
        guard let screen = Verification.screen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if screen == "lesson" {
                selected = 1 // Select answer B but don't check
            } else if screen == "feedback-correct" {
                guard let q = round.questions.first else { return }
                selected = q.correct
                checked = true
            } else if screen == "feedback-wrong" {
                guard let q = round.questions.first else { return }
                selected = q.correct == 0 ? 1 : 0
                checked = true
            }
        }
        #endif
    }

    // MARK: - Card color helpers

    func chipBgColor(isSelected: Bool, isCorrect: Bool, checked: Bool) -> Color {
        if checked {
            if isCorrect { return .successGreen }
            if isSelected { return .danger }
            return .surface2
        }
        return isSelected ? .orangeAccent : .surface2
    }
    func chipTextColor(isSelected: Bool, isCorrect: Bool, checked: Bool) -> Color {
        if checked {
            if isCorrect || isSelected { return .white }
            return .ink
        }
        return isSelected ? .white : .ink
    }
    func cardBgColor(isSelected: Bool, isCorrect: Bool, checked: Bool) -> Color {
        if checked {
            if isCorrect { return .greenTint }
            if isSelected { return Color.danger.opacity(0.08) }
            return .white
        }
        return isSelected ? .accentTint : .white
    }
    func cardBorderColor(isSelected: Bool, isCorrect: Bool, checked: Bool) -> Color {
        if checked {
            if isCorrect { return .successGreen }
            if isSelected { return .danger }
            return .lineBorder
        }
        return isSelected ? .orangeAccent : .lineBorder
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
