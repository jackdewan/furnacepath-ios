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
                    Text(error).font(.subheadline).foregroundStyle(Color.ink.opacity(0.7))
                    Button("Reload sim state") { Task { await sim.load(); resetChoices() } }
                        .font(.subheadline.weight(.medium)).foregroundStyle(Color.accentInk)
                }
                if sim.busy { ProgressView("Contacting P51…") }
                if let result = sim.result { resultView(result) }
                else if let state = sim.state { playView(state) }
                else if let data = sim.data, sim.loaded { setupView(data) }
                else if sim.error == nil { ProgressView("Loading Run the Shop…") }
                if sim.loaded { historyView }
                Text("Practice numbers from the venture model · not a real quote.")
                    .font(.caption).foregroundStyle(Color.ink.opacity(0.4))
            }.padding(.horizontal, 20).padding(.bottom, 100).frame(maxWidth: 700)
        }
        .background(Color.paper).navigationTitle("Run the Shop").navigationBarTitleDisplayMode(.inline)
        .task { await sim.load() }
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button("Refresh") { Task { await sim.refreshDebriefs() } }
                .font(.subheadline.weight(.medium))
        }}
        .confirmationDialog("Quit this run? Your active simulation will be abandoned.", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quit run", role: .destructive) { Task { await sim.abandon(); resetChoices() } }
        }
    }

    // MARK: - Setup (uses server-provided plant data, no hardcoded names)

    @ViewBuilder func setupView(_ data: SimData) -> some View {
        Text("Choose your plant and furnace").font(.title2.bold()).tracking(-0.3)
        Text("Then run 12 months.").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))

        Text("PLANT").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
            .padding(.top, 8)
        ForEach(data.plants) { p in
            Button { plant = p.id } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(p.name).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if plant == p.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orangeAccent)
                        }
                    }
                    Text(p.desc).font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
                    if let tag = p.tag { Text(tag).font(.subheadline.bold()) }
                    if let placeholder = p.placeholder { Text(placeholder).font(.caption).foregroundStyle(Color.ink.opacity(0.55)) }
                    if let growth = p.growthNote { Text(growth).font(.caption).foregroundStyle(Color.ink.opacity(0.55)) }
                    HStack(spacing: 16) {
                        Label(money(p.occupancy) + "/mo", systemImage: "building.2").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                        Label("Launch " + money(p.baseLaunchCost), systemImage: "arrow.up.circle").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(plant == p.id ? Color.orangeAccent : Color.lineBorder, lineWidth: plant == p.id ? 2 : 1))
            }.buttonStyle(.plain)
        }

        Text("FURNACE").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
            .padding(.top, 8)
        ForEach(data.furnaces) { f in
            Button { furnace = f.id } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(f.name).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if furnace == f.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orangeAccent)
                        }
                    }
                    Text(f.desc).font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
                    Text(money(f.cost)).font(.subheadline.weight(.medium))
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(furnace == f.id ? Color.orangeAccent : Color.lineBorder, lineWidth: furnace == f.id ? 2 : 1))
            }.buttonStyle(.plain)
        }

        if let p = data.plants.first(where: { $0.id == plant }), let f = data.furnaces.first(where: { $0.id == furnace }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("STARTING POSITION").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
                simMetric("Funding", money(data.funding))
                simMetric("Plant launch", money(p.baseLaunchCost))
                simMetric("Furnace", money(f.cost))
                Divider()
                simMetric("Starting cash", money(data.funding - p.baseLaunchCost - f.cost))
                simMetric("Monthly fixed", money(p.occupancy + data.basePayroll + data.insuranceMisc))
                simMetric("Break-even billed", money(p.breakEven))
            }.instrumentCard()

            Button {
                Task { await sim.launch(plant: plant, furnace: furnace); resetChoices() }
            } label: {
                Text("Launch the business").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
            }.disabled(sim.busy || sim.error != nil)
        }
    }

    // MARK: - Play View (Instrument shop dashboard)

    @ViewBuilder func playView(_ state: SimState) -> some View {
        // Eyebrow + month header
        Text("RUN THE SHOP").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
        HStack(alignment: .firstTextBaseline) {
            Text("Month \(state.month)").font(.system(size: 34, weight: .bold)).tracking(-0.5)
            Text("of 12").font(.system(size: 20, weight: .medium)).foregroundStyle(Color.ink.opacity(0.4))
            Spacer()
            // Plant chip (uses server name, no hardcoded real names)
            HStack(spacing: 6) {
                Circle().fill(Color.successGreen).frame(width: 8, height: 8)
                Text(plantDisplayName(state.plant)).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white, in: Capsule()).overlay(Capsule().strokeBorder(Color.lineBorder))
        }

        // Journey line
        journeyLine(currentMonth: state.month)

        Text("Survive all 12 months · graded on the Owner Track")
            .font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.55))

        // Stat grid 2×2
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard("CASH ON HAND", money(state.cash), nil)
            statCard("BILLED THIS MONTH", money(state.lastBilled), nil)
            statCard("FURNACE UTILIZATION", "\(Int(usedHours(state) / max(1, state.capacityHrs) * 100))%",
                     "\(Int(usedHours(state))) of \(Int(state.capacityHrs)) hrs booked")
            statCard("REPUTATION", state.reputation.formatted(), nil)
        }

        if state.anchorActive {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANCHOR ACCOUNT").font(.system(size: 11, weight: .bold)).tracking(1.0).foregroundStyle(Color.ink.opacity(0.4))
                Text("\(state.anchorLoads) loads at \(money(state.anchorPrice))")
                    .font(.subheadline.weight(.medium))
                Text("\((Double(state.anchorLoads) * state.anchorHrsPerLoad).formatted()) hrs reserved")
                    .font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }.instrumentCard()
        }

        // Job offers
        Text("JOB OFFERS").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Color.ink.opacity(0.4))
        ForEach(Array(state.monthJobs.enumerated()), id: \.offset) { index, job in
            jobView(job, index: index, state: state)
        }

        // Capacity bar
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999).fill(Color.trackBg)
                RoundedRectangle(cornerRadius: 999).fill(Color.orangeAccent)
                    .frame(width: geo.size.width * min(usedHours(state), state.capacityHrs) / max(1, state.capacityHrs))
            }
        }.frame(height: 6)
        Text("\(usedHours(state).formatted()) / \(state.capacityHrs.formatted()) furnace hrs used")
            .font(.caption).foregroundStyle(Color.ink.opacity(0.55))

        // Standing decision
        if let definition = sim.data?.standingDecisions.first(where: { $0.type == state.monthStandingDecisionType }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(definition.title).font(.headline)
                Text(definition.desc).font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
                ForEach(definition.options, id: \.value) { option in
                    Button { standing = option.value } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).font(.subheadline.weight(.semibold))
                                Text(option.desc).font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                            }
                            Spacer()
                            if standing == option.value {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orangeAccent)
                            }
                        }
                        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(standing == option.value ? Color.orangeAccent : Color.lineBorder,
                                         lineWidth: standing == option.value ? 2 : 1))
                    }.buttonStyle(.plain)
                }
            }.instrumentCard()
        }

        // End month button
        Button {
            let mapped = Dictionary(uniqueKeysWithValues: prices.map { (String($0.key), $0.value) })
            Task {
                await sim.submit(MonthDecisions(acceptedJobs: accepted.sorted(), playerPrices: mapped, standingDecision: standing, woodworthOverflow: overflow))
                showEvent = true; showDebrief = false
                await progress.refresh()
            }
        } label: {
            Text("End month \(state.month)").font(.body.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
        }.disabled(standing.isEmpty || sim.busy || sim.error != nil)

        Button("Quit run", role: .destructive) { confirmQuit = true }
            .font(.subheadline.weight(.medium)).foregroundStyle(Color.danger).disabled(sim.busy)
    }

    // MARK: - Job card (Instrument style)

    @ViewBuilder func jobView(_ job: SimJob, index: Int, state: SimState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(job.customerType.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color.ink.opacity(0.4))
                Spacer()
                Toggle(isOn: Binding(get: { accepted.contains(index) }, set: { selected in
                    if !selected { accepted.remove(index) }
                    else if usedHours(state) + job.furnaceHrs <= state.capacityHrs { accepted.insert(index) }
                })) { EmptyView() }.labelsHidden()
            }
            Text(job.title).font(.system(size: 16, weight: .semibold))
            Text(job.subtitle).font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))
            Text("\(job.weight.formatted()) lb · \(job.furnaceHrs.formatted()) hrs")
                .font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))

            if job.pricing == "player", let minimum = job.priceMin, let maximum = job.priceMax {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your price: \(money(prices[index] ?? minimum))").font(.subheadline.weight(.medium))
                    Slider(value: Binding(get: { prices[index] ?? minimum }, set: { prices[index] = $0.rounded() }),
                           in: minimum...maximum, step: 1).tint(Color.orangeAccent)
                    Text("\(money(minimum)) – \(money(maximum))").font(.caption).foregroundStyle(Color.ink.opacity(0.4))
                }
            } else {
                Text("Price: \(money(job.price ?? 0))").font(.subheadline.weight(.medium))
            }

            Divider()

            // Contribution metric
            let price = job.pricing == "player" ? (prices[index] ?? job.priceMin ?? 0) : (job.price ?? 0)
            let contrib = (price - job.variableCost) / max(0.1, job.furnaceHrs)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTRIBUTION").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Color.ink.opacity(0.4))
                    Text(money(contrib) + "/hr").font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(contrib > 0 ? Color.successGreen : Color.danger)
                }
                Spacer()
            }

            if !accepted.contains(index) && usedHours(state) + job.furnaceHrs > state.capacityHrs {
                Text("Exceeds available capacity").font(.caption).foregroundStyle(Color.danger)
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(accepted.contains(index) ? Color.orangeAccent : Color.lineBorder,
                         lineWidth: accepted.contains(index) ? 2 : 1))
        .disabled(sim.busy)
    }

    // MARK: - Result / P&L / Debrief

    @ViewBuilder func resultView(_ result: SimMonthResult) -> some View {
        if showEvent, let event = result.event {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title).font(.title2.bold()).tracking(-0.3)
                Text(event.desc).font(.subheadline)
                Text(event.teaching).font(.subheadline).foregroundStyle(Color.successGreen)
            }.instrumentCard()
            Button { showEvent = false } label: {
                Text("Continue to P&L").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        } else if showDebrief, let score = result.scoring {
            Text(result.status == "game_over" ? "Cash out" : "12 months complete")
                .font(.system(size: 28, weight: .bold)).tracking(-0.5)
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(score.grade).font(.system(size: 24, weight: .bold))
                    Text("Grade").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                }
                VStack(spacing: 4) {
                    Text("\(score.score)").font(.system(size: 24, weight: .bold).monospacedDigit())
                    Text("Score").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                }
                VStack(spacing: 4) {
                    Text("+\(score.xp)").font(.system(size: 24, weight: .bold).monospacedDigit()).foregroundStyle(Color.successGreen)
                    Text("XP").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                simMetric("Months survived", "\(score.monthsSurvived) of 12")
                simMetric("Best billed", money(score.bestBilled))
                simMetric("Ending cash", money(result.state.cash))
            }.instrumentCard()

            if let cause = score.cause {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What went wrong").font(.headline)
                    Text(cause).font(.subheadline).foregroundStyle(Color.danger)
                }.instrumentCard()
            }
            if let weak = score.weakSpots {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weak spots").font(.headline)
                    ForEach(Array(weak.enumerated()), id: \.offset) { _, pair in
                        if pair.count >= 2 {
                            Text("\(pair[0].text): \(pair[1].text) of 12 months needing work")
                                .font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
                        }
                    }
                }.instrumentCard()
            }
            debriefNote(result.runId)
            Button { sim.state = nil; sim.result = nil; resetChoices() } label: {
                Text("New run").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
            }
        } else {
            pnlView(result.pnl)
            if result.status == "continue" {
                Button { sim.result = nil; resetChoices() } label: {
                    Text("Start month \(result.state.month)").font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Button { showDebrief = true } label: {
                    Text("See debrief and final score").font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    @ViewBuilder func pnlView(_ pnl: SimPNL) -> some View {
        Text("Month \(pnl.month) P&L").font(.title2.bold()).tracking(-0.3)
        Text("\(pnl.loads) loads · \(pnl.utilizationPct.formatted())% utilization")
            .font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))
        VStack(alignment: .leading, spacing: 10) {
            simMetric("Billed", money(pnl.billed))
            simMetric("Collected (net 30)", money(pnl.collected))
            simMetric("Variable costs", money(pnl.variableCosts))
            simMetric("Fixed costs", money(pnl.fixedCosts))
            if pnl.eventCost != 0 { simMetric("Event cost", money(pnl.eventCost)) }
            Divider()
            HStack {
                Text("Net cash flow").font(.subheadline)
                Spacer()
                Text(money(pnl.net)).font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(pnl.net >= 0 ? Color.successGreen : Color.danger)
            }
            simMetric("Cash balance", money(pnl.cashEnd))
            simMetric("Break-even target", money(pnl.breakEven))
        }.instrumentCard()

        if let occupancy = pnl.occupancy {
            VStack(alignment: .leading, spacing: 4) {
                Text("OCCUPANCY DETAIL").font(.system(size: 11, weight: .bold)).tracking(1.0).foregroundStyle(Color.ink.opacity(0.4))
                Text("Occupancy (included in fixed): \(money(occupancy))").font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }.instrumentCard()
        }

        Text(pnl.teachingLine).font(.subheadline).foregroundStyle(Color.successGreen).instrumentCard()
    }

    // MARK: - History

    var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Run history").font(.title2.bold()).tracking(-0.3)
            if sim.history.isEmpty { Text("No completed runs yet.").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55)) }
            ForEach(sim.history) { run in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(run.plant) · \(run.furnace)").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))
                        simMetric("Score", "\(run.score)")
                        simMetric("XP", "+\(run.xp_awarded)")
                        simMetric("Ending cash", money(run.ending_cash))
                        simMetric("Best billed", money(run.best_month_billed))
                        if let cause = run.cause_of_death { Text(cause).font(.subheadline).foregroundStyle(Color.danger) }
                        debriefNote(run.run_id)
                    }.padding(.top, 8)
                } label: {
                    HStack {
                        Text("Run \(run.run_id)").font(.subheadline.weight(.semibold))
                        Text("·").foregroundStyle(Color.ink.opacity(0.4))
                        Text(run.grade).font(.subheadline.weight(.medium))
                        Text("·").foregroundStyle(Color.ink.opacity(0.4))
                        Text("\(run.ending_month) of 12 months").font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))
                    }
                }
                .instrumentCard()
            }
        }
    }

    // MARK: - Components

    func journeyLine(currentMonth: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(1...12, id: \.self) { month in
                    Circle()
                        .fill(month < currentMonth ? Color.orangeAccent :
                              month == currentMonth ? .white : Color.trackBg)
                        .frame(width: month == currentMonth ? 14 : 8, height: month == currentMonth ? 14 : 8)
                        .overlay {
                            if month == currentMonth {
                                Circle().strokeBorder(Color.orangeAccent, lineWidth: 2)
                            }
                        }
                    if month < 12 {
                        Rectangle().fill(month < currentMonth ? Color.orangeAccent : Color.trackBg)
                            .frame(height: 2).frame(maxWidth: .infinity)
                    }
                }
            }
            HStack {
                Text("M1").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.ink.opacity(0.4))
                Spacer()
                Text("MONTH \(currentMonth) · NOW")
                    .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Color.accentInk)
                Spacer()
                Text("M12").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.ink.opacity(0.4))
            }
        }
    }

    func statCard(_ label: String, _ value: String, _ caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Color.ink.opacity(0.4))
            Text(value).font(.system(size: 24, weight: .bold).monospacedDigit()).tracking(-0.3)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.lineBorder))
    }

    func debriefNote(_ id: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tutor debrief").font(.subheadline.bold())
            Text(sim.debriefs.first { $0.run_id == id }?.text ?? "This run is queued for a tutor debrief. Refresh after the next review.")
                .font(.subheadline).foregroundStyle(Color.ink.opacity(0.65))
        }
    }

    func simMetric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).multilineTextAlignment(.trailing)
        }
    }

    func money(_ value: Double) -> String { value.formatted(.currency(code: "USD").precision(.fractionLength(0))) }

    func usedHours(_ state: SimState) -> Double {
        accepted.reduce(0) { $0 + (state.monthJobs.indices.contains($1) ? state.monthJobs[$1].furnaceHrs : 0) }
            + (state.anchorActive ? Double(state.anchorLoads) * state.anchorHrsPerLoad : 0)
    }

    func plantDisplayName(_ plantId: String) -> String {
        sim.data?.plants.first { $0.id == plantId }?.name ?? plantId
    }

    func resetChoices() { accepted = []; prices = [:]; standing = ""; overflow = false; showEvent = true; showDebrief = false }
}
