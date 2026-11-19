import SwiftUI

// MARK: - Design Tokens (Instrument light — normative token table from REDESIGN_AUTH_BRIEF.md)
extension Color {
    static let paper = Color(red: 247/255, green: 246/255, blue: 242/255)       // #F7F6F2
    static let ink = Color(red: 22/255, green: 24/255, blue: 29/255)            // #16181D
    static let orangeAccent = Color(red: 232/255, green: 93/255, blue: 31/255)  // #E85D1F fills & graphics
    static let accentInk = Color(red: 180/255, green: 68/255, blue: 8/255)      // #B44408 ALL accent text
    static let danger = Color(red: 192/255, green: 57/255, blue: 43/255)        // #C0392B
    static let successGreen = Color(red: 30/255, green: 158/255, blue: 97/255)  // #1E9E61
    static let accentTint = Color(red: 252/255, green: 238/255, blue: 226/255)  // #FCEEE2
    static let greenTint = Color(red: 227/255, green: 244/255, blue: 234/255)   // #E3F4EA
    static let surface2 = Color(red: 239/255, green: 237/255, blue: 230/255)    // #EFEDE6
    static let lineBorder = Color(red: 229/255, green: 226/255, blue: 217/255)  // #E5E2D9
    static let hero = Color(red: 20/255, green: 22/255, blue: 26/255)           // #14161A
    static let trackBg = Color(red: 234/255, green: 231/255, blue: 222/255)     // #EAE7DE
    static let amber = Color(red: 232/255, green: 147/255, blue: 12/255)        // #E8930C
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
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Starting…").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
        } else {
        VStack(spacing: 0) {
            if store.failed { networkBanner }
            if let state = store.state, let bank = store.bank {
                TabView(selection: $tab) {
                    pathTab(state, bank)
                        .tabItem { Label("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(0)
                    page("Drills") { drillsContent(state) }
                        .tabItem { Label("Drills", systemImage: "bolt") }.tag(1)
                    page("Review") { reviewContent(state) }
                        .tabItem { Label("Review", systemImage: "arrow.clockwise") }.tag(2)
                    page("Mastery") { masteryContent(state) }
                        .tabItem { Label("Mastery", systemImage: "chart.bar") }.tag(3)
                }
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom) { InstrumentTabBar(selection: $tab) }
            } else if store.loading { ProgressView("Loading your progress…").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper) }
            else {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.slash").font(.system(size: 48)).foregroundStyle(Color.ink.opacity(0.25))
                    Text("Progress unavailable").font(.title3.bold())
                    Text("Connect to Tailscale and tap Retry.").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)).multilineTextAlignment(.center)
                    Button { Task { await store.refresh() } } label: {
                        Text("Retry").font(.body.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 32).padding(.vertical, 14)
                            .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
            }
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
            if ready && Verification.screen == "feedback-correct" { start("Feedback · Correct", "lesson", Array(store.questions.filter { $0.type == "mc" }.prefix(1))) }
            if ready && Verification.screen == "feedback-wrong" { start("Feedback · Wrong", "lesson", Array(store.questions.filter { $0.type == "mc" }.prefix(1))) }
            #if DEBUG && targetEnvironment(simulator)
            if ready && (Verification.screen == "profile" || Verification.screen == "profile-demo") { showProfile = true }
            #endif
        }
    }

    // MARK: - Network banner

    var networkBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(Color.amber).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Can't reach the P51").font(.subheadline.bold())
                Text("Check that Tailscale is connected, then retry.").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }
            Spacer()
            Button("Retry") { Task { await store.refresh() } }.font(.subheadline.weight(.medium)).disabled(store.loading)
        }
        .padding(14).background(Color.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    // MARK: - Path Tab (current unit first per accepted point 7)

    func pathTab(_ state: ProgressState, _ bank: Bank) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pathHeader(state)

                    // Current unit + lesson timeline first
                    if let currentUnit = bank.units.first(where: { $0.id == state.currentUnit }) {
                        unitSection(currentUnit, state, expanded: true)
                    }

                    // Sprint hero card
                    sprintCard(state)

                    // CEO Rep
                    ceoRepCard

                    // Remaining units
                    ForEach(bank.units.filter { $0.id != state.currentUnit }) { unit in
                        unitSection(unit, state, expanded: false)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 100)
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
            .navigationDestination(isPresented: .constant(Verification.screen == "sim")) { SimView() }
        }
    }

    func pathHeader(_ state: ProgressState) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text("FurnacePath").font(.system(size: 17, weight: .bold)).tracking(-0.3)
            }
            Spacer()
            // Streak chip
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(Color.orangeAccent)
                Text("\(state.streak)").font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text("DAY").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.ink.opacity(0.4)).tracking(0.5)
            }
            .padding(.horizontal, 13).frame(height: 34)
            .background(.white, in: Capsule()).overlay(Capsule().strokeBorder(Color.lineBorder))
            // XP chip
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(Color.amber)
                Text("\(state.xp)").font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text("XP").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.ink.opacity(0.4)).tracking(0.5)
            }
            .padding(.horizontal, 13).frame(height: 34)
            .background(.white, in: Capsule()).overlay(Capsule().strokeBorder(Color.lineBorder))
            // Profile
            Button { showProfile = true } label: {
                Image(systemName: "person.crop.circle").font(.system(size: 22)).foregroundStyle(Color.ink.opacity(0.4))
            }.accessibilityIdentifier("open-profile")
        }.padding(.top, 8)
    }

    func sprintCard(_ state: ProgressState) -> some View {
        Button {
            start("Sprint", "sprint", Array(store.questions.filter { $0.unit > 0 }.shuffled().prefix(5)))
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DAILY SPRINT")
                        .font(.system(size: 11, weight: .bold)).tracking(1.3)
                        .foregroundStyle(Color(red: 1, green: 0.54, blue: 0.3))
                    Text("5 questions · 5 minutes")
                        .font(.system(size: 19, weight: .semibold)).tracking(-0.2).foregroundStyle(.white)
                    Text("Mixed review · Units 1–\(store.questions.compactMap { $0.unit > 0 ? $0.unit : nil }.max() ?? 1)")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text("Start").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 19).padding(.vertical, 11)
                    .background(Color.orangeAccent, in: Capsule())
            }
            .padding(20).background(Color.hero, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(.plain)
    }

    var ceoRepCard: some View {
        Button {
            start("CEO Rep", "ceorep", store.questions.filter { $0.scenario == true })
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "briefcase").font(.system(size: 18)).foregroundStyle(Color.orangeAccent)
                    .frame(width: 41, height: 41)
                    .background(Color.accentTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("CEO Rep").font(.system(size: 16, weight: .semibold)).tracking(-0.15)
                    Text("Owner-level scenarios").font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.55))
                }
                Spacer()
                Text("20 MIN").font(.system(size: 10.5, weight: .bold)).tracking(0.6).foregroundStyle(Color.ink.opacity(0.55))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .overlay(Capsule().strokeBorder(Color.lineBorder))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink.opacity(0.3))
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.lineBorder))
        }.buttonStyle(.plain)
    }

    func unitSection(_ unit: LearningUnit, _ state: ProgressState, expanded: Bool) -> some View {
        let complete = state.units.first { $0.unitId == unit.id }?.lessonsCompleted ?? 0
        let lessons = Array(Set(store.questions.filter { $0.unit == unit.id }.compactMap(\.lesson).filter { $0 > 0 })).sorted()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("UNIT \(unit.id)").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
                Spacer()
                Text("\(complete) of \(unit.totalLessons) lessons").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink.opacity(0.55))
            }
            Text(unit.title).font(.system(size: 21, weight: .bold)).tracking(-0.4).padding(.top, 5)
            Text(unit.subtitle).font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.55)).padding(.top, 2)
            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999).fill(Color.trackBg)
                    RoundedRectangle(cornerRadius: 999).fill(Color.orangeAccent)
                        .frame(width: geo.size.width * CGFloat(complete) / CGFloat(max(1, unit.totalLessons)))
                }
            }.frame(height: 6).padding(.top, 13)

            if !lessons.isEmpty {
                // Lesson timeline with connecting line
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.lineBorder).frame(width: 2)
                        .padding(.leading, 13).padding(.top, 30).padding(.bottom, 30)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(lessons, id: \.self) { lesson in
                            let isDone = lesson <= complete
                            let isCurrent = lesson == complete + 1
                            let qCount = store.questions.filter { $0.unit == unit.id && $0.lesson == lesson }.count
                            Button {
                                start("\(unit.title) · Lesson \(lesson)", "lesson",
                                      store.questions.filter { $0.unit == unit.id && $0.lesson == lesson })
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        if isDone {
                                            Circle().fill(Color.successGreen).frame(width: 28, height: 28)
                                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                        } else if isCurrent {
                                            Circle().fill(.white).frame(width: 28, height: 28)
                                                .overlay(Circle().strokeBorder(Color.orangeAccent, lineWidth: 2))
                                                .shadow(color: Color.accentTint, radius: 5)
                                            Text("\(lesson)").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.orangeAccent)
                                        } else {
                                            Circle().fill(.white).frame(width: 28, height: 28)
                                                .overlay(Circle().strokeBorder(Color.lineBorder, lineWidth: 1.5))
                                            Text("\(lesson)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.ink.opacity(0.4))
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Lesson \(lesson)").font(.system(size: 16, weight: isDone ? .medium : .semibold))
                                            .foregroundStyle(isDone ? Color.ink.opacity(0.55) : Color.ink).tracking(-0.1)
                                        Text("\(qCount) question\(qCount == 1 ? "" : "s")").font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.4))
                                    }
                                    Spacer()
                                    if isCurrent {
                                        Text("UP NEXT").font(.system(size: 10, weight: .bold)).tracking(1.0).foregroundStyle(Color.accentInk)
                                            .padding(.horizontal, 9).padding(.vertical, 5)
                                            .background(Color.accentTint, in: Capsule())
                                    }
                                }.padding(.vertical, 14).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("unit-\(unit.id)-lesson-\(lesson)")
                        }
                    }
                }.padding(.top, 16)
            }

            if expanded && state.reviewDueCount > 0 {
                Button { tab = 2 } label: {
                    HStack(spacing: 4) {
                        Text("Resume · \(state.reviewDueCount) reviews due").font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.right").font(.caption)
                    }.foregroundStyle(Color.accentInk)
                }.padding(.top, 8)
            }
        }
    }

    // MARK: - Drills

    @ViewBuilder func drillsContent(_ state: ProgressState) -> some View {
        ForEach(categories, id: \.self) { category in
            let total = store.questions.filter { $0.unit > 0 && $0.category == category }.count
            let pct = state.categoryStats[category]?.pct ?? 0
            Button {
                start(category, "drill", Array(store.questions.filter { $0.unit > 0 && $0.category == category }.shuffled().prefix(5)))
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category).font(.system(size: 16, weight: .semibold))
                        Text("\(total) questions").font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.55))
                    }
                    Spacer()
                    Text("\(pct)%").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Color.accentInk)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink.opacity(0.3))
                }.instrumentCard()
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Review

    @ViewBuilder func reviewContent(_ state: ProgressState) -> some View {
        if let queue = store.queue {
            HStack {
                Text(queue.isEmpty ? "All caught up!" : "\(queue.count) cards due today").font(.headline)
                Spacer()
            }
            if !queue.isEmpty {
                Button { start("Review", "review", Array(store.reviewQuestions.prefix(5))) } label: {
                    Text("Start review").font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            ForEach(queue, id: \.question_id) { item in
                if let q = store.questions.first(where: { $0.id == item.question_id }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(q.category).font(.system(size: 11, weight: .bold)).tracking(1.0).foregroundStyle(Color.ink.opacity(0.4))
                        Text(q.prompt).font(.subheadline)
                        Text("Missed \(item.times_missed) times · Due today").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                    }.instrumentCard()
                }
            }
        } else { ProgressView("Loading review queue…") }

        if let tutor = store.tutor {
            if tutor.pending > 0 {
                Text("Tutor reviews · \(tutor.pending) thinking answers awaiting review").font(.headline).padding(.top, 8)
            }
            ForEach(Array(tutor.reviews.enumerated()), id: \.offset) { _, review in
                VStack(alignment: .leading, spacing: 8) {
                    if let data = review.question_json.data(using: .utf8), let q = try? JSONDecoder().decode(Question.self, from: data) {
                        Text(q.prompt).font(.subheadline.weight(.medium))
                    }
                    if let reasoning = review.reasoning { Text("Your work: \(reasoning)").font(.subheadline).foregroundStyle(Color.ink.opacity(0.7)) }
                    HStack(spacing: 6) {
                        Circle().fill(review.verdict == "correct" ? Color.successGreen : Color.amber).frame(width: 8, height: 8)
                        Text(review.verdict ?? "Pending").font(.subheadline.bold())
                    }
                    if let feedback = review.feedback { Text(feedback).font(.subheadline).foregroundStyle(Color.ink.opacity(0.7)) }
                }.instrumentCard()
            }
        }
        if store.tutorFailed { Text("Tutor notes unavailable. Pull to refresh.").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)) }
    }

    // MARK: - Mastery

    @ViewBuilder func masteryContent(_ state: ProgressState) -> some View {
        Text("Weak spots").font(.title2.bold())
        ForEach(categories, id: \.self) { category in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category).font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(state.categoryStats[category]?.pct ?? 0)%").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Color.accentInk)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999).fill(Color.trackBg)
                        RoundedRectangle(cornerRadius: 999).fill(Color.orangeAccent)
                            .frame(width: geo.size.width * CGFloat(state.categoryStats[category]?.pct ?? 0) / 100)
                    }
                }.frame(height: 6)
            }
        }
        Button { tab = 2 } label: {
            HStack(spacing: 4) {
                Text("Review queue · \(state.reviewDueCount) due").font(.subheadline.weight(.medium))
                Image(systemName: "arrow.right").font(.caption)
            }.foregroundStyle(Color.accentInk)
        }

        // Coach card
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach").font(.title2.bold())
            if let tutor = store.tutor {
                Text(tutor.coach?.text ?? "Your coach note will appear after the tutor reviews your thinking answers.")
                    .font(.subheadline).foregroundStyle(Color.ink.opacity(0.7))
                if let coach = tutor.coach {
                    HStack(spacing: 6) {
                        Text("Focus:").font(.subheadline.bold())
                        Text(coach.top_misconception.replacingOccurrences(of: "_", with: " ")).font(.subheadline).foregroundStyle(Color.accentInk)
                    }
                    Button {
                        Task { await store.refresh()
                            let pool = store.questions.filter { $0.generated == true && $0.misconception == coach.top_misconception }
                            if pool.count >= 5 { start("Coach drill", "tutor_drill", Array(pool.shuffled().prefix(5))) }
                        }
                    } label: {
                        Text("Drill it").font(.body.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(store.questions.filter { $0.generated == true && $0.misconception == coach.top_misconception }.count < 5)
                }
            } else { Text(store.tutorFailed ? "Coach unavailable. Pull to refresh." : "Loading coach…").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)) }
        }.instrumentCard()

        NavigationLink("Run the Shop history and debriefs") { SimView() }
            .font(.subheadline.weight(.medium)).foregroundStyle(Color.accentInk)

        // Owner Track
        Text("Owner Track").font(.title2.bold())
        ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: state.xp >= level.1 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(state.xp >= level.1 ? Color.successGreen : Color.ink.opacity(0.3))
                    Text(level.0).font(.headline)
                }
                if state.xp < level.1 {
                    Text("\(level.1 - state.xp) XP needed").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                } else if index < levels.count - 1 && state.xp < levels[index + 1].1 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999).fill(Color.trackBg)
                            RoundedRectangle(cornerRadius: 999).fill(Color.orangeAccent)
                                .frame(width: geo.size.width * CGFloat(state.xp - level.1) / CGFloat(levels[index + 1].1 - level.1))
                        }
                    }.frame(height: 6)
                } else {
                    Text("Achieved").font(.caption).foregroundStyle(Color.successGreen)
                }
            }.instrumentCard()
        }
    }

    // MARK: - Page helper (for Drills, Review, Mastery)

    func page<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20, content: content).padding(.horizontal, 20).padding(.bottom, 100).frame(maxWidth: 700)
            }.background(Color.paper).navigationTitle(title).refreshable { await store.refresh() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle").foregroundStyle(Color.ink.opacity(0.4))
                }.accessibilityIdentifier("open-profile")
            }}
        }
    }
}

