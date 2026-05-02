import Foundation

/// Extended attributes for a country, used by `GeographyProblemGenerator`
/// to generate culture/society/geography/code/trivia questions on top of
/// the core capital/flag/continent set. All fields are optional — the
/// generator only emits a question type when the relevant field is set,
/// so partial data is fine.
struct CountryExtras {
    var iso3: String? = nil
    var currency: String? = nil
    var currencySymbol: String? = nil
    var language: String? = nil
    var biggestCity: String? = nil           // when ≠ capital
    var phoneCode: String? = nil
    var drivingSide: String? = nil           // "Høyre" / "Venstre"
    var government: String? = nil
    var religion: String? = nil
    var landlocked: Bool? = nil
    var transcontinental: Bool? = nil
    var equatorCrosses: Bool? = nil
    var hemisphereNS: String? = nil          // "Nord" / "Sør" / "Begge"
    var utcOffset: String? = nil             // "+1" / "-5"
    var endonym: String? = nil               // "Deutschland", "Nippon"
    var neighbors: [String]? = nil
    var nationalDish: String? = nil
    var nationalSport: String? = nil
    var nationalAnimal: String? = nil
    var highestPoint: String? = nil
    var longestRiver: String? = nil
    var independenceYear: Int? = nil

    static func lookup(iso: String) -> CountryExtras? {
        byISO[iso.lowercased()]
    }

