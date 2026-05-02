import Foundation

/// Generates geography questions from `CountryData` plus a curated pool of
/// landmarks/rivers/mountains. For each country in the level we derive
/// four question types (capital, capital→country, continent, flag) so a
/// 12-country level expands to 48+ programmatic questions, and adding
/// any handcrafted "specials" pushes well past the 50-per-level target.
enum GeographyProblemGenerator {

    /// Set of `correct` answers already served in the current round (#64).
    /// Spans levels — once you've seen a question, it doesn't reappear in
    /// the round even after leveling up. Cleared via `resetRoundHistory()`.
    private static var seenCorrects: Set<String> = []

    static func resetRoundHistory() {
        seenCorrects.removeAll()
    }

    static func generate(level: Int = 1) -> GeographyProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        var candidates = pool.filter { !seenCorrects.contains($0.correct + ":" + $0.prompt) }
        if candidates.isEmpty {
            seenCorrects.subtract(pool.map { $0.correct + ":" + $0.prompt })
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        seenCorrects.insert(raw.correct + ":" + raw.prompt)
        return GeographyProblem(
            prompt: raw.prompt,
            flag: raw.flag,
            correctAnswer: raw.correct,
            options: ([raw.correct] + raw.distractors).shuffled()
        )
    }

    static func curriculumLabel(forLevel level: Int) -> String {
        let l = max(1, min(20, level))
        if l <= 10 {
            return String(format: String(localized: "curriculum_grade_format"), l)
        } else if l <= 13 {
            return String(format: String(localized: "curriculum_vgs_format"), l - 10)
        } else {
            return String(format: String(localized: "curriculum_university_format"), l - 13)
        }
    }

    struct Raw {
        let prompt: String
        var flag: String? = nil
        let correct: String
        let distractors: [String]
    }

    /// Compose the level pool from programmatic country questions +
    /// handcrafted specials (landmarks, rivers, etc.).
    private static func pool(forLevel level: Int) -> [Raw] {
        let countries = CountryData.countries(forLevel: level)
        var pool: [Raw] = []
        for country in countries {
            pool.append(contentsOf: questions(for: country, allInLevel: countries))
        }
        pool.append(contentsOf: specials(forLevel: level))
        return pool
    }

    /// Four programmatic question types per country: capital lookup,
    /// reverse capital lookup, continent, and flag. With 12+ countries
    /// per level this alone yields 48+ questions.
    private static func questions(for c: Country, allInLevel: [Country]) -> [Raw] {
        let regionalPool = (allInLevel + CountryData.allCountries)
        let otherCapitals = regionalPool
            .filter { $0.capital != c.capital }
            .map(\.capital)
        let otherCountries = regionalPool
            .filter { $0.name != c.name }
            .map(\.name)
        let continents = ["Europa", "Asia", "Afrika", "Nord-Amerika", "Sør-Amerika", "Oseania"]
            .filter { $0 != c.continent }

        return [
            Raw(prompt: "Hovedstaden i \(c.name)?",
                correct: c.capital,
                distractors: pickDistractors(from: otherCapitals, count: 3)),
            Raw(prompt: "I hvilket land ligger \(c.capital)?",
                correct: c.name,
                distractors: pickDistractors(from: otherCountries, count: 3)),
            Raw(prompt: "Hvilken kontinent ligger \(c.name) i?",
                correct: c.continent,
                distractors: pickDistractors(from: continents, count: 3)),
            Raw(prompt: "Hvilket land har dette flagget?",
                flag: regionalIndicator(for: c.iso),
                correct: c.name,
                distractors: pickDistractors(from: otherCountries, count: 3))
        ]
    }

    /// Random unique distractors from the candidate pool. If the pool is
    /// too small we fall back to whatever fits (still unique).
    private static func pickDistractors(from candidates: [String], count: Int) -> [String] {
        let unique = Array(Set(candidates))
        return Array(unique.shuffled().prefix(count))
    }

