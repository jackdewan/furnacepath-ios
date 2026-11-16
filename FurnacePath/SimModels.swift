import Foundation

struct SimData: Decodable {
    let plants: [Plant]; let furnaces: [Furnace]; let funding: Double
    let basePayroll: Double; let insuranceMisc: Double; let standingDecisions: [StandingDefinition]
}
struct Plant: Decodable, Identifiable {
    let id: String; let name: String; let desc: String; let occupancy: Double; let baseLaunchCost: Double; let breakEven: Double
    let tag: String?; let placeholder: String?; let growthNote: String?
}
struct Furnace: Decodable, Identifiable { let id: String; let name: String; let desc: String; let cost: Double }
struct StandingDefinition: Decodable { let type: String; let title: String; let desc: String; let options: [StandingOption] }
struct StandingOption: Decodable { let value: String; let label: String; let desc: String }
struct SimEnvelope: Decodable { let active: Bool; let runId: Int?; let state: SimState? }
struct SimNewResult: Decodable { let ok: Bool; let runId: Int; let state: SimState }
struct SimState: Decodable {
    let plant: String; let furnace: String; let month: Int; let cash: Double; let reputation: Double
    let capacityHrs: Double; let lastBilled: Double; let phase: String
    let anchorActive: Bool; let anchorLoads: Int; let anchorPrice: Double; let anchorHrsPerLoad: Double
    let monthJobs: [SimJob]; let monthStandingDecisionType: String?
    let pendingCollection: Double; let delayedCollection: Double
}
struct SimJob: Decodable {
    let title: String; let subtitle: String; let furnaceHrs: Double; let weight: Double; let pricing: String
    let price: Double?; let priceMin: Double?; let priceMax: Double?; let variableCost: Double; let customerType: String
}
struct SimEvent: Decodable { let title: String; let desc: String; let teaching: String }
struct SimMonthResult: Decodable {
    let ok: Bool; let runId: Int; let state: SimState; let status: String; let pnl: SimPNL; let event: SimEvent?; let scoring: SimScore?
}
struct SimPNL: Decodable {
    let month: Int; let loads: Int; let utilizationPct: Double; let billed: Double; let collected: Double
    let variableCosts: Double; let fixedCosts: Double; let eventCost: Double; let net: Double; let cashEnd: Double
    let breakEven: Double; let teachingLine: String
    let occupancy: Double?; let woodworthOverflowHrs: Double?; let woodworthOverflowBilled: Double?; let woodworthOverflowCost: Double?
    let woodworthBackupHrs: Double?; let woodworthBackupFee: Double?
}
struct SimScore: Decodable {
    let grade: String; let score: Int; let xp: Int; let bestBilled: Double; let monthsSurvived: Int; let cause: String?
    let weakSpots: [[JSONValue]]?
}
struct SimHistory: Decodable, Identifiable {
    var id: Int { run_id }
    let run_id: Int; let plant: String; let furnace: String; let ending_month: Int; let ending_cash: Double
    let best_month_billed: Double; let cause_of_death: String?; let grade: String; let score: Int; let xp_awarded: Int
}
struct SimDebrief: Decodable { let run_id: Int; let text: String?; let status: String }
struct SimTutor: Decodable { let debriefs: [SimDebrief] }
struct MonthDecisions: Encodable {
    let acceptedJobs: [Int]; let playerPrices: [String: Double]; let standingDecision: String; let woodworthOverflow: Bool
}
