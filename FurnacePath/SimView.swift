import SwiftUI

struct SimView: View {
    @StateObject private var sim = SimStore()
    @EnvironmentObject var progress: Store
    @State private var plant = ""
    @State private var furnace = ""
    @State private var accepted = Set<Int>()
    @State private var prices: [Int: Double] = [:]
    @State private var standing = ""
    @State private var overflow = false
    @State private var showEvent = true
    @State private var showDebrief = false
    @State private var confirmQuit = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = sim.error {
                    Text(error).foregroundStyle(Color.orangeAccent)
                    Button("Reload sim state") { Task { await sim.load(); resetChoices() } }
                }
                if sim.busy { ProgressView("Contacting P51…") }
                if let result = sim.result { resultView(result) }
                else if let state = sim.state { playView(state) }
                else if let data = sim.data, sim.loaded { setupView(data) }
                else if sim.error == nil { ProgressView("Loading Run the Shop…") }
                if sim.loaded { historyView }
                Text("Practice numbers from the venture model · not a real quote.").font(.caption)
            }.padding().frame(maxWidth: 700)
        }.background(Color.paper).navigationTitle("Run the Shop").navigationBarTitleDisplayMode(.inline)
            .task { await sim.load() }
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Refresh") { Task { await sim.refreshDebriefs() } } } }
            .confirmationDialog("Quit this run? Your active simulation will be abandoned.", isPresented: $confirmQuit, titleVisibility: .visible) {
                Button("Quit run", role: .destructive) { Task { await sim.abandon(); resetChoices() } }
            }
    }
    @ViewBuilder func setupView(_ data: SimData) -> some View {
        Text("Choose your plant and furnace. Then run 12 months.")
        Text("Pick the plant").font(.title2.bold())
        ForEach(data.plants) { p in
            Button { plant = p.id } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(plant == p.id ? "✓ " : "")\(p.name)").font(.headline)
                    Text(p.desc)
                    if let tag = p.tag { Text(tag).bold() }
                    if let placeholder = p.placeholder { Text(placeholder) }
                    if let growth = p.growthNote { Text(growth) }
                    Text("Occupancy \(money(p.occupancy))/mo · Launch \(money(p.baseLaunchCost)) + furnace").font(.caption)
                }.card()
            }.buttonStyle(.plain)
        }
        Text("Pick the furnace").font(.title2.bold())
        ForEach(data.furnaces) { f in
            Button { furnace = f.id } label: {
                VStack(alignment: .leading) { Text("\(furnace == f.id ? "✓ " : "")\(f.name)").font(.headline); Text(f.desc); Text(money(f.cost)) }.card()
            }.buttonStyle(.plain)
        }
        if let p = data.plants.first(where: { $0.id == plant }), let f = data.furnaces.first(where: { $0.id == furnace }) {
            VStack(alignment: .leading) {
                Text("Starting position").font(.headline)
                metric("Funding", money(data.funding))
                metric("Plant launch", money(p.baseLaunchCost))
                metric("Furnace", money(f.cost))
                metric("Starting cash", money(data.funding - p.baseLaunchCost - f.cost))
                metric("Monthly fixed", money(p.occupancy + data.basePayroll + data.insuranceMisc))
                metric("Break-even billed", money(p.breakEven))
            }.card()
            Button("Launch the business") { Task { await sim.launch(plant: plant, furnace: furnace); resetChoices() } }.buttonStyle(.borderedProminent).disabled(sim.busy || sim.error != nil)
        }
    }
    @ViewBuilder func playView(_ state: SimState) -> some View {
        Text("Month \(state.month) of 12").font(.title.bold())
        VStack {
            metric("Cash", money(state.cash)); metric("Last billed", money(state.lastBilled))
            metric("Utilization", "\(Int(usedHours(state) / max(1, state.capacityHrs) * 100))%")
            metric("Reputation", state.reputation.formatted())
            metric("Awaiting collection", money(state.pendingCollection + state.delayedCollection))
            metric("Accepted jobs", "\(accepted.count)")
        }.card()
        if state.anchorActive { Text("Anchor account: \(state.anchorLoads) loads at \(money(state.anchorPrice)); \((Double(state.anchorLoads) * state.anchorHrsPerLoad).formatted()) hrs reserved").card() }
        Text("Job offers · select to accept").font(.headline)
        ForEach(Array(state.monthJobs.enumerated()), id: \.offset) { index, job in
            jobView(job, index: index, state: state)
        }
        ProgressView(value: min(usedHours(state), state.capacityHrs), total: max(1, state.capacityHrs)).tint(.steel)
        Text("\(usedHours(state).formatted()) / \(state.capacityHrs.formatted()) furnace hrs used")
        if let definition = sim.data?.standingDecisions.first(where: { $0.type == state.monthStandingDecisionType }) {
            Text(definition.title).font(.title2.bold()); Text(definition.desc)
            ForEach(definition.options, id: \.value) { option in
                Button { standing = option.value } label: {
                    VStack(alignment: .leading) { Text("\(standing == option.value ? "✓ " : "")\(option.label)").bold(); Text(option.desc) }.card()
                }.buttonStyle(.plain)
            }
        }
        if state.plant == "woodworth_flint" { Toggle("Use Woodworth overflow for capacity-rejected work (up to 8 hrs; keep 40% of contribution)", isOn: $overflow) }
        Button("End month \(state.month)") {
            let mapped = Dictionary(uniqueKeysWithValues: prices.map { (String($0.key), $0.value) })
            Task {
                await sim.submit(MonthDecisions(acceptedJobs: accepted.sorted(), playerPrices: mapped, standingDecision: standing, woodworthOverflow: overflow))
                showEvent = true; showDebrief = false
                await progress.refresh()
            }
        }.buttonStyle(.borderedProminent).disabled(standing.isEmpty || sim.busy || sim.error != nil)
        Button("Quit run", role: .destructive) { confirmQuit = true }.disabled(sim.busy)
    }
    @ViewBuilder func jobView(_ job: SimJob, index: Int, state: SimState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { accepted.contains(index) }, set: { selected in
                if !selected { accepted.remove(index) }
                else if usedHours(state) + job.furnaceHrs <= state.capacityHrs { accepted.insert(index) }
            })) { Text(job.title).font(.headline) }
            Text("\(job.customerType.uppercased()) · \(job.subtitle)")
            Text("\(job.weight.formatted()) lb · \(job.furnaceHrs.formatted()) hrs")
            if job.pricing == "player", let minimum = job.priceMin, let maximum = job.priceMax {
                Text("Your price: \(money(prices[index] ?? minimum))")
                Slider(value: Binding(get: { prices[index] ?? minimum }, set: { prices[index] = $0.rounded() }), in: minimum...maximum, step: 1)
                Text("\(money(minimum)) – \(money(maximum))").font(.caption)
            } else { Text("Price: \(money(job.price ?? 0))") }
            let price = job.pricing == "player" ? (prices[index] ?? job.priceMin ?? 0) : (job.price ?? 0)
            Text("Contribution: \(money((price - job.variableCost) / max(0.1, job.furnaceHrs)))/furnace hr").foregroundStyle(Color.steel)
            if !accepted.contains(index) && usedHours(state) + job.furnaceHrs > state.capacityHrs { Text("Exceeds available capacity").foregroundStyle(Color.orangeAccent) }
        }.card().disabled(sim.busy)
    }
    @ViewBuilder func resultView(_ result: SimMonthResult) -> some View {
        if showEvent, let event = result.event {
            VStack(alignment: .leading, spacing: 16) { Text(event.title).font(.title.bold()); Text(event.desc); Text(event.teaching).foregroundStyle(Color.steel) }.card()
            Button("Continue to P&L") { showEvent = false }.buttonStyle(.borderedProminent)
        } else if showDebrief, let score = result.scoring {
            Text(result.status == "game_over" ? "Cash out" : "12 months complete").font(.largeTitle.bold())
            Text("\(score.grade) · Score \(score.score) · +\(score.xp) XP").font(.title2)
            metric("Months survived", "\(score.monthsSurvived)"); metric("Best billed", money(score.bestBilled)); metric("Ending cash", money(result.state.cash))
            if let cause = score.cause { Text("What went wrong").font(.headline); Text(cause) }
            if let weak = score.weakSpots {
                Text("Weak spots").font(.headline)
                ForEach(Array(weak.enumerated()), id: \.offset) { _, pair in
                    if pair.count >= 2 { Text("\(pair[0].text): \(pair[1].text) months needing work") }
                }
            }
            debriefNote(result.runId)
            Button("New run") { sim.state = nil; sim.result = nil; resetChoices() }.buttonStyle(.borderedProminent)
        } else {
            pnlView(result.pnl)
            if result.status == "continue" {
                Button("Start month \(result.state.month)") { sim.result = nil; resetChoices() }.buttonStyle(.borderedProminent)
            } else { Button("See debrief and final score") { showDebrief = true }.buttonStyle(.borderedProminent) }
        }
    }
    @ViewBuilder func pnlView(_ pnl: SimPNL) -> some View {
        Text("Month \(pnl.month) P&L").font(.title.bold())
        Text("\(pnl.loads) loads · \(pnl.utilizationPct.formatted())% utilization")
        VStack(spacing: 10) {
            metric("Billed", money(pnl.billed)); metric("Collected (net 30)", money(pnl.collected))
            metric("Variable costs", money(pnl.variableCosts)); metric("Fixed costs", money(pnl.fixedCosts))
            metric("Event cost", money(pnl.eventCost)); Divider(); metric("Net cash flow", money(pnl.net)); metric("Cash balance", money(pnl.cashEnd))
            metric("Break-even target", money(pnl.breakEven))
        }.card()
        if let occupancy = pnl.occupancy {
            Text("Occupancy (included in fixed): \(money(occupancy)). Woodworth overflow: \((pnl.woodworthOverflowHrs ?? 0).formatted()) hrs, billed \(money(pnl.woodworthOverflowBilled ?? 0)), partner costs \(money(pnl.woodworthOverflowCost ?? 0)). Backup saved \((pnl.woodworthBackupHrs ?? 0).formatted()) hrs; routing fee \(money(pnl.woodworthBackupFee ?? 0)).").card()
        }
        Text(pnl.teachingLine).foregroundStyle(Color.steel).card()
    }
    var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Run history").font(.title2.bold())
            if sim.history.isEmpty { Text("No completed runs yet.") }
            ForEach(sim.history) { run in
                DisclosureGroup("Run \(run.run_id) · \(run.grade) · \(run.ending_month) months") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(run.plant) · \(run.furnace)")
                        Text("Score \(run.score) · +\(run.xp_awarded) XP")
                        metric("Ending cash", money(run.ending_cash)); metric("Best billed", money(run.best_month_billed))
                        if let cause = run.cause_of_death { Text(cause) }
                        debriefNote(run.run_id)
                    }.padding(.top)
                }.card()
            }
        }
    }
    func debriefNote(_ id: Int) -> some View {
        VStack(alignment: .leading) {
            Text("Tutor debrief").font(.headline)
            Text(sim.debriefs.first { $0.run_id == id }?.text ?? "This run is queued for a tutor debrief. Refresh after the next review.")
        }
    }
    func metric(_ label: String, _ value: String) -> some View { HStack(alignment: .firstTextBaseline) { Text(label); Spacer(); Text(value).bold().multilineTextAlignment(.trailing) } }
    func money(_ value: Double) -> String { value.formatted(.currency(code: "USD").precision(.fractionLength(0))) }
    func usedHours(_ state: SimState) -> Double {
        accepted.reduce(0) { $0 + (state.monthJobs.indices.contains($1) ? state.monthJobs[$1].furnaceHrs : 0) } + (state.anchorActive ? Double(state.anchorLoads) * state.anchorHrsPerLoad : 0)
    }
    func resetChoices() { accepted = []; prices = [:]; standing = ""; overflow = false; showEvent = true; showDebrief = false }
}
