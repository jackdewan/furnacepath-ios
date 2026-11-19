import SwiftUI

extension Color {
    static let ink = Color(red: 27/255, green: 34/255, blue: 48/255)
    static let paper = Color(red: 255/255, green: 248/255, blue: 236/255)
    static let orangeAccent = Color(red: 232/255, green: 93/255, blue: 31/255)
    static let steel = Color(red: 0.055, green: 0.486, blue: 0.482)
    static let amber = Color(red: 0.95, green: 0.66, blue: 0.11)
}
@main struct FurnacePathApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).furnaceTheme()
                .task { await store.bootstrap() }
                .onChange(of: scenePhase) { _, phase in if phase == .active, store.authState == .signedIn || store.authState == .demo { Task { await store.refresh() } } }
        }
    }
}
struct Round: Identifiable { let id = UUID(); let title: String; let mode: String; let questions: [Question] }
struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = Verification.tab
    @State private var round: Round?
    @State private var showProfile = false
    let categories = ["Basics", "Pricing", "Capacity", "Cash", "Buildings", "Risk"]
    let levels = [("Operator", 0), ("Foreman", 500), ("Plant Mgr", 1500), ("Owner", 3000)]
    func start(_ title: String, _ mode: String, _ questions: [Question]) {
        guard !questions.isEmpty else { return }
        round = Round(title: title, mode: mode, questions: questions)
    }
    var body: some View {
        Group {
        if store.authState == .signedOut {
            SignInView()
        } else if store.authState == .unknown && store.state == nil {
            ProgressView("Starting…").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
        } else {
        VStack(spacing: 0) {
            if store.failed {
                VStack { Text("Can't reach your progress on the P51. Check that Tailscale is connected, then retry.")
                    Button("Retry") { Task { await store.refresh() } }.disabled(store.loading)
                }.padding().background(Color.amber.opacity(0.2))
            }
            if let state = store.state, let bank = store.bank {
                TabView(selection: $tab) {
                    page("Path") {
                        Text("\(state.xp) XP · \(state.streak) day streak").font(.headline)
                        if state.reviewDueCount > 0 { Button("Resume · \(state.reviewDueCount) reviews due →") { tab = 2 } }
                        Button("Sprint · 5 questions") { start("Sprint", "sprint", Array(store.questions.filter { $0.unit > 0 }.shuffled().prefix(5))) }.buttonStyle(.borderedProminent)
                        NavigationLink("Run the Shop · Resume / New run") { SimView() }
                        Button("CEO Rep") { start("CEO Rep", "ceorep", store.questions.filter { $0.scenario == true }) }.buttonStyle(.bordered)
                        ForEach(bank.units) { unit in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("UNIT \(unit.id) · \(unit.title)").font(.headline)
                                Text(unit.subtitle).font(.subheadline)
                                let complete = state.units.first { $0.unitId == unit.id }?.lessonsCompleted ?? 0
                                ProgressView(value: Double(complete), total: Double(max(1, unit.totalLessons))).tint(.steel)
                                Text("\(complete) of \(unit.totalLessons) lessons complete").font(.caption)
                                let lessons = Array(Set(store.questions.filter { $0.unit == unit.id }.compactMap(\.lesson).filter { $0 > 0 })).sorted()
                                ForEach(lessons, id: \.self) { lesson in
                                    Button("Lesson \(lesson) →") { start("\(unit.title) · Lesson \(lesson)", "lesson", store.questions.filter { $0.unit == unit.id && $0.lesson == lesson }) }
                                }
                            }.card()
                        }
                    }.tabItem { Label("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(0)
                    page("Drills") {
                        ForEach(categories, id: \.self) { category in
                            Button { start(category, "drill", Array(store.questions.filter { $0.unit > 0 && $0.category == category }.shuffled().prefix(5))) } label: {
                                HStack { VStack(alignment: .leading) { Text(category).font(.headline); Text("\(store.questions.filter { $0.unit > 0 && $0.category == category }.count) questions") }; Spacer(); Text("\(state.categoryStats[category]?.pct ?? 0)% →") }
                            }.card()
                        }
                    }.tabItem { Label("Drills", systemImage: "bolt") }.tag(1)
                    page("Review") {
                        if let queue = store.queue {
                            Text(queue.isEmpty ? "All caught up!" : "\(queue.count) cards due today").font(.headline)
                            if !queue.isEmpty { Button("Start review") { start("Review", "review", Array(store.reviewQuestions.prefix(5))) }.buttonStyle(.borderedProminent) }
                            ForEach(queue, id: \.question_id) { item in
                                if let q = store.questions.first(where: { $0.id == item.question_id }) {
                                    VStack(alignment: .leading) { Text(q.category).font(.caption); Text(q.prompt); Text("Missed \(item.times_missed) times · Due today").font(.caption) }.card()
                                }
                            }
                        } else { ProgressView("Loading review queue…") }
                        if let tutor = store.tutor {
                            Text("Tutor reviews · \(tutor.pending) thinking answers awaiting review").font(.headline)
                            ForEach(Array(tutor.reviews.enumerated()), id: \.offset) { _, review in
                                VStack(alignment: .leading, spacing: 8) {
                                    if let data = review.question_json.data(using: .utf8), let q = try? JSONDecoder().decode(Question.self, from: data) { Text(q.prompt).font(.headline) }
                                    if let reasoning = review.reasoning { Text("Your work: \(reasoning)") }
                                    Text("Tutor reviewed · \(review.verdict ?? "Pending")").bold()
                                    Text(review.feedback ?? "Awaiting feedback")
                                }.card()
                            }
                        }
                        if store.tutorFailed { Text("Tutor notes unavailable. Pull to refresh.") }
                    }.tabItem { Label("Review", systemImage: "arrow.clockwise") }.tag(2)
                    page("Mastery") {
                        Text("Weak spots").font(.title2.bold())
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading) { Text("\(category) · \(state.categoryStats[category]?.pct ?? 0)%"); ProgressView(value: Double(state.categoryStats[category]?.pct ?? 0), total: 100).tint(.steel) }
                        }
                        Button("Review queue · \(state.reviewDueCount) due →") { tab = 2 }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coach").font(.title2.bold())
                            if let tutor = store.tutor {
                                Text(tutor.coach?.text ?? "Your coach note will appear after the tutor reviews your thinking answers.")
                                if let coach = tutor.coach {
                                    Text("Current focus: \(coach.top_misconception.replacingOccurrences(of: "_", with: " "))")
                                    Button("Drill it") { Task { await store.refresh(); let pool = store.questions.filter { $0.generated == true && $0.misconception == coach.top_misconception }; if pool.count >= 5 { start("Coach drill", "tutor_drill", Array(pool.shuffled().prefix(5))) } } }
                                    .disabled(store.questions.filter { $0.generated == true && $0.misconception == coach.top_misconception }.count < 5)
                                }
                            } else { Text(store.tutorFailed ? "Coach unavailable. Pull to refresh." : "Loading coach…") }
                        }.card()
                        NavigationLink("Run the Shop history and debriefs") { SimView() }
                        Text("Owner Track").font(.title2.bold())
                        ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                            VStack(alignment: .leading) {
                                Text("\(state.xp >= level.1 ? "✓" : "○") \(level.0)").font(.headline)
                                if state.xp < level.1 { Text("\(level.1 - state.xp) XP needed") }
                                else if index < levels.count - 1 && state.xp < levels[index + 1].1 {
                                    ProgressView(value: Double(state.xp - level.1), total: Double(levels[index + 1].1 - level.1)).tint(.steel)
                                } else { Text("Achieved") }
                            }.card()
                        }
                    }.tabItem { Label("Mastery", systemImage: "chart.bar") }.tag(3)
                }
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom) { WarmTabBar(selection: $tab) }
            } else if store.loading { ProgressView("Loading your progress…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { ContentUnavailableView("Progress unavailable", systemImage: "network.slash", description: Text("Connect to Tailscale and tap Retry.")) }
        }
        }
        }.foregroundStyle(Color.ink)
        .sheet(item: $round) { round in LessonView(round: round).environmentObject(store).furnaceTheme() }
        .sheet(isPresented: $showProfile) { NavigationStack { ProfileView() }.environmentObject(store).furnaceTheme() }
        .onChange(of: store.authState) { _, value in
            if value == .signedOut { showProfile = false; round = nil }
        }
        .onChange(of: store.bank != nil) { _, ready in
            if ready && Verification.screen == "lesson" { start("The Language of Money · Lesson 1", "lesson", Array(store.questions.filter { $0.type == "mc" }.prefix(2))) }
            #if DEBUG && targetEnvironment(simulator)
            if ready && (Verification.screen == "profile" || Verification.screen == "profile-demo") { showProfile = true }
            #endif
        }
    }
    func page<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20, content: content).padding().frame(maxWidth: 700) }.background(Color.paper).navigationTitle(title).refreshable { await store.refresh() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showProfile = true } label: { Image(systemName: "person.crop.circle").foregroundStyle(Color.ink) }.accessibilityIdentifier("open-profile") } }
            .navigationDestination(isPresented: .constant(Verification.screen == "sim")) { SimView() } }
    }
}
extension View {
    func card() -> some View { self.padding().frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16)) }
}

