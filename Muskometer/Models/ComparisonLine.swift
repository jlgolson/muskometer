import Foundation

/// A contextual comparison caption selected for the current paper gain.
/// Produced by `ComparisonLineSelector`; consumed by `ComparisonCaptionView`.
struct ComparisonLine: Equatable, Sendable {
    let text: String
    let highlight: String?
    let systemImage: String

    init(text: String, highlight: String? = nil, systemImage: String = "sparkles") {
        self.text = text
        self.highlight = highlight
        self.systemImage = systemImage
    }
}

enum ComparisonCategory: String, Sendable, CaseIterable {
    case economics
    case space
    case sports
    case entertainment
    case government
    case infrastructure
    case technology
    case philanthropy
    case luxury
    case nature
}

struct ComparisonLibraryEntry: Identifiable, Equatable, Sendable {
    let id: String
    /// Clause after "Today's gain " — spending / funding metaphors OK.
    let gainText: String
    /// Clause after "Today's loss " — size / equivalence / magnitude only.
    let lossText: String
    let gainHighlight: String?
    let lossHighlight: String?
    let systemImage: String
    let minMagnitude: Double
    let maxMagnitude: Double
    let category: ComparisonCategory

    func line(forGain gain: Double) -> ComparisonLine {
        let prefix: String
        let body: String
        let highlight: String?

        if gain > 0 {
            prefix = "Today's gain "
            body = gainText
            highlight = gainHighlight
        } else if gain < 0 {
            prefix = "Today's loss "
            body = lossText
            highlight = lossHighlight
        } else {
            prefix = "Today's move "
            body = gainText
            highlight = gainHighlight
        }

        return ComparisonLine(
            text: prefix + body,
            highlight: highlight,
            systemImage: systemImage
        )
    }

    func matchesMagnitude(_ magnitude: Double) -> Bool {
        magnitude >= minMagnitude && magnitude < maxMagnitude
    }
}

