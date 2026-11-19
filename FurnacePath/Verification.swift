import Foundation

// Simulator-only, opt-in verification. Every request is intercepted before URLSession;
// POSTs and unknown routes fail closed, so screenshots cannot mutate production.
enum Verification {
    static var screen: String? {
        #if DEBUG && targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--verify-screen"), args.indices.contains(index + 1) { return args[index + 1] }
        #endif
        return nil
    }
    static var tab: Int { ["drills": 1, "review": 2, "mastery": 3][screen ?? ""] ?? 0 }
    static func response<T: Decodable>(_ path: String, body: Data?) throws -> T {
        #if DEBUG && targetEnvironment(simulator)
        let json: String
        if body != nil, let j = postFixtures[path] { json = j }
        else if body == nil, let j = fixtures[path] { json = j }
        else { throw URLError(.unsupportedURL) }
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        #else
        throw URLError(.unsupportedURL)
        #endif
    }
    #if DEBUG && targetEnvironment(simulator)
    static var fixtureClaimResponse: ClaimResponse {
        ClaimResponse(dryRun: true, claimEnabled: false, dataset: ClaimDataset(
            xp: 880, streak: 1, currentUnit: 1, units: [ClaimUnit(unitId: 1, lessonsCompleted: 5)],
            answerCount: 29, reviewQueueCount: 12, simHistoryCount: 2, roundCount: 15))
    }
    private static let postFixtures: [String: String] = [
        "api/auth/demo": #"{"sessionToken":"verification-demo","isDemo":true}"#,
        "api/auth/pair": #"{"code":"482019","expiresIn":600}"#,
    ]
    private static let fixtures: [String: String] = [
        "data/questions.json": questionsFixture,
        "data/sim_data.json": simDataFixture,
        "api/state": stateFixture,
        "api/review-queue": reviewFixture,
        "api/tutor": tutorFixture,
        "api/sim/state": #"{"active":false,"state":null}"#,
        "api/sim/history": "[]",
    ]

    // MARK: - Fixture data