// Paper surfaces always use the light semantic environment, including system chrome
// and presented sheets. Accent tint belongs to controls, never inherited body text.
struct FurnaceTheme: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(Color.ink).tint(.ink)
            .background(Color.paper).preferredColorScheme(.light)
            .environment(\.colorScheme, .light)
    }
}
extension View {
    func furnaceTheme() -> some View { modifier(FurnaceTheme()) }
}
struct WarmTabBar: View {
    @Binding var selection: Int
    let tabs = [("Path", "point.topleft.down.to.point.bottomright.curvepath"), ("Drills", "bolt"), ("Review", "arrow.clockwise"), ("Mastery", "chart.bar")]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs.indices, id: \.self) { index in
                Button { selection = index } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].1).font(.system(size: 20))
                            .foregroundStyle(selection == index ? Color.orangeAccent : Color.ink)
                        Text(tabs[index].0).font(.caption2.bold()).foregroundStyle(Color.ink)
                    }.frame(maxWidth: .infinity).frame(height: 52)
                        .background(selection == index ? Color.orangeAccent.opacity(0.12) : .clear, in: Capsule())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }.padding(5).background(.ultraThinMaterial, in: Capsule())
            .background(Color(red: 1, green: 252/255, blue: 245/255).opacity(0.62), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.75)))
            .shadow(color: .ink.opacity(0.15), radius: 12, y: 5)
            .frame(maxWidth: 430).padding(.horizontal, 16).padding(.bottom, 8)
    }
}
struct AnswerCardStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(Color.ink).padding(16)
            .background(selected ? Color.orangeAccent.opacity(0.12) : Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.orangeAccent : Color.ink.opacity(0.25), lineWidth: selected ? 2 : 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
