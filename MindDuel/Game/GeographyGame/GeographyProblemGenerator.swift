import Foundation

/// Geography questions covering capitals, countries, continents, flags,
/// neighbours, cities, rivers, landmarks and famous buildings (#45/#52).
/// Same 20-level curriculum scheme as math/chemistry — easier categories
/// and Nordic/European focus on low levels, expanding to global +
/// obscure trivia at the top.
enum GeographyProblemGenerator {

    /// Recent question identities (correct answers), kept so we don't repeat
    /// the same question within a short window (#64). Identifying by `correct`
    /// — not `prompt` — distinguishes flag questions which all share one prompt
    /// text but differ by country. Keeps the last 3 to avoid both back-to-back
    /// duplicates and ABAB cycling at small pool sizes.
    private static var recentCorrects: [String] = []
    private static let recentWindow = 3

    static func generate(level: Int = 1) -> GeographyProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        var candidates = pool.filter { !recentCorrects.contains($0.correct) }
        if candidates.isEmpty { candidates = pool }
        let raw = candidates.randomElement() ?? pool[0]
        recentCorrects.append(raw.correct)
        if recentCorrects.count > recentWindow {
            recentCorrects.removeFirst(recentCorrects.count - recentWindow)
        }
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

    // swiftlint:disable function_body_length
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
                Raw(prompt: flagPrompt, flag: "🇳🇴", correct: "Norge",
                    distractors: ["Sverige", "Island", "Danmark"]),
                Raw(prompt: "Hvilken kontinent ligger Norge i?", correct: "Europa",
                    distractors: ["Asia", "Afrika", "Nord-Amerika"])
            ]

        case 2:
            return [
                Raw(prompt: "Hovedstaden i Island?", correct: "Reykjavík",
                    distractors: ["Akureyri", "Tórshavn", "Nuuk"]),
                Raw(prompt: flagPrompt, flag: "🇸🇪", correct: "Sverige",
                    distractors: ["Finland", "Norge", "Danmark"]),
                Raw(prompt: flagPrompt, flag: "🇩🇰", correct: "Danmark",
                    distractors: ["Norge", "Island", "Sveits"]),
                Raw(prompt: flagPrompt, flag: "🇫🇮", correct: "Finland",
                    distractors: ["Sverige", "Estland", "Hellas"]),
                Raw(prompt: "I hvilket land ligger Stockholm?", correct: "Sverige",
                    distractors: ["Norge", "Finland", "Danmark"]),
                Raw(prompt: "Norges nordligste by?", correct: "Hammerfest",
                    distractors: ["Tromsø", "Bodø", "Alta"])
            ]

        case 3:
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
                Raw(prompt: flagPrompt, flag: "🇩🇪", correct: "Tyskland",
                    distractors: ["Belgia", "Østerrike", "Nederland"])
            ]

        case 4:
            return [
                Raw(prompt: "Hovedstaden i Nederland?", correct: "Amsterdam",
                    distractors: ["Rotterdam", "Haag", "Utrecht"]),
                Raw(prompt: "Hovedstaden i Belgia?", correct: "Brussel",
                    distractors: ["Antwerpen", "Brugge", "Gent"]),
                Raw(prompt: "Hovedstaden i Portugal?", correct: "Lisboa",
                    distractors: ["Porto", "Madrid", "Faro"]),
                Raw(prompt: "Hovedstaden i Hellas?", correct: "Athen",
                    distractors: ["Thessaloniki", "Sparta", "Patras"]),
                Raw(prompt: "Hovedstaden i Polen?", correct: "Warszawa",
                    distractors: ["Kraków", "Gdańsk", "Wrocław"]),
                Raw(prompt: "Hovedstaden i Østerrike?", correct: "Wien",
                    distractors: ["Salzburg", "Graz", "Linz"])
            ]

        case 5:
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
                    distractors: ["Asia", "Antarktis", "Afrika"])
            ]

        case 6:
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
                    distractors: ["Valparaíso", "Concepción", "Antofagasta"])
            ]

        case 7:
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
                    distractors: ["Ho Chi Minh-byen", "Da Nang", "Hue"])
            ]

        case 8:
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
                    distractors: ["Asmara", "Khartoum", "Mogadishu"])
            ]

        case 9:
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
                    distractors: ["Pakistan", "Bangladesh", "Iran"])
            ]

        case 10:
            return [
                Raw(prompt: "Verdens lengste elv?", correct: "Nilen",
                    distractors: ["Amazonas", "Yangtze", "Mississippi"]),
                Raw(prompt: "I hvilket land renner Donau ut?", correct: "Romania",
                    distractors: ["Ungarn", "Bulgaria", "Ukraina"]),
                Raw(prompt: "Hvilken elv renner gjennom Paris?", correct: "Seinen",
                    distractors: ["Loire", "Rhone", "Themsen"]),
                Raw(prompt: "Hvilken elv renner gjennom London?", correct: "Themsen",
                    distractors: ["Severn", "Mersey", "Seinen"]),
                Raw(prompt: "Hvilken elv renner gjennom Wien?", correct: "Donau",
                    distractors: ["Rhinen", "Elben", "Inn"]),
                Raw(prompt: "Hvilken elv er lengst i Sør-Amerika?", correct: "Amazonas",
                    distractors: ["Paraná", "Orinoco", "São Francisco"])
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
                Raw(prompt: flagPrompt, flag: "🇨🇭", correct: "Sveits",
                    distractors: ["Østerrike", "Liechtenstein", "Polen"]),
                Raw(prompt: flagPrompt, flag: "🇧🇷", correct: "Brasil",
                    distractors: ["Argentina", "Colombia", "Mexico"]),
                Raw(prompt: flagPrompt, flag: "🇿🇦", correct: "Sør-Afrika",
                    distractors: ["Kenya", "Etiopia", "Nigeria"]),
                Raw(prompt: flagPrompt, flag: "🇰🇷", correct: "Sør-Korea",
                    distractors: ["Japan", "Nord-Korea", "Kina"])
            ]

        case 13:
            return [
                Raw(prompt: "Hvor ligger Machu Picchu?", correct: "Peru",
                    distractors: ["Bolivia", "Ecuador", "Chile"]),
                Raw(prompt: "Hvor ligger Kreml?", correct: "Moskva",
                    distractors: ["St. Petersburg", "Kiev", "Minsk"]),
                Raw(prompt: "Hvor ligger Akropolis?", correct: "Athen",
                    distractors: ["Roma", "Istanbul", "Sparta"]),
                Raw(prompt: "Hvor ligger Burj Khalifa?", correct: "Dubai",
                    distractors: ["Abu Dhabi", "Riyadh", "Doha"]),
                Raw(prompt: "Hvor ligger Sagrada Família?", correct: "Barcelona",
                    distractors: ["Madrid", "Valencia", "Sevilla"]),
                Raw(prompt: "Hvor ligger Petra?", correct: "Jordan",
                    distractors: ["Egypt", "Israel", "Saudi-Arabia"]),
                Raw(prompt: "Hvor ligger Angkor Wat?", correct: "Kambodsja",
                    distractors: ["Thailand", "Vietnam", "Laos"])
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
                    distractors: ["Colombo", "Kandy", "Galle"])
            ]

        case 15:
            return [
                Raw(prompt: "Verdens største ferskvannssjø (areal)?", correct: "Lake Superior",
                    distractors: ["Victoriasjøen", "Kaspihavet", "Bajkalsjøen"]),
                Raw(prompt: "Verdens dypeste innsjø?", correct: "Bajkalsjøen",
                    distractors: ["Tanganyikasjøen", "Kaspihavet", "Caspian"]),
                Raw(prompt: "Hvilken elv renner gjennom Kairo?", correct: "Nilen",
                    distractors: ["Niger", "Kongo", "Zambezi"]),
                Raw(prompt: "Hvilken elv renner gjennom Budapest?", correct: "Donau",
                    distractors: ["Tisza", "Drava", "Sava"]),
                Raw(prompt: "Hvilken elv danner grensen mellom USA og Mexico?", correct: "Rio Grande",
                    distractors: ["Colorado", "Mississippi", "Pecos"]),
                Raw(prompt: "Hvilken elv renner gjennom Bagdad?", correct: "Tigris",
                    distractors: ["Eufrat", "Jordan", "Karun"]),
                Raw(prompt: "Hvilken elv munner ut i Det kaspiske hav?", correct: "Volga",
                    distractors: ["Ural", "Don", "Dnepr"])
            ]

        case 16:
            return [
                Raw(prompt: "Hvor ligger Mount Everest (på grensen mellom)?", correct: "Nepal og Kina",
                    distractors: ["Nepal og India", "India og Kina", "Bhutan og Kina"]),
                Raw(prompt: "Hvor ligger K2?", correct: "Pakistan",
                    distractors: ["India", "Nepal", "Kina"]),
                Raw(prompt: "Hvor ligger Kilimanjaro?", correct: "Tanzania",
                    distractors: ["Kenya", "Uganda", "Etiopia"]),
                Raw(prompt: "Hvor ligger Aconcagua?", correct: "Argentina",
                    distractors: ["Chile", "Peru", "Bolivia"]),
                Raw(prompt: "Hvor ligger Denali?", correct: "Alaska",
                    distractors: ["Yukon", "British Columbia", "Montana"]),
                Raw(prompt: "Hvor ligger Mont Blanc?", correct: "Frankrike og Italia",
                    distractors: ["Sveits og Italia", "Frankrike og Sveits", "Østerrike og Italia"]),
                Raw(prompt: "Hvilken fjellkjede ligger Matterhorn i?", correct: "Alpene",
                    distractors: ["Pyreneene", "Karpatene", "Apenninene"])
            ]

        case 17:
            return [
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
                    distractors: ["Córdoba", "Sevilla", "Toledo"])
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
                    distractors: ["Luxembourg", "Andorra la Vella", "San Marino"])
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
                    distractors: ["Rødehavet", "Middelhavet", "Karibhavet"])
            ]

        default:
            return [
                Raw(prompt: flagPrompt, flag: "🇧🇹", correct: "Bhutan",
                    distractors: ["Nepal", "Mongolia", "Tibet"]),
                Raw(prompt: flagPrompt, flag: "🇰🇿", correct: "Kasakhstan",
                    distractors: ["Usbekistan", "Aserbajdsjan", "Kirgisistan"]),
                Raw(prompt: "Hvor ligger Socotra-øya?", correct: "Jemen",
                    distractors: ["Oman", "Somalia", "Eritrea"]),
                Raw(prompt: "Hvor renner elva Limpopo?", correct: "Sør-Afrika",
                    distractors: ["Tanzania", "Angola", "Namibia"]),
                Raw(prompt: "Hvor ligger Borobudur?", correct: "Indonesia",
                    distractors: ["Malaysia", "Thailand", "Filippinene"]),
                Raw(prompt: "Hvilket land deler øya Hispaniola med Haiti?", correct: "Dominikanske republikk",
                    distractors: ["Cuba", "Jamaica", "Puerto Rico"]),
                Raw(prompt: "Hvor ligger Timbuktu?", correct: "Mali",
                    distractors: ["Niger", "Mauritania", "Burkina Faso"]),
                Raw(prompt: "Hvor renner elva Lena?", correct: "Russland",
                    distractors: ["Kasakhstan", "Kina", "Mongolia"]),
                Raw(prompt: "Hovedstaden i Nauru?", correct: "Yaren",
                    distractors: ["Funafuti", "Tarawa", "Palikir"])
            ]
        }
    }
    // swiftlint:enable function_body_length
}
