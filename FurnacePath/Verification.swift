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
        "api/complete-round": #"{"ok":true,"xp":640,"streak":5}"#,
    ]
    private static let fixtures: [String: String] = [
        "data/questions.json": questionsFixture,
        "data/course.json": courseFixture,
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

    // Simulator fixture includes lessons in both the current and a later unit.
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
    {"id": "u1q09", "unit": 1, "lesson": 8, "category": "Basics", "type": "mc", "prompt": "Your furnace capacity is 170 hours/month. You are at 85% utilization. How many hours are booked?", "choices": ["85", "144.5", "155", "170"], "correct": 1, "explanation": "170 × 0.85 = 144.5 hours booked. The remaining 25.5 hours are empty capacity — revenue you can never recover.", "difficulty": 2, "concept": "capacity"},
    {"id": "fixture-u2q01", "unit": 2, "lesson": 1, "category": "Pricing", "type": "mc", "prompt": "Simulator fixture question", "choices": ["One", "Two"], "correct": 0, "explanation": "Simulator fixture explanation", "difficulty": 1, "concept": "pricing"}
    ]}
    """#

    // Course fixture: two units matching the questions fixture, with teaching cards, questions, and recaps.
    private static let courseFixture = #"""
    {"units":[{"unit":1,"title":"The Language of Money","subtitle":"Fixed cost, variable cost, contribution. The words every decision uses.","totalLessons":8,"lessons":[{"lesson":1,"title":"What Is a Fixed Cost?","cards":[{"position":1,"title":"The Monthly Nut","idea":"Every heat-treat shop has bills that arrive whether the furnace runs or not. Rent, insurance, base salaries — they hit every month regardless of load count.","shopFloor":"These costs are fixed: they do not change with volume.","anchor":"A shop pays $6,000/month rent. Zero loads or fifty — the rent is the same. That is a fixed cost.","misconception":"\"If I run more loads the rent goes down per load.\" Per-load allocation changes, but the total bill does not."},{"position":2,"title":"Variable Costs Move With Volume","idea":"Some costs only appear when the furnace runs. Gas, ammonia, power per cycle, and media wear are all variable costs.","shopFloor":"No cycle, no cost. That is what makes them variable.","anchor":"Each cycle uses about $400 in gas and ammonia. No cycle, no cost.","misconception":"\"All costs are fixed when you sign the lease.\" Only occupancy and salaries are fixed. Consumables scale with volume."}],"questions":[{"id":"u1q01","rampLevel":"define","type":"mc","prompt":"Your building lease is $6,000/month whether you run zero loads or fifty. What kind of cost is this?","choices":["Variable cost","Fixed cost","Contribution","Marginal cost"],"correct":1,"explanation":"A fixed cost stays the same regardless of volume."},{"id":"u1q02","rampLevel":"define","type":"mc","prompt":"Gas consumption goes up every time you run a furnace cycle. What kind of cost is this?","choices":["Fixed cost","Sunk cost","Variable cost","Overhead"],"correct":2,"explanation":"Variable costs rise and fall with production volume."}],"recap":"Fixed costs hit every month regardless of volume. Variable costs only appear when the furnace runs."},{"lesson":2,"title":"Contribution","cards":[{"position":1,"title":"What Is Left Over","idea":"Contribution is the money left after variable costs. Price minus variable cost equals contribution.","shopFloor":"This is what pays your fixed costs and eventually becomes profit.","anchor":"A $5,400 load with $710 variable costs leaves $4,690 contribution.","misconception":"\"Revenue is profit.\" Revenue is the top line. Contribution is what pays fixed costs."}],"questions":[{"id":"u1q03","rampLevel":"recognize","type":"mc","prompt":"You bill $5,400 for a load. Variable costs are $710. What is the contribution?","choices":["$710","$4,690","$5,400","$6,110"],"correct":1,"explanation":"Contribution = Price − Variable Cost = $4,690."}],"recap":"Contribution is revenue minus variable costs — the dollars that go toward paying your fixed costs."}]},{"unit":2,"title":"Price the Load","subtitle":"Per load, per pound, and the only number that matters: dollars per furnace hour.","totalLessons":6,"lessons":[{"lesson":1,"title":"Price Per Furnace Hour","cards":[{"position":1,"title":"The Real Yardstick","idea":"Price per furnace hour is how owners compare jobs. Divide the price by the hours to get the rate.","shopFloor":"This is the only number that compares jobs on equal footing.","anchor":"A $4,800 load using 4.5 hours = $1,067/hr.","misconception":"\"Price per pound is the best comparison.\" Weight ignores time. Furnace hours are the scarce resource."}],"questions":[{"id":"fixture-u2q01","rampLevel":"define","type":"mc","prompt":"Simulator fixture question","choices":["One","Two"],"correct":0,"explanation":"Simulator fixture explanation"}],"recap":"Dollars per furnace hour is the only number that compares jobs on equal footing."}]}]}
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