    private static let stateFixture = #"""
    {"xp": 620, "streak": 4, "currentUnit": 1, "reviewDueCount": 1, "units": [{"unitId": 1, "lessonsCompleted": 5}], "categoryStats": {"Basics": {"total": 10, "correct": 7, "pct": 70}, "Pricing": {"total": 10, "correct": 7, "pct": 70}, "Capacity": {"total": 10, "correct": 7, "pct": 70}, "Cash": {"total": 10, "correct": 7, "pct": 70}, "Buildings": {"total": 10, "correct": 7, "pct": 70}, "Risk": {"total": 10, "correct": 7, "pct": 70}}}
    """#

    private static let reviewFixture = #"""
    [{"question_id": "u1q01", "times_missed": 2}]
    """#

    private static let tutorFixture = #"""
    {"pending": 0, "coach": {"text": "Practice contribution per furnace hour before choosing your next load.", "top_misconception": "contribution"}, "reviews": [], "debriefs": []}
    """#

    // Questions: one per lesson for unit 1 (8 lessons) so the path timeline renders fully
    private static let questionsFixture = #"""
    {"units": [{"id": 1, "title": "The Language of Money", "subtitle": "Fixed cost, variable cost, contribution. The words every decision uses.", "totalLessons": 8}, {"id": 2, "title": "Price the Load", "subtitle": "Per load, per pound, and the only number that matters: dollars per furnace hour.", "totalLessons": 6}], "questions": [
    {"id": "u1q01", "unit": 1, "lesson": 1, "category": "Basics", "type": "mc", "prompt": "Your building lease is $6,000/month whether you run zero loads or fifty. What kind of cost is this?", "choices": ["Variable cost", "Fixed cost", "Contribution", "Marginal cost"], "correct": 1, "explanation": "A fixed cost stays the same regardless of volume. Lease, insurance, base salaries — they hit every month whether the furnace is cold or running 24/7.", "difficulty": 1, "concept": "contribution", "thinking": true},
    {"id": "u1q02", "unit": 1, "lesson": 1, "category": "Basics", "type": "mc", "prompt": "Gas consumption goes up every time you run a furnace cycle. What kind of cost is this?", "choices": ["Fixed cost", "Sunk cost", "Variable cost", "Overhead"], "correct": 2, "explanation": "Variable costs rise and fall with production volume. Gas, NH₃, power per cycle, and media wear are all variable — they only hit when the furnace runs.", "difficulty": 1, "concept": "contribution", "thinking": true},
    {"id": "u1q03", "unit": 1, "lesson": 2, "category": "Basics", "type": "mc", "prompt": "You bill $5,400 for a load. Variable costs are $710. What is the contribution?", "choices": ["$710", "$4,690", "$5,400", "$6,110"], "correct": 1, "explanation": "Contribution = Price − Variable Cost. That $4,690 is what goes toward paying your fixed costs and, eventually, profit.", "difficulty": 1, "concept": "contribution"},
    {"id": "u1q04", "unit": 1, "lesson": 3, "category": "Basics", "type": "mc", "prompt": "Which of these is NOT a fixed cost for a heat-treat shop?", "choices": ["Rent", "Insurance", "Ammonia gas", "Base salary"], "correct": 2, "explanation": "Ammonia is consumed per cycle — it is a variable cost. Rent, insurance, and base salaries are due every month regardless of how many loads you run.", "difficulty": 1, "concept": "contribution"},
    {"id": "u1q05", "unit": 1, "lesson": 4, "category": "Basics", "type": "mc", "prompt": "A quote shows a price of $4,800 for a 4.5-hour load. What is the price per furnace hour?", "choices": ["$960", "$1,067", "$1,200", "$4,800"], "correct": 1, "explanation": "$4,800 ÷ 4.5 hrs ≈ $1,067 per furnace hour. This is the number owners use to compare jobs on an apples-to-apples basis.", "difficulty": 2, "concept": "pricing"},
    {"id": "u1q06", "unit": 1, "lesson": 5, "category": "Basics", "type": "mc", "prompt": "Your monthly fixed costs total $33,000. At an average contribution of $1,000 per load, how many loads to break even?", "choices": ["30", "33", "35", "40"], "correct": 1, "explanation": "Break-even loads = Fixed Costs ÷ Contribution per Load = $33,000 ÷ $1,000 = 33 loads. Below that, you are losing money every month.", "difficulty": 2, "concept": "breakeven"},
    {"id": "u1q07", "unit": 1, "lesson": 6, "category": "Basics", "type": "mc", "prompt": "Break-even loads are 33 this month. You ran 28 loads. What happened?", "choices": ["You made a profit", "You broke even", "You lost money", "Need more data"], "correct": 2, "explanation": "28 loads < 33 break-even loads = you lost money. Your fixed costs exceeded the total contribution from 28 loads.", "difficulty": 2, "concept": "breakeven"},
    {"id": "u1q08", "unit": 1, "lesson": 7, "category": "Basics", "type": "mc", "prompt": "Two jobs: Job A pays $900/furnace hr for 6 hrs. Job B pays $1,200/furnace hr for 3 hrs. Which contributes more total dollars?", "choices": ["Job A: $5,400 total", "Job B: $3,600 total", "They are equal", "Need variable costs"], "correct": 0, "explanation": "Job A: $900 × 6 = $5,400. Job B: $1,200 × 3 = $3,600. Even though B has a higher rate per hour, A contributes more total dollars because it uses more furnace time.", "difficulty": 2, "concept": "contribution"},
    {"id": "u1q09", "unit": 1, "lesson": 8, "category": "Basics", "type": "mc", "prompt": "Your furnace capacity is 170 hours/month. You are at 85% utilization. How many hours are booked?", "choices": ["85", "144.5", "155", "170"], "correct": 1, "explanation": "170 × 0.85 = 144.5 hours booked. The remaining 25.5 hours are empty capacity — revenue you can never recover.", "difficulty": 2, "concept": "capacity"}
    ]}
    """#

    // Sim data: THREE generic plants (no real place names per SIM SETUP OVERRIDE)
    private static let simDataFixture = #"""
    {"plants": [
    {"id": "shared_bay", "name": "Shared plant bay", "desc": "Space in an existing facility · Your furnace, shared infrastructure", "occupancy": 4000, "baseLaunchCost": 200000, "breakEven": 49000},
    {"id": "crane_lease", "name": "Crane-equipped lease", "desc": "Your own space · Cranes installed · Room for one furnace", "occupancy": 10000, "baseLaunchCost": 500000, "breakEven": 60000},
    {"id": "larger_lease", "name": "Larger leased plant", "desc": "Dedicated facility · Room to grow · Higher fixed costs", "occupancy": 15000, "baseLaunchCost": 850000, "breakEven": 75000}
    ], "furnaces": [
    {"id": "new", "name": "New Furnace", "desc": "$650K · Lower breakdown odds · Warranty year 1", "cost": 650000},
    {"id": "used", "name": "Used + Retrofit", "desc": "$300K · Higher breakdown odds · Cheaper start", "cost": 300000}
    ], "funding": 2000000, "basePayroll": 21000, "insuranceMisc": 8000, "standingDecisions": []}
    """#
    #endif
}