    // swiftlint:disable function_body_length
    static let byISO: [String: CountryExtras] = [
        "no": CountryExtras(
            iso3: "NOR", currency: "Norske kroner", currencySymbol: "kr",
            language: "Norsk", phoneCode: "+47", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", religion: "Kristendom",
            landlocked: false, transcontinental: false, equatorCrosses: false,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Sverige", "Finland", "Russland"],
            nationalDish: "Fårikål", nationalSport: "Langrenn",
            nationalAnimal: "Elg", highestPoint: "Galdhøpiggen",
            longestRiver: "Glomma", independenceYear: 1905
        ),
        "se": CountryExtras(
            iso3: "SWE", currency: "Svenske kroner", currencySymbol: "kr",
            language: "Svensk", phoneCode: "+46", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Norge", "Finland"],
            nationalDish: "Köttbullar", nationalSport: "Ishockey",
            nationalAnimal: "Elg", highestPoint: "Kebnekaise"
        ),
        "dk": CountryExtras(
            iso3: "DNK", currency: "Danske kroner", currencySymbol: "kr",
            language: "Dansk", phoneCode: "+45", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Tyskland"],
            nationalDish: "Smørrebrød", nationalSport: "Håndball"
        ),
        "fi": CountryExtras(
            iso3: "FIN", currency: "Euro", currencySymbol: "€",
            language: "Finsk", phoneCode: "+358", drivingSide: "Høyre",
            government: "Republikk", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+2",
            endonym: "Suomi", neighbors: ["Norge", "Sverige", "Russland"]
        ),
        "is": CountryExtras(
            iso3: "ISL", currency: "Islandske kroner", currencySymbol: "kr",
            language: "Islandsk", phoneCode: "+354", drivingSide: "Høyre",
            government: "Republikk", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+0",
            endonym: "Ísland", neighbors: []
        ),
        "de": CountryExtras(
            iso3: "DEU", currency: "Euro", currencySymbol: "€",
            language: "Tysk", biggestCity: "Berlin", phoneCode: "+49",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "Deutschland",
            neighbors: ["Frankrike", "Polen", "Tsjekkia", "Østerrike", "Sveits", "Nederland", "Belgia", "Luxembourg", "Danmark"],
            nationalDish: "Bratwurst", nationalSport: "Fotball"
        ),
        "fr": CountryExtras(
            iso3: "FRA", currency: "Euro", currencySymbol: "€",
            language: "Fransk", biggestCity: "Paris", phoneCode: "+33",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Spania", "Italia", "Sveits", "Tyskland", "Belgia", "Luxembourg", "Monaco", "Andorra"],
            nationalDish: "Croissant", nationalSport: "Fotball"
        ),
        "gb": CountryExtras(
            iso3: "GBR", currency: "Pund sterling", currencySymbol: "£",
            language: "Engelsk", biggestCity: "London", phoneCode: "+44",
            drivingSide: "Venstre", government: "Konstitusjonelt monarki",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+0",
            neighbors: ["Irland"],
            nationalDish: "Fish and chips", nationalSport: "Fotball"
        ),
        "es": CountryExtras(
            iso3: "ESP", currency: "Euro", currencySymbol: "€",
            language: "Spansk", biggestCity: "Madrid", phoneCode: "+34",
            drivingSide: "Høyre", government: "Konstitusjonelt monarki",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "España",
            neighbors: ["Portugal", "Frankrike", "Andorra", "Marokko"],
            nationalDish: "Paella", nationalSport: "Fotball"
        ),
        "it": CountryExtras(
            iso3: "ITA", currency: "Euro", currencySymbol: "€",
            language: "Italiensk", biggestCity: "Roma", phoneCode: "+39",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "Italia",
            neighbors: ["Frankrike", "Sveits", "Østerrike", "Slovenia", "San Marino", "Vatikanstaten"],
            nationalDish: "Pizza", nationalSport: "Fotball"
        ),
        "nl": CountryExtras(
            iso3: "NLD", currency: "Euro", currencySymbol: "€",
            language: "Nederlandsk", biggestCity: "Amsterdam", phoneCode: "+31",
            drivingSide: "Høyre", government: "Konstitusjonelt monarki",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "Nederland",
            neighbors: ["Tyskland", "Belgia"]
        ),
        "be": CountryExtras(
            iso3: "BEL", currency: "Euro", currencySymbol: "€",
            language: "Nederlandsk/Fransk", phoneCode: "+32",
            drivingSide: "Høyre", government: "Konstitusjonelt monarki",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Frankrike", "Nederland", "Tyskland", "Luxembourg"]
        ),
        "pt": CountryExtras(
            iso3: "PRT", currency: "Euro", currencySymbol: "€",
            language: "Portugisisk", biggestCity: "Lisboa", phoneCode: "+351",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+0",
            neighbors: ["Spania"]
        ),
        "gr": CountryExtras(
            iso3: "GRC", currency: "Euro", currencySymbol: "€",
            language: "Gresk", phoneCode: "+30", drivingSide: "Høyre",
            government: "Republikk", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+2",
            endonym: "Elláda", neighbors: ["Albania", "Nord-Makedonia", "Bulgaria", "Tyrkia"]
        ),
        "pl": CountryExtras(
            iso3: "POL", currency: "Złoty", currencySymbol: "zł",
            language: "Polsk", phoneCode: "+48", drivingSide: "Høyre",
            government: "Republikk", religion: "Kristendom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1",
            endonym: "Polska", neighbors: ["Tyskland", "Tsjekkia", "Slovakia", "Ukraina", "Belarus", "Litauen", "Russland"]
        ),
        "at": CountryExtras(
            iso3: "AUT", currency: "Euro", currencySymbol: "€",
            language: "Tysk", phoneCode: "+43", drivingSide: "Høyre",
            government: "Republikk", religion: "Kristendom",
            landlocked: true, hemisphereNS: "Nord", utcOffset: "+1",
            endonym: "Österreich",
            neighbors: ["Tyskland", "Tsjekkia", "Slovakia", "Ungarn", "Slovenia", "Italia", "Sveits", "Liechtenstein"]
        ),
        "ie": CountryExtras(
            iso3: "IRL", currency: "Euro", currencySymbol: "€",
            language: "Engelsk/Irsk", phoneCode: "+353",
            drivingSide: "Venstre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+0", endonym: "Éire",
            neighbors: ["Storbritannia"]
        ),
        "cz": CountryExtras(
            iso3: "CZE", currency: "Tsjekkiske kroner", currencySymbol: "Kč",
            language: "Tsjekkisk", phoneCode: "+420", drivingSide: "Høyre",
            government: "Republikk", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "Česko",
            neighbors: ["Tyskland", "Polen", "Slovakia", "Østerrike"]
        ),
        "hu": CountryExtras(
            iso3: "HUN", currency: "Forint", currencySymbol: "Ft",
            language: "Ungarsk", phoneCode: "+36", drivingSide: "Høyre",
            government: "Republikk", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+1", endonym: "Magyarország",
            neighbors: ["Østerrike", "Slovakia", "Ukraina", "Romania", "Serbia", "Kroatia", "Slovenia"]
        ),
        "ch": CountryExtras(
            iso3: "CHE", currency: "Sveitsiske franc", currencySymbol: "CHF",
            language: "Tysk/Fransk/Italiensk", phoneCode: "+41",
            drivingSide: "Høyre", government: "Forbundsrepublikk",
            landlocked: true, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Tyskland", "Frankrike", "Italia", "Østerrike", "Liechtenstein"]
        ),
        "ru": CountryExtras(
            iso3: "RUS", currency: "Russiske rubler", currencySymbol: "₽",
            language: "Russisk", biggestCity: "Moskva", phoneCode: "+7",
            drivingSide: "Høyre", government: "Republikk",
            landlocked: false, transcontinental: true,
            hemisphereNS: "Nord", utcOffset: "+3 til +12",
            endonym: "Rossiya",
            neighbors: ["Norge", "Finland", "Estland", "Latvia", "Litauen", "Polen", "Belarus", "Ukraina", "Georgia", "Aserbajdsjan", "Kasakhstan", "Kina", "Mongolia", "Nord-Korea"]
        ),
        "tr": CountryExtras(
            iso3: "TUR", currency: "Tyrkiske lira", currencySymbol: "₺",
            language: "Tyrkisk", biggestCity: "Istanbul", phoneCode: "+90",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Islam", landlocked: false, transcontinental: true,
            hemisphereNS: "Nord", utcOffset: "+3", endonym: "Türkiye",
            neighbors: ["Hellas", "Bulgaria", "Georgia", "Armenia", "Aserbajdsjan", "Iran", "Irak", "Syria"]
        ),
        "us": CountryExtras(
            iso3: "USA", currency: "Amerikanske dollar", currencySymbol: "$",
            language: "Engelsk", biggestCity: "New York", phoneCode: "+1",
            drivingSide: "Høyre", government: "Forbundsrepublikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "-5 til -10",
            neighbors: ["Canada", "Mexico"],
            nationalDish: "Hamburger", nationalSport: "Amerikansk fotball"
        ),
        "ca": CountryExtras(
            iso3: "CAN", currency: "Kanadiske dollar", currencySymbol: "$",
            language: "Engelsk/Fransk", biggestCity: "Toronto", phoneCode: "+1",
            drivingSide: "Høyre", government: "Konstitusjonelt monarki",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "-3.5 til -8",
            neighbors: ["USA"],
            nationalSport: "Ishockey", nationalAnimal: "Bever"
        ),
        "mx": CountryExtras(
            iso3: "MEX", currency: "Meksikanske peso", currencySymbol: "$",
            language: "Spansk", biggestCity: "Mexico by", phoneCode: "+52",
            drivingSide: "Høyre", government: "Forbundsrepublikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "-6",
            endonym: "México",
            neighbors: ["USA", "Guatemala", "Belize"]
        ),
        "br": CountryExtras(
            iso3: "BRA", currency: "Brasilianske real", currencySymbol: "R$",
            language: "Portugisisk", biggestCity: "São Paulo", phoneCode: "+55",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            equatorCrosses: true, hemisphereNS: "Begge",
            utcOffset: "-2 til -5", endonym: "Brasil",
            neighbors: ["Argentina", "Bolivia", "Colombia", "Guyana", "Paraguay", "Peru", "Surinam", "Uruguay", "Venezuela", "Fransk Guyana"],
            nationalDish: "Feijoada", nationalSport: "Fotball"
        ),
        "ar": CountryExtras(
            iso3: "ARG", currency: "Argentinske peso", currencySymbol: "$",
            language: "Spansk", biggestCity: "Buenos Aires", phoneCode: "+54",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Sør", utcOffset: "-3",
            neighbors: ["Bolivia", "Brasil", "Chile", "Paraguay", "Uruguay"],
            nationalSport: "Fotball"
        ),
        "cl": CountryExtras(
            iso3: "CHL", currency: "Chilenske peso", currencySymbol: "$",
            language: "Spansk", biggestCity: "Santiago", phoneCode: "+56",
            drivingSide: "Høyre", government: "Republikk",
            landlocked: false, hemisphereNS: "Sør", utcOffset: "-4",
            neighbors: ["Peru", "Bolivia", "Argentina"]
        ),
        "co": CountryExtras(
            iso3: "COL", currency: "Colombianske peso", currencySymbol: "$",
            language: "Spansk", biggestCity: "Bogotá", phoneCode: "+57",
            drivingSide: "Høyre", government: "Republikk",
            landlocked: false, equatorCrosses: true, hemisphereNS: "Begge",
            utcOffset: "-5",
            neighbors: ["Brasil", "Ecuador", "Panama", "Peru", "Venezuela"]
        ),
        "pe": CountryExtras(
            iso3: "PER", currency: "Peruanske sol", currencySymbol: "S/",
            language: "Spansk", phoneCode: "+51", drivingSide: "Høyre",
            government: "Republikk", landlocked: false,
            hemisphereNS: "Sør", utcOffset: "-5",
            neighbors: ["Ecuador", "Colombia", "Brasil", "Bolivia", "Chile"]
        ),
        "jp": CountryExtras(
            iso3: "JPN", currency: "Japanske yen", currencySymbol: "¥",
            language: "Japansk", biggestCity: "Tokyo", phoneCode: "+81",
            drivingSide: "Venstre", government: "Konstitusjonelt monarki",
            religion: "Shinto/Buddhisme", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+9", endonym: "Nippon",
            neighbors: [],
            nationalDish: "Sushi", nationalSport: "Sumo"
        ),
        "cn": CountryExtras(
            iso3: "CHN", currency: "Yuan", currencySymbol: "¥",
            language: "Mandarin", biggestCity: "Shanghai", phoneCode: "+86",
            drivingSide: "Høyre", government: "Ettpartistat",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+8",
            endonym: "Zhōngguó",
            neighbors: ["Russland", "Mongolia", "Nord-Korea", "Vietnam", "Laos", "Myanmar", "India", "Bhutan", "Nepal", "Pakistan", "Afghanistan", "Tadsjikistan", "Kirgisistan", "Kasakhstan"]
        ),
        "kr": CountryExtras(
            iso3: "KOR", currency: "Sør-koreanske won", currencySymbol: "₩",
            language: "Koreansk", biggestCity: "Seoul", phoneCode: "+82",
            drivingSide: "Høyre", government: "Republikk",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+9",
            neighbors: ["Nord-Korea"]
        ),
        "kp": CountryExtras(
            iso3: "PRK", currency: "Nord-koreanske won", currencySymbol: "₩",
            language: "Koreansk", phoneCode: "+850", drivingSide: "Høyre",
            government: "Ettpartistat", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+9",
            neighbors: ["Sør-Korea", "Kina", "Russland"]
        ),
        "in": CountryExtras(
            iso3: "IND", currency: "Indiske rupi", currencySymbol: "₹",
            language: "Hindi/Engelsk", biggestCity: "Mumbai", phoneCode: "+91",
            drivingSide: "Venstre", government: "Republikk",
            religion: "Hinduisme", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+5.5", endonym: "Bhārat",
            neighbors: ["Pakistan", "Kina", "Nepal", "Bhutan", "Bangladesh", "Myanmar"],
            nationalSport: "Hockey"
        ),
        "pk": CountryExtras(
            iso3: "PAK", currency: "Pakistanske rupi", currencySymbol: "₨",
            language: "Urdu", phoneCode: "+92", drivingSide: "Venstre",
            government: "Republikk", religion: "Islam",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+5",
            neighbors: ["India", "Kina", "Afghanistan", "Iran"]
        ),
        "id": CountryExtras(
            iso3: "IDN", currency: "Indonesiske rupiah", currencySymbol: "Rp",
            language: "Indonesisk", biggestCity: "Jakarta", phoneCode: "+62",
            drivingSide: "Venstre", government: "Republikk",
            religion: "Islam", landlocked: false, transcontinental: true,
            equatorCrosses: true, hemisphereNS: "Begge",
            utcOffset: "+7 til +9",
            neighbors: ["Malaysia", "Papua Ny-Guinea", "Øst-Timor"]
        ),
        "th": CountryExtras(
            iso3: "THA", currency: "Baht", currencySymbol: "฿",
            language: "Thai", phoneCode: "+66", drivingSide: "Venstre",
            government: "Konstitusjonelt monarki", religion: "Buddhisme",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+7",
            neighbors: ["Myanmar", "Laos", "Kambodsja", "Malaysia"]
        ),
        "vn": CountryExtras(
            iso3: "VNM", currency: "Đồng", currencySymbol: "₫",
            language: "Vietnamesisk", biggestCity: "Ho Chi Minh-byen",
            phoneCode: "+84", drivingSide: "Høyre",
            government: "Ettpartistat", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+7", endonym: "Việt Nam",
            neighbors: ["Kina", "Laos", "Kambodsja"]
        ),
        "sg": CountryExtras(
            iso3: "SGP", currency: "Singapore-dollar", currencySymbol: "S$",
            language: "Engelsk/Mandarin/Malay/Tamil", phoneCode: "+65",
            drivingSide: "Venstre", government: "Republikk",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+8",
            neighbors: []
        ),
        "my": CountryExtras(
            iso3: "MYS", currency: "Ringgit", currencySymbol: "RM",
            language: "Malaysisk", phoneCode: "+60", drivingSide: "Venstre",
            government: "Konstitusjonelt monarki", religion: "Islam",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+8",
            neighbors: ["Thailand", "Indonesia", "Brunei", "Singapore"]
        ),
        "ph": CountryExtras(
            iso3: "PHL", currency: "Filippinske peso", currencySymbol: "₱",
            language: "Filippinsk/Engelsk", phoneCode: "+63",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Kristendom", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+8"
        ),
        "sa": CountryExtras(
            iso3: "SAU", currency: "Saudi-arabiske rial", currencySymbol: "ر.س",
            language: "Arabisk", phoneCode: "+966", drivingSide: "Høyre",
            government: "Absolutt monarki", religion: "Islam",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+3",
            neighbors: ["Jordan", "Irak", "Kuwait", "Qatar", "Forenede arabiske emirater", "Oman", "Jemen"]
        ),
        "ir": CountryExtras(
            iso3: "IRN", currency: "Iranske rial", currencySymbol: "﷼",
            language: "Persisk", biggestCity: "Teheran", phoneCode: "+98",
            drivingSide: "Høyre", government: "Islamsk republikk",
            religion: "Islam", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+3.5",
            endonym: "Īrān",
            neighbors: ["Tyrkia", "Aserbajdsjan", "Armenia", "Turkmenistan", "Afghanistan", "Pakistan", "Irak"]
        ),
        "il": CountryExtras(
            iso3: "ISR", currency: "Sjekel", currencySymbol: "₪",
            language: "Hebraisk", phoneCode: "+972", drivingSide: "Høyre",
            government: "Republikk", religion: "Jødedom",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+2",
            neighbors: ["Libanon", "Syria", "Jordan", "Egypt"]
        ),
        "ae": CountryExtras(
            iso3: "ARE", currency: "Dirham", currencySymbol: "د.إ",
            language: "Arabisk", biggestCity: "Dubai", phoneCode: "+971",
            drivingSide: "Høyre", government: "Føderalt monarki",
            religion: "Islam", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+4",
            neighbors: ["Oman", "Saudi-Arabia"]
        ),
        "eg": CountryExtras(
            iso3: "EGY", currency: "Egyptiske pund", currencySymbol: "E£",
            language: "Arabisk", biggestCity: "Kairo", phoneCode: "+20",
            drivingSide: "Høyre", government: "Republikk",
            religion: "Islam", landlocked: false, transcontinental: true,
            hemisphereNS: "Nord", utcOffset: "+2", endonym: "Misr",
            neighbors: ["Libya", "Sudan", "Israel"]
        ),
        "ma": CountryExtras(
            iso3: "MAR", currency: "Marokkanske dirham", currencySymbol: "د.م.",
            language: "Arabisk", phoneCode: "+212", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", religion: "Islam",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Algerie", "Spania (Ceuta/Melilla)"]
        ),
        "za": CountryExtras(
            iso3: "ZAF", currency: "Rand", currencySymbol: "R",
            language: "Engelsk + 10 til", biggestCity: "Johannesburg",
            phoneCode: "+27", drivingSide: "Venstre",
            government: "Republikk", landlocked: false,
            hemisphereNS: "Sør", utcOffset: "+2",
            neighbors: ["Namibia", "Botswana", "Zimbabwe", "Mosambik", "Eswatini", "Lesotho"]
        ),
        "ng": CountryExtras(
            iso3: "NGA", currency: "Naira", currencySymbol: "₦",
            language: "Engelsk", biggestCity: "Lagos", phoneCode: "+234",
            drivingSide: "Høyre", government: "Forbundsrepublikk",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Benin", "Niger", "Tsjad", "Kamerun"]
        ),
        "ke": CountryExtras(
            iso3: "KEN", currency: "Kenyanske shilling", currencySymbol: "KSh",
            language: "Swahili/Engelsk", phoneCode: "+254",
            drivingSide: "Venstre", government: "Republikk",
            landlocked: false, equatorCrosses: true,
            hemisphereNS: "Begge", utcOffset: "+3",
            neighbors: ["Etiopia", "Sør-Sudan", "Uganda", "Tanzania", "Somalia"]
        ),
        "et": CountryExtras(
            iso3: "ETH", currency: "Birr", currencySymbol: "Br",
            language: "Amharisk", phoneCode: "+251", drivingSide: "Høyre",
            government: "Forbundsrepublikk", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+3",
            neighbors: ["Eritrea", "Djibouti", "Somalia", "Kenya", "Sør-Sudan", "Sudan"]
        ),
        "au": CountryExtras(
            iso3: "AUS", currency: "Australske dollar", currencySymbol: "A$",
            language: "Engelsk", biggestCity: "Sydney", phoneCode: "+61",
            drivingSide: "Venstre", government: "Konstitusjonelt monarki",
            landlocked: false, hemisphereNS: "Sør",
            utcOffset: "+8 til +10",
            neighbors: [],
            nationalSport: "Cricket", nationalAnimal: "Kenguru"
        ),
        "nz": CountryExtras(
            iso3: "NZL", currency: "New Zealand-dollar", currencySymbol: "NZ$",
            language: "Engelsk/Maori", biggestCity: "Auckland",
            phoneCode: "+64", drivingSide: "Venstre",
            government: "Konstitusjonelt monarki", landlocked: false,
            hemisphereNS: "Sør", utcOffset: "+12", endonym: "Aotearoa",
            nationalSport: "Rugby", nationalAnimal: "Kiwi"
        ),
        "kz": CountryExtras(
            iso3: "KAZ", currency: "Tenge", currencySymbol: "₸",
            language: "Kasakhisk/Russisk", biggestCity: "Almaty",
            phoneCode: "+7", drivingSide: "Høyre", government: "Republikk",
            landlocked: true, transcontinental: true,
            hemisphereNS: "Nord", utcOffset: "+5 til +6",
            neighbors: ["Russland", "Kina", "Kirgisistan", "Usbekistan", "Turkmenistan"]
        ),
        "mn": CountryExtras(
            iso3: "MNG", currency: "Tögrög", currencySymbol: "₮",
            language: "Mongolsk", phoneCode: "+976", drivingSide: "Høyre",
            government: "Republikk", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+8",
            neighbors: ["Russland", "Kina"]
        ),
        "np": CountryExtras(
            iso3: "NPL", currency: "Nepalske rupi", currencySymbol: "₨",
            language: "Nepali", phoneCode: "+977", drivingSide: "Venstre",
            government: "Republikk", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+5.75",
            neighbors: ["India", "Kina"],
            highestPoint: "Mount Everest"
        ),
        "bd": CountryExtras(
            iso3: "BGD", currency: "Taka", currencySymbol: "৳",
            language: "Bengali", phoneCode: "+880", drivingSide: "Venstre",
            government: "Republikk", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+6",
            neighbors: ["India", "Myanmar"]
        ),
        "lk": CountryExtras(
            iso3: "LKA", currency: "Lankesiske rupi", currencySymbol: "Rs",
            language: "Singalesisk/Tamil", phoneCode: "+94",
            drivingSide: "Venstre", government: "Republikk",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+5.5"
        ),
        "vu": CountryExtras(
            iso3: "VUT", currency: "Vatu", currencySymbol: "Vt",
            language: "Bislama/Engelsk/Fransk", phoneCode: "+678",
            drivingSide: "Høyre", landlocked: false,
            hemisphereNS: "Sør", utcOffset: "+11"
        ),
        "fj": CountryExtras(
            iso3: "FJI", currency: "Fiji-dollar", currencySymbol: "FJ$",
            language: "Engelsk/Fijiansk/Hindi", phoneCode: "+679",
            drivingSide: "Venstre", government: "Republikk",
            landlocked: false, hemisphereNS: "Sør", utcOffset: "+12"
        ),
        "mc": CountryExtras(
            iso3: "MCO", currency: "Euro", currencySymbol: "€",
            language: "Fransk", phoneCode: "+377", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", landlocked: false,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Frankrike"]
        ),
        "va": CountryExtras(
            iso3: "VAT", currency: "Euro", currencySymbol: "€",
            language: "Italiensk/Latin", phoneCode: "+379",
            drivingSide: "Høyre", government: "Absolutt monarki",
            religion: "Kristendom", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Italia"]
        ),
        "li": CountryExtras(
            iso3: "LIE", currency: "Sveitsiske franc", currencySymbol: "CHF",
            language: "Tysk", phoneCode: "+423", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Sveits", "Østerrike"]
        ),
        "ad": CountryExtras(
            iso3: "AND", currency: "Euro", currencySymbol: "€",
            language: "Katalansk", phoneCode: "+376", drivingSide: "Høyre",
            government: "Konstitusjonelt monarki", landlocked: true,
            hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Frankrike", "Spania"]
        ),
        "lu": CountryExtras(
            iso3: "LUX", currency: "Euro", currencySymbol: "€",
            language: "Luxembourgsk/Fransk/Tysk", phoneCode: "+352",
            drivingSide: "Høyre", government: "Konstitusjonelt monarki",
            landlocked: true, hemisphereNS: "Nord", utcOffset: "+1",
            neighbors: ["Belgia", "Frankrike", "Tyskland"]
        ),
        "mt": CountryExtras(
            iso3: "MLT", currency: "Euro", currencySymbol: "€",
            language: "Maltesisk/Engelsk", phoneCode: "+356",
            drivingSide: "Venstre", government: "Republikk",
            landlocked: false, hemisphereNS: "Nord", utcOffset: "+1"
        )
    ]
    // swiftlint:enable function_body_length
}