// MARK: - Card modifier (radius 20 per normative token table)

extension View {
    func instrumentCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.lineBorder))
    }
    func card() -> some View { instrumentCard() }
}

// MARK: - Theme

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

// MARK: - Tab Bar (Instrument floating glass capsule)

struct InstrumentTabBar: View {
    @Binding var selection: Int
    let tabs = [("Path", "point.topleft.down.to.point.bottomright.curvepath"),
                ("Drills", "bolt"), ("Review", "arrow.clockwise"), ("Mastery", "chart.bar")]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs.indices, id: \.self) { index in
                Button { selection = index } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tabs[index].1).font(.system(size: 20))
                            .foregroundStyle(selection == index ? Color.orangeAccent : Color.ink.opacity(0.4))
                        Text(tabs[index].0).font(.system(size: 10.5, weight: .semibold)).tracking(0.1)
                            .foregroundStyle(selection == index ? Color.ink : Color.ink.opacity(0.4))
                    }.frame(maxWidth: .infinity).frame(height: 54)
                        .background(selection == index ? Color.surface2 : .clear, in: Capsule())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }.padding(6)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.82), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.lineBorder))
            .shadow(color: .ink.opacity(0.15), radius: 12, y: 5)
            .frame(maxWidth: 430).padding(.horizontal, 16).padding(.bottom, 8)
    }
}

// MARK: - Accent text highlighting for question prompts

func accentPrompt(_ text: String) -> Text {
    guard let regex = try? NSRegularExpression(pattern: #"\$[\d,]+(?:/\w+)?|\d+%"#) else { return Text(text) }
    let ns = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return Text(text) }
    var result = Text(""); var last = text.startIndex
    for match in matches {
        guard let range = Range(match.range, in: text) else { continue }
        if last < range.lowerBound { result = result + Text(text[last..<range.lowerBound]) }
        result = result + Text(text[range]).foregroundColor(.accentInk)
        last = range.upperBound
    }
    if last < text.endIndex { result = result + Text(text[last...]) }
    return result
}
