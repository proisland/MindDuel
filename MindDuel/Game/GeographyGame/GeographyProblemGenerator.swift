import Foundation

/// Geography questions covering capitals, countries, continents, flags,
/// neighbours, cities, rivers, landmarks and famous buildings (#45/#52).
/// Same 20-level curriculum scheme as math/chemistry — easier categories
/// and Nordic/European focus on low levels, expanding to global +
/// obscure trivia at the top.
enum GeographyProblemGenerator {

    /// Set of `correct` answers already served in the current round, across
    /// every level the player passes through. A question never repeats while
    /// the round lasts (#64) — only when the entire pool of all 20 levels is
    /// exhausted does the set reset. The view calls `resetRoundHistory()`
    /// when starting / restarting a round to clear this.
    private static var seenCorrects: Set<String> = []

    static func resetRoundHistory() {
        seenCorrects.removeAll()
    }

    static func generate(level: Int = 1) -> GeographyProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        var candidates = pool.filter { !seenCorrects.contains($0.correct) }
        if candidates.isEmpty {
            // Whole level is already seen this round — clear so the player
            // can keep playing rather than getting stuck. Other levels in
            // the round retain their seen-state via the same set.
            seenCorrects.subtract(pool.map(\.correct))
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        seenCorrects.insert(raw.correct)
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

    private struct Raw {
        let prompt: String
        var flag: String? = nil
        let correct: String
        let distractors: [String]
    }

    private static let flagPrompt = "Hvilket land har dette flagget?"

    // swiftlint:disable function_body_length file_length
    private static func pool(forLevel level: Int) -> [Raw] {
        switch level {

        // MARK: Grunnskolen — Norden & nære naboer

        case 1:
            return [
                Raw(prompt: "Hovedstaden i Norge?", correct: "Oslo",
                    distractors: ["Bergen", "Trondheim", "Stavanger"]),
                Raw(prompt: "Hovedstaden i Sverige?", correct: "Stockholm",
                    distractors: ["Göteborg", "Malmö", "Uppsala"]),
                Raw(prompt: "Hovedstaden i Danmark?", correct: "København",
                    distractors: ["Aarhus", "Odense", "Aalborg"]),
                Raw(prompt: "Hovedstaden i Finland?", correct: "Helsinki",
                    distractors: ["Turku", "Tampere", "Espoo"]),
                Raw(prompt: "Hovedstaden i Island?", correct: "Reykjavík",
                    distractors: ["Akureyri", "Tórshavn", "Nuuk"]),
                Raw(prompt: flagPrompt, flag: "🇳🇴", correct: "Norge",
                    distractors: ["Sverige", "Island", "Danmark"]),
                Raw(prompt: flagPrompt, flag: "🇸🇪", correct: "Sverige",
                    distractors: ["Finland", "Norge", "Danmark"]),
                Raw(prompt: flagPrompt, flag: "🇩🇰", correct: "Danmark",
                    distractors: ["Norge", "Island", "Tyskland"]),
                Raw(prompt: flagPrompt, flag: "🇫🇮", correct: "Finland",
                    distractors: ["Sverige", "Estland", "Hellas"]),
                Raw(prompt: flagPrompt, flag: "🇮🇸", correct: "Island",
                    distractors: ["Norge", "Færøyene", "Grønland"]),
                Raw(prompt: "Hvilken kontinent ligger Norge i?", correct: "Europa",
                    distractors: ["Asia", "Afrika", "Nord-Amerika"]),
                Raw(prompt: "Norges nordligste fastlandsby?", correct: "Hammerfest",
                    distractors: ["Tromsø", "Bodø", "Alta"]),
                Raw(prompt: "Norges lengste fjord?", correct: "Sognefjorden",
                    distractors: ["Hardangerfjorden", "Geirangerfjorden", "Trondheimsfjorden"]),
                Raw(prompt: "Hvilket hav ligger vest for Norge?", correct: "Norskehavet",
                    distractors: ["Nordsjøen", "Østersjøen", "Barentshavet"]),
                Raw(prompt: "Hva heter Norges nasjonalfjell?", correct: "Stetind",
                    distractors: ["Galdhøpiggen", "Romsdalshorn", "Trolltindane"])
            ]

        case 2:
            return [
                Raw(prompt: "Hovedstaden i Tyskland?", correct: "Berlin",
                    distractors: ["München", "Hamburg", "Frankfurt"]),
                Raw(prompt: "Hovedstaden i Frankrike?", correct: "Paris",
                    distractors: ["Lyon", "Marseille", "Nice"]),
                Raw(prompt: "Hovedstaden i Storbritannia?", correct: "London",
                    distractors: ["Manchester", "Edinburgh", "Liverpool"]),
                Raw(prompt: "Hovedstaden i Spania?", correct: "Madrid",
                    distractors: ["Barcelona", "Sevilla", "Valencia"]),
                Raw(prompt: "Hovedstaden i Italia?", correct: "Roma",
                    distractors: ["Milano", "Napoli", "Venezia"]),
                Raw(prompt: "Hovedstaden i Nederland?", correct: "Amsterdam",
                    distractors: ["Rotterdam", "Haag", "Utrecht"]),
                Raw(prompt: "Hovedstaden i Belgia?", correct: "Brussel",
                    distractors: ["Antwerpen", "Brugge", "Gent"]),
                Raw(prompt: flagPrompt, flag: "🇩🇪", correct: "Tyskland",
                    distractors: ["Belgia", "Østerrike", "Nederland"]),
                Raw(prompt: flagPrompt, flag: "🇫🇷", correct: "Frankrike",
                    distractors: ["Italia", "Nederland", "Russland"]),
                Raw(prompt: flagPrompt, flag: "🇬🇧", correct: "Storbritannia",
                    distractors: ["USA", "Australia", "New Zealand"]),
                Raw(prompt: flagPrompt, flag: "🇪🇸", correct: "Spania",
                    distractors: ["Portugal", "Italia", "Mexico"]),
                Raw(prompt: flagPrompt, flag: "🇮🇹", correct: "Italia",
                    distractors: ["Mexico", "Hellas", "Spania"]),
                Raw(prompt: flagPrompt, flag: "🇳🇱", correct: "Nederland",
                    distractors: ["Frankrike", "Luxembourg", "Russland"]),
                Raw(prompt: "I hvilket land ligger Stockholm?", correct: "Sverige",
                    distractors: ["Norge", "Finland", "Danmark"]),
                Raw(prompt: "Hva er Tysklands største by?", correct: "Berlin",
                    distractors: ["Hamburg", "München", "Köln"]),
                Raw(prompt: "Hvilken elv renner gjennom Paris?", correct: "Seinen",
                    distractors: ["Loire", "Rhône", "Themsen"])
            ]

        case 3:
            return [
                Raw(prompt: "Hovedstaden i Portugal?", correct: "Lisboa",
                    distractors: ["Porto", "Madrid", "Faro"]),
                Raw(prompt: "Hovedstaden i Hellas?", correct: "Athen",
                    distractors: ["Thessaloniki", "Sparta", "Patras"]),
                Raw(prompt: "Hovedstaden i Polen?", correct: "Warszawa",
                    distractors: ["Kraków", "Gdańsk", "Wrocław"]),
                Raw(prompt: "Hovedstaden i Østerrike?", correct: "Wien",
                    distractors: ["Salzburg", "Graz", "Linz"]),
                Raw(prompt: "Hovedstaden i Irland?", correct: "Dublin",
                    distractors: ["Cork", "Belfast", "Galway"]),
                Raw(prompt: "Hovedstaden i Tsjekkia?", correct: "Praha",
                    distractors: ["Brno", "Bratislava", "Wien"]),
                Raw(prompt: "Hovedstaden i Ungarn?", correct: "Budapest",
                    distractors: ["Beograd", "Wien", "Zagreb"]),
                Raw(prompt: flagPrompt, flag: "🇵🇹", correct: "Portugal",
                    distractors: ["Spania", "Brasil", "Romania"]),
                Raw(prompt: flagPrompt, flag: "🇬🇷", correct: "Hellas",
                    distractors: ["Argentina", "Israel", "Uruguay"]),
                Raw(prompt: flagPrompt, flag: "🇵🇱", correct: "Polen",
                    distractors: ["Indonesia", "Monaco", "Singapore"]),
                Raw(prompt: flagPrompt, flag: "🇦🇹", correct: "Østerrike",
                    distractors: ["Latvia", "Libanon", "Peru"]),
                Raw(prompt: flagPrompt, flag: "🇮🇪", correct: "Irland",
                    distractors: ["Italia", "Elfenbenskysten", "India"]),
                Raw(prompt: flagPrompt, flag: "🇨🇿", correct: "Tsjekkia",
                    distractors: ["Polen", "Slovakia", "Russland"]),
                Raw(prompt: flagPrompt, flag: "🇭🇺", correct: "Ungarn",
                    distractors: ["Bulgaria", "Italia", "Iran"]),
                Raw(prompt: "Hvilken elv renner gjennom Wien?", correct: "Donau",
                    distractors: ["Rhinen", "Elben", "Inn"]),
                Raw(prompt: "Hvilken kontinent ligger Hellas i?", correct: "Europa",
                    distractors: ["Asia", "Afrika", "Midtøsten"])
            ]

        case 4:
            return [
                Raw(prompt: "Hvilket land grenser til Norge i øst?", correct: "Sverige",
                    distractors: ["Finland", "Russland", "Danmark"]),
                Raw(prompt: "Hvilket land grenser ikke til Norge?", correct: "Estland",
                    distractors: ["Sverige", "Finland", "Russland"]),
                Raw(prompt: "Hvilken kontinent ligger Egypt i?", correct: "Afrika",
                    distractors: ["Asia", "Europa", "Sør-Amerika"]),
                Raw(prompt: "Hvilken kontinent ligger Brasil i?", correct: "Sør-Amerika",
                    distractors: ["Nord-Amerika", "Afrika", "Asia"]),
                Raw(prompt: "Hvilken kontinent ligger Japan i?", correct: "Asia",
                    distractors: ["Oseania", "Europa", "Afrika"]),
                Raw(prompt: "Hvilken kontinent ligger Australia i?", correct: "Oseania",
                    distractors: ["Asia", "Antarktis", "Afrika"]),
                Raw(prompt: "Hvilken kontinent ligger Mexico i?", correct: "Nord-Amerika",
                    distractors: ["Sør-Amerika", "Mellom-Amerika", "Karibia"]),
                Raw(prompt: "Hvor mange kontinenter har vi?", correct: "7",
                    distractors: ["5", "6", "8"]),
                Raw(prompt: "Hvilket hav ligger mellom Europa og Afrika?", correct: "Middelhavet",
                    distractors: ["Atlanterhavet", "Rødehavet", "Svartehavet"]),
                Raw(prompt: "Hvilket hav ligger øst for Norge?", correct: "Østersjøen",
                    distractors: ["Nordsjøen", "Norskehavet", "Barentshavet"]),
                Raw(prompt: flagPrompt, flag: "🇪🇪", correct: "Estland",
                    distractors: ["Latvia", "Litauen", "Finland"]),
                Raw(prompt: flagPrompt, flag: "🇷🇺", correct: "Russland",
                    distractors: ["Slovenia", "Slovakia", "Nederland"]),
                Raw(prompt: flagPrompt, flag: "🇧🇪", correct: "Belgia",
                    distractors: ["Tyskland", "Romania", "Tsjad"]),
                Raw(prompt: "Verdens største kontinent?", correct: "Asia",
                    distractors: ["Afrika", "Nord-Amerika", "Europa"]),
                Raw(prompt: "Verdens minste kontinent?", correct: "Oseania",
                    distractors: ["Europa", "Antarktis", "Sør-Amerika"])
            ]

        case 5:
            return [
                Raw(prompt: "Hovedstaden i USA?", correct: "Washington D.C.",
                    distractors: ["New York", "Los Angeles", "Boston"]),
                Raw(prompt: "Hovedstaden i Canada?", correct: "Ottawa",
                    distractors: ["Toronto", "Montréal", "Vancouver"]),
                Raw(prompt: "Hovedstaden i Mexico?", correct: "Mexico by",
                    distractors: ["Cancún", "Guadalajara", "Tijuana"]),
                Raw(prompt: "Hovedstaden i Brasil?", correct: "Brasília",
                    distractors: ["Rio de Janeiro", "São Paulo", "Salvador"]),
                Raw(prompt: "Hovedstaden i Argentina?", correct: "Buenos Aires",
                    distractors: ["Córdoba", "Rosario", "Mendoza"]),
                Raw(prompt: "Hovedstaden i Chile?", correct: "Santiago",
                    distractors: ["Valparaíso", "Concepción", "Antofagasta"]),
                Raw(prompt: "Hovedstaden i Colombia?", correct: "Bogotá",
                    distractors: ["Medellín", "Cali", "Cartagena"]),
                Raw(prompt: "Hovedstaden i Peru?", correct: "Lima",
                    distractors: ["Cusco", "Arequipa", "Trujillo"]),
                Raw(prompt: "Hovedstaden i Venezuela?", correct: "Caracas",
                    distractors: ["Maracaibo", "Valencia", "Bogotá"]),
                Raw(prompt: "Hovedstaden i Cuba?", correct: "Havana",
                    distractors: ["Santiago de Cuba", "Holguín", "Miami"]),
                Raw(prompt: flagPrompt, flag: "🇺🇸", correct: "USA",
                    distractors: ["Liberia", "Malaysia", "Chile"]),
                Raw(prompt: flagPrompt, flag: "🇨🇦", correct: "Canada",
                    distractors: ["Peru", "Tunisia", "Libanon"]),
                Raw(prompt: flagPrompt, flag: "🇲🇽", correct: "Mexico",
                    distractors: ["Italia", "Hellas", "Iran"]),
                Raw(prompt: flagPrompt, flag: "🇧🇷", correct: "Brasil",
                    distractors: ["Argentina", "Colombia", "Mexico"]),
                Raw(prompt: flagPrompt, flag: "🇦🇷", correct: "Argentina",
                    distractors: ["Hellas", "Uruguay", "El Salvador"]),
                Raw(prompt: flagPrompt, flag: "🇨🇱", correct: "Chile",
                    distractors: ["Texas", "Tsjekkia", "Liberia"])
            ]

        case 6:
            return [
                Raw(prompt: "Hovedstaden i Japan?", correct: "Tokyo",
                    distractors: ["Osaka", "Kyoto", "Nagoya"]),
                Raw(prompt: "Hovedstaden i Kina?", correct: "Beijing",
                    distractors: ["Shanghai", "Hong Kong", "Guangzhou"]),
                Raw(prompt: "Hovedstaden i India?", correct: "New Delhi",
                    distractors: ["Mumbai", "Kolkata", "Bangalore"]),
                Raw(prompt: "Hovedstaden i Sør-Korea?", correct: "Seoul",
                    distractors: ["Busan", "Incheon", "Pyongyang"]),
                Raw(prompt: "Hovedstaden i Thailand?", correct: "Bangkok",
                    distractors: ["Phuket", "Chiang Mai", "Pattaya"]),
                Raw(prompt: "Hovedstaden i Vietnam?", correct: "Hanoi",
                    distractors: ["Ho Chi Minh-byen", "Da Nang", "Hue"]),
                Raw(prompt: "Hovedstaden i Filippinene?", correct: "Manila",
                    distractors: ["Cebu", "Davao", "Quezon City"]),
                Raw(prompt: "Hovedstaden i Malaysia?", correct: "Kuala Lumpur",
                    distractors: ["George Town", "Johor Bahru", "Singapore"]),
                Raw(prompt: "Hovedstaden i Singapore?", correct: "Singapore",
                    distractors: ["Kuala Lumpur", "Jakarta", "Bangkok"]),
                Raw(prompt: "Hovedstaden i Pakistan?", correct: "Islamabad",
                    distractors: ["Karachi", "Lahore", "Rawalpindi"]),
                Raw(prompt: flagPrompt, flag: "🇯🇵", correct: "Japan",
                    distractors: ["Bangladesh", "Palau", "Sør-Korea"]),
                Raw(prompt: flagPrompt, flag: "🇨🇳", correct: "Kina",
                    distractors: ["Vietnam", "Marokko", "Tyrkia"]),
                Raw(prompt: flagPrompt, flag: "🇮🇳", correct: "India",
                    distractors: ["Niger", "Elfenbenskysten", "Iran"]),
                Raw(prompt: flagPrompt, flag: "🇰🇷", correct: "Sør-Korea",
                    distractors: ["Japan", "Nord-Korea", "Kina"]),
                Raw(prompt: flagPrompt, flag: "🇹🇭", correct: "Thailand",
                    distractors: ["Costa Rica", "Frankrike", "Russland"]),
                Raw(prompt: flagPrompt, flag: "🇻🇳", correct: "Vietnam",
                    distractors: ["Kina", "Marokko", "Tyrkia"])
            ]

        case 7:
            return [
                Raw(prompt: "Hovedstaden i Egypt?", correct: "Kairo",
                    distractors: ["Alexandria", "Giza", "Luxor"]),
                Raw(prompt: "Hovedstaden i Sør-Afrika (regjering)?", correct: "Pretoria",
                    distractors: ["Johannesburg", "Cape Town", "Durban"]),
                Raw(prompt: "Hovedstaden i Marokko?", correct: "Rabat",
                    distractors: ["Casablanca", "Marrakech", "Fez"]),
                Raw(prompt: "Hovedstaden i Kenya?", correct: "Nairobi",
                    distractors: ["Mombasa", "Kisumu", "Addis Abeba"]),
                Raw(prompt: "Hovedstaden i Nigeria?", correct: "Abuja",
                    distractors: ["Lagos", "Kano", "Ibadan"]),
                Raw(prompt: "Hovedstaden i Etiopia?", correct: "Addis Abeba",
                    distractors: ["Asmara", "Khartoum", "Mogadishu"]),
                Raw(prompt: "Hovedstaden i Ghana?", correct: "Accra",
                    distractors: ["Kumasi", "Lagos", "Abidjan"]),
                Raw(prompt: "Hovedstaden i Algerie?", correct: "Alger",
                    distractors: ["Oran", "Tunis", "Tripoli"]),
                Raw(prompt: "Hovedstaden i Tunisia?", correct: "Tunis",
                    distractors: ["Sfax", "Alger", "Tripoli"]),
                Raw(prompt: "Hovedstaden i Senegal?", correct: "Dakar",
                    distractors: ["Bamako", "Conakry", "Nouakchott"]),
                Raw(prompt: flagPrompt, flag: "🇪🇬", correct: "Egypt",
                    distractors: ["Jemen", "Syria", "Irak"]),
                Raw(prompt: flagPrompt, flag: "🇿🇦", correct: "Sør-Afrika",
                    distractors: ["Kenya", "Etiopia", "Nigeria"]),
                Raw(prompt: flagPrompt, flag: "🇲🇦", correct: "Marokko",
                    distractors: ["Tunisia", "Vietnam", "Kina"]),
                Raw(prompt: flagPrompt, flag: "🇰🇪", correct: "Kenya",
                    distractors: ["Sør-Sudan", "Tanzania", "Uganda"]),
                Raw(prompt: flagPrompt, flag: "🇳🇬", correct: "Nigeria",
                    distractors: ["Pakistan", "Italia", "Madagaskar"]),
                Raw(prompt: flagPrompt, flag: "🇪🇹", correct: "Etiopia",
                    distractors: ["Ghana", "Senegal", "Bolivia"])
            ]

        case 8:
            return [
                Raw(prompt: "Hvor ligger Eiffeltårnet?", correct: "Paris",
                    distractors: ["Roma", "London", "Madrid"]),
                Raw(prompt: "Hvor ligger Big Ben?", correct: "London",
                    distractors: ["Edinburgh", "Dublin", "Cardiff"]),
                Raw(prompt: "Hvor ligger Colosseum?", correct: "Roma",
                    distractors: ["Athen", "Madrid", "Firenze"]),
                Raw(prompt: "Hvor ligger Frihetsgudinnen?", correct: "New York",
                    distractors: ["Washington D.C.", "Boston", "Chicago"]),
                Raw(prompt: "Hvor ligger Den kinesiske mur?", correct: "Kina",
                    distractors: ["Japan", "Mongolia", "Korea"]),
                Raw(prompt: "Hvor ligger Taj Mahal?", correct: "India",
                    distractors: ["Pakistan", "Bangladesh", "Iran"]),
                Raw(prompt: "Hvor ligger Pyramidene i Giza?", correct: "Egypt",
                    distractors: ["Sudan", "Libya", "Saudi-Arabia"]),
                Raw(prompt: "Hvor ligger Golden Gate Bridge?", correct: "San Francisco",
                    distractors: ["New York", "Seattle", "Los Angeles"]),
                Raw(prompt: "Hvor ligger Brandenburger Tor?", correct: "Berlin",
                    distractors: ["München", "Hamburg", "Wien"]),
                Raw(prompt: "Hvor ligger Akropolis?", correct: "Athen",
                    distractors: ["Roma", "Istanbul", "Sparta"]),
                Raw(prompt: "Hvor står Lille havfrue?", correct: "København",
                    distractors: ["Stockholm", "Oslo", "Helsinki"]),
                Raw(prompt: "Hvor ligger Kreml?", correct: "Moskva",
                    distractors: ["St. Petersburg", "Kiev", "Minsk"]),
                Raw(prompt: "Hvor ligger Tower Bridge?", correct: "London",
                    distractors: ["New York", "Sydney", "Manchester"]),
                Raw(prompt: "Hvilken by kalles 'den evige stad'?", correct: "Roma",
                    distractors: ["Athen", "Jerusalem", "Istanbul"]),
                Raw(prompt: "Hvor ligger Petra?", correct: "Jordan",
                    distractors: ["Egypt", "Israel", "Saudi-Arabia"])
            ]

        case 9:
            return [
                Raw(prompt: "Verdens lengste elv?", correct: "Nilen",
                    distractors: ["Amazonas", "Yangtze", "Mississippi"]),
                Raw(prompt: "I hvilket land renner Donau ut?", correct: "Romania",
                    distractors: ["Ungarn", "Bulgaria", "Ukraina"]),
                Raw(prompt: "Hvilken elv renner gjennom London?", correct: "Themsen",
                    distractors: ["Severn", "Mersey", "Seinen"]),
                Raw(prompt: "Hvilken elv er lengst i Sør-Amerika?", correct: "Amazonas",
                    distractors: ["Paraná", "Orinoco", "São Francisco"]),
                Raw(prompt: "Verdens største innsjø (areal)?", correct: "Kaspihavet",
                    distractors: ["Lake Superior", "Victoriasjøen", "Bajkalsjøen"]),
                Raw(prompt: "Verdens dypeste innsjø?", correct: "Bajkalsjøen",
                    distractors: ["Tanganyikasjøen", "Kaspihavet", "Lake Superior"]),
                Raw(prompt: "Hvilken elv renner gjennom Berlin?", correct: "Spree",
                    distractors: ["Rhinen", "Elben", "Donau"]),
                Raw(prompt: "Hvilken elv renner gjennom Roma?", correct: "Tiberen",
                    distractors: ["Po", "Arno", "Nilen"]),
                Raw(prompt: "Hvilken elv renner gjennom Praha?", correct: "Vltava",
                    distractors: ["Donau", "Elben", "Oder"]),
                Raw(prompt: "Største ørken i verden (varm)?", correct: "Sahara",
                    distractors: ["Gobi", "Kalahari", "Atacama"]),
                Raw(prompt: "Hvor ligger Atacama-ørkenen?", correct: "Chile",
                    distractors: ["Peru", "Argentina", "Bolivia"]),
                Raw(prompt: "Hvor ligger Gobi-ørkenen?", correct: "Mongolia",
                    distractors: ["Kasakhstan", "Iran", "Kina"]),
                Raw(prompt: "Hvilken sjø ligger mellom Tyrkia og Russland?", correct: "Svartehavet",
                    distractors: ["Kaspihavet", "Egeerhavet", "Adriaterhavet"]),
                Raw(prompt: flagPrompt, flag: "🇮🇩", correct: "Indonesia",
                    distractors: ["Polen", "Monaco", "Tonga"]),
                Raw(prompt: flagPrompt, flag: "🇹🇷", correct: "Tyrkia",
                    distractors: ["Tunisia", "Marokko", "Sveits"])
            ]

        case 10:
            return [
                Raw(prompt: "Verdens høyeste fjell?", correct: "Mount Everest",
                    distractors: ["K2", "Kanchenjunga", "Aconcagua"]),
                Raw(prompt: "Hvor ligger Mount Everest (på grensen mellom)?", correct: "Nepal og Kina",
                    distractors: ["Nepal og India", "India og Kina", "Bhutan og Kina"]),
                Raw(prompt: "Verdens nest høyeste fjell?", correct: "K2",
                    distractors: ["Kanchenjunga", "Lhotse", "Makalu"]),
                Raw(prompt: "Hvor ligger Kilimanjaro?", correct: "Tanzania",
                    distractors: ["Kenya", "Uganda", "Etiopia"]),
                Raw(prompt: "Hvilken fjellkjede deler Sør-Amerika?", correct: "Andesfjellene",
                    distractors: ["Klippene", "Pyreneene", "Alpene"]),
                Raw(prompt: "Hvilken fjellkjede ligger i Nord-Amerika (vest)?", correct: "Klippene",
                    distractors: ["Andesfjellene", "Appalachene", "Alpene"]),
                Raw(prompt: "Hvilken fjellkjede ligger Matterhorn i?", correct: "Alpene",
                    distractors: ["Pyreneene", "Karpatene", "Apenninene"]),
                Raw(prompt: "Hvor ligger Himalaya?", correct: "Asia",
                    distractors: ["Afrika", "Europa", "Sør-Amerika"]),
                Raw(prompt: "Hvor ligger Pyreneene?", correct: "Mellom Spania og Frankrike",
                    distractors: ["Mellom Italia og Sveits", "Mellom Tyskland og Polen", "Mellom Hellas og Tyrkia"]),
                Raw(prompt: "Hvilket land har flest fjell over 8000m?", correct: "Nepal",
                    distractors: ["Kina", "India", "Pakistan"]),
                Raw(prompt: "Hvor ligger Aconcagua?", correct: "Argentina",
                    distractors: ["Chile", "Peru", "Bolivia"]),
                Raw(prompt: "Hvor ligger Denali?", correct: "Alaska",
                    distractors: ["Yukon", "British Columbia", "Montana"]),
                Raw(prompt: "Hvor ligger Mont Blanc?", correct: "Frankrike og Italia",
                    distractors: ["Sveits og Italia", "Frankrike og Sveits", "Østerrike og Italia"]),
                Raw(prompt: flagPrompt, flag: "🇳🇵", correct: "Nepal",
                    distractors: ["Bhutan", "Sri Lanka", "Maldivene"]),
                Raw(prompt: flagPrompt, flag: "🇨🇭", correct: "Sveits",
                    distractors: ["Østerrike", "Liechtenstein", "Polen"])
            ]

        // MARK: Videregående — verdensdekkende

        case 11:
            return [
                Raw(prompt: "Hovedstaden i Australia?", correct: "Canberra",
                    distractors: ["Sydney", "Melbourne", "Perth"]),
                Raw(prompt: "Hovedstaden i New Zealand?", correct: "Wellington",
                    distractors: ["Auckland", "Christchurch", "Dunedin"]),
                Raw(prompt: "Hovedstaden i Tyrkia?", correct: "Ankara",
                    distractors: ["Istanbul", "Izmir", "Bursa"]),
                Raw(prompt: "Hovedstaden i Sveits?", correct: "Bern",
                    distractors: ["Zürich", "Genève", "Basel"]),
                Raw(prompt: "Hovedstaden i Russland?", correct: "Moskva",
                    distractors: ["St. Petersburg", "Kazan", "Sotsji"]),
                Raw(prompt: "Hovedstaden i Indonesia?", correct: "Jakarta",
                    distractors: ["Bali", "Surabaya", "Bandung"]),
                Raw(prompt: "Hovedstaden i Saudi-Arabia?", correct: "Riyadh",
                    distractors: ["Mekka", "Jeddah", "Medina"]),
                Raw(prompt: "Hovedstaden i Iran?", correct: "Teheran",
                    distractors: ["Isfahan", "Mashhad", "Tabriz"]),
                Raw(prompt: "Hovedstaden i Israel?", correct: "Jerusalem",
                    distractors: ["Tel Aviv", "Haifa", "Eilat"]),
                Raw(prompt: "Hovedstaden i Forenede Arabiske Emirater?", correct: "Abu Dhabi",
                    distractors: ["Dubai", "Sharjah", "Doha"]),
                Raw(prompt: flagPrompt, flag: "🇦🇺", correct: "Australia",
                    distractors: ["New Zealand", "Storbritannia", "USA"]),
                Raw(prompt: flagPrompt, flag: "🇳🇿", correct: "New Zealand",
                    distractors: ["Australia", "Storbritannia", "Fiji"]),
                Raw(prompt: flagPrompt, flag: "🇸🇦", correct: "Saudi-Arabia",
                    distractors: ["Pakistan", "Iran", "Egypt"]),
                Raw(prompt: flagPrompt, flag: "🇮🇷", correct: "Iran",
                    distractors: ["Tadsjikistan", "Italia", "India"]),
                Raw(prompt: flagPrompt, flag: "🇮🇱", correct: "Israel",
                    distractors: ["Argentina", "Hellas", "Uruguay"]),
                Raw(prompt: "Hvilken kontinent ligger Kasakhstan mest i?", correct: "Asia",
                    distractors: ["Europa", "Afrika", "Oseania"])
            ]

        case 12:
            return [
                Raw(prompt: "Hvilke land grenser til Tyskland (et av)?", correct: "Polen",
                    distractors: ["Ungarn", "Spania", "Romania"]),
                Raw(prompt: "Hvilket land grenser ikke til Frankrike?", correct: "Portugal",
                    distractors: ["Spania", "Italia", "Belgia"]),
                Raw(prompt: "Hvilket land grenser til både Russland og Kina?", correct: "Mongolia",
                    distractors: ["Kasakhstan", "Nord-Korea", "Vietnam"]),
                Raw(prompt: "Hvilket land grenser til Norge i nord?", correct: "Russland",
                    distractors: ["Sverige", "Finland", "Estland"]),
                Raw(prompt: "Hvor mange land grenser til Brasil?", correct: "10",
                    distractors: ["8", "12", "14"]),
                Raw(prompt: "Hvilket land grenser til flest land i verden?", correct: "Kina",
                    distractors: ["Russland", "Brasil", "USA"]),
                Raw(prompt: "Hvilket land grenser til Nord-Korea i sør?", correct: "Sør-Korea",
                    distractors: ["Kina", "Japan", "Russland"]),
                Raw(prompt: "Hvilket land deler øya Hispaniola med Haiti?", correct: "Dominikanske republikk",
                    distractors: ["Cuba", "Jamaica", "Puerto Rico"]),
                Raw(prompt: "Hvilket land deler øya Borneo (3 land)?", correct: "Indonesia, Malaysia, Brunei",
                    distractors: ["Indonesia, Filippinene, Malaysia", "Malaysia, Singapore, Brunei", "Indonesia, Vietnam, Malaysia"]),
                Raw(prompt: flagPrompt, flag: "🇰🇿", correct: "Kasakhstan",
                    distractors: ["Usbekistan", "Aserbajdsjan", "Kirgisistan"]),
                Raw(prompt: flagPrompt, flag: "🇲🇳", correct: "Mongolia",
                    distractors: ["Romania", "Kirgisistan", "Bhutan"]),
                Raw(prompt: flagPrompt, flag: "🇧🇩", correct: "Bangladesh",
                    distractors: ["Pakistan", "Sri Lanka", "Myanmar"]),
                Raw(prompt: flagPrompt, flag: "🇵🇰", correct: "Pakistan",
                    distractors: ["India", "Bangladesh", "Iran"]),
                Raw(prompt: flagPrompt, flag: "🇺🇦", correct: "Ukraina",
                    distractors: ["Russland", "Belarus", "Polen"]),
                Raw(prompt: flagPrompt, flag: "🇧🇾", correct: "Belarus",
                    distractors: ["Russland", "Ukraina", "Polen"])
            ]

        case 13:
            return [
                Raw(prompt: "Hvor ligger Machu Picchu?", correct: "Peru",
                    distractors: ["Bolivia", "Ecuador", "Chile"]),
                Raw(prompt: "Hvor ligger Burj Khalifa?", correct: "Dubai",
                    distractors: ["Abu Dhabi", "Riyadh", "Doha"]),
                Raw(prompt: "Hvor ligger Sagrada Família?", correct: "Barcelona",
                    distractors: ["Madrid", "Valencia", "Sevilla"]),
                Raw(prompt: "Hvor ligger Angkor Wat?", correct: "Kambodsja",
                    distractors: ["Thailand", "Vietnam", "Laos"]),
                Raw(prompt: "Hvor står Christ the Redeemer?", correct: "Rio de Janeiro",
                    distractors: ["São Paulo", "Buenos Aires", "Lima"]),
                Raw(prompt: "Hvor ligger Chichén Itzá?", correct: "Mexico",
                    distractors: ["Guatemala", "Honduras", "Belize"]),
                Raw(prompt: "Hvor står Hagia Sophia?", correct: "Istanbul",
                    distractors: ["Athen", "Jerusalem", "Roma"]),
                Raw(prompt: "Hvor ligger Forbidden City?", correct: "Beijing",
                    distractors: ["Xi'an", "Nanjing", "Shanghai"]),
                Raw(prompt: "Hvor står Sydney Opera House?", correct: "Sydney",
                    distractors: ["Melbourne", "Brisbane", "Auckland"]),
                Raw(prompt: "Hvor står Sheikh Zayed-moskeen?", correct: "Abu Dhabi",
                    distractors: ["Dubai", "Doha", "Muscat"]),
                Raw(prompt: "Hvor ligger Alhambra?", correct: "Granada",
                    distractors: ["Córdoba", "Sevilla", "Toledo"]),
                Raw(prompt: "Hvor står Stonehenge?", correct: "England",
                    distractors: ["Skottland", "Wales", "Irland"]),
                Raw(prompt: "Hvor ligger Notre-Dame?", correct: "Paris",
                    distractors: ["Roma", "Reims", "Strasbourg"]),
                Raw(prompt: flagPrompt, flag: "🇰🇭", correct: "Kambodsja",
                    distractors: ["Vietnam", "Thailand", "Laos"]),
                Raw(prompt: flagPrompt, flag: "🇵🇪", correct: "Peru",
                    distractors: ["Ecuador", "Chile", "Colombia"])
            ]

        // MARK: Universitet — vanskeligere & mer obskurt

        case 14:
            return [
                Raw(prompt: "Hovedstaden i Mongolia?", correct: "Ulaanbaatar",
                    distractors: ["Astana", "Bishkek", "Tashkent"]),
                Raw(prompt: "Hovedstaden i Kasakhstan?", correct: "Astana",
                    distractors: ["Almaty", "Tashkent", "Bishkek"]),
                Raw(prompt: "Hovedstaden i Aserbajdsjan?", correct: "Baku",
                    distractors: ["Jerevan", "Tbilisi", "Tehran"]),
                Raw(prompt: "Hovedstaden i Armenia?", correct: "Jerevan",
                    distractors: ["Tbilisi", "Baku", "Beirut"]),
                Raw(prompt: "Hovedstaden i Georgia?", correct: "Tbilisi",
                    distractors: ["Jerevan", "Baku", "Sukhumi"]),
                Raw(prompt: "Hovedstaden i Usbekistan?", correct: "Tasjkent",
                    distractors: ["Samarkand", "Bukhara", "Dusjanbe"]),
                Raw(prompt: "Hovedstaden i Sri Lanka?", correct: "Sri Jayawardenepura Kotte",
                    distractors: ["Colombo", "Kandy", "Galle"]),
                Raw(prompt: "Hovedstaden i Myanmar?", correct: "Naypyidaw",
                    distractors: ["Yangon", "Mandalay", "Bagan"]),
                Raw(prompt: "Hovedstaden i Tadsjikistan?", correct: "Dusjanbe",
                    distractors: ["Tasjkent", "Bishkek", "Asjgabat"]),
                Raw(prompt: "Hovedstaden i Kirgisistan?", correct: "Bishkek",
                    distractors: ["Almaty", "Tasjkent", "Dusjanbe"]),
                Raw(prompt: "Hovedstaden i Turkmenistan?", correct: "Asjgabat",
                    distractors: ["Bukhara", "Mary", "Tasjkent"]),
                Raw(prompt: flagPrompt, flag: "🇦🇿", correct: "Aserbajdsjan",
                    distractors: ["Tyrkia", "Tyrkmenistan", "Iran"]),
                Raw(prompt: flagPrompt, flag: "🇦🇲", correct: "Armenia",
                    distractors: ["Bulgaria", "Iran", "Russland"]),
                Raw(prompt: flagPrompt, flag: "🇬🇪", correct: "Georgia",
                    distractors: ["Armenia", "Hellas", "Aserbajdsjan"]),
                Raw(prompt: flagPrompt, flag: "🇺🇿", correct: "Usbekistan",
                    distractors: ["Kasakhstan", "Tadsjikistan", "Iran"])
            ]

        case 15:
            return [
                Raw(prompt: "Verdens største ferskvannssjø (areal)?", correct: "Lake Superior",
                    distractors: ["Victoriasjøen", "Kaspihavet", "Bajkalsjøen"]),
                Raw(prompt: "Hvilken elv renner gjennom Kairo?", correct: "Nilen",
                    distractors: ["Niger", "Kongo", "Zambezi"]),
                Raw(prompt: "Hvilken elv renner gjennom Budapest?", correct: "Donau",
                    distractors: ["Tisza", "Drava", "Sava"]),
                Raw(prompt: "Hvilken elv danner grensen mellom USA og Mexico?", correct: "Rio Grande",
                    distractors: ["Colorado", "Mississippi", "Pecos"]),
                Raw(prompt: "Hvilken elv renner gjennom Bagdad?", correct: "Tigris",
                    distractors: ["Eufrat", "Jordan", "Karun"]),
                Raw(prompt: "Hvilken elv munner ut i Det kaspiske hav?", correct: "Volga",
                    distractors: ["Ural", "Don", "Dnepr"]),
                Raw(prompt: "Hvor renner elva Limpopo?", correct: "Sør-Afrika",
                    distractors: ["Tanzania", "Angola", "Namibia"]),
                Raw(prompt: "Hvor renner elva Lena?", correct: "Russland",
                    distractors: ["Kasakhstan", "Kina", "Mongolia"]),
                Raw(prompt: "Hvilken elv er Afrikas nest lengste?", correct: "Kongo",
                    distractors: ["Niger", "Zambezi", "Limpopo"]),
                Raw(prompt: "Hvor er kilden til Nilen?", correct: "Victoriasjøen",
                    distractors: ["Tanganyikasjøen", "Tana-sjøen", "Albertsjøen"]),
                Raw(prompt: "Hvilken elv renner gjennom Kairo og Khartoum?", correct: "Nilen",
                    distractors: ["Kongo", "Niger", "Zambezi"]),
                Raw(prompt: "Hvilket fossefall er det største (vannmengde)?", correct: "Inga-fallene",
                    distractors: ["Niagara", "Iguazú", "Victoria"]),
                Raw(prompt: "Hvor ligger Iguazú-fossene?", correct: "Mellom Argentina og Brasil",
                    distractors: ["Mellom Peru og Brasil", "Mellom Bolivia og Argentina", "Mellom Chile og Argentina"]),
                Raw(prompt: "Hvor ligger Victoria-fossene?", correct: "Mellom Zambia og Zimbabwe",
                    distractors: ["Mellom Kenya og Tanzania", "Mellom Sør-Afrika og Mosambik", "Mellom Botswana og Namibia"])
            ]

        case 16:
            return [
                Raw(prompt: "Hvor ligger K2?", correct: "Pakistan",
                    distractors: ["India", "Nepal", "Kina"]),
                Raw(prompt: "Hvilken fjellkjede ligger Karpatene i?", correct: "Sentral-Europa",
                    distractors: ["Vest-Europa", "Sør-Europa", "Asia"]),
                Raw(prompt: "I hvilket land ligger Mount Fuji?", correct: "Japan",
                    distractors: ["Sør-Korea", "Kina", "Filippinene"]),
                Raw(prompt: "Hvor ligger Atlasfjellene?", correct: "Nordvest-Afrika",
                    distractors: ["Sør-Afrika", "Øst-Afrika", "Sahara"]),
                Raw(prompt: "Hvor ligger Uralfjellene?", correct: "Russland",
                    distractors: ["Kasakhstan", "Mongolia", "Ukraina"]),
                Raw(prompt: "Hvor ligger Anatolia?", correct: "Tyrkia",
                    distractors: ["Iran", "Syria", "Hellas"]),
                Raw(prompt: "Hvor ligger Patagonia?", correct: "Argentina og Chile",
                    distractors: ["Peru og Bolivia", "Brasil og Paraguay", "Uruguay og Argentina"]),
                Raw(prompt: "Hvor ligger Sibir?", correct: "Russland",
                    distractors: ["Kasakhstan", "Mongolia", "Kina"]),
                Raw(prompt: "Hvor ligger Andalusia?", correct: "Spania",
                    distractors: ["Portugal", "Italia", "Hellas"]),
                Raw(prompt: "Hvor ligger Skandinavia?", correct: "Nord-Europa",
                    distractors: ["Sentral-Europa", "Vest-Europa", "Øst-Europa"]),
                Raw(prompt: "Hvor ligger Balkan-halvøya?", correct: "Sørøst-Europa",
                    distractors: ["Sentral-Europa", "Øst-Europa", "Sør-Europa"]),
                Raw(prompt: "Hvor ligger Den arabiske halvøy?", correct: "Sørvest-Asia",
                    distractors: ["Nordøst-Afrika", "Sentral-Asia", "Sør-Asia"]),
                Raw(prompt: "Hvor ligger Den iberiske halvøy?", correct: "Spania og Portugal",
                    distractors: ["Italia og Hellas", "Frankrike og Spania", "Tyrkia og Hellas"]),
                Raw(prompt: flagPrompt, flag: "🇲🇲", correct: "Myanmar",
                    distractors: ["Sri Lanka", "Bangladesh", "Laos"]),
                Raw(prompt: flagPrompt, flag: "🇱🇰", correct: "Sri Lanka",
                    distractors: ["Bangladesh", "Maldivene", "India"])
            ]

        case 17:
            return [
                Raw(prompt: "Hvor ligger Borobudur?", correct: "Indonesia",
                    distractors: ["Malaysia", "Thailand", "Filippinene"]),
                Raw(prompt: "Hvor ligger Petronas-tårnene?", correct: "Kuala Lumpur",
                    distractors: ["Singapore", "Bangkok", "Manila"]),
                Raw(prompt: "Hvor ligger Marina Bay Sands?", correct: "Singapore",
                    distractors: ["Hong Kong", "Kuala Lumpur", "Bangkok"]),
                Raw(prompt: "Hvor ligger Mount Rushmore?", correct: "South Dakota",
                    distractors: ["Wyoming", "Montana", "Colorado"]),
                Raw(prompt: "Hvor ligger Niagarafallene?", correct: "Mellom USA og Canada",
                    distractors: ["I USA", "I Canada", "Mellom USA og Mexico"]),
                Raw(prompt: "Hvor ligger Yellowstone?", correct: "Wyoming",
                    distractors: ["Montana", "Idaho", "Colorado"]),
                Raw(prompt: "Hvor ligger Grand Canyon?", correct: "Arizona",
                    distractors: ["Utah", "Nevada", "New Mexico"]),
                Raw(prompt: "Hvor ligger Uluru (Ayers Rock)?", correct: "Australia",
                    distractors: ["New Zealand", "Sør-Afrika", "Argentina"]),
                Raw(prompt: "Hvor ligger Galápagos-øyene?", correct: "Ecuador",
                    distractors: ["Peru", "Chile", "Colombia"]),
                Raw(prompt: "Hvor ligger Påskeøya?", correct: "Chile",
                    distractors: ["Peru", "Fransk Polynesia", "Argentina"]),
                Raw(prompt: "Hvor ligger Madagaskar?", correct: "Sørøst-Afrika",
                    distractors: ["Vest-Afrika", "Det indiske hav (vest for India)", "Stillehavet"]),
                Raw(prompt: "Hvor ligger Maldivene?", correct: "Det indiske hav",
                    distractors: ["Stillehavet", "Sørkinahavet", "Atlanterhavet"]),
                Raw(prompt: flagPrompt, flag: "🇪🇨", correct: "Ecuador",
                    distractors: ["Peru", "Colombia", "Bolivia"]),
                Raw(prompt: flagPrompt, flag: "🇲🇬", correct: "Madagaskar",
                    distractors: ["Mosambik", "Tanzania", "Mauritius"]),
                Raw(prompt: flagPrompt, flag: "🇲🇻", correct: "Maldivene",
                    distractors: ["Sri Lanka", "Bahrain", "Tyrkia"])
            ]

        case 18:
            return [
                Raw(prompt: "Hovedstaden i Bhutan?", correct: "Thimphu",
                    distractors: ["Paro", "Kathmandu", "Dhaka"]),
                Raw(prompt: "Hovedstaden i Eritrea?", correct: "Asmara",
                    distractors: ["Addis Abeba", "Khartoum", "Djibouti"]),
                Raw(prompt: "Hovedstaden i Surinam?", correct: "Paramaribo",
                    distractors: ["Cayenne", "Georgetown", "Port-of-Spain"]),
                Raw(prompt: "Hovedstaden i Lesotho?", correct: "Maseru",
                    distractors: ["Mbabane", "Gaborone", "Lilongwe"]),
                Raw(prompt: "Hovedstaden i Vanuatu?", correct: "Port Vila",
                    distractors: ["Suva", "Apia", "Honiara"]),
                Raw(prompt: "Hovedstaden i Kiribati?", correct: "Tarawa",
                    distractors: ["Funafuti", "Majuro", "Palikir"]),
                Raw(prompt: "Hovedstaden i Liechtenstein?", correct: "Vaduz",
                    distractors: ["Luxembourg", "Andorra la Vella", "San Marino"]),
                Raw(prompt: "Hovedstaden i Andorra?", correct: "Andorra la Vella",
                    distractors: ["Vaduz", "Monaco", "San Marino"]),
                Raw(prompt: "Hovedstaden i Monaco?", correct: "Monaco",
                    distractors: ["Monte Carlo", "Nice", "Genova"]),
                Raw(prompt: "Hovedstaden i San Marino?", correct: "San Marino",
                    distractors: ["Vaduz", "Andorra la Vella", "Roma"]),
                Raw(prompt: "Hovedstaden i Brunei?", correct: "Bandar Seri Begawan",
                    distractors: ["Kuala Lumpur", "Manila", "Singapore"]),
                Raw(prompt: "Hovedstaden i Øst-Timor?", correct: "Dili",
                    distractors: ["Jakarta", "Bali", "Manila"]),
                Raw(prompt: "Hovedstaden i Bahrain?", correct: "Manama",
                    distractors: ["Doha", "Dubai", "Riyadh"]),
                Raw(prompt: flagPrompt, flag: "🇧🇹", correct: "Bhutan",
                    distractors: ["Nepal", "Mongolia", "Tibet"]),
                Raw(prompt: flagPrompt, flag: "🇪🇷", correct: "Eritrea",
                    distractors: ["Etiopia", "Sudan", "Djibouti"])
            ]

        case 19:
            return [
                Raw(prompt: "Hvilken stat er omsluttet av Sør-Afrika?", correct: "Lesotho",
                    distractors: ["Eswatini", "Botswana", "Zimbabwe"]),
                Raw(prompt: "Verdens minste land etter areal?", correct: "Vatikanstaten",
                    distractors: ["Monaco", "San Marino", "Tuvalu"]),
                Raw(prompt: "Verdens høyest beliggende hovedstad?", correct: "La Paz",
                    distractors: ["Quito", "Bogotá", "Lhasa"]),
                Raw(prompt: "Hvilket land har flest tidssoner?", correct: "Frankrike",
                    distractors: ["Russland", "USA", "Storbritannia"]),
                Raw(prompt: "Hvilket land har lengst kystlinje?", correct: "Canada",
                    distractors: ["Russland", "Indonesia", "Australia"]),
                Raw(prompt: "Hvilken elv krysser flest land?", correct: "Donau",
                    distractors: ["Nilen", "Kongo", "Mekong"]),
                Raw(prompt: "Hvilket hav er saltest?", correct: "Dødehavet",
                    distractors: ["Rødehavet", "Middelhavet", "Karibhavet"]),
                Raw(prompt: "Hvilket land har størst befolkning?", correct: "India",
                    distractors: ["Kina", "USA", "Indonesia"]),
                Raw(prompt: "Hvilket land har størst flateareal?", correct: "Russland",
                    distractors: ["Canada", "Kina", "USA"]),
                Raw(prompt: "Hvilket land har flest naboland?", correct: "Kina",
                    distractors: ["Russland", "Brasil", "Tyskland"]),
                Raw(prompt: "Hvilken by er verdens folkerikeste storbyområde?", correct: "Tokyo",
                    distractors: ["Delhi", "Shanghai", "São Paulo"]),
                Raw(prompt: "Hvilket land er omsluttet av Italia?", correct: "San Marino",
                    distractors: ["Vatikanstaten", "Monaco", "Andorra"]),
                Raw(prompt: "Hvilket land er det eneste som ligger på kun én lengdegrad-halvkule?", correct: "Kiribati",
                    distractors: ["Russland", "USA", "Fiji"]),
                Raw(prompt: flagPrompt, flag: "🇻🇦", correct: "Vatikanstaten",
                    distractors: ["San Marino", "Monaco", "Italia"]),
                Raw(prompt: flagPrompt, flag: "🇲🇨", correct: "Monaco",
                    distractors: ["Indonesia", "Polen", "Frankrike"])
            ]

        default:
            return [
                Raw(prompt: "Hvor ligger Socotra-øya?", correct: "Jemen",
                    distractors: ["Oman", "Somalia", "Eritrea"]),
                Raw(prompt: "Hvor ligger Timbuktu?", correct: "Mali",
                    distractors: ["Niger", "Mauritania", "Burkina Faso"]),
                Raw(prompt: "Hovedstaden i Nauru?", correct: "Yaren",
                    distractors: ["Funafuti", "Tarawa", "Palikir"]),
                Raw(prompt: "Hovedstaden i Tuvalu?", correct: "Funafuti",
                    distractors: ["Tarawa", "Yaren", "Apia"]),
                Raw(prompt: "Hovedstaden i Mikronesia?", correct: "Palikir",
                    distractors: ["Majuro", "Yaren", "Koror"]),
                Raw(prompt: "Hovedstaden i Komorene?", correct: "Moroni",
                    distractors: ["Antananarivo", "Victoria", "Port Louis"]),
                Raw(prompt: "Hovedstaden i Sao Tome og Príncipe?", correct: "São Tomé",
                    distractors: ["Malabo", "Libreville", "Brazzaville"]),
                Raw(prompt: "Hovedstaden i Djibouti?", correct: "Djibouti",
                    distractors: ["Asmara", "Mogadishu", "Hargeisa"]),
                Raw(prompt: "Hvilket land ble dannet i 2011?", correct: "Sør-Sudan",
                    distractors: ["Eritrea", "Kosovo", "Sør-Ossetia"]),
                Raw(prompt: "Hvilket land het tidligere Burma?", correct: "Myanmar",
                    distractors: ["Thailand", "Vietnam", "Bangladesh"]),
                Raw(prompt: "Hvilket land het tidligere Ceylon?", correct: "Sri Lanka",
                    distractors: ["Maldivene", "Bangladesh", "India"]),
                Raw(prompt: "Hvilket land het tidligere Zaire?", correct: "DR Kongo",
                    distractors: ["Republikken Kongo", "Angola", "Sør-Sudan"]),
                Raw(prompt: flagPrompt, flag: "🇸🇨", correct: "Seychellene",
                    distractors: ["Komorene", "Mauritius", "Madagaskar"]),
                Raw(prompt: flagPrompt, flag: "🇫🇯", correct: "Fiji",
                    distractors: ["Samoa", "Tonga", "Vanuatu"]),
                Raw(prompt: flagPrompt, flag: "🇰🇮", correct: "Kiribati",
                    distractors: ["Tuvalu", "Marshalløyene", "Nauru"])
            ]
        }
    }
    // swiftlint:enable function_body_length file_length
}