enum ComparisonLibrary {
    static let entries: [ComparisonLibraryEntry] = [
        // MARK: $0–$10B
        entry(
            "econ-01",
            "equals the GDP of Iceland — for today.",
            icon: "globe.europe.africa.fill", 0, 10, .economics
        ),
        entry(
            "econ-02",
            gain: "could pay every US teacher's salary for a week.",
            loss: "matches a week's payroll for every US teacher.",
            gainHighlight: "a week",
            lossHighlight: "a week",
            icon: "person.3.fill", 0, 10, .economics
        ),
        entry(
            "econ-03",
            "matches the annual budget of the National Science Foundation.",
            icon: "building.columns.fill", 0, 10, .economics
        ),
        entry(
            "econ-04",
            gain: "could erase a mid-size city's annual operating shortfall.",
            loss: "equals a mid-size city's annual operating budget.",
            icon: "building.2.fill", 0, 10, .economics
        ),
        entry(
            "space-01",
            gain: "could fuel a Falcon 9 launch cadence for a month.",
            loss: "equals a month of Falcon 9 launch ops costs.",
            gainHighlight: "a month",
            lossHighlight: "a month",
            icon: "airplane.departure", 0, 10, .space
        ),
        entry(
            "space-02",
            gain: "would cover a Dragon crew mission end to end.",
            loss: "matches the sticker price of a Dragon crew mission.",
            icon: "sparkles", 0, 10, .space
        ),
        entry(
            "sports-01",
            "beats the lifetime earnings of 200 Hall of Fame athletes.",
            highlight: "200",
            icon: "sportscourt.fill", 0, 10, .sports
        ),
        entry(
            "sports-02",
            "outpaces the annual payroll of two mid-market MLB clubs.",
            highlight: "two",
            icon: "baseball.fill", 0, 10, .sports
        ),
        entry(
            "ent-01",
            gain: "could bankroll a summer blockbuster marketing blitz.",
            loss: "matches a summer blockbuster's full marketing spend.",
            icon: "film.fill", 0, 10, .entertainment
        ),
        entry(
            "gov-01",
            "exceeds the annual operating budget of a mid-size US city.",
            icon: "building.2.fill", 0, 10, .government
        ),
        entry(
            "infra-01",
            gain: "could repave 1,000 lane-miles of interstate.",
            loss: "equals the cost of repaving 1,000 lane-miles of interstate.",
            gainHighlight: "1,000",
            lossHighlight: "1,000",
            icon: "road.lanes", 0, 10, .infrastructure
        ),
        entry(
            "tech-01",
            "is more than many unicorn startups raise in a Series C.",
            icon: "cpu.fill", 0, 10, .technology
        ),

        // MARK: $10–$20B
        entry(
            "econ-10",
            "equals roughly 55,000 median US household incomes.",
            highlight: "55,000",
            icon: "person.3.fill", 10, 20, .economics
        ),
        entry(
            "econ-11",
            gain: "could wipe out the student debt of 400,000 borrowers.",
            loss: "equals the student debt of 400,000 borrowers.",
            gainHighlight: "400,000",
            lossHighlight: "400,000",
            icon: "graduationcap.fill", 10, 20, .economics
        ),
        entry(
            "econ-12",
            "matches a year of net profit for a Fortune 50 retailer.",
            icon: "cart.fill", 10, 20, .economics
        ),
        entry(
            "econ-13",
            "is about the size of a G7 nation's annual foreign-aid line item.",
            icon: "globe.americas.fill", 10, 20, .economics
        ),
        entry(
            "space-10",
            gain: "could fund a Starship test campaign and still have change.",
            loss: "matches a full Starship test-campaign budget.",
            icon: "airplane.departure", 10, 20, .space
        ),
        entry(
            "space-11",
            gain: "would pay for dozens of Starlink constellation launches.",
            loss: "equals the cost of dozens of Starlink launches.",
            gainHighlight: "dozens",
            lossHighlight: "dozens",
            icon: "antenna.radiowaves.left.and.right", 10, 20, .space
        ),
        entry(
            "sports-10",
            "outpaces the payroll of an entire major sports league season.",
            icon: "sportscourt.fill", 10, 20, .sports
        ),
        entry(
            "ent-10",
            gain: "could produce three prestige streaming series at once.",
            loss: "matches the budget of three prestige streaming series.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "tv.fill", 10, 20, .entertainment
        ),
        entry(
            "gov-10",
            "exceeds NASA's planetary science budget for a year.",
            icon: "building.columns.fill", 10, 20, .government
        ),
        entry(
            "infra-10",
            gain: "could modernize power grids in a mid-sized state.",
            loss: "equals a mid-sized state's grid-modernization bill.",
            icon: "bolt.fill", 10, 20, .infrastructure
        ),
        entry(
            "lux-10",
            gain: "would buy every hypercar produced this year — twice.",
            loss: "matches twice the sticker price of every hypercar made this year.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "car.fill", 10, 20, .luxury
        ),
        entry(
            "tech-10",
            "is larger than the late-stage war chest of a hot AI lab.",
            icon: "cpu.fill", 10, 20, .technology
        ),

        // MARK: $20–$30B
        entry(
            "econ-20",
            "equals the market cap swing of a top-20 S&P company.",
            icon: "chart.line.uptrend.xyaxis", 20, 30, .economics
        ),
        entry(
            "econ-21",
            gain: "could fund universal pre-K in a large state for a decade.",
            loss: "matches a large state's universal pre-K budget for a decade.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "figure.and.child.holdinghands", 20, 30, .economics
        ),
        entry(
            "econ-22",
            "matches annual venture funding for an entire mid-tier tech hub.",
            icon: "building.2.fill", 20, 30, .economics
        ),
        entry(
            "space-20",
            gain: "could launch a lunar lander program's first phase.",
            loss: "equals the first-phase budget of a lunar lander program.",
            icon: "moon.fill", 20, 30, .space
        ),
        entry(
            "space-21",
            gain: "would cover a year's worth of heavy-lift manifest bookings.",
            loss: "matches a year of heavy-lift launch bookings.",
            icon: "airplane.departure", 20, 30, .space
        ),
        entry(
            "sports-20",
            "beats the combined franchise values of half the NHL.",
            highlight: "half the NHL",
            icon: "hockey.puck.fill", 20, 30, .sports
        ),
        entry(
            "ent-20",
            gain: "could bankroll the biggest box-office year in cinema history.",
            loss: "matches the biggest box-office year in cinema history.",
            icon: "film.fill", 20, 30, .entertainment
        ),
        entry(
            "gov-20",
            "exceeds the annual foreign aid outlay of a G7 nation.",
            icon: "globe.americas.fill", 20, 30, .government
        ),
        entry(
            "infra-20",
            gain: "could build two brand-new international airports.",
            loss: "equals the construction cost of two international airports.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "airplane", 20, 30, .infrastructure
        ),
        entry(
            "tech-20",
            "is larger than the cash pile many cloud giants keep on hand.",
            icon: "cloud.fill", 20, 30, .technology
        ),
        entry(
            "phil-20",
            gain: "could vaccinate the world's under-5 population twice over.",
            loss: "matches the cost of vaccinating every under-5 twice over.",
            gainHighlight: "twice over",
            lossHighlight: "twice over",
            icon: "cross.case.fill", 20, 30, .philanthropy
        ),
        entry(
            "lux-20",
            gain: "would buy a mid-tier European football club — cash only.",
            loss: "equals the sale price of a mid-tier European football club.",
            icon: "soccerball", 20, 30, .luxury
        ),

        // MARK: $30–$40B
        entry(
            "econ-30",
            "equals the annual economic output of Bolivia.",
            icon: "globe.americas.fill", 30, 40, .economics
        ),
        entry(
            "econ-31",
            gain: "could pay off the external debt of a small nation.",
            loss: "equals the external debt of a small nation.",
            icon: "banknote.fill", 30, 40, .economics
        ),
        entry(
            "econ-32",
            "is about the size of a top-50 company's annual free cash flow.",
            icon: "chart.bar.fill", 30, 40, .economics
        ),
        entry(
            "space-30",
            gain: "could seed a Mars cargo precursor mission pipeline.",
            loss: "matches a Mars cargo precursor mission pipeline budget.",
            icon: "moon.stars.fill", 30, 40, .space
        ),
        entry(
            "space-31",
            gain: "would fund Starbase expansion for several years.",
            loss: "equals several years of Starbase expansion capital.",
            gainHighlight: "several years",
            lossHighlight: "several years",
            icon: "building.fill", 30, 40, .space
        ),
        entry(
            "sports-30",
            "outvalues every Premier League club's match-day revenue for a season.",
            icon: "soccerball", 30, 40, .sports
        ),
        entry(
            "ent-30",
            gain: "could acquire a major Hollywood studio — in cash.",
            loss: "matches the cash sale price of a major Hollywood studio.",
            gainHighlight: "in cash",
            lossHighlight: "cash sale",
            icon: "film.stack.fill", 30, 40, .entertainment
        ),
        entry(
            "gov-30",
            "exceeds the US annual budget for national parks.",
            icon: "tree.fill", 30, 40, .government
        ),
        entry(
            "infra-30",
            gain: "could lay high-speed rail between two major US metros.",
            loss: "matches the cost of high-speed rail between two major US metros.",
            icon: "tram.fill", 30, 40, .infrastructure
        ),
        entry(
            "lux-30",
            gain: "would buy every private island listed this decade.",
            loss: "matches the asking price of every private island listed this decade.",
            icon: "sailboat.fill", 30, 40, .luxury
        ),
        entry(
            "nat-30",
            gain: "could restore 3 million acres of wildfire-scarred forest.",
            loss: "equals the cost of restoring 3 million acres of wildfire-scarred forest.",
            gainHighlight: "3 million acres",
            lossHighlight: "3 million acres",
            icon: "leaf.fill", 30, 40, .nature
        ),
        entry(
            "tech-30",
            "beats the annual capex of a mid-tier semiconductor fab buildout.",
            icon: "cpu.fill", 30, 40, .technology
        ),

        // MARK: $40–$50B
        entry(
            "econ-40",
            "equals the GDP of Luxembourg — in a single session.",
            highlight: "a single session",
            icon: "globe.europe.africa.fill", 40, 50, .economics
        ),
        entry(
            "econ-41",
            gain: "could fund the US National Institutes of Health for a year.",
            loss: "matches the NIH's entire annual budget.",
            gainHighlight: "a year",
            lossHighlight: "entire annual budget",
            icon: "cross.case.fill", 40, 50, .economics
        ),
        entry(
            "econ-42",
            "is as big as a year of US customs and border protection funding.",
            icon: "building.columns.fill", 40, 50, .economics
        ),
        entry(
            "space-40",
            gain: "could underwrite a constellation of deep-space relay satellites.",
            loss: "matches a deep-space relay constellation budget.",
            icon: "antenna.radiowaves.left.and.right", 40, 50, .space
        ),
        entry(
            "space-41",
            gain: "would pay for a decade of booster reuse R&D at full throttle.",
            loss: "equals a decade of booster reuse R&D spend.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "wrench.and.screwdriver.fill", 40, 50, .space
        ),
        entry(
            "sports-40",
            "beats the total career prize money in tennis history.",
            icon: "tennisball.fill", 40, 50, .sports
        ),
        entry(
            "ent-40",
            gain: "could buy out every Broadway season's gross — twice.",
            loss: "matches twice every Broadway season's total gross.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "theatermasks.fill", 40, 50, .entertainment
        ),
        entry(
            "gov-40",
            "exceeds the annual defense procurement of Canada.",
            icon: "shield.fill", 40, 50, .government
        ),
        entry(
            "infra-40",
            gain: "could bury fiber to every home in a large state.",
            loss: "matches statewide fiber-to-the-home costs for a large state.",
            icon: "cable.connector", 40, 50, .infrastructure
        ),
        entry(
            "tech-40",
            "is bigger than the IPO proceeds of a generational tech listing.",
            icon: "chart.bar.fill", 40, 50, .technology
        ),
        entry(
            "phil-40",
            gain: "could end extreme water insecurity for 50 million people.",
            loss: "matches the price tag to end extreme water insecurity for 50 million people.",
            gainHighlight: "50 million",
            lossHighlight: "50 million",
            icon: "drop.fill", 40, 50, .philanthropy
        ),
        entry(
            "lux-40",
            gain: "would buy every yacht over 100 meters currently for sale.",
            loss: "equals the asking price of every 100m+ yacht currently listed.",
            icon: "sailboat.fill", 40, 50, .luxury
        ),

        // MARK: $50–$60B
        entry(
            "econ-50",
            "equals the market value of a top-10 global automaker swing.",
            icon: "car.fill", 50, 60, .economics
        ),
        entry(
            "econ-51",
            gain: "could zero out credit-card balances for 40 million households.",
            loss: "equals the credit-card balances of 40 million households.",
            gainHighlight: "40 million",
            lossHighlight: "40 million",
            icon: "creditcard.fill", 50, 60, .economics
        ),
        entry(
            "econ-52",
            "matches a year of net interest for a major money-center bank.",
            icon: "banknote.fill", 50, 60, .economics
        ),
        entry(
            "space-50",
            gain: "could fund an Artemis-scale hardware push on its own.",
            loss: "matches an Artemis-scale hardware program budget.",
            gainHighlight: "Artemis-scale",
            lossHighlight: "Artemis-scale",
            icon: "moon.fill", 50, 60, .space
        ),
        entry(
            "space-51",
            gain: "would cover the capital cost of a private space station fleet.",
            loss: "equals the capital cost of a private space station fleet.",
            icon: "sparkles", 50, 60, .space
        ),
        entry(
            "sports-50",
            "outpaces a decade of Super Bowl ad spend — combined.",
            highlight: "a decade",
            icon: "sportscourt.fill", 50, 60, .sports
        ),
        entry(
            "ent-50",
            gain: "could acquire three major record labels and still tour.",
            loss: "matches the combined market value of three major record labels.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "music.note.list", 50, 60, .entertainment
        ),
        entry(
            "gov-50",
            "exceeds the annual budget of the European Space Agency.",
            icon: "building.columns.fill", 50, 60, .government
        ),
        entry(
            "infra-50",
            gain: "could rebuild every bridge on the interstate top-10 list.",
            loss: "equals the rebuild cost of every bridge on the interstate top-10 list.",
            icon: "road.lanes.curved.left", 50, 60, .infrastructure
        ),
        entry(
            "lux-50",
            gain: "would buy the world's ten most expensive homes — with tips.",
            loss: "matches the price of the world's ten most expensive homes — with tips.",
            gainHighlight: "ten",
            lossHighlight: "ten",
            icon: "house.fill", 50, 60, .luxury
        ),
        entry(
            "nat-50",
            gain: "could fund coastal resilience for the entire Gulf Coast.",
            loss: "equals a Gulf Coast–wide coastal resilience program.",
            icon: "water.waves", 50, 60, .nature
        ),
        entry(
            "tech-50",
            "is larger than a year of cloud revenue for a second-tier hyperscaler.",
            icon: "cloud.fill", 50, 60, .technology
        ),

        // MARK: $60–$70B
        entry(
            "econ-60",
            "equals the annual federal R&D tax credit pool — in one day.",
            highlight: "one day",
            icon: "lightbulb.fill", 60, 70, .economics
        ),
        entry(
            "econ-61",
            gain: "could pay a $1,000 bonus to every US taxpayer.",
            loss: "equals $1,000 for every US taxpayer.",
            gainHighlight: "every US taxpayer",
            lossHighlight: "every US taxpayer",
            icon: "person.3.fill", 60, 70, .economics
        ),
        entry(
            "econ-62",
            "matches the annual profits of a top-5 global oil major.",
            icon: "flame.fill", 60, 70, .economics
        ),
        entry(
            "space-60",
            gain: "could bankroll a Mars surface logistics demo at scale.",
            loss: "matches a Mars surface logistics demo program budget.",
            icon: "moon.stars.fill", 60, 70, .space
        ),
        entry(
            "space-61",
            gain: "would fund Starlink Gen3 deployment for a full orbital shell.",
            loss: "equals a full Starlink Gen3 orbital-shell deployment.",
            icon: "antenna.radiowaves.left.and.right", 60, 70, .space
        ),
        entry(
            "sports-60",
            "beats the combined transfer fees of a decade of soccer windows.",
            highlight: "a decade",
            icon: "soccerball", 60, 70, .sports
        ),
        entry(
            "ent-60",
            gain: "could run every major streaming service at a loss for a quarter.",
            loss: "matches a quarter of operating losses across every major streamer.",
            gainHighlight: "a quarter",
            lossHighlight: "a quarter",
            icon: "play.tv.fill", 60, 70, .entertainment
        ),
        entry(
            "gov-60",
            "exceeds the US annual spend on renewable energy credits.",
            icon: "sun.max.fill", 60, 70, .government
        ),
        entry(
            "infra-60",
            gain: "could modernize every major US port's container cranes.",
            loss: "matches the cost of modernizing every major US port's container cranes.",
            icon: "shippingbox.fill", 60, 70, .infrastructure
        ),
        entry(
            "tech-60",
            "is larger than the cash component of the biggest tech merger ever.",
            icon: "arrow.triangle.merge", 60, 70, .technology
        ),
        entry(
            "phil-60",
            gain: "could erase malaria program funding gaps for 15 years.",
            loss: "matches 15 years of malaria program funding gaps.",
            gainHighlight: "15 years",
            lossHighlight: "15 years",
            icon: "cross.case.fill", 60, 70, .philanthropy
        ),
        entry(
            "nat-60",
            gain: "could rewild an area the size of Yellowstone — twice.",
            loss: "equals rewilding costs for twice the area of Yellowstone.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "leaf.fill", 60, 70, .nature
        ),

        // MARK: $70B+
        entry(
            "econ-70",
            "equals the GDP of Kenya — before lunch.",
            highlight: "before lunch",
            icon: "globe.africa.fill", 70, 1_000, .economics
        ),
        entry(
            "econ-71",
            gain: "could fund the Apollo program — adjusted for vibes.",
            loss: "matches the Apollo program — adjusted for vibes.",
            gainHighlight: "Apollo program",
            lossHighlight: "Apollo program",
            icon: "clock.fill", 70, 1_000, .economics
        ),
        entry(
            "econ-72",
            "is about the size of a small G20 nation's annual federal budget.",
            icon: "building.columns.fill", 70, 1_000, .economics
        ),
        entry(
            "space-70",
            gain: "could seed a self-sustaining lunar industrial base.",
            loss: "matches seed capital for a self-sustaining lunar industrial base.",
            icon: "moon.fill", 70, 1_000, .space
        ),
        entry(
            "space-71",
            gain: "would pay for a Starship production line's first full year.",
            loss: "equals a Starship production line's first full year of capital.",
            gainHighlight: "first full year",
            lossHighlight: "first full year",
            icon: "gearshape.2.fill", 70, 1_000, .space
        ),
        entry(
            "sports-70",
            "outvalues the GDP of a nation that could field an Olympic team.",
            icon: "medal.fill", 70, 1_000, .sports
        ),
        entry(
            "ent-70",
            gain: "could buy the entire video game industry's annual revenue.",
            loss: "matches the entire video game industry's annual revenue.",
            icon: "gamecontroller.fill", 70, 1_000, .entertainment
        ),
        entry(
            "gov-70",
            "exceeds the World Bank's annual climate finance commitments.",
            icon: "globe.americas.fill", 70, 1_000, .government
        ),
        entry(
            "infra-70",
            gain: "could tunnel high-speed rail under the Appalachian chain.",
            loss: "matches the cost of tunneling high-speed rail under the Appalachians.",
            icon: "tram.fill", 70, 1_000, .infrastructure
        ),
        entry(
            "lux-70",
            gain: "would fund a fleet of 500 private jets — crew included.",
            loss: "matches the cost of 500 private jets — crew included.",
            gainHighlight: "500",
            lossHighlight: "500",
            icon: "airplane", 70, 1_000, .luxury
        ),
        entry(
            "nat-70",
            gain: "could reforest an area the size of West Virginia.",
            loss: "equals reforestation costs for an area the size of West Virginia.",
            gainHighlight: "West Virginia",
            lossHighlight: "West Virginia",
            icon: "tree.fill", 70, 1_000, .nature
        ),
        entry(
            "tech-70",
            "is larger than the annual capex of a top-three chip foundry.",
            icon: "cpu.fill", 70, 1_000, .technology
        ),

        // MARK: Expanded library — low buckets (agent batch)
// MARK: $0–$10B (batch-low)
        entry(
            "nfl-05",
            "matches the franchise value of a mid-tier NFL club.",
            highlight: "mid-tier NFL",
            icon: "football.fill",
            0, 10, .sports
        ),
        entry(
            "nba-04",
            "equals the sale price of a rising NBA franchise.",
            icon: "basketball.fill",
            0, 10, .sports
        ),
        entry(
            "mlb-03",
            "outpaces the payroll of three big-market MLB clubs combined.",
            highlight: "three",
            icon: "baseball.fill",
            0, 10, .sports
        ),
        entry(
            "nhl-03",
            "beats the combined payroll of half the NHL for a season.",
            highlight: "half the NHL",
            icon: "hockey.puck.fill",
            0, 10, .sports
        ),
        entry(
            "sb-ads-05",
            "costs as much as eight Super Bowl ad slates.",
            highlight: "eight",
            icon: "tv.fill",
            0, 10, .sports
        ),
        entry(
            "olympic-host-08",
            gain: "could underwrite a mid-size Olympic host city's operations budget.",
            loss: "equals a mid-size Olympic host city's operations budget.",
            icon: "medal.fill",
            0, 10, .sports
        ),
        entry(
            "f1-team-04",
            "matches the annual budget of a top Formula 1 team — twice.",
            highlight: "twice",
            icon: "flag.checkered",
            0, 10, .sports
        ),
        entry(
            "wimbledon-prize-hist",
            "exceeds a century of Wimbledon prize money — adjusted for vibes.",
            icon: "tennisball.fill",
            0, 10, .sports
        ),
        entry(
            "cdc-budget-09",
            "matches the CDC's annual operating budget.",
            icon: "cross.case.fill",
            0, 10, .government
        ),
        entry(
            "nasa-heliophysics-05",
            "equals NASA's heliophysics directorate for several years.",
            icon: "sun.max.fill",
            0, 10, .space
        ),
        entry(
            "esa-science-06",
            "is the size of ESA's annual science program line.",
            icon: "globe.europe.africa.fill",
            0, 10, .space
        ),
        entry(
            "rover-followon-04",
            gain: "could fund a Mars rover follow-on mission end to end.",
            loss: "matches the sticker price of a Mars rover follow-on mission.",
            icon: "moon.stars.fill",
            0, 10, .space
        ),
        entry(
            "cubesat-swarm-02",
            gain: "could loft a thousand university CubeSats.",
            loss: "equals the cost of lofting a thousand university CubeSats.",
            gainHighlight: "a thousand",
            lossHighlight: "a thousand",
            icon: "antenna.radiowaves.left.and.right",
            0, 10, .space
        ),
        entry(
            "broadway-season-02",
            "matches two full Broadway seasons of total gross.",
            highlight: "two",
            icon: "theatermasks.fill",
            0, 10, .entertainment
        ),
        entry(
            "museum-wing-03",
            gain: "could build a world-class museum wing — and stock it.",
            loss: "equals the cost of a world-class museum wing, fully stocked.",
            icon: "building.columns.fill",
            0, 10, .entertainment
        ),
        entry(
            "netflix-slate-05",
            gain: "could bankroll a mid-tier streamer's entire annual original slate.",
            loss: "matches a mid-tier streamer's annual original-content slate.",
            icon: "play.tv.fill",
            0, 10, .entertainment
        ),
        entry(
            "album-campaigns-02",
            gain: "could launch twenty global pop album campaigns at once.",
            loss: "equals twenty global pop album campaign budgets.",
            gainHighlight: "twenty",
            lossHighlight: "twenty",
            icon: "music.note.list",
            0, 10, .entertainment
        ),
        entry(
            "theme-park-land-06",
            gain: "could open a new theme-park land at a major resort.",
            loss: "matches the build cost of a new theme-park land at a major resort.",
            icon: "ticket.fill",
            0, 10, .entertainment
        ),
        entry(
            "bridge-span-04",
            gain: "could replace a major river bridge end to end.",
            loss: "equals the full replacement cost of a major river bridge.",
            icon: "road.lanes",
            0, 10, .infrastructure
        ),
        entry(
            "subway-extension-08",
            gain: "could fund a short subway extension under a dense city.",
            loss: "matches the cost of a short subway extension under a dense city.",
            icon: "tram.fill",
            0, 10, .infrastructure
        ),
        entry(
            "water-plant-05",
            gain: "could modernize a regional water-treatment plant network.",
            loss: "equals a regional water-treatment plant modernization bill.",
            icon: "drop.fill",
            0, 10, .infrastructure
        ),
        entry(
            "fiber-county-03",
            gain: "could bury fiber across a large rural county.",
            loss: "matches countywide rural fiber-to-the-home costs.",
            icon: "cable.connector",
            0, 10, .infrastructure
        ),
        entry(
            "chip-pilot-line-07",
            gain: "could stand up a pilot semiconductor line.",
            loss: "equals the capital cost of a pilot semiconductor line.",
            icon: "cpu.fill",
            0, 10, .technology
        ),
        entry(
            "ai-cluster-04",
            "is larger than a mid-size AI lab's annual compute spend.",
            icon: "server.rack",
            0, 10, .technology
        ),
        entry(
            "appstore-hits-05",
            "outpaces a year of revenue for the top ten indie apps — combined.",
            highlight: "top ten",
            icon: "iphone",
            0, 10, .technology
        ),
        entry(
            "saas-ipo-06",
            "matches the IPO proceeds of a solid mid-cap SaaS listing.",
            icon: "chart.bar.fill",
            0, 10, .technology
        ),
        entry(
            "gdp-malta-07",
            "equals a large slice of Malta's annual GDP.",
            icon: "globe.europe.africa.fill",
            0, 10, .economics
        ),
        entry(
            "debt-muni-05",
            "is the size of a large city's annual municipal bond issuance.",
            icon: "banknote.fill",
            0, 10, .economics
        ),
        entry(
            "corp-tax-refund-04",
            "matches a quarter of quarterly tax refunds for a mid-size state.",
            icon: "doc.text.fill",
            0, 10, .economics
        ),
        entry(
            "vc-seed-year-08",
            "equals a full year of US seed-stage venture checks.",
            icon: "chart.line.uptrend.xyaxis",
            0, 10, .economics
        ),
        entry(
            "philanthropy-foodbank-03",
            gain: "could stock every major US food bank for a year.",
            loss: "matches a year's restocking cost for every major US food bank.",
            gainHighlight: "a year",
            lossHighlight: "a year",
            icon: "cart.fill",
            0, 10, .philanthropy
        ),
        entry(
            "scholarship-cohort-06",
            gain: "could endow full rides for 50,000 college students.",
            loss: "equals the cost of full rides for 50,000 college students.",
            gainHighlight: "50,000",
            lossHighlight: "50,000",
            icon: "graduationcap.fill",
            0, 10, .philanthropy
        ),
        entry(
            "lux-jet-fleet-05",
            gain: "would buy a fleet of fifty mid-cabin private jets.",
            loss: "matches the sticker price of fifty mid-cabin private jets.",
            gainHighlight: "fifty",
            lossHighlight: "fifty",
            icon: "airplane",
            0, 10, .luxury
        ),
        entry(
            "lux-penthouse-block-04",
            gain: "would clear every penthouse listing in Manhattan this quarter.",
            loss: "equals the asking price of every Manhattan penthouse listed this quarter.",
            icon: "building.2.fill",
            0, 10, .luxury
        ),
        entry(
            "nature-reef-restore-03",
            gain: "could restore hundreds of miles of coral reef nursery.",
            loss: "equals the cost of restoring hundreds of miles of coral reef nursery.",
            icon: "water.waves",
            0, 10, .nature
        ),
        entry(
            "nature-urban-trees-02",
            gain: "could plant a tree for every resident of California.",
            loss: "matches the cost of planting a tree for every Californian.",
            icon: "leaf.fill",
            0, 10, .nature
        ),
        entry(
            "gov-fbi-ops-08",
            "exceeds a large share of the FBI's annual operating budget.",
            icon: "shield.fill",
            0, 10, .government
        ),
        entry(
            "gov-state-parks-04",
            "matches several years of a large state's park system budget.",
            icon: "tree.fill",
            0, 10, .government
        ),
        entry(
            "ent-festival-circuit-03",
            gain: "could underwrite the global summer music-festival circuit.",
            loss: "matches the production cost of the global summer music-festival circuit.",
            icon: "music.mic",
            0, 10, .entertainment
        ),
        entry(
            "tech-robotics-line-05",
            gain: "could equip a full warehouse robotics retrofit for a national retailer.",
            loss: "equals a national retailer's warehouse robotics retrofit bill.",
            icon: "gearshape.2.fill",
            0, 10, .technology
        ),
        entry(
            "infra-levee-system-07",
            gain: "could rebuild a regional levee system after a major flood year.",
            loss: "equals the rebuild cost of a regional levee system.",
            icon: "water.waves",
            0, 10, .infrastructure
        ),
        entry(
            "sports-mls-club-02",
            "matches the franchise value of a top MLS expansion club.",
            icon: "soccerball",
            0, 10, .sports
        ),

        // MARK: $10–$20B (batch-low)
        entry(
            "nfl-duo-15",
            "equals the combined franchise value of two solid NFL teams.",
            highlight: "two",
            icon: "football.fill",
            10, 20, .sports
        ),
        entry(
            "nba-pair-12",
            "matches the sale price of two mid-market NBA franchises.",
            highlight: "two",
            icon: "basketball.fill",
            10, 20, .sports
        ),
        entry(
            "mlb-payroll-league-14",
            "outpaces a full MLB season of combined team payrolls.",
            icon: "baseball.fill",
            10, 20, .sports
        ),
        entry(
            "premier-midtable-16",
            "beats the transfer spend of every mid-table Premier League club — for years.",
            icon: "soccerball",
            10, 20, .sports
        ),
        entry(
            "olympic-build-18",
            gain: "could fund a compact Olympic village and venues package.",
            loss: "equals a compact Olympic village and venues package.",
            icon: "medal.fill",
            10, 20, .sports
        ),
        entry(
            "nascar-decade-11",
            "costs as much as a decade of top-tier NASCAR team operations.",
            highlight: "a decade",
            icon: "flag.checkered",
            10, 20, .sports
        ),
        entry(
            "gdp-estonia-15",
            "equals roughly half of Estonia's annual GDP.",
            icon: "globe.europe.africa.fill",
            10, 20, .economics
        ),
        entry(
            "debt-student-slice-12",
            gain: "could erase student loans for half a million borrowers.",
            loss: "equals the student debt of half a million borrowers.",
            gainHighlight: "half a million",
            lossHighlight: "half a million",
            icon: "graduationcap.fill",
            10, 20, .economics
        ),
        entry(
            "corp-buyback-day-14",
            "matches a busy week of S&P 500 corporate buybacks.",
            icon: "chart.line.uptrend.xyaxis",
            10, 20, .economics
        ),
        entry(
            "vc-series-b-year-18",
            "is the size of a full year of US Series B venture funding.",
            icon: "building.2.fill",
            10, 20, .economics
        ),
        entry(
            "retail-chain-profit-13",
            "equals a year's net profit for a national big-box chain.",
            icon: "cart.fill",
            10, 20, .economics
        ),
        entry(
            "space-crew-cadence-12",
            gain: "could fund a year of crew rotation flights to orbit.",
            loss: "matches a year of crewed orbital rotation flight costs.",
            gainHighlight: "a year",
            lossHighlight: "a year",
            icon: "airplane.departure",
            10, 20, .space
        ),
        entry(
            "space-probe-pair-15",
            gain: "could launch two flagship planetary probes.",
            loss: "equals the cost of two flagship planetary probes.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "sparkles",
            10, 20, .space
        ),
        entry(
            "space-ground-net-11",
            gain: "could build a global deep-space ground-station network upgrade.",
            loss: "matches a global deep-space ground-station network upgrade.",
            icon: "antenna.radiowaves.left.and.right",
            10, 20, .space
        ),
        entry(
            "broadway-decade-12",
            "matches a decade of Broadway's total ticket gross.",
            highlight: "a decade",
            icon: "theatermasks.fill",
            10, 20, .entertainment
        ),
        entry(
            "streaming-hit-slate-16",
            gain: "could produce a streamer's entire tentpole slate for two years.",
            loss: "matches two years of a streamer's tentpole production slate.",
            gainHighlight: "two years",
            lossHighlight: "two years",
            icon: "tv.fill",
            10, 20, .entertainment
        ),
        entry(
            "label-catalog-14",
            gain: "could acquire a storied mid-size record-label catalog.",
            loss: "equals the sale price of a storied mid-size record-label catalog.",
            icon: "music.note.list",
            10, 20, .entertainment
        ),
        entry(
            "game-studio-cluster-18",
            gain: "could buy a cluster of mid-size AAA game studios.",
            loss: "matches the combined value of a mid-size AAA studio cluster.",
            icon: "gamecontroller.fill",
            10, 20, .entertainment
        ),
        entry(
            "museum-campus-15",
            gain: "could endow a new national museum campus end to end.",
            loss: "equals the endowment-scale cost of a new national museum campus.",
            icon: "building.columns.fill",
            10, 20, .entertainment
        ),
        entry(
            "gov-nps-multi-12",
            "exceeds several years of National Park Service operations.",
            icon: "tree.fill",
            10, 20, .government
        ),
        entry(
            "gov-faa-year-14",
            "matches the FAA's annual budget — with runway lights left over.",
            icon: "airplane",
            10, 20, .government
        ),
        entry(
            "gov-coast-guard-16",
            "is about the size of the US Coast Guard's annual appropriation.",
            icon: "shield.fill",
            10, 20, .government
        ),
        entry(
            "bridge-corridor-15",
            gain: "could rebuild an entire interstate bridge corridor.",
            loss: "equals the rebuild cost of an entire interstate bridge corridor.",
            icon: "road.lanes.curved.left",
            10, 20, .infrastructure
        ),
        entry(
            "rail-electrify-18",
            gain: "could electrify a major intercity rail corridor.",
            loss: "matches the cost of electrifying a major intercity rail corridor.",
            icon: "tram.fill",
            10, 20, .infrastructure
        ),
        entry(
            "port-terminal-12",
            gain: "could double the capacity of a top-10 US container terminal.",
            loss: "equals a top-10 US container terminal capacity-doubling project.",
            icon: "shippingbox.fill",
            10, 20, .infrastructure
        ),
        entry(
            "grid-substation-14",
            gain: "could upgrade substations across a multi-state utility territory.",
            loss: "matches a multi-state utility substation upgrade program.",
            icon: "bolt.fill",
            10, 20, .infrastructure
        ),
        entry(
            "chip-module-16",
            gain: "could fund a major module of a leading-edge chip fab.",
            loss: "equals one major module of a leading-edge chip fab.",
            icon: "cpu.fill",
            10, 20, .technology
        ),
        entry(
            "ai-supercluster-18",
            "is larger than a hyperscaler's annual AI-training cluster order.",
            icon: "server.rack",
            10, 20, .technology
        ),
        entry(
            "cloud-region-13",
            gain: "could stand up a new multi-zone cloud region from scratch.",
            loss: "matches the capital cost of a new multi-zone cloud region.",
            icon: "cloud.fill",
            10, 20, .technology
        ),
        entry(
            "cyber-national-11",
            gain: "could fund a national critical-infrastructure cyber hardening push.",
            loss: "equals a national critical-infrastructure cyber hardening program.",
            icon: "lock.shield.fill",
            10, 20, .technology
        ),
        entry(
            "phil-malaria-nets-12",
            gain: "could supply long-lasting bed nets for a continent-scale campaign.",
            loss: "matches a continent-scale long-lasting bed-net campaign.",
            icon: "cross.case.fill",
            10, 20, .philanthropy
        ),
        entry(
            "phil-clinic-network-15",
            gain: "could build and staff a network of rural clinics across a large state.",
            loss: "equals the cost of a large-state rural clinic network, staffed.",
            icon: "cross.case.fill",
            10, 20, .philanthropy
        ),
        entry(
            "lux-superyacht-class-14",
            gain: "would buy a class of ten mega-superyachts — crew and tenders included.",
            loss: "matches the price of ten mega-superyachts with crew and tenders.",
            gainHighlight: "ten",
            lossHighlight: "ten",
            icon: "sailboat.fill",
            10, 20, .luxury
        ),
        entry(
            "lux-art-auction-year-12",
            gain: "would clear a full year of top-tier art auction lots.",
            loss: "equals a full year of top-tier art auction hammer prices.",
            icon: "paintpalette.fill",
            10, 20, .luxury
        ),
        entry(
            "nature-wetland-16",
            gain: "could restore a million acres of coastal wetlands.",
            loss: "equals the cost of restoring a million acres of coastal wetlands.",
            gainHighlight: "a million acres",
            lossHighlight: "a million acres",
            icon: "leaf.fill",
            10, 20, .nature
        ),
        entry(
            "nature-dam-removal-14",
            gain: "could fund a multi-state dam-removal and river-revival slate.",
            loss: "matches a multi-state dam-removal and river-revival slate.",
            icon: "water.waves",
            10, 20, .nature
        ),
        entry(
            "ent-theme-park-full-19",
            gain: "could build an entire destination theme park from dirt.",
            loss: "equals the ground-up cost of a destination theme park.",
            icon: "ticket.fill",
            10, 20, .entertainment
        ),
        entry(
            "gov-nih-institute-17",
            "exceeds the annual budget of several major NIH institutes combined.",
            icon: "cross.case.fill",
            10, 20, .government
        ),
        entry(
            "sports-rugby-world-13",
            "matches several Rugby World Cup cycles of commercial revenue.",
            icon: "sportscourt.fill",
            10, 20, .sports
        ),
        entry(
            "econ-airline-fleet-15",
            gain: "could refresh a major airline's narrow-body fleet.",
            loss: "equals a major airline's narrow-body fleet refresh bill.",
            icon: "airplane",
            10, 20, .economics
        ),

        // MARK: $20–$30B (batch-low)
        entry(
            "nfl-trio-25",
            "equals the combined franchise value of three solid NFL teams.",
            highlight: "three",
            icon: "football.fill",
            20, 30, .sports
        ),
        entry(
            "nba-big-market-24",
            "matches a top-tier NBA franchise's enterprise value.",
            icon: "basketball.fill",
            20, 30, .sports
        ),
        entry(
            "nhl-expansion-era-22",
            "beats a full era of NHL expansion and relocation fees.",
            icon: "hockey.puck.fill",
            20, 30, .sports
        ),
        entry(
            "mlb-pair-premium-26",
            "outvalues two premium MLB franchises sold same-day.",
            highlight: "two",
            icon: "baseball.fill",
            20, 30, .sports
        ),
        entry(
            "uefa-window-28",
            "costs as much as several peak UEFA transfer windows combined.",
            icon: "soccerball",
            20, 30, .sports
        ),
        entry(
            "olympic-broadcast-23",
            "matches a global Olympic broadcast-rights cycle for a major market.",
            icon: "tv.fill",
            20, 30, .sports
        ),
        entry(
            "gdp-latvia-25",
            "equals roughly Latvia's annual GDP.",
            icon: "globe.europe.africa.fill",
            20, 30, .economics
        ),
        entry(
            "debt-state-muni-22",
            "is the size of a large state's annual municipal debt service — multi-year.",
            icon: "banknote.fill",
            20, 30, .economics
        ),
        entry(
            "fortune-cashflow-26",
            "matches annual free cash flow for a top-tier industrial giant.",
            icon: "chart.bar.fill",
            20, 30, .economics
        ),
        entry(
            "vc-growth-year-24",
            "equals a full year of US late-stage growth equity checks.",
            icon: "chart.line.uptrend.xyaxis",
            20, 30, .economics
        ),
        entry(
            "housing-starts-region-28",
            gain: "could finance a regional housing-start boom for a year.",
            loss: "matches a year of regional housing-start financing volume.",
            gainHighlight: "a year",
            lossHighlight: "a year",
            icon: "house.fill",
            20, 30, .economics
        ),
        entry(
            "space-lander-block-25",
            gain: "could fund a multi-flight lunar lander demonstration block.",
            loss: "equals a multi-flight lunar lander demonstration block.",
            icon: "moon.fill",
            20, 30, .space
        ),
        entry(
            "space-habitat-proto-22",
            gain: "could prototype a commercial orbital habitat fleet.",
            loss: "matches the prototype cost of a commercial orbital habitat fleet.",
            icon: "sparkles",
            20, 30, .space
        ),
        entry(
            "space-science-decade-27",
            gain: "could underwrite a decade of mid-class planetary science missions.",
            loss: "equals a decade of mid-class planetary science mission budgets.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "moon.stars.fill",
            20, 30, .space
        ),
        entry(
            "ent-studio-slate-24",
            gain: "could bankroll a major studio's theatrical slate for years.",
            loss: "matches years of a major studio's theatrical production slate.",
            icon: "film.stack.fill",
            20, 30, .entertainment
        ),
        entry(
            "ent-streamer-quarter-26",
            gain: "could run a top streamer's content budget for several quarters.",
            loss: "matches several quarters of a top streamer's content budget.",
            icon: "play.tv.fill",
            20, 30, .entertainment
        ),
        entry(
            "broadway-empire-22",
            gain: "could acquire a portfolio of long-running Broadway hits.",
            loss: "equals the portfolio value of a slate of long-running Broadway hits.",
            icon: "theatermasks.fill",
            20, 30, .entertainment
        ),
        entry(
            "game-publisher-mid-28",
            gain: "could buy a mid-tier global game publisher outright.",
            loss: "matches the market value of a mid-tier global game publisher.",
            icon: "gamecontroller.fill",
            20, 30, .entertainment
        ),
        entry(
            "museum-endow-25",
            "matches the endowment of a world-class art museum.",
            icon: "building.columns.fill",
            20, 30, .entertainment
        ),
        entry(
            "gov-epa-multi-23",
            "exceeds several years of EPA annual appropriations.",
            icon: "leaf.fill",
            20, 30, .government
        ),
        entry(
            "gov-foreign-aid-slice-26",
            "is about the size of a G7 nation's bilateral aid portfolio for a year.",
            icon: "globe.americas.fill",
            20, 30, .government
        ),
        entry(
            "gov-va-hospitals-24",
            gain: "could modernize a regional VA hospital network.",
            loss: "equals a regional VA hospital network modernization bill.",
            icon: "cross.case.fill",
            20, 30, .government
        ),
        entry(
            "airport-pair-25",
            gain: "could build two mid-size international airport terminals.",
            loss: "equals the construction cost of two mid-size international terminals.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "airplane",
            20, 30, .infrastructure
        ),
        entry(
            "bridge-mega-28",
            gain: "could deliver a signature mega-bridge project.",
            loss: "matches the full cost of a signature mega-bridge project.",
            icon: "road.lanes",
            20, 30, .infrastructure
        ),
        entry(
            "transit-metro-line-22",
            gain: "could dig a new metro line across a major US city.",
            loss: "equals the cost of a new metro line across a major US city.",
            icon: "tram.fill",
            20, 30, .infrastructure
        ),
        entry(
            "desal-plant-cluster-26",
            gain: "could build a coastal desalination plant cluster.",
            loss: "matches a coastal desalination plant cluster buildout.",
            icon: "drop.fill",
            20, 30, .infrastructure
        ),
        entry(
            "chip-fab-wing-24",
            gain: "could fund a full wing of a leading-edge semiconductor fab.",
            loss: "equals a full wing of a leading-edge semiconductor fab.",
            icon: "cpu.fill",
            20, 30, .technology
        ),
        entry(
            "ai-training-armada-28",
            "is larger than a frontier lab's multi-year training-chip armada order.",
            icon: "server.rack",
            20, 30, .technology
        ),
        entry(
            "cloud-edge-mesh-22",
            gain: "could deploy a continental edge-cloud mesh for a carrier.",
            loss: "matches a continental edge-cloud mesh deployment for a carrier.",
            icon: "cloud.fill",
            20, 30, .technology
        ),
        entry(
            "robotics-oem-26",
            gain: "could acquire a leading industrial robotics OEM.",
            loss: "equals the enterprise value of a leading industrial robotics OEM.",
            icon: "gearshape.2.fill",
            20, 30, .technology
        ),
        entry(
            "phil-vaccine-push-25",
            gain: "could underwrite a multi-disease global vaccine access push.",
            loss: "matches a multi-disease global vaccine access program budget.",
            icon: "cross.case.fill",
            20, 30, .philanthropy
        ),
        entry(
            "phil-scholarship-gen-23",
            gain: "could endow need-based scholarships for a generation of STEM students.",
            loss: "equals a generation-scale STEM need-based scholarship endowment.",
            icon: "graduationcap.fill",
            20, 30, .philanthropy
        ),
        entry(
            "lux-football-club-cash-27",
            gain: "would buy a solid European football club — cash on the barrel.",
            loss: "equals the cash sale price of a solid European football club.",
            icon: "soccerball",
            20, 30, .luxury
        ),
        entry(
            "lux-jet-armada-24",
            gain: "would buy an armada of long-range business jets for a global fleet.",
            loss: "matches a global long-range business-jet fleet purchase.",
            icon: "airplane",
            20, 30, .luxury
        ),
        entry(
            "nature-forest-corridor-26",
            gain: "could protect a continental wildlife corridor the size of a small state.",
            loss: "equals the cost of protecting a small-state-sized wildlife corridor.",
            icon: "leaf.fill",
            20, 30, .nature
        ),
        entry(
            "nature-reef-nation-22",
            gain: "could fund reef restoration for an entire island nation.",
            loss: "matches nation-scale reef restoration for an island country.",
            icon: "water.waves",
            20, 30, .nature
        ),
        entry(
            "ent-music-festival-empire-29",
            gain: "could acquire a global live-music promoter's festival portfolio.",
            loss: "equals a global live-music promoter's festival portfolio value.",
            icon: "music.mic",
            20, 30, .entertainment
        ),
        entry(
            "gov-noaa-fleet-21",
            gain: "could recapitalize NOAA's weather-satellite and research fleet.",
            loss: "matches a NOAA weather-satellite and research fleet recapitalization.",
            icon: "cloud.sun.fill",
            20, 30, .government
        ),
        entry(
            "sports-tennis-circuit-25",
            "outpaces a decade of prize money across the entire tennis tour.",
            highlight: "a decade",
            icon: "tennisball.fill",
            20, 30, .sports
        ),
        entry(
            "infra-grid-storage-27",
            gain: "could install grid-scale battery storage across a large state.",
            loss: "equals statewide grid-scale battery storage for a large state.",
            icon: "bolt.fill",
            20, 30, .infrastructure
        ),

        // MARK: $30–$40B (batch-low)
        entry(
            "nfl-quartet-35",
            "equals the combined franchise value of four NFL teams.",
            highlight: "four",
            icon: "football.fill",
            30, 40, .sports
        ),
        entry(
            "nba-duo-premium-32",
            "matches two premium NBA franchises sold back-to-back.",
            highlight: "two",
            icon: "basketball.fill",
            30, 40, .sports
        ),
        entry(
            "mlb-trio-34",
            "outvalues three big-market MLB clubs combined.",
            highlight: "three",
            icon: "baseball.fill",
            30, 40, .sports
        ),
        entry(
            "premier-top-club-36",
            "beats the enterprise value of a top Premier League powerhouse.",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "olympic-full-host-38",
            gain: "could underwrite a large share of a Summer Games host budget.",
            loss: "equals a large share of a Summer Games host operating budget.",
            icon: "medal.fill",
            30, 40, .sports
        ),
        entry(
            "f1-grid-decade-33",
            "costs as much as a decade of full Formula 1 grid operations.",
            highlight: "a decade",
            icon: "flag.checkered",
            30, 40, .sports
        ),
        entry(
            "gdp-paraguay-35",
            "equals roughly Paraguay's annual GDP.",
            icon: "globe.americas.fill",
            30, 40, .economics
        ),
        entry(
            "debt-muni-state-stack-32",
            "matches a stack of large-state pension shortfall snapshots.",
            icon: "banknote.fill",
            30, 40, .economics
        ),
        entry(
            "corp-mega-buyback-36",
            "matches a mega-cap tech company's annual buyback authorization.",
            icon: "chart.line.uptrend.xyaxis",
            30, 40, .economics
        ),
        entry(
            "vc-us-year-slice-34",
            "is about the size of a large slice of annual US venture capital.",
            icon: "building.2.fill",
            30, 40, .economics
        ),
        entry(
            "airline-group-38",
            gain: "could recapitalize a major global airline group.",
            loss: "equals a major global airline group recapitalization.",
            icon: "airplane",
            30, 40, .economics
        ),
        entry(
            "space-gateway-modules-35",
            gain: "could fund a run of lunar Gateway-class habitat modules.",
            loss: "matches a run of lunar Gateway-class habitat modules.",
            icon: "moon.stars.fill",
            30, 40, .space
        ),
        entry(
            "space-station-private-32",
            gain: "could fund a private space-station construction phase.",
            loss: "equals a private space-station construction phase budget.",
            icon: "sparkles",
            30, 40, .space
        ),
        entry(
            "space-starship-line-37",
            gain: "could expand a Starship production line for several years.",
            loss: "matches several years of Starship production-line expansion capital.",
            gainHighlight: "several years",
            lossHighlight: "several years",
            icon: "gearshape.2.fill",
            30, 40, .space
        ),
        entry(
            "ent-cinema-chain-35",
            gain: "could buy a global cinema-chain operator outright.",
            loss: "matches the enterprise value of a global cinema-chain operator.",
            icon: "film.stack.fill",
            30, 40, .entertainment
        ),
        entry(
            "ent-streamer-year-33",
            gain: "could fund a top streamer's original content for a full year.",
            loss: "equals a top streamer's full-year original content budget.",
            gainHighlight: "a full year",
            lossHighlight: "full-year",
            icon: "play.tv.fill",
            30, 40, .entertainment
        ),
        entry(
            "broadway-plus-tours-36",
            "matches a decade of Broadway plus national-tour grosses.",
            highlight: "a decade",
            icon: "theatermasks.fill",
            30, 40, .entertainment
        ),
        entry(
            "game-publisher-major-38",
            gain: "could buy a major global game publisher at a fair premium.",
            loss: "equals a major global game publisher at a fair-premium valuation.",
            icon: "gamecontroller.fill",
            30, 40, .entertainment
        ),
        entry(
            "music-major-label-34",
            gain: "could acquire a major recorded-music company.",
            loss: "matches the market value of a major recorded-music company.",
            icon: "music.note.list",
            30, 40, .entertainment
        ),
        entry(
            "gov-parks-multi-decade-32",
            "exceeds multi-decade US national parks capital needs — on paper.",
            icon: "tree.fill",
            30, 40, .government
        ),
        entry(
            "gov-nasa-science-36",
            "is larger than several years of NASA science directorate funding.",
            icon: "building.columns.fill",
            30, 40, .government
        ),
        entry(
            "gov-defense-ally-34",
            "matches a mid-size ally's annual defense procurement budget.",
            icon: "shield.fill",
            30, 40, .government
        ),
        entry(
            "hsr-spur-network-35",
            gain: "could fund a regional high-speed rail spur network.",
            loss: "matches a regional high-speed rail spur network budget.",
            icon: "tram.fill",
            30, 40, .infrastructure
        ),
        entry(
            "bridge-state-network-38",
            gain: "could replace a state's entire backlog of critical bridges.",
            loss: "equals a statewide critical-bridge replacement backlog.",
            icon: "road.lanes.curved.left",
            30, 40, .infrastructure
        ),
        entry(
            "port-mega-expansion-33",
            gain: "could expand a top global port to next-generation capacity.",
            loss: "matches a top global port's next-generation expansion bill.",
            icon: "shippingbox.fill",
            30, 40, .infrastructure
        ),
        entry(
            "nuclear-smr-fleet-36",
            gain: "could deploy a first fleet of small modular reactors.",
            loss: "equals the capital cost of a first SMR fleet deployment.",
            icon: "bolt.fill",
            30, 40, .infrastructure
        ),
        entry(
            "chip-packaging-campus-34",
            "beats the build cost of an advanced chip-packaging campus.",
            icon: "cpu.fill",
            30, 40, .technology
        ),
        entry(
            "ai-national-cluster-38",
            gain: "could stand up a national-scale AI research compute cluster.",
            loss: "matches a national-scale AI research compute cluster buildout.",
            icon: "server.rack",
            30, 40, .technology
        ),
        entry(
            "telecom-5g-state-32",
            gain: "could densify 5G across every metro in a large state.",
            loss: "equals statewide metro 5G densification for a large state.",
            icon: "antenna.radiowaves.left.and.right",
            30, 40, .technology
        ),
        entry(
            "semiconductor-tooling-36",
            gain: "could equip a full advanced-node tooling package for a fab.",
            loss: "matches a full advanced-node fab tooling package.",
            icon: "wrench.and.screwdriver.fill",
            30, 40, .technology
        ),
        entry(
            "phil-malaria-gap-35",
            gain: "could close multi-year malaria program funding gaps worldwide.",
            loss: "matches multi-year worldwide malaria program funding gaps.",
            icon: "cross.case.fill",
            30, 40, .philanthropy
        ),
        entry(
            "phil-water-access-33",
            gain: "could bring safe water access to tens of millions of people.",
            loss: "equals the price tag of safe water access for tens of millions.",
            gainHighlight: "tens of millions",
            lossHighlight: "tens of millions",
            icon: "drop.fill",
            30, 40, .philanthropy
        ),
        entry(
            "lux-chateau-vineyard-37",
            gain: "would buy a portfolio of trophy châteaux and vineyards across Europe.",
            loss: "matches a portfolio of trophy European châteaux and vineyards.",
            icon: "wineglass.fill",
            30, 40, .luxury
        ),
        entry(
            "lux-skyline-penthouses-34",
            gain: "would clear the world's top skyline penthouse inventory.",
            loss: "equals the world's top skyline penthouse inventory — sticker price.",
            icon: "building.2.fill",
            30, 40, .luxury
        ),
        entry(
            "nature-prairie-belt-36",
            gain: "could restore a prairie belt spanning multiple Great Plains states.",
            loss: "equals restoring a multi-state Great Plains prairie belt.",
            icon: "leaf.fill",
            30, 40, .nature
        ),
        entry(
            "nature-mangrove-belt-32",
            gain: "could replant a continental mangrove protection belt.",
            loss: "matches a continental mangrove protection-belt replanting program.",
            icon: "leaf.fill",
            30, 40, .nature
        ),
        entry(
            "ent-theme-resort-city-39",
            gain: "could build a destination resort city around a flagship park.",
            loss: "equals a destination resort city built around a flagship park.",
            icon: "ticket.fill",
            30, 40, .entertainment
        ),
        entry(
            "gov-cdc-multi-year-31",
            "exceeds several years of CDC total program funding.",
            icon: "cross.case.fill",
            30, 40, .government
        ),
        entry(
            "sports-league-expansion-wave-35",
            "matches a full wave of major-league expansion fees — across sports.",
            icon: "sportscourt.fill",
            30, 40, .sports
        ),
        entry(
            "infra-fiber-large-state-37",
            gain: "could bury fiber to nearly every address in a large state.",
            loss: "matches near-statewide fiber-to-the-home for a large state.",
            icon: "cable.connector",
            30, 40, .infrastructure
        ),
        entry(
            "econ-auto-oem-slice-33",
            "equals a mid-size global automaker's annual revenue slice.",
            icon: "car.fill",
            30, 40, .economics
        ),
        entry(
            "space-constellation-shell-39",
            gain: "could deploy an entire broadband constellation shell.",
            loss: "matches the deployment cost of an entire broadband constellation shell.",
            icon: "antenna.radiowaves.left.and.right",
            30, 40, .space
        ),

        // MARK: Expanded library — high buckets (agent batch)
// MARK: Batch $40–$50B (mega-40*)
        entry(
            "mega-40-lux-gdp",
            "equals the GDP of Luxembourg — in a single trading day.",
            highlight: "Luxembourg",
            icon: "globe.europe.africa.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-nih-year",
            gain: "could fund the NIH for an entire fiscal year.",
            loss: "matches the NIH's entire annual budget.",
            gainHighlight: "entire fiscal year",
            lossHighlight: "entire annual budget",
            icon: "cross.case.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-cbp-year",
            "is as big as a year of US Customs and Border Protection funding.",
            icon: "building.columns.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-tunisia-gdp",
            "matches the annual GDP of Tunisia.",
            highlight: "Tunisia",
            icon: "globe.africa.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-lithuania-gdp",
            "equals Lithuania's entire annual economic output.",
            highlight: "Lithuania",
            icon: "globe.europe.africa.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-bank-profits",
            "exceeds a year of after-tax profits for a top global retail bank.",
            icon: "banknote.fill",
            40, 50, .economics
        ),
        entry(
            "megaecon-40-airline-fleet",
            gain: "could re-fleet a major US airline with next-gen narrowbodies.",
            loss: "equals the sticker price of a major airline's next-gen narrowbody fleet.",
            icon: "airplane",
            40, 50, .economics
        ),
        entry(
            "mega-space-40-relay",
            gain: "could underwrite a constellation of deep-space relay satellites.",
            loss: "matches a deep-space relay constellation program budget.",
            icon: "antenna.radiowaves.left.and.right",
            40, 50, .space
        ),
        entry(
            "mega-space-40-reuse-rd",
            gain: "would pay for a decade of booster reuse R&D at full throttle.",
            loss: "equals a decade of booster reuse R&D spend.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "wrench.and.screwdriver.fill",
            40, 50, .space
        ),
        entry(
            "mega-space-40-nasa-two",
            gain: "could cover nearly two years of NASA's full agency budget.",
            loss: "matches nearly two years of NASA's full agency budget.",
            gainHighlight: "two years",
            lossHighlight: "two years",
            icon: "sparkles",
            40, 50, .space
        ),
        entry(
            "mega-space-40-lunar-lander",
            gain: "would fund a commercial lunar lander fleet through first ops.",
            loss: "equals the capital cost of a commercial lunar lander fleet through first ops.",
            icon: "moon.fill",
            40, 50, .space
        ),
        entry(
            "mega-sports-40-tennis-history",
            "beats the total career prize money in tennis history.",
            icon: "tennisball.fill",
            40, 50, .sports
        ),
        entry(
            "mega-sports-40-nfl-three",
            "outvalues three mid-market NFL franchises combined.",
            highlight: "three",
            icon: "sportscourt.fill",
            40, 50, .sports
        ),
        entry(
            "mega-sports-40-olympics-host",
            gain: "could underwrite a full Summer Olympics host-city buildout.",
            loss: "matches a full Summer Olympics host-city buildout budget.",
            icon: "medal.fill",
            40, 50, .sports
        ),
        entry(
            "mega-sports-40-f1-decade",
            "exceeds a decade of Formula 1 team operating budgets combined.",
            highlight: "a decade",
            icon: "flag.checkered",
            40, 50, .sports
        ),
        entry(
            "mega-ent-40-broadway-twice",
            gain: "could buy out every Broadway season's gross — twice.",
            loss: "matches twice every Broadway season's total gross.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "theatermasks.fill",
            40, 50, .entertainment
        ),
        entry(
            "mega-ent-40-hollywood-year",
            "equals a year of global box-office receipts for a major studio slate.",
            icon: "film.fill",
            40, 50, .entertainment
        ),
        entry(
            "mega-ent-40-theme-parks",
            gain: "could build two world-class destination theme parks from dirt.",
            loss: "matches the all-in cost of two world-class destination theme parks.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "ferriswheel",
            40, 50, .entertainment
        ),
        entry(
            "mega-gov-40-canada-procure",
            "exceeds the annual defense procurement of Canada.",
            icon: "shield.fill",
            40, 50, .government
        ),
        entry(
            "mega-gov-40-fema-multi",
            "matches several years of FEMA disaster-relief appropriations.",
            icon: "building.columns.fill",
            40, 50, .government
        ),
        entry(
            "mega-gov-40-state-budget",
            "is about the size of a mid-size US state's annual general fund.",
            icon: "map.fill",
            40, 50, .government
        ),
        entry(
            "mega-infra-40-fiber-state",
            gain: "could bury fiber to every home in a large state.",
            loss: "matches statewide fiber-to-the-home costs for a large state.",
            icon: "cable.connector",
            40, 50, .infrastructure
        ),
        entry(
            "mega-infra-40-carriers-three",
            gain: "could buy three Ford-class aircraft carriers — paint included.",
            loss: "equals the construction cost of three Ford-class aircraft carriers.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "ferry.fill",
            40, 50, .infrastructure
        ),
        entry(
            "mega-infra-40-subway-line",
            gain: "would fund a new heavy-rail subway line under a mega-city.",
            loss: "matches the all-in cost of a new heavy-rail subway line under a mega-city.",
            icon: "tram.fill",
            40, 50, .infrastructure
        ),
        entry(
            "mega-infra-40-airport-hub",
            gain: "could rebuild a major international airport hub end to end.",
            loss: "equals the rebuild cost of a major international airport hub.",
            icon: "airplane.departure",
            40, 50, .infrastructure
        ),
        entry(
            "mega-tech-40-ipo",
            "is bigger than the IPO proceeds of a generational tech listing.",
            icon: "chart.bar.fill",
            40, 50, .technology
        ),
        entry(
            "mega-tech-40-chip-fab",
            gain: "could build a leading-edge chip fab campus in the US.",
            loss: "matches the capital cost of a leading-edge US chip fab campus.",
            icon: "cpu.fill",
            40, 50, .technology
        ),
        entry(
            "mega-tech-40-datacenter-region",
            gain: "would fund a hyperscale data-center region with full power hookup.",
            loss: "equals a hyperscale data-center region buildout with full power hookup.",
            icon: "server.rack",
            40, 50, .technology
        ),
        entry(
            "mega-tech-40-ai-cluster",
            gain: "could stand up a frontier AI training cluster for a full generation.",
            loss: "matches the hardware bill for a frontier AI training cluster generation.",
            icon: "brain.head.profile",
            40, 50, .technology
        ),
        entry(
            "mega-phil-40-water-50m",
            gain: "could end extreme water insecurity for 50 million people.",
            loss: "matches the price tag to end extreme water insecurity for 50 million people.",
            gainHighlight: "50 million",
            lossHighlight: "50 million",
            icon: "drop.fill",
            40, 50, .philanthropy
        ),
        entry(
            "mega-phil-40-vaccines",
            gain: "could bankroll a decade of global childhood vaccine top-ups.",
            loss: "equals a decade of global childhood vaccine top-up funding.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "cross.case.fill",
            40, 50, .philanthropy
        ),
        entry(
            "mega-phil-40-scholarships",
            gain: "would endow full-ride scholarships for 400,000 students.",
            loss: "matches an endowment for full-ride scholarships for 400,000 students.",
            gainHighlight: "400,000",
            lossHighlight: "400,000",
            icon: "graduationcap.fill",
            40, 50, .philanthropy
        ),
        entry(
            "mega-lux-40-yachts",
            gain: "would buy every yacht over 100 meters currently for sale.",
            loss: "equals the asking price of every 100m+ yacht currently listed.",
            icon: "sailboat.fill",
            40, 50, .luxury
        ),
        entry(
            "mega-lux-40-patek",
            gain: "could corner the entire annual production of ultra-high-end watches.",
            loss: "matches the annual retail value of ultra-high-end watch production.",
            icon: "watch.analog",
            40, 50, .luxury
        ),
        entry(
            "mega-lux-40-art-record",
            "exceeds a decade of record-breaking art-auction hammer totals.",
            highlight: "a decade",
            icon: "paintpalette.fill",
            40, 50, .luxury
        ),
        entry(
            "mega-nat-40-coral",
            gain: "could fund large-scale coral reef restoration across the tropics.",
            loss: "matches a tropics-wide coral reef restoration program budget.",
            icon: "water.waves",
            40, 50, .nature
        ),
        entry(
            "mega-nat-40-wildfire",
            gain: "would equip a generation of wildfire-resilient landscapes in the West.",
            loss: "equals a generation of western wildfire-resilience landscape work.",
            icon: "flame.fill",
            40, 50, .nature
        ),
        entry(
            "mega-nat-40-parks",
            gain: "could double the National Park Service capital backlog fix.",
            loss: "matches twice the National Park Service capital maintenance backlog.",
            gainHighlight: "double",
            lossHighlight: "twice",
            icon: "tree.fill",
            40, 50, .nature
        ),
        entry(
            "megaecon-40-pension-slice",
            "is a meaningful slice of a large public pension system's assets.",
            icon: "chart.line.uptrend.xyaxis",
            40, 50, .economics
        ),
        entry(
            "mega-gov-40-coast-guard",
            "exceeds several years of US Coast Guard annual appropriations.",
            icon: "shield.lefthalf.filled",
            40, 50, .government
        ),
        entry(
            "mega-sports-40-mlb-payrolls",
            "outpaces a decade of combined MLB luxury-tax payrolls.",
            highlight: "a decade",
            icon: "baseball.fill",
            40, 50, .sports
        ),
        entry(
            "mega-ent-40-music-streams",
            "matches years of global recorded-music industry revenue.",
            icon: "music.note.list",
            40, 50, .entertainment
        ),

        // MARK: Batch $50–$60B (mega-50*)
        entry(
            "megaecon-50-auto-swing",
            "equals the market-value swing of a top-10 global automaker.",
            icon: "car.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-cc-40m",
            gain: "could zero out credit-card balances for 40 million households.",
            loss: "equals the credit-card balances of 40 million households.",
            gainHighlight: "40 million",
            lossHighlight: "40 million",
            icon: "creditcard.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-bank-nii",
            "matches a year of net interest income for a major money-center bank.",
            icon: "banknote.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-croatia-gdp",
            "equals the annual GDP of Croatia.",
            highlight: "Croatia",
            icon: "globe.europe.africa.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-ghana-gdp",
            "matches Ghana's entire yearly economic output.",
            highlight: "Ghana",
            icon: "globe.africa.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-swf-slice",
            "is a solid annual return for a mid-size sovereign wealth fund.",
            icon: "chart.pie.fill",
            50, 60, .economics
        ),
        entry(
            "megaecon-50-insurance-float",
            "exceeds a year of premiums written by a top global insurer.",
            icon: "doc.text.fill",
            50, 60, .economics
        ),
        entry(
            "mega-space-50-artemis",
            gain: "could fund an Artemis-scale hardware push on its own.",
            loss: "matches an Artemis-scale hardware program budget.",
            gainHighlight: "Artemis-scale",
            lossHighlight: "Artemis-scale",
            icon: "moon.fill",
            50, 60, .space
        ),
        entry(
            "mega-space-50-station-fleet",
            gain: "would cover the capital cost of a private space station fleet.",
            loss: "equals the capital cost of a private space station fleet.",
            icon: "sparkles",
            50, 60, .space
        ),
        entry(
            "mega-space-50-mars-sample",
            gain: "could bankroll a Mars sample-return campaign with contingency.",
            loss: "matches a Mars sample-return campaign budget with contingency.",
            icon: "globe.americas.fill",
            50, 60, .space
        ),
        entry(
            "mega-space-50-heavy-lift",
            gain: "would fund a decade of heavy-lift launch capacity purchases.",
            loss: "equals a decade of heavy-lift launch capacity purchase spend.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "airplane.departure",
            50, 60, .space
        ),
        entry(
            "mega-sports-50-sb-ads",
            "outpaces a decade of Super Bowl ad spend — combined.",
            highlight: "a decade",
            icon: "sportscourt.fill",
            50, 60, .sports
        ),
        entry(
            "mega-sports-50-nba-four",
            "outvalues four average NBA franchises put together.",
            highlight: "four",
            icon: "basketball.fill",
            50, 60, .sports
        ),
        entry(
            "mega-sports-50-world-cup-infra",
            gain: "could fund World Cup stadium upgrades for a host nation.",
            loss: "matches World Cup stadium-upgrade costs for a host nation.",
            icon: "soccerball",
            50, 60, .sports
        ),
        entry(
            "mega-sports-50-golf-history",
            "beats cumulative PGA Tour prize money across modern history.",
            icon: "figure.golf",
            50, 60, .sports
        ),
        entry(
            "mega-ent-50-labels",
            gain: "could acquire three major record labels and still tour.",
            loss: "matches the combined market value of three major record labels.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "music.note.list",
            50, 60, .entertainment
        ),
        entry(
            "mega-ent-50-streaming-catalog",
            gain: "would license every major film studio's back catalog for years.",
            loss: "equals multi-year licensing value of every major studio back catalog.",
            icon: "play.tv.fill",
            50, 60, .entertainment
        ),
        entry(
            "mega-ent-50-concert-tours",
            "exceeds a decade of global stadium-tour grosses for top acts.",
            highlight: "a decade",
            icon: "music.mic",
            50, 60, .entertainment
        ),
        entry(
            "mega-gov-50-esa",
            "exceeds the annual budget of the European Space Agency.",
            icon: "building.columns.fill",
            50, 60, .government
        ),
        entry(
            "mega-gov-50-usda-farm",
            "matches a large slice of annual US farm-bill outlays.",
            icon: "leaf.fill",
            50, 60, .government
        ),
        entry(
            "mega-gov-50-va-health",
            "is about a year of VA medical-care funding.",
            icon: "cross.case.fill",
            50, 60, .government
        ),
        entry(
            "mega-infra-50-bridges",
            gain: "could rebuild every bridge on the interstate top-10 list.",
            loss: "equals the rebuild cost of every bridge on the interstate top-10 list.",
            icon: "road.lanes.curved.left",
            50, 60, .infrastructure
        ),
        entry(
            "mega-infra-50-hsr-corridor",
            gain: "would build a high-speed rail corridor between two mega-metros.",
            loss: "matches the cost of a high-speed rail corridor between two mega-metros.",
            icon: "tram.fill",
            50, 60, .infrastructure
        ),
        entry(
            "mega-infra-50-grid-storage",
            gain: "could deploy utility-scale grid storage for a multi-state region.",
            loss: "equals multi-state utility-scale grid storage deployment costs.",
            icon: "bolt.fill",
            50, 60, .infrastructure
        ),
        entry(
            "mega-infra-50-desal",
            gain: "would fund coastal desalination plants for a drought-hit state.",
            loss: "matches coastal desalination plant costs for a drought-hit state.",
            icon: "drop.triangle.fill",
            50, 60, .infrastructure
        ),
        entry(
            "mega-tech-50-cloud-year",
            "is larger than a year of cloud revenue for a second-tier hyperscaler.",
            icon: "cloud.fill",
            50, 60, .technology
        ),
        entry(
            "mega-tech-50-two-fabs",
            gain: "could plant two advanced logic fabs on greenfield sites.",
            loss: "matches the capital cost of two advanced logic fabs.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "cpu.fill",
            50, 60, .technology
        ),
        entry(
            "mega-tech-50-eu-chips",
            gain: "would cover a major European Chips Act investment tranche.",
            loss: "equals a major European Chips Act investment tranche.",
            icon: "memorychip.fill",
            50, 60, .technology
        ),
        entry(
            "mega-tech-50-robotics-fleet",
            gain: "could capitalize a global industrial-robotics buildout wave.",
            loss: "matches capital for a global industrial-robotics buildout wave.",
            icon: "gearshape.2.fill",
            50, 60, .technology
        ),
        entry(
            "mega-lux-50-homes-ten",
            gain: "would buy the world's ten most expensive homes — with tips.",
            loss: "matches the price of the world's ten most expensive homes — with tips.",
            gainHighlight: "ten",
            lossHighlight: "ten",
            icon: "house.fill",
            50, 60, .luxury
        ),
        entry(
            "mega-lux-50-jets-vip",
            gain: "could outfit a VIP air fleet of long-range business jets.",
            loss: "equals the cost of a VIP air fleet of long-range business jets.",
            icon: "airplane",
            50, 60, .luxury
        ),
        entry(
            "mega-lux-50-islands",
            gain: "would acquire a portfolio of private islands with resort upgrades.",
            loss: "matches the market value of a private-island portfolio with resort upgrades.",
            icon: "island",
            50, 60, .luxury
        ),
        entry(
            "mega-nat-50-gulf",
            gain: "could fund coastal resilience for the entire Gulf Coast.",
            loss: "equals a Gulf Coast–wide coastal resilience program.",
            icon: "water.waves",
            50, 60, .nature
        ),
        entry(
            "mega-nat-50-amazon-slice",
            gain: "would finance large-scale Amazon basin conservation easements.",
            loss: "matches large-scale Amazon basin conservation-easement costs.",
            icon: "leaf.fill",
            50, 60, .nature
        ),
        entry(
            "mega-nat-50-methane",
            gain: "could plug super-emitter methane leaks worldwide for years.",
            loss: "equals multi-year costs to plug super-emitter methane leaks worldwide.",
            icon: "smoke.fill",
            50, 60, .nature
        ),
        entry(
            "mega-phil-50-malaria-gap",
            gain: "could close global malaria funding gaps for a long stretch.",
            loss: "matches a long stretch of global malaria funding gaps.",
            icon: "cross.case.fill",
            50, 60, .philanthropy
        ),
        entry(
            "mega-phil-50-housing",
            gain: "would seed permanent supportive housing in every major US city.",
            loss: "matches seed capital for permanent supportive housing in every major US city.",
            icon: "building.2.fill",
            50, 60, .philanthropy
        ),
        entry(
            "mega-phil-50-clean-cook",
            gain: "could distribute clean cookstoves to hundreds of millions of homes.",
            loss: "equals the cost of clean cookstoves for hundreds of millions of homes.",
            icon: "flame.fill",
            50, 60, .philanthropy
        ),
        entry(
            "mega-gov-50-navy-ships",
            "exceeds a multi-year US Navy surface-combatant procurement tranche.",
            icon: "ferry.fill",
            50, 60, .government
        ),
        entry(
            "mega-sports-50-epl-clubs",
            "outvalues a handful of Premier League mid-table clubs combined.",
            icon: "soccerball.inverse",
            50, 60, .sports
        ),
        entry(
            "mega-ent-50-gaming-pubs",
            gain: "could acquire several mid-tier game publishers at once.",
            loss: "matches the combined enterprise value of several mid-tier game publishers.",
            icon: "gamecontroller.fill",
            50, 60, .entertainment
        ),
        entry(
            "megaecon-50-muni-bonds",
            "is a sizable year of US municipal bond new issuance.",
            icon: "building.columns.fill",
            50, 60, .economics
        ),

        // MARK: Batch $60–$70B (mega-60*)
        entry(
            "megaecon-60-rd-credit",
            "equals the annual federal R&D tax credit pool — in one day.",
            highlight: "one day",
            icon: "lightbulb.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-taxpayer-1k",
            gain: "could pay a $1,000 bonus to every US taxpayer.",
            loss: "equals $1,000 for every US taxpayer.",
            gainHighlight: "every US taxpayer",
            lossHighlight: "every US taxpayer",
            icon: "person.3.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-oil-major",
            "matches the annual profits of a top-5 global oil major.",
            icon: "flame.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-slovakia-gdp",
            "equals the annual GDP of Slovakia.",
            highlight: "Slovakia",
            icon: "globe.europe.africa.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-morocco-gdp",
            "matches Morocco's yearly economic output.",
            highlight: "Morocco",
            icon: "globe.africa.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-fortune100-rev",
            "is a mid-pack Fortune 100 company's entire annual revenue.",
            icon: "chart.bar.fill",
            60, 70, .economics
        ),
        entry(
            "megaecon-60-vc-year",
            "exceeds a strong year of total US venture capital deployment.",
            icon: "dollarsign.circle.fill",
            60, 70, .economics
        ),
        entry(
            "mega-space-60-mars-logistics",
            gain: "could bankroll a Mars surface logistics demo at scale.",
            loss: "matches a Mars surface logistics demo program budget.",
            icon: "moon.stars.fill",
            60, 70, .space
        ),
        entry(
            "mega-space-60-starlink-shell",
            gain: "would fund Starlink Gen3 deployment for a full orbital shell.",
            loss: "equals a full Starlink Gen3 orbital-shell deployment.",
            icon: "antenna.radiowaves.left.and.right",
            60, 70, .space
        ),
        entry(
            "mega-space-60-gateway",
            gain: "could underwrite a lunar Gateway-class outpost program.",
            loss: "matches a lunar Gateway-class outpost program budget.",
            icon: "sparkles",
            60, 70, .space
        ),
        entry(
            "mega-space-60-esa-artemis",
            gain: "would cover ESA contributions to lunar exploration for years.",
            loss: "equals multi-year ESA lunar-exploration contribution levels.",
            icon: "globe.europe.africa.fill",
            60, 70, .space
        ),
        entry(
            "mega-sports-60-soccer-windows",
            "beats the combined transfer fees of a decade of soccer windows.",
            highlight: "a decade",
            icon: "soccerball",
            60, 70, .sports
        ),
        entry(
            "mega-sports-60-nfl-four",
            "outvalues four mid-tier NFL franchises stacked together.",
            highlight: "four",
            icon: "sportscourt.fill",
            60, 70, .sports
        ),
        entry(
            "mega-sports-60-olympics-winter",
            gain: "could stage a Winter Olympics with modern venues and security.",
            loss: "matches a modern Winter Olympics venue-and-security budget.",
            icon: "snowflake",
            60, 70, .sports
        ),
        entry(
            "mega-sports-60-mlb-teams",
            "exceeds the combined value of several MLB mid-market clubs.",
            icon: "baseball.fill",
            60, 70, .sports
        ),
        entry(
            "mega-ent-60-streamers-quarter",
            gain: "could run every major streaming service at a loss for a quarter.",
            loss: "matches a quarter of operating losses across every major streamer.",
            gainHighlight: "a quarter",
            lossHighlight: "a quarter",
            icon: "play.tv.fill",
            60, 70, .entertainment
        ),
        entry(
            "mega-ent-60-hollywood-global",
            "equals a strong year of global theatrical box-office totals.",
            icon: "film.fill",
            60, 70, .entertainment
        ),
        entry(
            "mega-ent-60-disney-parks",
            gain: "could build a new Disney-scale resort destination from scratch.",
            loss: "matches the all-in cost of a new Disney-scale resort destination.",
            icon: "ferriswheel",
            60, 70, .entertainment
        ),
        entry(
            "mega-gov-60-renewable-credits",
            "exceeds the US annual spend on renewable energy credits.",
            icon: "sun.max.fill",
            60, 70, .government
        ),
        entry(
            "mega-gov-60-irs-multi",
            "matches multi-year IRS modernization and enforcement funding.",
            icon: "building.columns.fill",
            60, 70, .government
        ),
        entry(
            "mega-gov-60-dot-highways",
            "is about a major multi-year federal highway obligation tranche.",
            icon: "road.lanes",
            60, 70, .government
        ),
        entry(
            "mega-infra-60-port-cranes",
            gain: "could modernize every major US port's container cranes.",
            loss: "matches the cost of modernizing every major US port's container cranes.",
            icon: "shippingbox.fill",
            60, 70, .infrastructure
        ),
        entry(
            "mega-infra-60-carriers-five",
            gain: "would buy five nuclear aircraft carriers — roughly.",
            loss: "equals the construction cost of about five nuclear aircraft carriers.",
            gainHighlight: "five",
            lossHighlight: "five",
            icon: "ferry.fill",
            60, 70, .infrastructure
        ),
        entry(
            "mega-infra-60-nuclear-plant",
            gain: "could complete a multi-reactor nuclear power plant project.",
            loss: "matches the all-in cost of a multi-reactor nuclear power plant.",
            icon: "bolt.circle.fill",
            60, 70, .infrastructure
        ),
        entry(
            "mega-infra-60-urban-tunnel",
            gain: "would dig a multi-decade urban transit tunnel network tranche.",
            loss: "equals a multi-decade urban transit tunnel network tranche.",
            icon: "tram.fill",
            60, 70, .infrastructure
        ),
        entry(
            "mega-tech-60-merger-cash",
            "is larger than the cash component of the biggest tech merger ever.",
            icon: "arrow.triangle.merge",
            60, 70, .technology
        ),
        entry(
            "mega-tech-60-fabs-cluster",
            gain: "could underwrite a multi-fab semiconductor cluster in one region.",
            loss: "matches capital for a multi-fab semiconductor cluster in one region.",
            icon: "cpu.fill",
            60, 70, .technology
        ),
        entry(
            "mega-tech-60-h100-era",
            gain: "would buy a generation of frontier GPU inventory at peak prices.",
            loss: "equals a generation of frontier GPU inventory at peak prices.",
            icon: "memorychip.fill",
            60, 70, .technology
        ),
        entry(
            "mega-tech-60-undersea-cables",
            gain: "could lay a new generation of intercontinental undersea cables.",
            loss: "matches the cost of a new generation of intercontinental undersea cables.",
            icon: "cable.connector.horizontal",
            60, 70, .technology
        ),
        entry(
            "mega-phil-60-malaria-15",
            gain: "could erase malaria program funding gaps for 15 years.",
            loss: "matches 15 years of malaria program funding gaps.",
            gainHighlight: "15 years",
            lossHighlight: "15 years",
            icon: "cross.case.fill",
            60, 70, .philanthropy
        ),
        entry(
            "mega-phil-60-polio-endgame",
            gain: "would fund polio endgame campaigns worldwide for a generation.",
            loss: "equals a generation of worldwide polio endgame campaign funding.",
            icon: "heart.fill",
            60, 70, .philanthropy
        ),
        entry(
            "mega-phil-60-college-debt-slice",
            gain: "could wipe a large slice of outstanding US student loan balances.",
            loss: "matches a large slice of outstanding US student loan balances.",
            icon: "graduationcap.fill",
            60, 70, .philanthropy
        ),
        entry(
            "mega-nat-60-yellowstone-twice",
            gain: "could rewild an area the size of Yellowstone — twice.",
            loss: "equals rewilding costs for twice the area of Yellowstone.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "leaf.fill",
            60, 70, .nature
        ),
        entry(
            "mega-nat-60-wetlands",
            gain: "would restore coastal wetlands along the entire Atlantic seaboard.",
            loss: "matches Atlantic seaboard coastal-wetland restoration costs.",
            icon: "water.waves",
            60, 70, .nature
        ),
        entry(
            "mega-nat-60-species",
            gain: "could bankroll a global endangered-species recovery blitz.",
            loss: "equals a global endangered-species recovery program budget.",
            icon: "bird.fill",
            60, 70, .nature
        ),
        entry(
            "mega-lux-60-superyacht-fleet",
            gain: "would assemble a fleet of the world's largest private superyachts.",
            loss: "matches the market value of a fleet of the world's largest private superyachts.",
            icon: "sailboat.fill",
            60, 70, .luxury
        ),
        entry(
            "mega-lux-60-penthouses",
            gain: "could buy every trophy penthouse listed in global gateway cities.",
            loss: "equals the asking prices of every trophy penthouse in global gateway cities.",
            icon: "building.fill",
            60, 70, .luxury
        ),
        entry(
            "mega-gov-60-nasa-multi",
            "exceeds more than two years of NASA's full agency appropriation.",
            highlight: "two years",
            icon: "sparkles",
            60, 70, .government
        ),
        entry(
            "mega-sports-60-nhl-values",
            "outvalues a big chunk of the entire NHL franchise ladder.",
            icon: "hockey.puck.fill",
            60, 70, .sports
        ),
        entry(
            "mega-ent-60-hollywood-industry",
            "matches a large share of a year of the global film industry.",
            icon: "popcorn.fill",
            60, 70, .entertainment
        ),
        entry(
            "megaecon-60-fx-day",
            "is a rounding error in a day of global FX turnover — but still huge.",
            icon: "arrow.left.arrow.right.circle.fill",
            60, 70, .economics
        ),
        entry(
            "mega-infra-60-broadband-rural",
            gain: "could finish rural broadband for every unserved US household.",
            loss: "matches the cost to finish rural broadband for every unserved US household.",
            icon: "wifi",
            60, 70, .infrastructure
        ),

        // MARK: Batch $70B+ (mega-70*)
        entry(
            "megaecon-70-kenya-gdp",
            "equals the GDP of Kenya — before lunch.",
            highlight: "before lunch",
            icon: "globe.africa.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-apollo-vibes",
            gain: "could fund the Apollo program — adjusted for vibes.",
            loss: "matches the Apollo program — adjusted for vibes.",
            gainHighlight: "Apollo program",
            lossHighlight: "Apollo program",
            icon: "clock.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-g20-budget",
            "is about the size of a small G20 nation's annual federal budget.",
            icon: "building.columns.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-guatemala-gdp",
            "matches the annual GDP of Guatemala.",
            highlight: "Guatemala",
            icon: "globe.americas.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-bulgaria-gdp",
            "equals Bulgaria's entire yearly economic output.",
            highlight: "Bulgaria",
            icon: "globe.europe.africa.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-swf-return",
            "matches a strong annual return for a large sovereign wealth fund.",
            icon: "chart.pie.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-sp500-earnings-slice",
            "is a non-trivial slice of annual S&P 500 aggregate earnings.",
            icon: "chart.line.uptrend.xyaxis",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-global-vc-cycle",
            "exceeds a full boom-cycle year of global venture investment.",
            icon: "dollarsign.circle.fill",
            70, 1000, .economics
        ),
        entry(
            "megaecon-70-ethiopia-gdp",
            "equals the annual GDP of Ethiopia.",
            highlight: "Ethiopia",
            icon: "globe.africa.fill",
            70, 1000, .economics
        ),
        entry(
            "mega-space-70-lunar-base",
            gain: "could seed a self-sustaining lunar industrial base.",
            loss: "matches seed capital for a self-sustaining lunar industrial base.",
            icon: "moon.fill",
            70, 1000, .space
        ),
        entry(
            "mega-space-70-starship-year",
            gain: "would pay for a Starship production line's first full year.",
            loss: "equals a Starship production line's first full year of capital.",
            gainHighlight: "first full year",
            lossHighlight: "first full year",
            icon: "gearshape.2.fill",
            70, 1000, .space
        ),
        entry(
            "mega-space-70-mars-city-seed",
            gain: "could fund the first decade of a Mars city starter kit.",
            loss: "matches the first decade of a Mars city starter-kit budget.",
            gainHighlight: "first decade",
            lossHighlight: "first decade",
            icon: "moon.stars.fill",
            70, 1000, .space
        ),
        entry(
            "mega-space-70-nasa-three",
            gain: "would cover more than three years of NASA at current levels.",
            loss: "equals more than three years of NASA funding at current levels.",
            gainHighlight: "three years",
            lossHighlight: "three years",
            icon: "sparkles",
            70, 1000, .space
        ),
        entry(
            "mega-space-70-jwst-fleet",
            gain: "could build a fleet of JWST-class observatories.",
            loss: "matches the cost of a fleet of JWST-class observatories.",
            icon: "telescope.fill",
            70, 1000, .space
        ),
        entry(
            "mega-nfl-70-half-league",
            "outvalues roughly a third of all NFL franchises combined.",
            highlight: "a third",
            icon: "sportscourt.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-nfl-70-full-league",
            "approaches the combined franchise value of the entire NFL.",
            highlight: "entire NFL",
            icon: "football.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-sports-70-olympic-nation",
            "outvalues the GDP of a nation that could field an Olympic team.",
            icon: "medal.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-sports-70-nba-half",
            "exceeds half the combined franchise value of the NBA.",
            highlight: "half",
            icon: "basketball.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-sports-70-epl-top",
            "outvalues the top half of the Premier League's club ladder.",
            icon: "soccerball",
            70, 1000, .sports
        ),
        entry(
            "mega-sports-70-mlb-league",
            "approaches the combined enterprise value of Major League Baseball.",
            icon: "baseball.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-ent-70-games-revenue",
            gain: "could buy the entire video game industry's annual revenue.",
            loss: "matches the entire video game industry's annual revenue.",
            icon: "gamecontroller.fill",
            70, 1000, .entertainment
        ),
        entry(
            "mega-ent-70-global-film",
            "equals a year of the global film industry's box office and streaming.",
            icon: "film.fill",
            70, 1000, .entertainment
        ),
        entry(
            "mega-ent-70-hollywood-majors",
            gain: "could acquire a major Hollywood studio group outright.",
            loss: "matches the enterprise value of a major Hollywood studio group.",
            icon: "theatermasks.fill",
            70, 1000, .entertainment
        ),
        entry(
            "mega-ent-70-music-global",
            "exceeds multiple years of the entire recorded-music industry.",
            icon: "music.note.list",
            70, 1000, .entertainment
        ),
        entry(
            "mega-gov-70-world-bank-climate",
            "exceeds the World Bank's annual climate finance commitments.",
            icon: "globe.americas.fill",
            70, 1000, .government
        ),
        entry(
            "mega-gov-70-uk-defense",
            "matches a multi-year UK defense budget tranche.",
            icon: "shield.fill",
            70, 1000, .government
        ),
        entry(
            "mega-gov-70-medicare-slice",
            "is a visible slice of annual US Medicare spending.",
            icon: "cross.case.fill",
            70, 1000, .government
        ),
        entry(
            "mega-gov-70-imf-quota",
            "exceeds many countries' entire IMF quota subscriptions.",
            icon: "building.columns.fill",
            70, 1000, .government
        ),
        entry(
            "mega-infra-70-appalachian-rail",
            gain: "could tunnel high-speed rail under the Appalachian chain.",
            loss: "matches the cost of tunneling high-speed rail under the Appalachians.",
            icon: "tram.fill",
            70, 1000, .infrastructure
        ),
        entry(
            "mega-infra-70-carrier-fleet",
            gain: "would fund a blue-water carrier strike group build cycle.",
            loss: "equals a blue-water carrier strike group construction cycle.",
            icon: "ferry.fill",
            70, 1000, .infrastructure
        ),
        entry(
            "mega-infra-70-national-grid",
            gain: "could modernize a national high-voltage transmission backbone.",
            loss: "matches modernization costs for a national high-voltage backbone.",
            icon: "bolt.fill",
            70, 1000, .infrastructure
        ),
        entry(
            "mega-infra-70-megaproject",
            gain: "would complete a generation-defining water or transit megaproject.",
            loss: "equals a generation-defining water or transit megaproject budget.",
            icon: "hammer.fill",
            70, 1000, .infrastructure
        ),
        entry(
            "mega-infra-70-interstate-rebuild",
            gain: "could rebuild a multi-state interstate corridor end to end.",
            loss: "matches end-to-end rebuild costs for a multi-state interstate corridor.",
            icon: "road.lanes",
            70, 1000, .infrastructure
        ),
        entry(
            "mega-tech-70-foundry-capex",
            "is larger than the annual capex of a top-three chip foundry.",
            icon: "cpu.fill",
            70, 1000, .technology
        ),
        entry(
            "mega-tech-70-chips-act",
            gain: "could match the full US CHIPS Act manufacturing incentives pot.",
            loss: "matches the full US CHIPS Act manufacturing incentives pot.",
            icon: "memorychip.fill",
            70, 1000, .technology
        ),
        entry(
            "mega-tech-70-hyperscale-year",
            "exceeds a year of combined hyperscaler data-center capex for one giant.",
            icon: "server.rack",
            70, 1000, .technology
        ),
        entry(
            "mega-tech-70-ai-capex-wave",
            gain: "would underwrite an industry-wide AI infrastructure investment wave.",
            loss: "matches an industry-wide AI infrastructure investment wave.",
            icon: "brain.head.profile",
            70, 1000, .technology
        ),
        entry(
            "mega-lux-70-jets-500",
            gain: "would fund a fleet of 500 private jets — crew included.",
            loss: "matches the cost of 500 private jets — crew included.",
            gainHighlight: "500",
            lossHighlight: "500",
            icon: "airplane",
            70, 1000, .luxury
        ),
        entry(
            "mega-lux-70-supercars",
            gain: "could buy every new hypercar produced for a decade.",
            loss: "equals a decade of new hypercar production at sticker.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "car.fill",
            70, 1000, .luxury
        ),
        entry(
            "mega-lux-70-trophy-realestate",
            gain: "would acquire a global portfolio of trophy city skylines stakes.",
            loss: "matches a global portfolio of trophy city skyline stakes.",
            icon: "building.2.fill",
            70, 1000, .luxury
        ),
        entry(
            "mega-nat-70-west-virginia",
            gain: "could reforest an area the size of West Virginia.",
            loss: "equals reforestation costs for an area the size of West Virginia.",
            gainHighlight: "West Virginia",
            lossHighlight: "West Virginia",
            icon: "tree.fill",
            70, 1000, .nature
        ),
        entry(
            "mega-nat-70-great-lakes",
            gain: "would fund Great Lakes restoration for a generation.",
            loss: "matches a generation of Great Lakes restoration funding.",
            icon: "water.waves",
            70, 1000, .nature
        ),
        entry(
            "mega-nat-70-global-parks",
            gain: "could expand protected lands on a continental scale.",
            loss: "equals continental-scale protected-lands expansion costs.",
            icon: "leaf.fill",
            70, 1000, .nature
        ),
        entry(
            "mega-phil-70-global-health",
            gain: "would supercharge global health agencies for a decade.",
            loss: "matches a decade of supercharged global health agency budgets.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "heart.fill",
            70, 1000, .philanthropy
        ),
        entry(
            "mega-phil-70-education",
            gain: "could fund universal secondary education gaps in dozens of countries.",
            loss: "matches universal secondary-education gap costs across dozens of countries.",
            icon: "graduationcap.fill",
            70, 1000, .philanthropy
        ),
        entry(
            "megaecon-70-ireland-budget",
            "is in the ballpark of Ireland's annual government expenditure.",
            highlight: "Ireland",
            icon: "globe.europe.africa.fill",
            70, 1000, .economics
        ),
        entry(
            "mega-space-70-iss-successor",
            gain: "could capitalize the successor to the International Space Station.",
            loss: "matches capital for the successor to the International Space Station.",
            icon: "globe.americas.fill",
            70, 1000, .space
        ),
        entry(
            "mega-nfl-70-draft-history",
            "dwarfs every NFL player contract ever signed — combined.",
            icon: "sportscourt.fill",
            70, 1000, .sports
        ),
        entry(
            "mega-gov-70-un-budget-multi",
            "exceeds many years of the entire UN regular budget.",
            highlight: "many years",
            icon: "globe",
            70, 1000, .government
        ),
        entry(
            "mega-tech-70-eu-digital",
            gain: "could bankroll a continent-scale digital infrastructure program.",
            loss: "matches a continent-scale digital infrastructure program budget.",
            icon: "network",
            70, 1000, .technology
        ),

        // MARK: Expanded library — sports & pop culture (agent batch)
        // MARK: Fun batch — $0–$10B
        entry(
            "fun-001",
            "beats a decade of Super Bowl commercial inventory.",
            highlight: "a decade",
            icon: "tv.fill",
            0, 10, .sports
        ),
        entry(
            "fun-002",
            "outpaces the lifetime earnings of 50 Hall of Fame QBs.",
            highlight: "50",
            icon: "sportscourt.fill",
            0, 10, .sports
        ),
        entry(
            "fun-003",
            "matches the annual payroll of three mid-market MLB clubs.",
            highlight: "three",
            icon: "baseball.fill",
            0, 10, .sports
        ),
        entry(
            "fun-004",
            gain: "could bankroll every NBA max contract signed this offseason.",
            loss: "matches every NBA max contract signed this offseason.",
            gainHighlight: "every NBA max",
            lossHighlight: "every NBA max",
            icon: "basketball.fill",
            0, 10, .sports
        ),
        entry(
            "fun-005",
            "exceeds a top F1 team's entire multi-year budget cycle.",
            icon: "flag.checkered",
            0, 10, .sports
        ),
        entry(
            "fun-006",
            "outvalues the prize pool of ten FIFA World Cups stacked.",
            highlight: "ten",
            icon: "soccerball",
            0, 10, .sports
        ),
        entry(
            "fun-007",
            gain: "could fund a mid-tier European club's transfer window thrice.",
            loss: "equals three mid-tier European club transfer windows.",
            gainHighlight: "thrice",
            lossHighlight: "three",
            icon: "soccerball",
            0, 10, .sports
        ),
        entry(
            "fun-008",
            "beats the career prize money of every living tennis legend — combined.",
            icon: "tennisball.fill",
            0, 10, .sports
        ),
        entry(
            "fun-009",
            "matches stadium naming-rights deals for half the NFL.",
            highlight: "half the NFL",
            icon: "building.2.fill",
            0, 10, .sports
        ),
        entry(
            "fun-010",
            gain: "could produce two summer tentpole blockbusters end to end.",
            loss: "matches the full budget of two summer tentpole blockbusters.",
            gainHighlight: "two",
            lossHighlight: "two",
            icon: "film.fill",
            0, 10, .entertainment
        ),
        entry(
            "fun-011",
            "outpaces a prestige streamer's entire awards-season slate.",
            icon: "tv.fill",
            0, 10, .entertainment
        ),
        entry(
            "fun-012",
            gain: "could bankroll a K-pop stadium tour of every continent.",
            loss: "matches a K-pop stadium tour across every continent.",
            icon: "music.mic",
            0, 10, .entertainment
        ),
        entry(
            "fun-013",
            "beats Broadway's entire capitalization for a busy season.",
            icon: "theatermasks.fill",
            0, 10, .entertainment
        ),
        entry(
            "fun-014",
            gain: "would cover marketing for three AAA open-world launches.",
            loss: "equals the marketing spend of three AAA open-world launches.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "gamecontroller.fill",
            0, 10, .entertainment
        ),
        entry(
            "fun-015",
            "matches a Marvel mid-tier film's production-plus-promo stack.",
            icon: "sparkles",
            0, 10, .entertainment
        ),
        entry(
            "fun-016",
            "exceeds Coachella's gross ticket take for several editions.",
            icon: "music.note.list",
            0, 10, .entertainment
        ),
        entry(
            "fun-017",
            gain: "could buy every Met Gala look ever archived — with spares.",
            loss: "matches the sticker price of every Met Gala look ever archived.",
            icon: "tshirt.fill",
            0, 10, .luxury
        ),
        entry(
            "fun-018",
            gain: "would stock a hangar with a dozen new Gulfstream G650s.",
            loss: "equals the price of a dozen new Gulfstream G650s.",
            gainHighlight: "a dozen",
            lossHighlight: "a dozen",
            icon: "airplane",
            0, 10, .luxury
        ),
        entry(
            "fun-019",
            "outpaces a year of global auction records for modern art.",
            icon: "paintpalette.fill",
            0, 10, .luxury
        ),
        entry(
            "fun-020",
            gain: "could commission a 50-meter superyacht — twice, actually.",
            loss: "matches the build cost of two 50-meter superyachts.",
            gainHighlight: "twice",
            lossHighlight: "two",
            icon: "sailboat.fill",
            0, 10, .luxury
        ),
        entry(
            "fun-021",
            "beats the lifetime box office of a beloved cult franchise trilogy.",
            icon: "film.stack.fill",
            0, 10, .entertainment
        ),
        entry(
            "fun-022",
            "matches every Olympic gold medal bonus paid this century — times ten.",
            highlight: "times ten",
            icon: "medal.fill",
            0, 10, .sports
        ),
        entry(
            "fun-023",
            gain: "could underwrite a theme-park dark-ride buildout from scratch.",
            loss: "equals the capital cost of a full theme-park dark-ride buildout.",
            icon: "ferriswheel",
            0, 10, .entertainment
        ),
        entry(
            "fun-024",
            "exceeds Fashion Week runway budgets for Paris, Milan, and NY combined.",
            icon: "tshirt.fill",
            0, 10, .luxury
        ),
        entry(
            "fun-025",
            "outvalues a viral meme-stock float on a particularly unhinged Tuesday.",
            icon: "chart.line.uptrend.xyaxis",
            0, 10, .entertainment
        ),

        // MARK: Fun batch — $10–$20B
        entry(
            "fun-026",
            "outpaces the payroll of an entire NBA regular season.",
            icon: "basketball.fill",
            10, 20, .sports
        ),
        entry(
            "fun-027",
            "matches the franchise value of a top-10 NFL club — cash only.",
            highlight: "top-10 NFL",
            icon: "sportscourt.fill",
            10, 20, .sports
        ),
        entry(
            "fun-028",
            "beats a full Premier League TV-rights cycle for one broadcaster.",
            icon: "soccerball",
            10, 20, .sports
        ),
        entry(
            "fun-029",
            gain: "could bankroll F1 operations for half the grid — for years.",
            loss: "matches multi-year F1 ops costs for half the grid.",
            gainHighlight: "half the grid",
            lossHighlight: "half the grid",
            icon: "flag.checkered",
            10, 20, .sports
        ),
        entry(
            "fun-030",
            "exceeds the combined salaries of every MLB roster for a season.",
            icon: "baseball.fill",
            10, 20, .sports
        ),
        entry(
            "fun-031",
            "outvalues a mid-market NBA franchise — with the practice facility.",
            icon: "basketball.fill",
            10, 20, .sports
        ),
        entry(
            "fun-032",
            gain: "could fund three Eras-scale stadium tours back to back.",
            loss: "matches the gross of three Eras-scale stadium tours.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "music.mic",
            10, 20, .entertainment
        ),
        entry(
            "fun-033",
            "beats Hollywood's entire mid-budget drama slate for a year.",
            icon: "film.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-034",
            gain: "could produce a prestige streaming universe — full phase one.",
            loss: "matches the budget of a prestige streaming universe's phase one.",
            icon: "play.tv.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-035",
            "matches the lifetime box office of a top animated franchise run.",
            icon: "film.stack.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-036",
            gain: "would cover a next-gen console launch marketing blitz worldwide.",
            loss: "equals a worldwide next-gen console launch marketing blitz.",
            icon: "gamecontroller.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-037",
            "outpaces a decade of Comic-Con global merch peaks.",
            highlight: "a decade",
            icon: "ticket.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-038",
            gain: "could buy every hypercar produced this year — with spares.",
            loss: "matches the sticker price of every hypercar produced this year.",
            icon: "car.fill",
            10, 20, .luxury
        ),
        entry(
            "fun-039",
            gain: "would stock a private fleet of 100 long-range business jets.",
            loss: "equals the price of 100 long-range business jets.",
            gainHighlight: "100",
            lossHighlight: "100",
            icon: "airplane",
            10, 20, .luxury
        ),
        entry(
            "fun-040",
            "beats a decade of record-breaking blue-chip art auctions.",
            highlight: "a decade",
            icon: "paintpalette.fill",
            10, 20, .luxury
        ),
        entry(
            "fun-041",
            gain: "could commission a 100-meter mega-yacht from a top yard.",
            loss: "matches the build cost of a top-yard 100-meter mega-yacht.",
            icon: "sailboat.fill",
            10, 20, .luxury
        ),
        entry(
            "fun-042",
            "exceeds Las Vegas Sphere-scale venue construction — twice over.",
            highlight: "twice over",
            icon: "building.2.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-043",
            "matches a full Olympic Games operations budget for a host city.",
            icon: "medal.fill",
            10, 20, .sports
        ),
        entry(
            "fun-044",
            gain: "could underwrite a Disney-scale park land expansion phase.",
            loss: "equals a Disney-scale park land expansion phase budget.",
            icon: "ferriswheel",
            10, 20, .entertainment
        ),
        entry(
            "fun-045",
            "outvalues the net worth stack of a top-20 celebrity power list.",
            highlight: "top-20",
            icon: "star.fill",
            10, 20, .entertainment
        ),
        entry(
            "fun-046",
            "beats every Super Bowl halftime show production ever — times a thousand.",
            highlight: "a thousand",
            icon: "music.note",
            10, 20, .entertainment
        ),
        entry(
            "fun-047",
            "matches a Champions League rights package across multiple cycles.",
            icon: "soccerball",
            10, 20, .sports
        ),
        entry(
            "fun-048",
            gain: "could bankroll esports world championships for a full decade.",
            loss: "matches a decade of esports world-championship budgets.",
            gainHighlight: "a full decade",
            lossHighlight: "a decade",
            icon: "gamecontroller.fill",
            10, 20, .sports
        ),
        entry(
            "fun-049",
            "exceeds Fashion Month spend for every capital — for years running.",
            icon: "tshirt.fill",
            10, 20, .luxury
        ),
        entry(
            "fun-050",
            "outpaces a viral creator economy's entire ad-revenue year.",
            icon: "iphone",
            10, 20, .entertainment
        ),

        // MARK: Fun batch — $20–$30B
        entry(
            "fun-051",
            "beats the combined franchise values of half the NHL.",
            highlight: "half the NHL",
            icon: "hockey.puck.fill",
            20, 30, .sports
        ),
        entry(
            "fun-052",
            "matches a record global box-office year for Hollywood — almost.",
            icon: "film.fill",
            20, 30, .entertainment
        ),
        entry(
            "fun-053",
            "outpaces every NFL free-agency signing bonus this decade — stacked.",
            highlight: "this decade",
            icon: "sportscourt.fill",
            20, 30, .sports
        ),
        entry(
            "fun-054",
            gain: "could acquire a top European football club — cash on the barrel.",
            loss: "equals the sale price of a top European football club.",
            icon: "soccerball",
            20, 30, .luxury
        ),
        entry(
            "fun-055",
            "exceeds a full FIFA World Cup host infrastructure package.",
            icon: "soccerball",
            20, 30, .sports
        ),
        entry(
            "fun-056",
            gain: "could bankroll Marvel's multi-film phase production stack.",
            loss: "matches Marvel's multi-film phase production budget.",
            icon: "sparkles",
            20, 30, .entertainment
        ),
        entry(
            "fun-057",
            "beats a decade of NBA Finals ad inventory — every tip-off included.",
            highlight: "a decade",
            icon: "basketball.fill",
            20, 30, .sports
        ),
        entry(
            "fun-058",
            "matches the lifetime revenue of a generational open-world franchise.",
            icon: "gamecontroller.fill",
            20, 30, .entertainment
        ),
        entry(
            "fun-059",
            gain: "would fund a universal theme-park resort build in a major metro.",
            loss: "equals the capital cost of a major-metro theme-park resort.",
            icon: "ferriswheel",
            20, 30, .entertainment
        ),
        entry(
            "fun-060",
            "outvalues a mid-tier Hollywood studio's entire content slate year.",
            icon: "film.stack.fill",
            20, 30, .entertainment
        ),
        entry(
            "fun-061",
            gain: "could buy a floating palace fleet of twenty mega-yachts.",
            loss: "matches the asking price of twenty mega-yachts.",
            gainHighlight: "twenty",
            lossHighlight: "twenty",
            icon: "sailboat.fill",
            20, 30, .luxury
        ),
        entry(
            "fun-062",
            "beats every Grammy-night production budget in recorded history.",
            icon: "music.mic",
            20, 30, .entertainment
        ),
        entry(
            "fun-063",
            "matches a top sportsbook platform's peak private valuation.",
            icon: "chart.bar.fill",
            20, 30, .sports
        ),
        entry(
            "fun-064",
            gain: "could underwrite Live Nation's global stadium circuit for years.",
            loss: "matches years of Live Nation global stadium-circuit costs.",
            icon: "music.note.list",
            20, 30, .entertainment
        ),
        entry(
            "fun-065",
            "exceeds a full Olympic Winter Games capital-build envelope.",
            icon: "medal.fill",
            20, 30, .sports
        ),
        entry(
            "fun-066",
            "outpaces the transfer fees of five chaotic Premier League windows.",
            highlight: "five",
            icon: "soccerball",
            20, 30, .sports
        ),
        entry(
            "fun-067",
            gain: "would stock every private-island listing currently on the market.",
            loss: "equals the asking price of every private island currently listed.",
            icon: "leaf.fill",
            20, 30, .luxury
        ),
        entry(
            "fun-068",
            "beats a decade of Super Bowl ticket grosses — nosebleeds included.",
            highlight: "a decade",
            icon: "ticket.fill",
            20, 30, .sports
        ),
        entry(
            "fun-069",
            "matches the cash pile behind a prestige streamer's biggest content year.",
            icon: "play.tv.fill",
            20, 30, .entertainment
        ),
        entry(
            "fun-070",
            gain: "could commission a private art museum's entire acquisition decade.",
            loss: "matches a private art museum's decade of acquisition spend.",
            gainHighlight: "decade",
            lossHighlight: "decade",
            icon: "paintpalette.fill",
            20, 30, .luxury
        ),
        entry(
            "fun-071",
            "outvalues F1's commercial rights for a multi-year cycle.",
            icon: "flag.checkered",
            20, 30, .sports
        ),
        entry(
            "fun-072",
            "exceeds Broadway's total gross across several record seasons.",
            icon: "theatermasks.fill",
            20, 30, .entertainment
        ),
        entry(
            "fun-073",
            gain: "could bankroll a fashion conglomerate's runway empire for years.",
            loss: "matches years of runway-empire spend for a fashion conglomerate.",
            icon: "tshirt.fill",
            20, 30, .luxury
        ),
        entry(
            "fun-074",
            "beats the viral tip-jar economy of the entire creator web — for a while.",
            icon: "iphone",
            20, 30, .entertainment
        ),
        entry(
            "fun-075",
            "matches a top MLB franchise sale price — hot dogs not included.",
            icon: "baseball.fill",
            20, 30, .sports
        ),

        // MARK: Fun batch — $30–$40B
        entry(
            "fun-076",
            "outvalues every Premier League club's match-day revenue for a season.",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "fun-077",
            gain: "could acquire a major Hollywood studio — in cash.",
            loss: "matches the cash sale price of a major Hollywood studio.",
            gainHighlight: "in cash",
            lossHighlight: "cash sale",
            icon: "film.stack.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-078",
            "beats the combined payrolls of the NFL, NBA, and MLB — for a year.",
            highlight: "for a year",
            icon: "sportscourt.fill",
            30, 40, .sports
        ),
        entry(
            "fun-079",
            "matches Fortnite-scale lifetime revenue for a single live-service title.",
            icon: "gamecontroller.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-080",
            gain: "could bankroll a full FIFA World Cup tournament ops stack.",
            loss: "equals a full FIFA World Cup tournament operations budget.",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "fun-081",
            "exceeds Netflix-scale annual content spend — with room for sequels.",
            icon: "play.tv.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-082",
            "outpaces a decade of Champions League final ticket grosses.",
            highlight: "a decade",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "fun-083",
            gain: "would buy every yacht over 80 meters currently for sale.",
            loss: "matches the asking price of every 80m+ yacht currently listed.",
            icon: "sailboat.fill",
            30, 40, .luxury
        ),
        entry(
            "fun-084",
            "beats the GTA franchise's lifetime take — map expansion included.",
            icon: "gamecontroller.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-085",
            "matches a top-five global soccer club valuation package.",
            highlight: "top-five",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "fun-086",
            gain: "could fund Disney Parks global expansion for a multi-year push.",
            loss: "matches a multi-year Disney Parks global expansion budget.",
            icon: "ferriswheel",
            30, 40, .entertainment
        ),
        entry(
            "fun-087",
            "outvalues a Las Vegas Strip mega-resort empire's flagship property.",
            icon: "building.2.fill",
            30, 40, .luxury
        ),
        entry(
            "fun-088",
            "exceeds a full Summer Olympics host-city capital program.",
            icon: "medal.fill",
            30, 40, .sports
        ),
        entry(
            "fun-089",
            gain: "could produce every Best Picture nominee this century — reshoots free.",
            loss: "matches the production cost of every Best Picture nominee this century.",
            icon: "film.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-090",
            "beats a decade of Wimbledon, Roland-Garros, and US Open prize pots.",
            highlight: "a decade",
            icon: "tennisball.fill",
            30, 40, .sports
        ),
        entry(
            "fun-091",
            gain: "would stock a private hangar with 200 intercontinental business jets.",
            loss: "equals the price of 200 intercontinental business jets.",
            gainHighlight: "200",
            lossHighlight: "200",
            icon: "airplane",
            30, 40, .luxury
        ),
        entry(
            "fun-092",
            "matches the market value of a major music-rights catalog conglomerate.",
            icon: "music.note.list",
            30, 40, .entertainment
        ),
        entry(
            "fun-093",
            "outpaces every Met Gala, Oscars after-party, and fashion week — for decades.",
            highlight: "for decades",
            icon: "tshirt.fill",
            30, 40, .luxury
        ),
        entry(
            "fun-094",
            gain: "could bankroll a streaming wars arms race for a full fiscal year.",
            loss: "matches a full fiscal year of streaming-wars content arms race spend.",
            icon: "tv.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-095",
            "beats the franchise values of every MLS club — scarves included.",
            icon: "soccerball",
            30, 40, .sports
        ),
        entry(
            "fun-096",
            "exceeds a decade of global esports sponsorship and prize money.",
            highlight: "a decade",
            icon: "gamecontroller.fill",
            30, 40, .sports
        ),
        entry(
            "fun-097",
            gain: "could underwrite a private art-world auction house's inventory year.",
            loss: "matches a top auction house's full inventory year at hammer price.",
            icon: "paintpalette.fill",
            30, 40, .luxury
        ),
        entry(
            "fun-098",
            "matches a top NFL franchise's enterprise value — luxury suites and all.",
            icon: "sportscourt.fill",
            30, 40, .sports
        ),
        entry(
            "fun-099",
            "outvalues a prestige studio's multi-year franchise slate commitment.",
            icon: "film.stack.fill",
            30, 40, .entertainment
        ),
        entry(
            "fun-100",
            "beats the combined tip of every viral internet fundraiser this decade.",
            highlight: "this decade",
            icon: "heart.fill",
            30, 40, .entertainment
        ),

        // MARK: Fun batch — $40–$50B
        entry(
            "fun-101",
            "beats the total career prize money in tennis history.",
            icon: "tennisball.fill",
            40, 50, .sports
        ),
        entry(
            "fun-102",
            gain: "could buy out every Broadway season's gross — twice.",
            loss: "matches twice every Broadway season's total gross.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "theatermasks.fill",
            40, 50, .entertainment
        ),
        entry(
            "fun-103",
            "outpaces a decade of Super Bowl ad rates at peak inventory.",
            highlight: "a decade",
            icon: "tv.fill",
            40, 50, .sports
        ),
        entry(
            "fun-104",
            "matches Hollywood's annual global theatrical production spend.",
            icon: "film.fill",
            40, 50, .entertainment
        ),
        entry(
            "fun-105",
            gain: "would buy every yacht over 100 meters currently for sale.",
            loss: "equals the asking price of every 100m+ yacht currently listed.",
            icon: "sailboat.fill",
            40, 50, .luxury
        ),
        entry(
            "fun-106",
            "exceeds UEFA multi-year media-rights packages across major markets.",
            icon: "soccerball",
            40, 50, .sports
        ),
        entry(
            "fun-107",
            "beats the MCU's lifetime worldwide box office — with popcorn left over.",
            icon: "sparkles",
            40, 50, .entertainment
        ),
        entry(
            "fun-108",
            gain: "could fund a luxury fashion house conglomerate acquisition.",
            loss: "matches the acquisition price of a luxury fashion conglomerate.",
            icon: "tshirt.fill",
            40, 50, .luxury
        ),
        entry(
            "fun-109",
            "outvalues several top NBA franchises combined — courtside seats free.",
            icon: "basketball.fill",
            40, 50, .sports
        ),
        entry(
            "fun-110",
            "matches a full Olympic movement multi-host cycle budget envelope.",
            icon: "medal.fill",
            40, 50, .sports
        ),
        entry(
            "fun-111",
            gain: "could bankroll every major label's global tour support for years.",
            loss: "matches years of global tour support across every major label.",
            icon: "music.mic",
            40, 50, .entertainment
        ),
        entry(
            "fun-112",
            "exceeds Formula 1's full commercial enterprise valuation band.",
            icon: "flag.checkered",
            40, 50, .sports
        ),
        entry(
            "fun-113",
            gain: "would stock a cruise line with a fleet of floating mega-resorts.",
            loss: "equals the capital cost of a floating mega-resort cruise fleet.",
            icon: "ferry.fill",
            40, 50, .luxury
        ),
        entry(
            "fun-114",
            "beats a decade of global music streaming payout pools.",
            highlight: "a decade",
            icon: "headphones",
            40, 50, .entertainment
        ),
        entry(
            "fun-115",
            "matches the enterprise value of a top-tier sports media network.",
            icon: "tv.fill",
            40, 50, .sports
        ),
        entry(
            "fun-116",
            gain: "could produce every Best Picture winner since the talkies — twice.",
            loss: "matches twice the production cost of every Best Picture winner since talkies.",
            gainHighlight: "twice",
            lossHighlight: "twice",
            icon: "film.stack.fill",
            40, 50, .entertainment
        ),
        entry(
            "fun-117",
            "outpaces a generation of AAA video-game marketing campaigns.",
            icon: "gamecontroller.fill",
            40, 50, .entertainment
        ),
        entry(
            "fun-118",
            gain: "would buy the world's most expensive penthouses — every skyline.",
            loss: "matches the price of the world's most expensive penthouses across skylines.",
            icon: "building.fill",
            40, 50, .luxury
        ),
        entry(
            "fun-119",
            "beats every NFL draft class signing-bonus pool this century.",
            highlight: "this century",
            icon: "sportscourt.fill",
            40, 50, .sports
        ),
        entry(
            "fun-120",
            "exceeds a decade of global theme-park ticket grosses for one operator.",
            highlight: "a decade",
            icon: "ferriswheel",
            40, 50, .entertainment
        ),
        entry(
            "fun-121",
            gain: "could underwrite a private aviation boom of 300 new long-range jets.",
            loss: "equals the price of 300 new long-range private jets.",
            gainHighlight: "300",
            lossHighlight: "300",
            icon: "airplane",
            40, 50, .luxury
        ),
        entry(
            "fun-122",
            "matches a top Hollywood conglomerate's annual free cash flow band.",
            icon: "film.fill",
            40, 50, .entertainment
        ),
        entry(
            "fun-123",
            "outvalues half the Premier League's combined club valuations.",
            highlight: "half the Premier League",
            icon: "soccerball",
            40, 50, .sports
        ),
        entry(
            "fun-124",
            "beats a viral platform's peak IPO-day market-cap daydream.",
            icon: "iphone",
            40, 50, .entertainment
        ),
        entry(
            "fun-125",
            gain: "could bankroll art auctions at Sotheby's scale for a decade.",
            loss: "matches a decade of Sotheby's-scale global art auction volume.",
            gainHighlight: "a decade",
            lossHighlight: "a decade",
            icon: "paintpalette.fill",
            40, 50, .luxury
        ),

        // MARK: Fun batch — $50–$60B
        entry(
            "fun-126",
            "outpaces a decade of Super Bowl ad spend — combined.",
            highlight: "a decade",
            icon: "sportscourt.fill",
            50, 60, .sports
        ),
        entry(
            "fun-127",
            gain: "could acquire three major record labels and still tour.",
            loss: "matches the combined market value of three major record labels.",
            gainHighlight: "three",
            lossHighlight: "three",
            icon: "music.note.list",
            50, 60, .entertainment
        ),
        entry(
            "fun-128",
            "beats the franchise values of several top NFL clubs stacked.",
            icon: "sportscourt.fill",
            50, 60, .sports
        ),
        entry(
            "fun-129",
            "matches a console generation's full software ecosystem revenue band.",
            icon: "gamecontroller.fill",
            50, 60, .entertainment
        ),
        entry(
            "fun-130",
            gain: "would buy the world's ten most expensive homes — with tips.",
            loss: "matches the price of the world's ten most expensive homes — with tips.",
            gainHighlight: "ten",
            lossHighlight: "ten",
            icon: "house.fill",
            50, 60, .luxury
        ),
        entry(
            "fun-131",
            "exceeds multi-cycle FIFA World Cup media-rights packages.",
            icon: "soccerball",
            50, 60, .sports
        ),
        entry(
            "fun-132",
            "outpaces the global recorded-music industry across several peak years.",
            icon: "music.mic",
            50, 60, .entertainment
        ),
        entry(
            "fun-133",
            gain: "could bankroll Hollywood's entire awards-season machinery for decades.",
            loss: "matches decades of Hollywood awards-season machinery spend.",
            gainHighlight: "for decades",
            lossHighlight: "decades",
            icon: "film.fill",
            50, 60, .entertainment
        ),
        entry(
            "fun-134",
            "beats every MLB franchise's combined annual gate receipts for years.",
            icon: "baseball.fill",
            50, 60, .sports
        ),
        entry(
            "fun-135",
            "matches a luxury watch industry multi-decade retail volume band.",
            icon: "watch.analog",
            50, 60, .luxury
        ),
        entry(
            "fun-136",
            gain: "could fund a private space-adjacent sports entertainment complex.",
            loss: "equals the capital stack of a private sports-entertainment mega-complex.",
            icon: "building.2.fill",
            50, 60, .sports
        ),
        entry(
            "fun-137",
            "outvalues a major studio-plus-streaming hybrid content war chest.",
            icon: "play.tv.fill",
            50, 60, .entertainment
        ),
        entry(
            "fun-138",
            gain: "would stock global private aviation with a new midsize jet boom.",
            loss: "matches a global midsize private-jet production boom.",
            icon: "airplane",
            50, 60, .luxury
        ),
        entry(
            "fun-139",
            "exceeds a decade of NBA national media rights at peak rates.",
            highlight: "a decade",
            icon: "basketball.fill",
            50, 60, .sports
        ),
        entry(
            "fun-140",
            "beats the lifetime box office of every Star Wars film — combined.",
            icon: "sparkles",
            50, 60, .entertainment
        ),
        entry(
            "fun-141",
            gain: "could underwrite Fashion Week empires on four continents for years.",
            loss: "matches years of Fashion Week empire costs across four continents.",
            icon: "tshirt.fill",
            50, 60, .luxury
        ),
        entry(
            "fun-142",
            "matches the enterprise value of a top global sportswear giant swing.",
            icon: "figure.run",
            50, 60, .sports
        ),
        entry(
            "fun-143",
            "outpaces a decade of Coachella, Glastonbury, and Tomorrowland grosses.",
            highlight: "a decade",
            icon: "music.note.list",
            50, 60, .entertainment
        ),
        entry(
            "fun-144",
            gain: "could buy a mid-ocean yacht armada fit for a Bond villain.",
            loss: "equals a Bond-villain-scale mid-ocean yacht armada.",
            icon: "sailboat.fill",
            50, 60, .luxury
        ),
        entry(
            "fun-145",
            "beats every Olympic athlete stipend paid since Athens 1896 — times many.",
            icon: "medal.fill",
            50, 60, .sports
        ),
        entry(
            "fun-146",
            "exceeds a prestige game publisher's multi-title pipeline valuation.",
            icon: "gamecontroller.fill",
            50, 60, .entertainment
        ),
        entry(
            "fun-147",
            gain: "could bankroll a viral internet platform's entire creator fund era.",
            loss: "matches an entire creator-fund era for a viral internet platform.",
            icon: "iphone",
            50, 60, .entertainment
        ),
        entry(
            "fun-148",
            "matches several top European football clubs packaged as one deal.",
            icon: "soccerball",
            50, 60, .sports
        ),
        entry(
            "fun-149",
            "outvalues a decade of record blue-chip art-market turnover.",
            highlight: "a decade",
            icon: "paintpalette.fill",
            50, 60, .luxury
        ),
        entry(
            "fun-150",
            "beats a full generation of theme-park capex for a global operator.",
            icon: "ferriswheel",
            50, 60, .entertainment
        ),

        // MARK: Fun batch — $60–$70B
        entry(
            "fun-151",
            "beats the combined transfer fees of a decade of soccer windows.",
            highlight: "a decade",
            icon: "soccerball",
            60, 70, .sports
        ),
        entry(
            "fun-152",
            gain: "could run every major streaming service at a loss for a quarter.",
            loss: "matches a quarter of operating losses across every major streamer.",
            gainHighlight: "a quarter",
            lossHighlight: "a quarter",
            icon: "play.tv.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-153",
            "outpaces Hollywood's worldwide theatrical market for a solid year.",
            icon: "film.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-154",
            "matches a package of top NFL franchises — stadium debt included.",
            icon: "sportscourt.fill",
            60, 70, .sports
        ),
        entry(
            "fun-155",
            gain: "could bankroll the Olympic movement across multiple full cycles.",
            loss: "matches Olympic movement funding across multiple full cycles.",
            icon: "medal.fill",
            60, 70, .sports
        ),
        entry(
            "fun-156",
            "exceeds a mega sports-betting market's multi-year handle economics.",
            icon: "chart.bar.fill",
            60, 70, .sports
        ),
        entry(
            "fun-157",
            gain: "would fund a fleet of 400 private jets — crew training included.",
            loss: "matches the cost of 400 private jets — crew training included.",
            gainHighlight: "400",
            lossHighlight: "400",
            icon: "airplane",
            60, 70, .luxury
        ),
        entry(
            "fun-158",
            "beats a decade of global live-music touring gross at peak years.",
            highlight: "a decade",
            icon: "music.mic",
            60, 70, .entertainment
        ),
        entry(
            "fun-159",
            "outvalues the top half of the Premier League's club market values.",
            highlight: "top half",
            icon: "soccerball",
            60, 70, .sports
        ),
        entry(
            "fun-160",
            gain: "could acquire a major entertainment conglomerate division — cash heavy.",
            loss: "matches the cash sale price of a major entertainment conglomerate division.",
            icon: "film.stack.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-161",
            "matches a luxury mega-yacht industry multi-decade order book.",
            icon: "sailboat.fill",
            60, 70, .luxury
        ),
        entry(
            "fun-162",
            "exceeds a gaming M&A mega-deal of the modern console era.",
            icon: "gamecontroller.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-163",
            "beats every Super Bowl, World Cup final, and Olympics ad stack this century.",
            highlight: "this century",
            icon: "tv.fill",
            60, 70, .sports
        ),
        entry(
            "fun-164",
            gain: "could underwrite Fashion Month on every continent until the sun cools.",
            loss: "matches a near-endless Fashion Month budget across every continent.",
            icon: "tshirt.fill",
            60, 70, .luxury
        ),
        entry(
            "fun-165",
            "outpaces a full MLB franchise-value tranche for half the league.",
            highlight: "half the league",
            icon: "baseball.fill",
            60, 70, .sports
        ),
        entry(
            "fun-166",
            "matches a prestige streamer's multi-year content war chest — twice.",
            highlight: "twice",
            icon: "play.tv.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-167",
            gain: "would buy every private island and then build a helipad on each.",
            loss: "equals every private-island asking price plus a helipad on each.",
            icon: "leaf.fill",
            60, 70, .luxury
        ),
        entry(
            "fun-168",
            "beats a decade of F1 team budgets for the entire grid.",
            highlight: "a decade",
            icon: "flag.checkered",
            60, 70, .sports
        ),
        entry(
            "fun-169",
            "exceeds Broadway, West End, and global touring theatre for many seasons.",
            icon: "theatermasks.fill",
            60, 70, .entertainment
        ),
        entry(
            "fun-170",
            gain: "could bankroll a Marvel-scale cinematic universe from pitch to phase five.",
            loss: "matches a Marvel-scale cinematic universe budget through phase five.",
            icon: "sparkles",
            60, 70, .entertainment
        ),
        entry(
            "fun-171",
            "outvalues a top global sports media rights cycle — every league included.",
            icon: "sportscourt.fill",
            60, 70, .sports
        ),
        entry(
            "fun-172",
            "matches the capital behind a world-class theme-park destination build.",
            icon: "ferriswheel",
            60, 70, .entertainment
        ),
        entry(
            "fun-173",
            gain: "could stock a private museum with every record auction lot this century.",
            loss: "equals every record auction lot this century at hammer price.",
            gainHighlight: "this century",
            lossHighlight: "this century",
            icon: "paintpalette.fill",
            60, 70, .luxury
        ),
        entry(
            "fun-174",
            "beats the viral creator economy's ad-revenue peak across major platforms.",
            icon: "iphone",
            60, 70, .entertainment
        ),
        entry(
            "fun-175",
            "exceeds a package of top NBA franchises — championship banners included.",
            icon: "basketball.fill",
            60, 70, .sports
        ),

        // MARK: Fun batch — $70B+
        entry(
            "fun-176",
            gain: "could buy the entire video game industry's annual revenue.",
            loss: "matches the entire video game industry's annual revenue.",
            icon: "gamecontroller.fill",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-177",
            gain: "would fund a fleet of 500 private jets — crew included.",
            loss: "matches the cost of 500 private jets — crew included.",
            gainHighlight: "500",
            lossHighlight: "500",
            icon: "airplane",
            70, 1_000, .luxury
        ),
        entry(
            "fun-178",
            "outvalues the GDP of a nation that could field an Olympic team.",
            icon: "medal.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-179",
            "beats the combined franchise values of the entire NHL — twice.",
            highlight: "twice",
            icon: "hockey.puck.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-180",
            gain: "could acquire a mega-studio entertainment empire — cash talks.",
            loss: "matches the cash sale price of a mega-studio entertainment empire.",
            icon: "film.stack.fill",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-181",
            "matches a hefty slice of total NFL franchise enterprise value.",
            icon: "sportscourt.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-182",
            "exceeds several years of global box-office revenue at peak.",
            highlight: "several years",
            icon: "film.fill",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-183",
            gain: "would buy every mega-yacht afloat and still need a bigger marina.",
            loss: "equals the replacement cost of every mega-yacht currently afloat.",
            icon: "sailboat.fill",
            70, 1_000, .luxury
        ),
        entry(
            "fun-184",
            "outpaces a decade of Premier League, La Liga, and Serie A TV rights.",
            highlight: "a decade",
            icon: "soccerball",
            70, 1_000, .sports
        ),
        entry(
            "fun-185",
            gain: "could bankroll live music's global touring economy for years.",
            loss: "matches years of global live-music touring economy revenue.",
            icon: "music.mic",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-186",
            "beats the lifetime box office of the MCU, Star Wars, and Harry Potter — stacked.",
            icon: "sparkles",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-187",
            "matches a package deal for half the NBA's franchise values.",
            highlight: "half the NBA",
            icon: "basketball.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-188",
            gain: "could fund theme parks on every continent — with monorails.",
            loss: "equals a multi-continent theme-park buildout with monorails.",
            icon: "ferriswheel",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-189",
            "exceeds a generation of luxury fashion conglomerate acquisition waves.",
            icon: "tshirt.fill",
            70, 1_000, .luxury
        ),
        entry(
            "fun-190",
            "outvalues FIFA and UEFA commercial engines across multiple cycles.",
            icon: "soccerball",
            70, 1_000, .sports
        ),
        entry(
            "fun-191",
            gain: "could underwrite Broadway forever — and still fly the cast first class.",
            loss: "matches a perpetual Broadway capitalization endowment.",
            icon: "theatermasks.fill",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-192",
            "beats a decade of global sports media rights across major leagues.",
            highlight: "a decade",
            icon: "tv.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-193",
            gain: "would stock private aviation with a thousand new long-range jets.",
            loss: "equals the price of a thousand new long-range private jets.",
            gainHighlight: "a thousand",
            lossHighlight: "a thousand",
            icon: "airplane",
            70, 1_000, .luxury
        ),
        entry(
            "fun-194",
            "matches the capital behind multiple AAA gaming publisher mega-mergers.",
            icon: "gamecontroller.fill",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-195",
            "outpaces the combined enterprise value of every MLS and NWSL club — forever.",
            icon: "soccerball",
            70, 1_000, .sports
        ),
        entry(
            "fun-196",
            gain: "could buy every record auction masterpiece this century — and the walls.",
            loss: "equals every record auction masterpiece this century at hammer price.",
            gainHighlight: "this century",
            lossHighlight: "this century",
            icon: "paintpalette.fill",
            70, 1_000, .luxury
        ),
        entry(
            "fun-197",
            "beats the viral internet's entire ad-tech tip jar for a generational run.",
            icon: "iphone",
            70, 1_000, .entertainment
        ),
        entry(
            "fun-198",
            "exceeds a full MLB-plus-NBA franchise value tranche at once.",
            icon: "sportscourt.fill",
            70, 1_000, .sports
        ),
        entry(
            "fun-199",
            gain: "could bankroll a Bond-villain island nation with stadiums and a spa.",
            loss: "matches a Bond-villain island nation buildout with stadiums and a spa.",
            icon: "building.2.fill",
            70, 1_000, .luxury
        ),
        entry(
            "fun-200",
            "outvalues a small G20 entertainment-and-sports economy for a year.",
            highlight: "a year",
            icon: "globe.americas.fill",
            70, 1_000, .entertainment
        ),
    ]

