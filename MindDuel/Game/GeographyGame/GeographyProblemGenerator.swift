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
    /// handcrafted specials + cross-cutting question types.
    private static func pool(forLevel level: Int) -> [Raw] {
        let countries = CountryData.countries(forLevel: level)
        var pool: [Raw] = []
        for country in countries {
            pool.append(contentsOf: questions(for: country, allInLevel: countries, level: level))
        }
        pool.append(contentsOf: specials(forLevel: level))
        if level >= 5 { pool.append(contentsOf: oddOneOut(forLevel: level)) }
        if level >= 9 { pool.append(contentsOf: timeDifference()) }
        return pool
    }

    /// "Hvilken er odd one out?" — three countries from one continent and
    /// one from another. The "different" continent's country is the answer.
    private static func oddOneOut(forLevel level: Int) -> [Raw] {
        let countries = CountryData.countries(forLevel: level)
        let byContinent = Dictionary(grouping: countries, by: \.continent)
        guard byContinent.count >= 2 else { return [] }
        var out: [Raw] = []
        for (continent, group) in byContinent where group.count >= 3 {
            let outsiders = countries.filter { $0.continent != continent }
            guard let odd = outsiders.randomElement() else { continue }
            let three = Array(group.shuffled().prefix(3))
            let options = (three.map(\.name) + [odd.name]).shuffled()
            out.append(Raw(
                prompt: "Hvilket av disse er odd one out (annerledes kontinent)?",
                correct: odd.name,
                distractors: options.filter { $0 != odd.name }
            ))
        }
        return out
    }

    /// Time-zone difference questions for major capitals. Independent of
    /// level so they appear in the pool from level 1 onwards as a fun
    /// twist on standard geography.
    private static func timeDifference() -> [Raw] {
        let pairs: [(from: String, to: String, diff: String)] = [
            ("Oslo", "Tokyo", "+8 timer"),
            ("Oslo", "New York", "−6 timer"),
            ("Oslo", "Sydney", "+9 timer"),
            ("Oslo", "Los Angeles", "−9 timer"),
            ("London", "New Delhi", "+5.5 timer"),
            ("Paris", "Beijing", "+7 timer")
        ]
        return pairs.map { p in
            Raw(prompt: "Hva er tidsforskjellen fra \(p.from) til \(p.to)?",
                correct: p.diff,
                distractors: ["+1 time", "+3 timer", "−2 timer", "+12 timer", "+5 timer"]
                    .filter { $0 != p.diff }.shuffled().prefix(3).map { $0 })
        }
    }

    /// Programmatic question types per country. The four core types fire
    /// for every country; the remaining types fire only when matching
    /// extras data exists (currency, language, neighbors, etc.). With
    /// 12+ countries per level this expands to 60–150+ prompts.
    private static func questions(for c: Country, allInLevel: [Country], level: Int) -> [Raw] {
        let regionalPool = allInLevel + CountryData.allCountries
        let otherCapitals = regionalPool.filter { $0.capital != c.capital }.map(\.capital)
        let otherCountries = regionalPool.filter { $0.name != c.name }.map(\.name)
        let continents = ["Europa", "Asia", "Afrika", "Nord-Amerika", "Sør-Amerika", "Oseania"]
            .filter { $0 != c.continent }

        var qs: [Raw] = [
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

        guard let x = CountryExtras.lookup(iso: c.iso) else { return qs }
        let allExtras = CountryExtras.byISO.values

        // Curriculum-aware level gates: capital/flag/continent always show;
        // each extras-derived type unlocks at the grade level where it's
        // pedagogically expected (LK20 progression).
        if level >= 3, let cur = x.currency {  // 3. klasse: penger/valuta intro
            let others = allExtras.compactMap(\.currency).filter { $0 != cur }
            qs.append(Raw(prompt: "Hvilken valuta brukes i \(c.name)?",
                          correct: cur, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 4, let lang = x.language {  // 4. klasse: språk i Norden/verden
            let others = allExtras.compactMap(\.language).filter { $0 != lang }
            qs.append(Raw(prompt: "Hvilket språk snakkes i \(c.name)?",
                          correct: lang, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 5, let big = x.biggestCity, big != c.capital {  // 5. klasse: byer
            qs.append(Raw(prompt: "Hva er den største byen i \(c.name)?",
                          correct: big, distractors: pickDistractors(from: otherCapitals, count: 3)))
        }
        if level >= 5, let landlocked = x.landlocked {  // 5. klasse: kart-konsept
            qs.append(Raw(prompt: "Er \(c.name) en innlandsstat?",
                          correct: landlocked ? "Ja" : "Nei",
                          distractors: [landlocked ? "Nei" : "Ja"]))
        }
        if level >= 5, let hemi = x.hemisphereNS {
            let others = ["Nord", "Sør", "Begge"].filter { $0 != hemi }
            qs.append(Raw(prompt: "Hvilken halvkule ligger \(c.name) i?",
                          correct: hemi, distractors: others))
        }
        if level >= 6, let neighbors = x.neighbors, !neighbors.isEmpty {  // 6. klasse: nabo-topologi
            if let n = neighbors.randomElement() {
                let nonNeighbors = otherCountries.filter { !neighbors.contains($0) && $0 != c.name }
                qs.append(Raw(prompt: "Hvilket land grenser til \(c.name)?",
                              correct: n, distractors: pickDistractors(from: nonNeighbors, count: 3)))
            }
            if level >= 7 {
                qs.append(Raw(prompt: "Hvor mange naboland har \(c.name)?",
                              correct: String(neighbors.count),
                              distractors: pickDistractors(from: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "12", "14"]
                                .filter { $0 != String(neighbors.count) }, count: 3)))
            }
        }
        if level >= 6, let eq = x.equatorCrosses, eq {  // 6. klasse: ekvator/klima
            qs.append(Raw(prompt: "Krysser ekvator gjennom \(c.name)?",
                          correct: "Ja", distractors: ["Nei"]))
        }
        if level >= 7, let religion = x.religion {  // 7. klasse: religion/samfunn
            let others = ["Kristendom", "Islam", "Buddhisme", "Hinduisme", "Jødedom", "Shinto/Buddhisme"].filter { $0 != religion }
            qs.append(Raw(prompt: "Hvilken religion er størst i \(c.name)?",
                          correct: religion, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 7, let dish = x.nationalDish {
            let others = allExtras.compactMap(\.nationalDish).filter { $0 != dish }
            qs.append(Raw(prompt: "Hvilken nasjonalrett er kjent fra \(c.name)?",
                          correct: dish, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 8, let gov = x.government {  // 8. klasse: styreform/samfunn
            let others = ["Republikk", "Konstitusjonelt monarki", "Absolutt monarki", "Forbundsrepublikk", "Ettpartistat", "Føderalt monarki", "Islamsk republikk"]
                .filter { $0 != gov }
            qs.append(Raw(prompt: "Hvilken styreform har \(c.name)?",
                          correct: gov, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 8, let trans = x.transcontinental, trans {
            qs.append(Raw(prompt: "\(c.name) er et transkontinentalt land. Sant eller usant?",
                          correct: "Sant", distractors: ["Usant"]))
        }
        if level >= 9, let high = x.highestPoint {
            qs.append(Raw(prompt: "Hva er det høyeste punktet i \(c.name)?",
                          correct: high,
                          distractors: pickDistractors(from: ["Mount Everest", "K2", "Kilimanjaro", "Mont Blanc", "Galdhøpiggen", "Kebnekaise", "Aconcagua", "Denali"].filter { $0 != high }, count: 3)))
        }
        if level >= 9, let river = x.longestRiver {
            qs.append(Raw(prompt: "Hva er den lengste elva i \(c.name)?",
                          correct: river,
                          distractors: pickDistractors(from: ["Glomma", "Donau", "Nilen", "Amazonas", "Themsen", "Seinen", "Volga", "Mississippi"].filter { $0 != river }, count: 3)))
        }
        if level >= 9, let year = x.independenceYear {
            qs.append(Raw(prompt: "Når ble \(c.name) selvstendig?",
                          correct: String(year),
                          distractors: pickDistractors(from: ["1776", "1814", "1905", "1917", "1922", "1947", "1960", "1991", "2011"].filter { $0 != String(year) }, count: 3)))
        }
        if level >= 10, let utc = x.utcOffset {  // 10. klasse: tidssoner
            let others = allExtras.compactMap(\.utcOffset).filter { $0 != utc }
            qs.append(Raw(prompt: "Hvilken tidssone (UTC) bruker \(c.name)?",
                          correct: utc, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 10, let driving = x.drivingSide {
            qs.append(Raw(prompt: "Hvilken side kjører de på i \(c.name)?",
                          correct: driving, distractors: ["Høyre", "Venstre"].filter { $0 != driving }))
        }
        if level >= 10, let sport = x.nationalSport {
            let others = ["Fotball", "Cricket", "Rugby", "Ishockey", "Sumo", "Hockey", "Amerikansk fotball", "Langrenn", "Håndball"].filter { $0 != sport }
            qs.append(Raw(prompt: "Hvilken sport regnes som nasjonalsport i \(c.name)?",
                          correct: sport, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 10, let animal = x.nationalAnimal {
            let others = ["Elg", "Bever", "Kenguru", "Kiwi", "Løve", "Bjørn", "Ørn", "Ulv"].filter { $0 != animal }
            qs.append(Raw(prompt: "Hvilket dyr er et nasjonalsymbol for \(c.name)?",
                          correct: animal, distractors: pickDistractors(from: others, count: 3)))
        }
        // VGS+ — trivia-koder og kulturhistorie
        if level >= 11, let endo = x.endonym {
            qs.append(Raw(prompt: "Hva kaller innbyggerne i \(c.name) selv landet?",
                          correct: endo,
                          distractors: pickDistractors(from: allExtras.compactMap(\.endonym).filter { $0 != endo }, count: 3)))
            qs.append(Raw(prompt: "Hvilket land kalles '\(endo)' på sitt eget språk?",
                          correct: c.name, distractors: pickDistractors(from: otherCountries, count: 3)))
        }
        if level >= 13, let phone = x.phoneCode {
            let others = allExtras.compactMap(\.phoneCode).filter { $0 != phone }
            qs.append(Raw(prompt: "Hvilken telefon-landkode har \(c.name)?",
                          correct: phone, distractors: pickDistractors(from: others, count: 3)))
        }
        if level >= 13, let iso3 = x.iso3 {
            let others = allExtras.compactMap(\.iso3).filter { $0 != iso3 }
            qs.append(Raw(prompt: "Hva er ISO-landkoden (3 bokstaver) for \(c.name)?",
                          correct: iso3, distractors: pickDistractors(from: others, count: 3)))
        }
        return qs
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

    /// Curriculum-aligned (LK20) handcrafted extras per level.
    /// 1.–2. klasse: Norge-fokus, kart-konsepter, himmelretninger.
    /// 3.–7. klasse: Norden, Europa, verdensdelene, klima.
    /// 8.–10. klasse: befolkning, naturressurser, geopolitikk-intro.
    /// VGS+: plate-tektonikk, klimasoner, demografi, regional analyse.
    /// Universitet: geomorfologi, geopolitikk avansert, kart-projeksjoner.
    // swiftlint:disable function_body_length
    private static func specials(forLevel level: Int) -> [Raw] {
        switch level {
        case 1: return level1Specials
        case 2: return level2Specials
        case 3: return level3Specials
        case 9991:
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
    // swiftlint:enable function_body_length

    // MARK: – 1. klasse (LK20): Norge-fokus, himmelretninger, kart-konsepter
    private static let level1Specials: [Raw] = [
        // Himmelretninger
        Raw(prompt: "Hvilken himmelretning peker en kompassnål mot?", correct: "Nord", distractors: ["Sør", "Øst", "Vest"]),
        Raw(prompt: "Hvor står sola opp?", correct: "Øst", distractors: ["Vest", "Nord", "Sør"]),
        Raw(prompt: "Hvor går sola ned?", correct: "Vest", distractors: ["Øst", "Nord", "Sør"]),
        Raw(prompt: "Hvilken himmelretning ligger Sverige fra Norge?", correct: "Øst", distractors: ["Vest", "Nord", "Sør"]),
        Raw(prompt: "Hvilken himmelretning ligger Danmark fra Norge?", correct: "Sør", distractors: ["Nord", "Øst", "Vest"]),
        Raw(prompt: "Hvilken himmelretning ligger havet (Atlanterhavet) fra Norge?", correct: "Vest", distractors: ["Øst", "Sør", "Nord"]),
        Raw(prompt: "Hvor mange hovedretninger har et kompass?", correct: "4", distractors: ["2", "6", "8"]),
        // Norske byer
        Raw(prompt: "Hva er hovedstaden i Norge?", correct: "Oslo", distractors: ["Bergen", "Trondheim", "Stavanger"]),
        Raw(prompt: "Hvilken by ligger lengst nord i Norge (av disse)?", correct: "Tromsø", distractors: ["Bergen", "Oslo", "Trondheim"]),
        Raw(prompt: "Hvilken by er kjent for olje og kalles oljehovedstaden?", correct: "Stavanger", distractors: ["Bergen", "Oslo", "Trondheim"]),
        Raw(prompt: "Hvilken by ligger på Vestlandet og er kjent for fiske?", correct: "Bergen", distractors: ["Oslo", "Tromsø", "Hamar"]),
        Raw(prompt: "Hvilken by ligger ved Trondheimsfjorden?", correct: "Trondheim", distractors: ["Bodø", "Tromsø", "Bergen"]),
        Raw(prompt: "Hvilken by ligger lengst sør i Norge?", correct: "Kristiansand", distractors: ["Stavanger", "Bergen", "Oslo"]),
        // Norske naturperler
        Raw(prompt: "Hva er Norges høyeste fjell?", correct: "Galdhøpiggen", distractors: ["Glittertind", "Snøhetta", "Romsdalshorn"]),
        Raw(prompt: "Hva er Norges lengste fjord?", correct: "Sognefjorden", distractors: ["Hardangerfjorden", "Geirangerfjorden", "Trondheimsfjorden"]),
        Raw(prompt: "Hva er Norges lengste elv?", correct: "Glomma", distractors: ["Lågen", "Numedalslågen", "Drammenselva"]),
        Raw(prompt: "Hvilken øygruppe ligger nord i Norge og er kjent for fjell og fiske?", correct: "Lofoten", distractors: ["Vesterålen", "Færøyene", "Shetland"]),
        Raw(prompt: "Hvilken øygruppe ligger lengst nord under Norge?", correct: "Svalbard", distractors: ["Lofoten", "Færøyene", "Bjørnøya"]),
        Raw(prompt: "Hvilket hav ligger vest for Norge?", correct: "Norskehavet", distractors: ["Nordsjøen", "Østersjøen", "Barentshavet"]),
        Raw(prompt: "Hvilket hav ligger nord for Norge?", correct: "Barentshavet", distractors: ["Norskehavet", "Nordsjøen", "Atlanterhavet"]),
        Raw(prompt: "Hvilket hav ligger sør for Norge (mellom Norge og UK)?", correct: "Nordsjøen", distractors: ["Norskehavet", "Østersjøen", "Skagerrak"]),
        // Naboland — kart
        Raw(prompt: "Hvilket land grenser til Norge i øst (sør for Trondheim)?", correct: "Sverige", distractors: ["Finland", "Russland", "Danmark"]),
        Raw(prompt: "Hvilket land grenser til Norge nord i Finnmark?", correct: "Russland", distractors: ["Sverige", "Finland", "Estland"]),
        Raw(prompt: "Hvilket land ligger sør for Norge (over havet)?", correct: "Danmark", distractors: ["Tyskland", "Polen", "Nederland"]),
        Raw(prompt: "Hvor mange land grenser til Norge på fastlandet?", correct: "3", distractors: ["1", "2", "4"]),
        Raw(prompt: "Hvilket land grenser til Norge i Nord-Norge (mellom Sverige og Russland)?", correct: "Finland", distractors: ["Sverige", "Estland", "Russland"]),
        // Nasjonale symboler
        Raw(prompt: "Hvilke farger har det norske flagget?", correct: "Rød, hvit, blå", distractors: ["Rød, hvit, gul", "Blå, hvit, grønn", "Rød, gul, blå"]),
        Raw(prompt: "Når er Norges nasjonaldag?", correct: "17. mai", distractors: ["1. mai", "8. mai", "1. juni"]),
        Raw(prompt: "Hva heter Norges nasjonalsang?", correct: "Ja, vi elsker dette landet", distractors: ["Gud signe vårt dyre fedreland", "Mellom bakkar og berg", "Fagert er landet"]),
        Raw(prompt: "Hva er Norges nasjonalfjell?", correct: "Stetind", distractors: ["Galdhøpiggen", "Romsdalshorn", "Trolltindane"]),
        Raw(prompt: "Hva er Norges nasjonalfugl?", correct: "Fossekall", distractors: ["Ørn", "Måke", "Kråke"]),
        // Kart-konsepter
        Raw(prompt: "Hva kalles en tegning av et område sett ovenfra?", correct: "Kart", distractors: ["Bilde", "Tegning", "Modell"]),
        Raw(prompt: "Hva kalles linjene som viser høyde på et kart?", correct: "Høydekurver", distractors: ["Veikurver", "Vannlinjer", "Stilinjer"]),
        Raw(prompt: "Hva kalles tegnet som forteller hva symbolene betyr på et kart?", correct: "Tegnforklaring", distractors: ["Innholdsfortegnelse", "Veiskilt", "Forord"]),
        Raw(prompt: "Hvilken farge brukes ofte for vann på kart?", correct: "Blå", distractors: ["Grønn", "Brun", "Gul"]),
        Raw(prompt: "Hvilken farge brukes ofte for skog på kart?", correct: "Grønn", distractors: ["Blå", "Brun", "Gul"]),
        // Konsept om jordkloden
        Raw(prompt: "Hvilken form har jorden?", correct: "Rund (kule)", distractors: ["Flat", "Firkantet", "Trekantet"]),
        Raw(prompt: "Hva kalles den varme delen av jorden midt på?", correct: "Ekvator", distractors: ["Polene", "Tropene", "Soner"]),
        Raw(prompt: "Hvor er det aller kaldest på jorden?", correct: "På polene", distractors: ["Ved ekvator", "I skogene", "I ørkenen"]),
        Raw(prompt: "Hvor mange verdensdeler finnes det?", correct: "7", distractors: ["5", "6", "8"]),
        Raw(prompt: "Hvilken verdensdel ligger Norge i?", correct: "Europa", distractors: ["Asia", "Afrika", "Nord-Amerika"]),
        Raw(prompt: "Hva er en globe?", correct: "En modell av jordkloden", distractors: ["En type kart", "Et bilde", "En atlas-bok"])
    ]

    // MARK: – 2. klasse (LK20): Norden + Norge utvidet
    private static let level2Specials: [Raw] = [
        // Norden flagg & land
        Raw(prompt: "Hvilke 5 land utgjør Norden?", correct: "Norge, Sverige, Danmark, Finland, Island",
            distractors: ["Norge, Sverige, Danmark, Tyskland, Island", "Norge, Sverige, Polen, Finland, Island", "Norge, Sverige, Danmark, Finland, Færøyene"]),
        Raw(prompt: "Hvilket nordisk land har bare ett naboland?", correct: "Danmark", distractors: ["Norge", "Finland", "Sverige"]),
        Raw(prompt: "Hvilket nordisk land er en øy uten naboland?", correct: "Island", distractors: ["Færøyene", "Grønland", "Svalbard"]),
        Raw(prompt: "Hvilket nordisk land grenser ikke til Norge?", correct: "Danmark", distractors: ["Sverige", "Finland", "Russland"]),
        Raw(prompt: "Hvilket nordisk språk er ikke skandinavisk?", correct: "Finsk", distractors: ["Svensk", "Dansk", "Norsk"]),
        // Norske fylker (LK20)
        Raw(prompt: "I hvilket fylke ligger Bergen?", correct: "Vestland", distractors: ["Rogaland", "Møre og Romsdal", "Trøndelag"]),
        Raw(prompt: "I hvilket fylke ligger Trondheim?", correct: "Trøndelag", distractors: ["Nordland", "Møre og Romsdal", "Innlandet"]),
        Raw(prompt: "I hvilket fylke ligger Stavanger?", correct: "Rogaland", distractors: ["Vestland", "Agder", "Vestfold"]),
        Raw(prompt: "I hvilket fylke ligger Tromsø?", correct: "Troms", distractors: ["Finnmark", "Nordland", "Trøndelag"]),
        Raw(prompt: "I hvilket fylke ligger Oslo?", correct: "Oslo", distractors: ["Akershus", "Buskerud", "Innlandet"]),
        Raw(prompt: "I hvilket fylke ligger Lillehammer?", correct: "Innlandet", distractors: ["Akershus", "Buskerud", "Trøndelag"]),
        Raw(prompt: "I hvilket fylke ligger Kristiansand?", correct: "Agder", distractors: ["Rogaland", "Vestfold", "Telemark"]),
        Raw(prompt: "I hvilket fylke ligger Bodø?", correct: "Nordland", distractors: ["Troms", "Finnmark", "Trøndelag"]),
        Raw(prompt: "Hvor mange fylker har Norge (etter 2024)?", correct: "15", distractors: ["11", "13", "19"]),
        // Naboforhold
        Raw(prompt: "Hvilket land grenser til både Norge og Finland?", correct: "Sverige", distractors: ["Russland", "Estland", "Danmark"]),
        Raw(prompt: "Hvilket land grenser til både Sverige og Finland?", correct: "Norge", distractors: ["Danmark", "Russland", "Estland"]),
        Raw(prompt: "Hvilket land grenser til Russland (av Norden)?", correct: "Norge", distractors: ["Sverige", "Danmark", "Island"]),
        Raw(prompt: "Hvilket nordisk land grenser til Tyskland?", correct: "Danmark", distractors: ["Sverige", "Norge", "Finland"]),
        // Hovedsteder
        Raw(prompt: "Hovedstaden i Sverige?", correct: "Stockholm", distractors: ["Göteborg", "Malmö", "Uppsala"]),
        Raw(prompt: "Hovedstaden i Danmark?", correct: "København", distractors: ["Aarhus", "Odense", "Aalborg"]),
        Raw(prompt: "Hovedstaden i Finland?", correct: "Helsinki", distractors: ["Turku", "Tampere", "Espoo"]),
        Raw(prompt: "Hovedstaden i Island?", correct: "Reykjavík", distractors: ["Akureyri", "Tórshavn", "Nuuk"]),
        // Norske naturperler utvidet
        Raw(prompt: "Hvor ligger Geirangerfjorden?", correct: "Møre og Romsdal", distractors: ["Vestland", "Rogaland", "Sogn og Fjordane"]),
        Raw(prompt: "Hvor ligger Preikestolen?", correct: "Rogaland", distractors: ["Vestland", "Agder", "Trøndelag"]),
        Raw(prompt: "Hvor ligger Trolltunga?", correct: "Vestland", distractors: ["Rogaland", "Møre og Romsdal", "Telemark"]),
        Raw(prompt: "Hva heter den lange fjellkjeden vi deler med Sverige?", correct: "Skandinaviske fjellkjede", distractors: ["Alpene", "Karpatene", "Pyreneene"]),
        Raw(prompt: "Hvilken hovedstad ligger nederst i Norge ved Oslofjorden?", correct: "Oslo", distractors: ["Stockholm", "København", "Helsinki"]),
        // Konsepter
        Raw(prompt: "Hvor mange landsdeler har Norge?", correct: "5", distractors: ["3", "4", "7"]),
        Raw(prompt: "Hvilken landsdel hører Bergen til?", correct: "Vestlandet", distractors: ["Østlandet", "Sørlandet", "Trøndelag"]),
        Raw(prompt: "Hvilken landsdel hører Tromsø til?", correct: "Nord-Norge", distractors: ["Trøndelag", "Vestlandet", "Østlandet"]),
        Raw(prompt: "Hva er midnattssol?", correct: "At sola ikke går ned om sommeren", distractors: ["At det er mørkt om sommeren", "Sterk sol om vinteren", "Et fenomen kun i Asia"]),
        Raw(prompt: "Hva er polarnatt?", correct: "At sola ikke kommer over horisonten om vinteren", distractors: ["Sterk sol om vinteren", "At det er lyst hele døgnet", "Stjerneklart hele året"]),
        Raw(prompt: "Hva heter den øygruppen som hører til Danmark og ligger i Atlanterhavet?", correct: "Færøyene", distractors: ["Lofoten", "Shetland", "Hebridene"]),
        Raw(prompt: "Hvilken stor øy nord-vest for Island tilhører Danmark?", correct: "Grønland", distractors: ["Island", "Færøyene", "Spitsbergen"])
    ]

    // MARK: – 3. klasse (LK20): Norden + Europa intro
    private static let level3Specials: [Raw] = [
        // Europa-konsepter
        Raw(prompt: "Hvilket hav skiller Norden fra Tyskland?", correct: "Østersjøen", distractors: ["Nordsjøen", "Atlanterhavet", "Middelhavet"]),
        Raw(prompt: "Hvilket hav skiller Norge fra Storbritannia?", correct: "Nordsjøen", distractors: ["Norskehavet", "Østersjøen", "Atlanterhavet"]),
        Raw(prompt: "Hvilken fjellkjede ligger mellom Norge og Sverige?", correct: "Skandinaviske fjellkjede", distractors: ["Alpene", "Pyreneene", "Karpatene"]),
        Raw(prompt: "Hvilken elv renner gjennom Berlin?", correct: "Spree", distractors: ["Rhinen", "Donau", "Elben"]),
        Raw(prompt: "Hvilken elv renner gjennom London?", correct: "Themsen", distractors: ["Severn", "Mersey", "Seinen"]),
        Raw(prompt: "Hvilken elv renner gjennom Moskva?", correct: "Moskvaelven", distractors: ["Volga", "Don", "Dnepr"]),
        Raw(prompt: "Hvor ligger Stonehenge?", correct: "Storbritannia", distractors: ["Tyskland", "Frankrike", "Irland"]),
        Raw(prompt: "Hvor ligger Brandenburger Tor?", correct: "Berlin", distractors: ["München", "Hamburg", "Wien"]),
        Raw(prompt: "Hvor ligger Buckingham Palace?", correct: "London", distractors: ["Edinburgh", "Dublin", "Paris"]),
        // Klima og natur
        Raw(prompt: "Hvilken type klima har Norge?", correct: "Tempererte (tempererte breddegrader)", distractors: ["Tropisk", "Polart", "Ørken"]),
        Raw(prompt: "Hva kalles klimaet i Sahara?", correct: "Ørkenklima", distractors: ["Tropisk", "Tempererte", "Polart"]),
        Raw(prompt: "Hva kalles klimaet ved Nordpolen?", correct: "Polart", distractors: ["Tropisk", "Tempererte", "Ørken"]),
        // Kontinenter og hav
        Raw(prompt: "Hvilket hav er størst i verden?", correct: "Stillehavet", distractors: ["Atlanterhavet", "Indiske hav", "Polhavet"]),
        Raw(prompt: "Hvor mange hav (verdenshav) finnes det?", correct: "5", distractors: ["3", "4", "7"]),
        Raw(prompt: "Hvilket kontinent ligger Russland mest i?", correct: "Asia", distractors: ["Europa", "Afrika", "Nord-Amerika"]),
        Raw(prompt: "Hvilket kontinent ligger Tyrkia mest i?", correct: "Asia", distractors: ["Europa", "Afrika", "Midtøsten"])
    ]
}
