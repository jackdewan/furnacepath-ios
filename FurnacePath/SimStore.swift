import Foundation
import SwiftUI

@MainActor final class SimStore: ObservableObject {
    @Published var data: SimData?
    @Published var state: SimState?
    @Published var history: [SimHistory] = []
    @Published var debriefs: [SimDebrief] = []
    @Published var result: SimMonthResult?
    @Published var busy = false
    @Published var error: String?
    @Published var loaded = false
    func load() async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            data = try await API.request("data/sim_data.json")
            let envelope: SimEnvelope = try await API.request("api/sim/state")
            state = envelope.state
            history = try await API.request("api/sim/history")
            loaded = true
        } catch { self.error = "Can't reach the sim on the P51. Check Tailscale, then retry." }
        await refreshDebriefs()
    }
    func refreshDebriefs() async {
        if let tutor: SimTutor = try? await API.request("api/tutor") { debriefs = tutor.debriefs }
    }
    func launch(plant: String, furnace: String) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["plant": plant, "furnace": furnace])
            let response: SimNewResult = try await API.request("api/sim/new", body: body)
            state = response.state; result = nil
        } catch { self.error = "Launch could not be confirmed. Reload sim state before trying again." }
    }
    func submit(_ decisions: MonthDecisions) async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            let response: SimMonthResult = try await API.request("api/sim/submit-month", body: JSONEncoder().encode(decisions))
            result = response; state = response.state
            if response.status == "finished" || response.status == "game_over" {
                if let runs: [SimHistory] = try? await API.request("api/sim/history") { history = runs }
                await refreshDebriefs()
            }
        } catch { self.error = "Month submission could not be confirmed. Reload sim state before submitting again; it may already have advanced." }
    }
    func abandon() async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            let _: [String: Bool] = try await API.request("api/sim/abandon", body: Data("{}".utf8))
            state = nil; result = nil
        } catch { self.error = "Couldn't confirm quitting. Reload sim state to check." }
    }
}