    static func candidates(forMagnitude magnitude: Double) -> [ComparisonLibraryEntry] {
        entries.filter { $0.matchesMagnitude(magnitude) }
    }

    /// Polarity-safe body shared by gain and loss (equals / matches / exceeds / size metaphors).
    private static func entry(
        _ id: String,
        _ text: String,
        highlight: String? = nil,
        icon systemImage: String,
        _ minBillions: Double,
        _ maxBillions: Double,
        _ category: ComparisonCategory
    ) -> ComparisonLibraryEntry {
        ComparisonLibraryEntry(
            id: id,
            gainText: text,
            lossText: text,
            gainHighlight: highlight,
            lossHighlight: highlight,
            systemImage: systemImage,
            minMagnitude: minBillions * 1_000_000_000,
            maxMagnitude: maxBillions * 1_000_000_000,
            category: category
        )
    }

    /// Separate gain (spend/fund) and loss (size/equivalence) bodies.
    private static func entry(
        _ id: String,
        gain gainText: String,
        loss lossText: String,
        gainHighlight: String? = nil,
        lossHighlight: String? = nil,
        icon systemImage: String,
        _ minBillions: Double,
        _ maxBillions: Double,
        _ category: ComparisonCategory
    ) -> ComparisonLibraryEntry {
        ComparisonLibraryEntry(
            id: id,
            gainText: gainText,
            lossText: lossText,
            gainHighlight: gainHighlight,
            lossHighlight: lossHighlight,
            systemImage: systemImage,
            minMagnitude: minBillions * 1_000_000_000,
            maxMagnitude: maxBillions * 1_000_000_000,
            category: category
        )
    }
}