    /// Convert ISO 3166 alpha-2 (e.g. "no") to a regional-indicator
    /// emoji pair (e.g. "🇳🇴"). FlagView parses this back into the same
    /// ISO code to load the PNG, so the round-trip is intentional —
    /// the emoji is purely a string carrier here.
    private static func regionalIndicator(for iso: String) -> String {
        let upper = iso.uppercased()
        var result = ""
        for char in upper {
            guard let ascii = char.asciiValue else { continue }
            let scalarValue = 0x1F1E6 + UInt32(ascii) - UInt32(Character("A").asciiValue!)
            if let scalar = UnicodeScalar(scalarValue) {
                result.append(Character(scalar))
            }
        }
        return result
    }

    /// Handcrafted level-specific extras (landmarks, rivers, mountains,
    /// trivia). Padding so the pool comfortably exceeds 50 questions.
    private static func specials(forLevel level: Int) -> [Raw] {
        switch level {
        case 1:
            return [
                Raw(prompt: "Hvilken kontinent er Norden en del av?", correct: "Europa",
                    distractors: ["Asia", "Afrika", "Nord-Amerika"]),
                Raw(prompt: "Norges nordligste fastlandsby?", correct: "Hammerfest",
                    distractors: ["Tromsø", "Bodø", "Alta"]),
                Raw(prompt: "Norges lengste fjord?", correct: "Sognefjorden",
                    distractors: ["Hardangerfjorden", "Geirangerfjorden", "Trondheimsfjorden"]),
                Raw(prompt: "Hva heter Norges nasjonalfjell?", correct: "Stetind",
                    distractors: ["Galdhøpiggen", "Romsdalshorn", "Trolltindane"]),
                Raw(prompt: "Hvilket hav ligger vest for Norge?", correct: "Norskehavet",
                    distractors: ["Nordsjøen", "Østersjøen", "Barentshavet"])
            ]
        case 2:
            return [
                Raw(prompt: "Hvilken elv renner gjennom Paris?", correct: "Seinen",
                    distractors: ["Loire", "Rhône", "Themsen"]),
                Raw(prompt: "Hvilken elv renner gjennom London?", correct: "Themsen",
                    distractors: ["Severn", "Mersey", "Seinen"]),
                Raw(prompt: "Hvor ligger Eiffeltårnet?", correct: "Paris",
                    distractors: ["Roma", "London", "Madrid"]),
                Raw(prompt: "Hvor ligger Big Ben?", correct: "London",
                    distractors: ["Edinburgh", "Dublin", "Cardiff"]),
                Raw(prompt: "Hvor ligger Colosseum?", correct: "Roma",
                    distractors: ["Athen", "Madrid", "Firenze"])
            ]
        case 3:
            return [
                Raw(prompt: "Hvilken elv renner gjennom Wien?", correct: "Donau",
                    distractors: ["Rhinen", "Elben", "Inn"]),
                Raw(prompt: "Hvilken elv renner gjennom Budapest?", correct: "Donau",
                    distractors: ["Tisza", "Drava", "Sava"]),
                Raw(prompt: "Hvilken elv renner gjennom Praha?", correct: "Vltava",
                    distractors: ["Donau", "Elben", "Oder"]),
                Raw(prompt: "Hvor ligger Akropolis?", correct: "Athen",
                    distractors: ["Roma", "Istanbul", "Sparta"]),
                Raw(prompt: "Hvor ligger Sagrada Família?", correct: "Barcelona",
                    distractors: ["Madrid", "Valencia", "Sevilla"])
            ]
        case 4:
            return [
                Raw(prompt: "Hvor ligger Frihetsgudinnen?", correct: "New York",
                    distractors: ["Washington D.C.", "Boston", "Chicago"]),
                Raw(prompt: "Hvor ligger Golden Gate Bridge?", correct: "San Francisco",
                    distractors: ["New York", "Seattle", "Los Angeles"]),
                Raw(prompt: "Hvor ligger Mount Rushmore?", correct: "South Dakota",
                    distractors: ["Wyoming", "Montana", "Colorado"]),
                Raw(prompt: "Hvor ligger Niagarafallene?", correct: "Mellom USA og Canada",
                    distractors: ["I USA", "I Canada", "Mellom USA og Mexico"]),
                Raw(prompt: "Hvor ligger Grand Canyon?", correct: "Arizona",
                    distractors: ["Utah", "Nevada", "New Mexico"])
            ]
        case 5:
            return [
                Raw(prompt: "Hvor ligger Machu Picchu?", correct: "Peru",
                    distractors: ["Bolivia", "Ecuador", "Chile"]),
                Raw(prompt: "Hvor står Christ the Redeemer?", correct: "Rio de Janeiro",
                    distractors: ["São Paulo", "Buenos Aires", "Lima"]),
                Raw(prompt: "Hvor ligger Iguazú-fossene?", correct: "Mellom Argentina og Brasil",
                    distractors: ["Mellom Peru og Brasil", "Mellom Bolivia og Argentina", "Mellom Chile og Argentina"]),
                Raw(prompt: "Hvilken elv er lengst i Sør-Amerika?", correct: "Amazonas",
                    distractors: ["Paraná", "Orinoco", "São Francisco"]),
                Raw(prompt: "Hvor ligger Atacama-ørkenen?", correct: "Chile",
                    distractors: ["Peru", "Argentina", "Bolivia"])
            ]
        case 6:
            return [
                Raw(prompt: "Hvor ligger Den kinesiske mur?", correct: "Kina",
                    distractors: ["Japan", "Mongolia", "Korea"]),
                Raw(prompt: "Hvor ligger Forbidden City?", correct: "Beijing",
                    distractors: ["Xi'an", "Nanjing", "Shanghai"]),
                Raw(prompt: "Hvor ligger Mount Fuji?", correct: "Japan",
                    distractors: ["Sør-Korea", "Kina", "Filippinene"]),
                Raw(prompt: "Hvor ligger Petronas-tårnene?", correct: "Kuala Lumpur",
                    distractors: ["Singapore", "Bangkok", "Manila"]),
                Raw(prompt: "Hvor ligger Marina Bay Sands?", correct: "Singapore",
                    distractors: ["Hong Kong", "Kuala Lumpur", "Bangkok"]),
                Raw(prompt: "Hvor ligger Angkor Wat?", correct: "Kambodsja",
                    distractors: ["Thailand", "Vietnam", "Laos"])
            ]
        case 7:
            return [
                Raw(prompt: "Hvor ligger Taj Mahal?", correct: "India",
                    distractors: ["Pakistan", "Bangladesh", "Iran"]),
                Raw(prompt: "Hvor ligger Mount Everest (på grensen mellom)?", correct: "Nepal og Kina",
                    distractors: ["Nepal og India", "India og Kina", "Bhutan og Kina"]),
                Raw(prompt: "Hvor ligger K2?", correct: "Pakistan",
                    distractors: ["India", "Nepal", "Kina"]),
                Raw(prompt: "Hvilken elv renner gjennom Bagdad?", correct: "Tigris",
                    distractors: ["Eufrat", "Jordan", "Karun"]),
                Raw(prompt: "Hvilken elv munner ut i Det kaspiske hav?", correct: "Volga",
                    distractors: ["Ural", "Don", "Dnepr"])
            ]
        case 8:
            return [
                Raw(prompt: "Hvor ligger Petra?", correct: "Jordan",
                    distractors: ["Egypt", "Israel", "Saudi-Arabia"]),
                Raw(prompt: "Hvor ligger Burj Khalifa?", correct: "Dubai",
                    distractors: ["Abu Dhabi", "Riyadh", "Doha"]),
                Raw(prompt: "Hvor står Sheikh Zayed-moskeen?", correct: "Abu Dhabi",
                    distractors: ["Dubai", "Doha", "Muscat"]),
                Raw(prompt: "Hvor står Hagia Sophia?", correct: "Istanbul",
                    distractors: ["Athen", "Jerusalem", "Roma"]),
                Raw(prompt: "Hvor ligger Den arabiske halvøy?", correct: "Sørvest-Asia",
                    distractors: ["Nordøst-Afrika", "Sentral-Asia", "Sør-Asia"])
            ]
        case 9:
            return [
                Raw(prompt: "Hvor ligger Pyramidene i Giza?", correct: "Egypt",
                    distractors: ["Sudan", "Libya", "Saudi-Arabia"]),
                Raw(prompt: "Verdens lengste elv?", correct: "Nilen",
                    distractors: ["Amazonas", "Yangtze", "Mississippi"]),
                Raw(prompt: "Hvilken elv renner gjennom Kairo og Khartoum?", correct: "Nilen",
                    distractors: ["Kongo", "Niger", "Zambezi"]),
                Raw(prompt: "Hvor ligger Sahara-ørkenen?", correct: "Nord-Afrika",
                    distractors: ["Sør-Afrika", "Øst-Afrika", "Sentral-Afrika"]),
                Raw(prompt: "Hvor ligger Atlasfjellene?", correct: "Nordvest-Afrika",
                    distractors: ["Sør-Afrika", "Øst-Afrika", "Sahara"])
            ]
        case 10:
            return [
                Raw(prompt: "Hvilken elv er Afrikas nest lengste?", correct: "Kongo",
                    distractors: ["Niger", "Zambezi", "Limpopo"]),
                Raw(prompt: "Hvor ligger Timbuktu?", correct: "Mali",
                    distractors: ["Niger", "Mauritania", "Burkina Faso"]),
                Raw(prompt: "Hvor ligger Sahel-regionen?", correct: "Sør for Sahara",
                    distractors: ["Nord for Sahara", "Øst-Afrika", "Sør-Afrika"]),
                Raw(prompt: "Hvilket land har lengst kystlinje i Vest-Afrika?", correct: "Nigeria",
                    distractors: ["Ghana", "Senegal", "Liberia"]),
                Raw(prompt: "Hvilken elv renner gjennom Mali?", correct: "Niger",
                    distractors: ["Senegal", "Volta", "Kongo"])
            ]
        case 11:
            return [
                Raw(prompt: "Hvor ligger Kilimanjaro?", correct: "Tanzania",
                    distractors: ["Kenya", "Uganda", "Etiopia"]),
                Raw(prompt: "Hvor er kilden til Nilen?", correct: "Victoriasjøen",
                    distractors: ["Tanganyikasjøen", "Tana-sjøen", "Albertsjøen"]),
                Raw(prompt: "Verdens dypeste innsjø?", correct: "Bajkalsjøen",
                    distractors: ["Tanganyikasjøen", "Kaspihavet", "Lake Superior"]),
                Raw(prompt: "Hvor ligger Serengeti?", correct: "Tanzania",
                    distractors: ["Kenya", "Uganda", "Sør-Afrika"]),
                Raw(prompt: "Hvor renner elva Limpopo?", correct: "Sør-Afrika",
                    distractors: ["Tanzania", "Angola", "Namibia"])
            ]
        case 12:
            return [
                Raw(prompt: "Hvor ligger Victoria-fossene?", correct: "Mellom Zambia og Zimbabwe",
                    distractors: ["Mellom Kenya og Tanzania", "Mellom Sør-Afrika og Mosambik", "Mellom Botswana og Namibia"]),
                Raw(prompt: "Hvilken stat er omsluttet av Sør-Afrika?", correct: "Lesotho",
                    distractors: ["Eswatini", "Botswana", "Zimbabwe"]),
                Raw(prompt: "Hvor ligger Kalahariørkenen?", correct: "Sørlige Afrika",
                    distractors: ["Nord-Afrika", "Øst-Afrika", "Vest-Afrika"]),
                Raw(prompt: "Hvor ligger Kapp det gode håp?", correct: "Sør-Afrika",
                    distractors: ["Namibia", "Mosambik", "Angola"]),
                Raw(prompt: "Hvilken elv danner grensen mellom Zambia og Zimbabwe?", correct: "Zambezi",
                    distractors: ["Limpopo", "Kongo", "Orange"])
            ]
        case 13:
            return [
                Raw(prompt: "Hvor ligger Uluru (Ayers Rock)?", correct: "Australia",
                    distractors: ["New Zealand", "Sør-Afrika", "Argentina"]),
                Raw(prompt: "Hvor står Sydney Opera House?", correct: "Sydney",
                    distractors: ["Melbourne", "Brisbane", "Auckland"]),
                Raw(prompt: "Hvor ligger Great Barrier Reef?", correct: "Australia",
                    distractors: ["Indonesia", "Filippinene", "Fiji"]),
                Raw(prompt: "Hvor ligger Tasmania?", correct: "Australia",
                    distractors: ["New Zealand", "Indonesia", "Papua Ny-Guinea"]),
                Raw(prompt: "Hvor ligger Tongariro nasjonalpark?", correct: "New Zealand",
                    distractors: ["Australia", "Fiji", "Samoa"])
            ]
        case 14:
            return [
                Raw(prompt: "Hvor ligger Galápagos-øyene?", correct: "Ecuador",
                    distractors: ["Peru", "Chile", "Colombia"]),
                Raw(prompt: "Hvor ligger Påskeøya?", correct: "Chile",
                    distractors: ["Peru", "Fransk Polynesia", "Argentina"]),
                Raw(prompt: "Hvilket land deler øya Hispaniola med Haiti?", correct: "Dominikanske republikk",
                    distractors: ["Cuba", "Jamaica", "Puerto Rico"]),
                Raw(prompt: "Hvor ligger Karibhavet?", correct: "Mellom Mellom-Amerika og Sør-Amerika",
                    distractors: ["Vest for Stillehavet", "Nord for Atlanterhavet", "Mellom Afrika og Sør-Amerika"]),
                Raw(prompt: "Hvilket land er størst i Karibia?", correct: "Cuba",
                    distractors: ["Jamaica", "Bahamas", "Dominikanske republikk"])
            ]
        case 15:
            return [
                Raw(prompt: "Verdens minste land etter areal?", correct: "Vatikanstaten",
                    distractors: ["Monaco", "San Marino", "Tuvalu"]),
                Raw(prompt: "Hvor ligger Alhambra?", correct: "Granada",
                    distractors: ["Córdoba", "Sevilla", "Toledo"]),
                Raw(prompt: "Hvilken by kalles 'den evige stad'?", correct: "Roma",
                    distractors: ["Athen", "Jerusalem", "Istanbul"]),
                Raw(prompt: "Hvilket land er omsluttet av Italia?", correct: "San Marino",
                    distractors: ["Vatikanstaten", "Monaco", "Andorra"]),
                Raw(prompt: "Hvor ligger Andorra?", correct: "Mellom Spania og Frankrike",
                    distractors: ["Mellom Italia og Sveits", "Mellom Tyskland og Polen", "Mellom Hellas og Tyrkia"])
            ]
        case 16:
            return [
                Raw(prompt: "Verdens høyest beliggende hovedstad?", correct: "La Paz",
                    distractors: ["Quito", "Bogotá", "Lhasa"]),
                Raw(prompt: "Verdens største innlandsstat etter areal?", correct: "Kasakhstan",
                    distractors: ["Mongolia", "Bolivia", "Tsjad"]),
                Raw(prompt: "Hvor ligger Uralfjellene?", correct: "Russland",
                    distractors: ["Kasakhstan", "Mongolia", "Ukraina"]),
                Raw(prompt: "Hvor ligger Sibir?", correct: "Russland",
                    distractors: ["Kasakhstan", "Mongolia", "Kina"]),
                Raw(prompt: "Hvor ligger Patagonia?", correct: "Argentina og Chile",
                    distractors: ["Peru og Bolivia", "Brasil og Paraguay", "Uruguay og Argentina"])
            ]
        case 17:
            return [
                Raw(prompt: "Hvilket land het tidligere Burma?", correct: "Myanmar",
                    distractors: ["Thailand", "Vietnam", "Bangladesh"]),
                Raw(prompt: "Hvilket land het tidligere Ceylon?", correct: "Sri Lanka",
                    distractors: ["Maldivene", "Bangladesh", "India"]),
                Raw(prompt: "Hvilket land het tidligere Zaire?", correct: "DR Kongo",
                    distractors: ["Republikken Kongo", "Angola", "Sør-Sudan"]),
                Raw(prompt: "Hvilket land ble dannet i 2011?", correct: "Sør-Sudan",
                    distractors: ["Eritrea", "Kosovo", "Sør-Ossetia"]),
                Raw(prompt: "Hvor ligger Madagaskar?", correct: "Sørøst-Afrika",
                    distractors: ["Vest-Afrika", "Det indiske hav (vest for India)", "Stillehavet"])
            ]
        case 18:
            return [
                Raw(prompt: "Hvilken stat er omsluttet av Italia?", correct: "San Marino",
                    distractors: ["Monaco", "Vatikanstaten", "Andorra"]),
                Raw(prompt: "Hvor ligger Bora Bora?", correct: "Fransk Polynesia",
                    distractors: ["Fiji", "Samoa", "Tonga"]),
                Raw(prompt: "Hvilket land er kjent for Maori-kulturen?", correct: "New Zealand",
                    distractors: ["Australia", "Fiji", "Samoa"]),
                Raw(prompt: "Hvor mange land er medlemmer av FN (per 2020)?", correct: "193",
                    distractors: ["180", "200", "250"]),
                Raw(prompt: "Hvilket land har flest tidssoner?", correct: "Frankrike",
                    distractors: ["Russland", "USA", "Storbritannia"])
            ]
        case 19:
            return [
                Raw(prompt: "Hvilket hav er saltest?", correct: "Dødehavet",
                    distractors: ["Rødehavet", "Middelhavet", "Karibhavet"]),
                Raw(prompt: "Verdens største kontinent?", correct: "Asia",
                    distractors: ["Afrika", "Nord-Amerika", "Europa"]),
                Raw(prompt: "Verdens minste kontinent?", correct: "Oseania",
                    distractors: ["Europa", "Antarktis", "Sør-Amerika"]),
                Raw(prompt: "Hvilket land har størst flateareal?", correct: "Russland",
                    distractors: ["Canada", "Kina", "USA"]),
                Raw(prompt: "Hvilket land har størst befolkning?", correct: "India",
                    distractors: ["Kina", "USA", "Indonesia"])
            ]
        default:
            return [
                Raw(prompt: "Hvor ligger Socotra-øya?", correct: "Jemen",
                    distractors: ["Oman", "Somalia", "Eritrea"]),
                Raw(prompt: "Hvor renner elva Lena?", correct: "Russland",
                    distractors: ["Kasakhstan", "Kina", "Mongolia"]),
                Raw(prompt: "Hvilket land grenser til flest land i verden?", correct: "Kina",
                    distractors: ["Russland", "Brasil", "USA"]),
                Raw(prompt: "Hvilken elv krysser flest land?", correct: "Donau",
                    distractors: ["Nilen", "Kongo", "Mekong"]),
                Raw(prompt: "Hvor ligger Borobudur?", correct: "Indonesia",
                    distractors: ["Malaysia", "Thailand", "Filippinene"])
            ]
        }
    }
}
