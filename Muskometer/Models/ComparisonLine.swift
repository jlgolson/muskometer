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
    let text: String
    let highlight: String?
    let systemImage: String
    let minMagnitude: Double
    let maxMagnitude: Double
    let category: ComparisonCategory

    func line(forGain gain: Double) -> ComparisonLine {
        let prefix: String
        if gain > 0 {
            prefix = "Today's gain "
        } else if gain < 0 {
            prefix = "Today's loss "
        } else {
            prefix = "Today's move "
        }

        return ComparisonLine(
            text: prefix + text,
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
        // $0–$10B
        entry("econ-01", "equals the GDP of Iceland — for today.", nil, "globe.europe.africa.fill", 0, 10, .economics),
        entry("econ-02", "could pay every US teacher's salary for a week.", "a week", "person.3.fill", 0, 10, .economics),
        entry("econ-03", "matches the annual budget of the National Science Foundation.", nil, "building.columns.fill", 0, 10, .economics),
        entry("space-01", "could fuel a Falcon 9 launch cadence for a month.", "a month", "airplane.departure", 0, 10, .space),
        entry("space-02", "would cover a Dragon crew mission end to end.", nil, "sparkles", 0, 10, .space),
        entry("sports-01", "beats the lifetime earnings of 200 Hall of Fame athletes.", "200", "sportscourt.fill", 0, 10, .economics),
        entry("ent-01", "could bankroll a summer blockbuster marketing blitz.", nil, "film.fill", 0, 10, .entertainment),
        entry("gov-01", "exceeds the annual operating budget of a mid-size US city.", nil, "building.2.fill", 0, 10, .government),
        entry("infra-01", "could repave 1,000 lane-miles of interstate.", "1,000", "road.lanes", 0, 10, .infrastructure),
        entry("tech-01", "is more than many unicorn startups raise in a Series C.", nil, "cpu.fill", 0, 10, .technology),

        // $10–$20B
        entry("econ-10", "equals roughly 55,000 median US household incomes.", "55,000", "person.3.fill", 10, 20, .economics),
        entry("econ-11", "could wipe out the student debt of 400,000 borrowers.", "400,000", "graduationcap.fill", 10, 20, .economics),
        entry("econ-12", "matches a year of net profit for a Fortune 50 retailer.", nil, "cart.fill", 10, 20, .economics),
        entry("space-10", "could fund a Starship test campaign and still have change.", nil, "airplane.departure", 10, 20, .space),
        entry("space-11", "would pay for dozens of Starlink constellation launches.", "dozens", "antenna.radiowaves.left.and.right", 10, 20, .space),
        entry("sports-10", "outpaces the payroll of an entire major sports league season.", nil, "sportscourt.fill", 10, 20, .sports),
        entry("ent-10", "could produce three prestige streaming series at once.", "three", "tv.fill", 10, 20, .entertainment),
        entry("gov-10", "exceeds NASA's planetary science budget for a year.", nil, "building.columns.fill", 10, 20, .government),
        entry("infra-10", "could modernize power grids in a mid-sized state.", nil, "bolt.fill", 10, 20, .infrastructure),
        entry("lux-10", "would buy every hypercar produced this year — twice.", "twice", "car.fill", 10, 20, .luxury),

        // $20–$30B
        entry("econ-20", "equals the market cap swing of a top-20 S&P company.", nil, "chart.line.uptrend.xyaxis", 20, 30, .economics),
        entry("econ-21", "could fund universal pre-K in a large state for a decade.", "a decade", "figure.and.child.holdinghands", 20, 30, .economics),
        entry("space-20", "could launch a lunar lander program's first phase.", nil, "moon.fill", 20, 30, .space),
        entry("space-21", "would cover a year's worth of heavy-lift manifest bookings.", nil, "airplane.departure", 20, 30, .space),
        entry("sports-20", "beats the combined franchise values of half the NHL.", "half the NHL", "hockey.puck.fill", 20, 30, .sports),
        entry("ent-20", "could bankroll the biggest box-office year in cinema history.", nil, "film.fill", 20, 30, .entertainment),
        entry("gov-20", "exceeds the annual foreign aid outlay of a G7 nation.", nil, "globe.americas.fill", 20, 30, .government),
        entry("infra-20", "could build two brand-new international airports.", "two", "airplane", 20, 30, .infrastructure),
        entry("tech-20", "is larger than the cash pile many cloud giants keep on hand.", nil, "cloud.fill", 20, 30, .technology),
        entry("phil-20", "could vaccinate the world's under-5 population twice over.", "twice over", "cross.case.fill", 20, 30, .philanthropy),

        // $30–$40B
        entry("econ-30", "equals the annual economic output of Bolivia.", nil, "globe.americas.fill", 30, 40, .economics),
        entry("econ-31", "could pay off the external debt of a small nation.", nil, "banknote.fill", 30, 40, .economics),
        entry("space-30", "could seed a Mars cargo precursor mission pipeline.", nil, "moon.stars.fill", 30, 40, .space),
        entry("space-31", "would fund Starbase expansion for several years.", "several years", "building.fill", 30, 40, .space),
        entry("sports-30", "outvalues every Premier League club's match-day revenue for a season.", nil, "soccerball", 30, 40, .sports),
        entry("ent-30", "could acquire a major Hollywood studio — in cash.", "in cash", "film.stack.fill", 30, 40, .entertainment),
        entry("gov-30", "exceeds the US annual budget for national parks.", nil, "tree.fill", 30, 40, .government),
        entry("infra-30", "could lay high-speed rail between two major US metros.", nil, "tram.fill", 30, 40, .infrastructure),
        entry("lux-30", "would buy every private island listed this decade.", nil, "sailboat.fill", 30, 40, .luxury),
        entry("nat-30", "could restore 3 million acres of wildfire-scarred forest.", "3 million acres", "leaf.fill", 30, 40, .nature),

        // $40–$50B
        entry("econ-40", "equals the GDP of Luxembourg — in a single session.", "a single session", "globe.europe.africa.fill", 40, 50, .economics),
        entry("econ-41", "could fund the US National Institutes of Health for a year.", "a year", "cross.case.fill", 40, 50, .economics),
        entry("space-40", "could underwrite a constellation of deep-space relay satellites.", nil, "antenna.radiowaves.left.and.right", 40, 50, .space),
        entry("space-41", "would pay for a decade of booster reuse R&D at full throttle.", "a decade", "wrench.and.screwdriver.fill", 40, 50, .space),
        entry("sports-40", "beats the total career prize money in tennis history.", nil, "tennisball.fill", 40, 50, .sports),
        entry("ent-40", "could buy out every Broadway season's gross — twice.", "twice", "theatermasks.fill", 40, 50, .entertainment),
        entry("gov-40", "exceeds the annual defense procurement of Canada.", nil, "shield.fill", 40, 50, .government),
        entry("infra-40", "could bury fiber to every home in a large state.", nil, "cable.connector", 40, 50, .infrastructure),
        entry("tech-40", "is bigger than the IPO proceeds of a generational tech listing.", nil, "chart.bar.fill", 40, 50, .technology),
        entry("phil-40", "could end extreme water insecurity for 50 million people.", "50 million", "drop.fill", 40, 50, .philanthropy),

        // $50–$60B
        entry("econ-50", "equals the market value of a top-10 global automaker swing.", nil, "car.fill", 50, 60, .economics),
        entry("econ-51", "could zero out credit-card balances for 40 million households.", "40 million", "creditcard.fill", 50, 60, .economics),
        entry("space-50", "could fund an Artemis-scale hardware push on its own.", "Artemis-scale", "moon.fill", 50, 60, .space),
        entry("space-51", "would cover the capital cost of a private space station fleet.", nil, "sparkles", 50, 60, .space),
        entry("sports-50", "outpaces a decade of Super Bowl ad spend — combined.", "a decade", "sportscourt.fill", 50, 60, .sports),
        entry("ent-50", "could acquire three major record labels and still tour.", "three", "music.note.list", 50, 60, .entertainment),
        entry("gov-50", "exceeds the annual budget of the European Space Agency.", nil, "building.columns.fill", 50, 60, .government),
        entry("infra-50", "could rebuild every bridge on the interstate top-10 list.", nil, "road.lanes.curved.left", 50, 60, .infrastructure),
        entry("lux-50", "would buy the world's ten most expensive homes — with tips.", "ten", "house.fill", 50, 60, .luxury),
        entry("nat-50", "could fund coastal resilience for the entire Gulf Coast.", nil, "water.waves", 50, 60, .nature),

        // $60–$70B
        entry("econ-60", "equals the annual federal R&D tax credit pool — in one day.", "one day", "lightbulb.fill", 60, 70, .economics),
        entry("econ-61", "could pay a $1,000 bonus to every US taxpayer.", "every US taxpayer", "person.3.fill", 60, 70, .economics),
        entry("space-60", "could bankroll a Mars surface logistics demo at scale.", nil, "moon.stars.fill", 60, 70, .space),
        entry("space-61", "would fund Starlink Gen3 deployment for a full orbital shell.", nil, "antenna.radiowaves.left.and.right", 60, 70, .space),
        entry("sports-60", "beats the combined transfer fees of a decade of soccer windows.", "a decade", "soccerball", 60, 70, .sports),
        entry("ent-60", "could run every major streaming service at a loss for a quarter.", "a quarter", "play.tv.fill", 60, 70, .entertainment),
        entry("gov-60", "exceeds the US annual spend on renewable energy credits.", nil, "sun.max.fill", 60, 70, .government),
        entry("infra-60", "could modernize every major US port's container cranes.", nil, "shippingbox.fill", 60, 70, .infrastructure),
        entry("tech-60", "is larger than the cash component of the biggest tech merger ever.", nil, "arrow.triangle.merge", 60, 70, .technology),
        entry("phil-60", "could erase malaria program funding gaps for 15 years.", "15 years", "cross.case.fill", 60, 70, .philanthropy),

        // $70B+
        entry("econ-70", "equals the GDP of Kenya — before lunch.", "before lunch", "globe.africa.fill", 70, 1_000, .economics),
        entry("econ-71", "could fund the Apollo program — adjusted for vibes.", "Apollo program", "clock.fill", 70, 1_000, .economics),
        entry("space-70", "could seed a self-sustaining lunar industrial base.", nil, "moon.fill", 70, 1_000, .space),
        entry("space-71", "would pay for a Starship production line's first full year.", "first full year", "gearshape.2.fill", 70, 1_000, .space),
        entry("sports-70", "outvalues the GDP of a nation that could field an Olympic team.", nil, "medal.fill", 70, 1_000, .sports),
        entry("ent-70", "could buy the entire video game industry's annual revenue.", nil, "gamecontroller.fill", 70, 1_000, .entertainment),
        entry("gov-70", "exceeds the World Bank's annual climate finance commitments.", nil, "globe.americas.fill", 70, 1_000, .government),
        entry("infra-70", "could tunnel high-speed rail under the Appalachian chain.", nil, "tram.fill", 70, 1_000, .infrastructure),
        entry("lux-70", "would fund a fleet of 500 private jets — crew included.", "500", "airplane", 70, 1_000, .luxury),
        entry("nat-70", "could reforest an area the size of West Virginia.", "West Virginia", "tree.fill", 70, 1_000, .nature)
    ]

    static func candidates(forMagnitude magnitude: Double) -> [ComparisonLibraryEntry] {
        entries.filter { $0.matchesMagnitude(magnitude) }
    }

    private static func entry(
        _ id: String,
        _ text: String,
        _ highlight: String?,
        _ systemImage: String,
        _ minBillions: Double,
        _ maxBillions: Double,
        _ category: ComparisonCategory
    ) -> ComparisonLibraryEntry {
        ComparisonLibraryEntry(
            id: id,
            text: text,
            highlight: highlight,
            systemImage: systemImage,
            minMagnitude: minBillions * 1_000_000_000,
            maxMagnitude: maxBillions * 1_000_000_000,
            category: category
        )
    }
}