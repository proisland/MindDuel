import Foundation

/// Country reference data used by `GeographyProblemGenerator`. Each country
/// yields ~4 programmatically-generated questions from this base data;
/// extras (currency, language, neighbors, …) live in `CountryExtras`.
///
/// Country buckets per level mirror the LK20 curriculum: 1.–2. klasse stays
/// in Norden / nærområde, 3.–7. klasse expands to Europa and the
/// kontinenter, 8.–10. klasse covers full world, VGS+ shifts toward
/// concept-level questions in `specials(forLevel:)` rather than more land.
struct Country {
    let name: String
    let capital: String
    let iso: String
    let continent: String
}

enum CountryData {
    // swiftlint:disable function_body_length file_length type_body_length
    static func countries(forLevel level: Int) -> [Country] {
        switch max(1, min(20, level)) {
        // MARK: 1. klasse — Norge & nærmeste naboland
        case 1:
            return [
                Country(name: "Norge",   capital: "Oslo",      iso: "no", continent: "Europa"),
                Country(name: "Sverige", capital: "Stockholm", iso: "se", continent: "Europa"),
                Country(name: "Danmark", capital: "København", iso: "dk", continent: "Europa")
            ]
        // MARK: 2. klasse — Norden
        case 2:
            return [
                Country(name: "Norge",   capital: "Oslo",      iso: "no", continent: "Europa"),
                Country(name: "Sverige", capital: "Stockholm", iso: "se", continent: "Europa"),
                Country(name: "Danmark", capital: "København", iso: "dk", continent: "Europa"),
                Country(name: "Finland", capital: "Helsinki",  iso: "fi", continent: "Europa"),
                Country(name: "Island",  capital: "Reykjavík", iso: "is", continent: "Europa")
            ]
        // MARK: 3. klasse — Norden + nærmeste Europa
        case 3:
            return [
                Country(name: "Norge",   capital: "Oslo",      iso: "no", continent: "Europa"),
                Country(name: "Sverige", capital: "Stockholm", iso: "se", continent: "Europa"),
                Country(name: "Danmark", capital: "København", iso: "dk", continent: "Europa"),
                Country(name: "Finland", capital: "Helsinki",  iso: "fi", continent: "Europa"),
                Country(name: "Island",  capital: "Reykjavík", iso: "is", continent: "Europa"),
                Country(name: "Tyskland", capital: "Berlin",   iso: "de", continent: "Europa"),
                Country(name: "Storbritannia", capital: "London", iso: "gb", continent: "Europa"),
                Country(name: "Russland", capital: "Moskva",   iso: "ru", continent: "Europa")
            ]
        // MARK: 4. klasse — Vest-Europa
        case 4:
            return [
                Country(name: "Tyskland",     capital: "Berlin",   iso: "de", continent: "Europa"),
                Country(name: "Frankrike",    capital: "Paris",    iso: "fr", continent: "Europa"),
                Country(name: "Storbritannia", capital: "London",  iso: "gb", continent: "Europa"),
                Country(name: "Spania",       capital: "Madrid",   iso: "es", continent: "Europa"),
                Country(name: "Italia",       capital: "Roma",     iso: "it", continent: "Europa"),
                Country(name: "Nederland",    capital: "Amsterdam", iso: "nl", continent: "Europa"),
                Country(name: "Belgia",       capital: "Brussel",  iso: "be", continent: "Europa"),
                Country(name: "Sveits",       capital: "Bern",     iso: "ch", continent: "Europa"),
                Country(name: "Østerrike",    capital: "Wien",     iso: "at", continent: "Europa"),
                Country(name: "Portugal",     capital: "Lisboa",   iso: "pt", continent: "Europa"),
                Country(name: "Irland",       capital: "Dublin",   iso: "ie", continent: "Europa"),
                Country(name: "Hellas",       capital: "Athen",    iso: "gr", continent: "Europa")
            ]
        // MARK: 5. klasse — Resten av Europa
        case 5:
            return [
                Country(name: "Polen",        capital: "Warszawa", iso: "pl", continent: "Europa"),
                Country(name: "Tsjekkia",     capital: "Praha",    iso: "cz", continent: "Europa"),
                Country(name: "Ungarn",       capital: "Budapest", iso: "hu", continent: "Europa"),
                Country(name: "Romania",      capital: "Bucuresti", iso: "ro", continent: "Europa"),
                Country(name: "Bulgaria",     capital: "Sofia",    iso: "bg", continent: "Europa"),
                Country(name: "Slovakia",     capital: "Bratislava", iso: "sk", continent: "Europa"),
                Country(name: "Kroatia",      capital: "Zagreb",   iso: "hr", continent: "Europa"),
                Country(name: "Serbia",       capital: "Beograd",  iso: "rs", continent: "Europa"),
                Country(name: "Estland",      capital: "Tallinn",  iso: "ee", continent: "Europa"),
                Country(name: "Latvia",       capital: "Riga",     iso: "lv", continent: "Europa"),
                Country(name: "Litauen",      capital: "Vilnius",  iso: "lt", continent: "Europa"),
                Country(name: "Ukraina",      capital: "Kyiv",     iso: "ua", continent: "Europa"),
                Country(name: "Russland",     capital: "Moskva",   iso: "ru", continent: "Europa"),
                Country(name: "Tyrkia",       capital: "Ankara",   iso: "tr", continent: "Europa")
            ]
        // MARK: 6. klasse — Verdensdelene (oversikt)
        case 6:
            return [
                Country(name: "USA",          capital: "Washington D.C.", iso: "us", continent: "Nord-Amerika"),
                Country(name: "Canada",       capital: "Ottawa",   iso: "ca", continent: "Nord-Amerika"),
                Country(name: "Mexico",       capital: "Mexico by", iso: "mx", continent: "Nord-Amerika"),
                Country(name: "Brasil",       capital: "Brasília", iso: "br", continent: "Sør-Amerika"),
                Country(name: "Argentina",    capital: "Buenos Aires", iso: "ar", continent: "Sør-Amerika"),
                Country(name: "Kina",         capital: "Beijing",  iso: "cn", continent: "Asia"),
                Country(name: "Japan",        capital: "Tokyo",    iso: "jp", continent: "Asia"),
                Country(name: "India",        capital: "New Delhi", iso: "in", continent: "Asia"),
                Country(name: "Egypt",        capital: "Kairo",    iso: "eg", continent: "Afrika"),
                Country(name: "Sør-Afrika",   capital: "Pretoria", iso: "za", continent: "Afrika"),
                Country(name: "Australia",    capital: "Canberra", iso: "au", continent: "Oseania"),
                Country(name: "New Zealand",  capital: "Wellington", iso: "nz", continent: "Oseania")
            ]
        // MARK: 7. klasse — Globale forbindelser, klima
        case 7:
            return [
                Country(name: "Brasil",       capital: "Brasília", iso: "br", continent: "Sør-Amerika"),
                Country(name: "Colombia",     capital: "Bogotá",   iso: "co", continent: "Sør-Amerika"),
                Country(name: "Peru",         capital: "Lima",     iso: "pe", continent: "Sør-Amerika"),
                Country(name: "Chile",        capital: "Santiago", iso: "cl", continent: "Sør-Amerika"),
                Country(name: "Venezuela",    capital: "Caracas",  iso: "ve", continent: "Sør-Amerika"),
                Country(name: "Sør-Korea",    capital: "Seoul",    iso: "kr", continent: "Asia"),
                Country(name: "Thailand",     capital: "Bangkok",  iso: "th", continent: "Asia"),
                Country(name: "Vietnam",      capital: "Hanoi",    iso: "vn", continent: "Asia"),
                Country(name: "Indonesia",    capital: "Jakarta",  iso: "id", continent: "Asia"),
                Country(name: "Filippinene",  capital: "Manila",   iso: "ph", continent: "Asia"),
                Country(name: "Malaysia",     capital: "Kuala Lumpur", iso: "my", continent: "Asia"),
                Country(name: "Singapore",    capital: "Singapore", iso: "sg", continent: "Asia")
            ]
        // MARK: 8. klasse — Befolkning, Midtøsten
        case 8:
            return [
                Country(name: "Saudi-Arabia", capital: "Riyadh",   iso: "sa", continent: "Asia"),
                Country(name: "Iran",         capital: "Teheran",  iso: "ir", continent: "Asia"),
                Country(name: "Irak",         capital: "Bagdad",   iso: "iq", continent: "Asia"),
                Country(name: "Israel",       capital: "Jerusalem", iso: "il", continent: "Asia"),
                Country(name: "Jordan",       capital: "Amman",    iso: "jo", continent: "Asia"),
                Country(name: "Libanon",      capital: "Beirut",   iso: "lb", continent: "Asia"),
                Country(name: "Syria",        capital: "Damaskus", iso: "sy", continent: "Asia"),
                Country(name: "Forenede arabiske emirater", capital: "Abu Dhabi", iso: "ae", continent: "Asia"),
                Country(name: "Pakistan",     capital: "Islamabad", iso: "pk", continent: "Asia"),
                Country(name: "Bangladesh",   capital: "Dhaka",    iso: "bd", continent: "Asia"),
                Country(name: "Afghanistan",  capital: "Kabul",    iso: "af", continent: "Asia"),
                Country(name: "Mongolia",     capital: "Ulaanbaatar", iso: "mn", continent: "Asia")
            ]
        // MARK: 9. klasse — Afrika
        case 9:
            return [
                Country(name: "Egypt",        capital: "Kairo",    iso: "eg", continent: "Afrika"),
                Country(name: "Marokko",      capital: "Rabat",    iso: "ma", continent: "Afrika"),
                Country(name: "Algerie",      capital: "Alger",    iso: "dz", continent: "Afrika"),
                Country(name: "Tunisia",      capital: "Tunis",    iso: "tn", continent: "Afrika"),
                Country(name: "Libya",        capital: "Tripoli",  iso: "ly", continent: "Afrika"),
                Country(name: "Sudan",        capital: "Khartoum", iso: "sd", continent: "Afrika"),
                Country(name: "Etiopia",      capital: "Addis Abeba", iso: "et", continent: "Afrika"),
                Country(name: "Kenya",        capital: "Nairobi",  iso: "ke", continent: "Afrika"),
                Country(name: "Tanzania",     capital: "Dodoma",   iso: "tz", continent: "Afrika"),
                Country(name: "Nigeria",      capital: "Abuja",    iso: "ng", continent: "Afrika"),
                Country(name: "Ghana",        capital: "Accra",    iso: "gh", continent: "Afrika"),
                Country(name: "Senegal",      capital: "Dakar",    iso: "sn", continent: "Afrika"),
                Country(name: "Sør-Afrika",   capital: "Pretoria", iso: "za", continent: "Afrika"),
                Country(name: "DR Kongo",     capital: "Kinshasa", iso: "cd", continent: "Afrika")
            ]
        // MARK: 10. klasse — Hele verden, geopolitikk
        case 10:
            return [
                Country(name: "Norge",        capital: "Oslo",     iso: "no", continent: "Europa"),
                Country(name: "USA",          capital: "Washington D.C.", iso: "us", continent: "Nord-Amerika"),
                Country(name: "Kina",         capital: "Beijing",  iso: "cn", continent: "Asia"),
                Country(name: "Russland",     capital: "Moskva",   iso: "ru", continent: "Europa"),
                Country(name: "Brasil",       capital: "Brasília", iso: "br", continent: "Sør-Amerika"),
                Country(name: "India",        capital: "New Delhi", iso: "in", continent: "Asia"),
                Country(name: "Tyskland",     capital: "Berlin",   iso: "de", continent: "Europa"),
                Country(name: "Frankrike",    capital: "Paris",    iso: "fr", continent: "Europa"),
                Country(name: "Storbritannia", capital: "London",  iso: "gb", continent: "Europa"),
                Country(name: "Japan",        capital: "Tokyo",    iso: "jp", continent: "Asia"),
                Country(name: "Australia",    capital: "Canberra", iso: "au", continent: "Oseania"),
                Country(name: "Canada",       capital: "Ottawa",   iso: "ca", continent: "Nord-Amerika"),
                Country(name: "Sør-Afrika",   capital: "Pretoria", iso: "za", continent: "Afrika"),
                Country(name: "Egypt",        capital: "Kairo",    iso: "eg", continent: "Afrika")
            ]
        // MARK: VG1 — Naturgeografi / kulturgeografi
        case 11:
            return [
                Country(name: "Island",       capital: "Reykjavík", iso: "is", continent: "Europa"),
                Country(name: "Indonesia",    capital: "Jakarta",   iso: "id", continent: "Asia"),
                Country(name: "Japan",        capital: "Tokyo",     iso: "jp", continent: "Asia"),
                Country(name: "Filippinene",  capital: "Manila",    iso: "ph", continent: "Asia"),
                Country(name: "Chile",        capital: "Santiago",  iso: "cl", continent: "Sør-Amerika"),
                Country(name: "New Zealand",  capital: "Wellington", iso: "nz", continent: "Oseania"),
                Country(name: "Italia",       capital: "Roma",      iso: "it", continent: "Europa"),
                Country(name: "Tyrkia",       capital: "Ankara",    iso: "tr", continent: "Europa"),
                Country(name: "Hellas",       capital: "Athen",     iso: "gr", continent: "Europa"),
                Country(name: "Sveits",       capital: "Bern",      iso: "ch", continent: "Europa"),
                Country(name: "Nepal",        capital: "Kathmandu", iso: "np", continent: "Asia"),
                Country(name: "Bolivia",      capital: "La Paz",    iso: "bo", continent: "Sør-Amerika")
            ]
        // MARK: VG2 — Klimasoner & vannressurser
        case 12:
            return [
                Country(name: "Brasil",       capital: "Brasília",  iso: "br", continent: "Sør-Amerika"),
                Country(name: "Indonesia",    capital: "Jakarta",   iso: "id", continent: "Asia"),
                Country(name: "Saudi-Arabia", capital: "Riyadh",    iso: "sa", continent: "Asia"),
                Country(name: "Australia",    capital: "Canberra",  iso: "au", continent: "Oseania"),
                Country(name: "Canada",       capital: "Ottawa",    iso: "ca", continent: "Nord-Amerika"),
                Country(name: "Russland",     capital: "Moskva",    iso: "ru", continent: "Europa"),
                Country(name: "DR Kongo",     capital: "Kinshasa",  iso: "cd", continent: "Afrika"),
                Country(name: "Egypt",        capital: "Kairo",     iso: "eg", continent: "Afrika"),
                Country(name: "Mongolia",     capital: "Ulaanbaatar", iso: "mn", continent: "Asia"),
                Country(name: "Argentina",    capital: "Buenos Aires", iso: "ar", continent: "Sør-Amerika"),
                Country(name: "Norge",        capital: "Oslo",      iso: "no", continent: "Europa"),
                Country(name: "Etiopia",      capital: "Addis Abeba", iso: "et", continent: "Afrika")
            ]
        // MARK: VG3 — Demografi & migrasjon
        case 13:
            return [
                Country(name: "India",        capital: "New Delhi", iso: "in", continent: "Asia"),
                Country(name: "Kina",         capital: "Beijing",   iso: "cn", continent: "Asia"),
                Country(name: "Nigeria",      capital: "Abuja",     iso: "ng", continent: "Afrika"),
                Country(name: "Bangladesh",   capital: "Dhaka",     iso: "bd", continent: "Asia"),
                Country(name: "Pakistan",     capital: "Islamabad", iso: "pk", continent: "Asia"),
                Country(name: "Indonesia",    capital: "Jakarta",   iso: "id", continent: "Asia"),
                Country(name: "USA",          capital: "Washington D.C.", iso: "us", continent: "Nord-Amerika"),
                Country(name: "Brasil",       capital: "Brasília",  iso: "br", continent: "Sør-Amerika"),
                Country(name: "Mexico",       capital: "Mexico by", iso: "mx", continent: "Nord-Amerika"),
                Country(name: "Tyskland",     capital: "Berlin",    iso: "de", continent: "Europa"),
                Country(name: "Tyrkia",       capital: "Ankara",    iso: "tr", continent: "Europa"),
                Country(name: "Egypt",        capital: "Kairo",     iso: "eg", continent: "Afrika")
            ]
        // MARK: Universitet (1) — Geopolitikk & regionale blokker
        case 14:
            return [
                Country(name: "Russland",     capital: "Moskva",    iso: "ru", continent: "Europa"),
                Country(name: "USA",          capital: "Washington D.C.", iso: "us", continent: "Nord-Amerika"),
                Country(name: "Kina",         capital: "Beijing",   iso: "cn", continent: "Asia"),
                Country(name: "EU-medlem: Frankrike", capital: "Paris", iso: "fr", continent: "Europa"),
                Country(name: "Tyskland",     capital: "Berlin",    iso: "de", continent: "Europa"),
                Country(name: "Storbritannia", capital: "London",   iso: "gb", continent: "Europa"),
                Country(name: "Japan",        capital: "Tokyo",     iso: "jp", continent: "Asia"),
                Country(name: "India",        capital: "New Delhi", iso: "in", continent: "Asia"),
                Country(name: "Saudi-Arabia", capital: "Riyadh",    iso: "sa", continent: "Asia"),
                Country(name: "Iran",         capital: "Teheran",   iso: "ir", continent: "Asia"),
                Country(name: "Brasil",       capital: "Brasília",  iso: "br", continent: "Sør-Amerika")
            ]
        // MARK: Universitet (2) — Mikrostater & uvanlige territorier
        case 15:
            return [
                Country(name: "Vatikanstaten", capital: "Vatikanstaten",  iso: "va", continent: "Europa"),
                Country(name: "Monaco",        capital: "Monaco",         iso: "mc", continent: "Europa"),
                Country(name: "San Marino",    capital: "San Marino",     iso: "sm", continent: "Europa"),
                Country(name: "Liechtenstein", capital: "Vaduz",          iso: "li", continent: "Europa"),
                Country(name: "Andorra",       capital: "Andorra la Vella", iso: "ad", continent: "Europa"),
                Country(name: "Malta",         capital: "Valletta",       iso: "mt", continent: "Europa"),
                Country(name: "Luxembourg",    capital: "Luxembourg",     iso: "lu", continent: "Europa"),
                Country(name: "Brunei",        capital: "Bandar Seri Begawan", iso: "bn", continent: "Asia"),
                Country(name: "Bhutan",        capital: "Thimphu",        iso: "bt", continent: "Asia"),
                Country(name: "Maldivene",     capital: "Malé",           iso: "mv", continent: "Asia")
            ]
        // MARK: Universitet (3) — Innlandsstater & spesielle topologier
        case 16:
            return [
                Country(name: "Kasakhstan",   capital: "Astana",     iso: "kz", continent: "Asia"),
                Country(name: "Mongolia",     capital: "Ulaanbaatar", iso: "mn", continent: "Asia"),
                Country(name: "Nepal",        capital: "Kathmandu",  iso: "np", continent: "Asia"),
                Country(name: "Bolivia",      capital: "La Paz",     iso: "bo", continent: "Sør-Amerika"),
                Country(name: "Paraguay",     capital: "Asunción",   iso: "py", continent: "Sør-Amerika"),
                Country(name: "Tsjad",        capital: "N'Djamena",  iso: "td", continent: "Afrika"),
                Country(name: "Niger",        capital: "Niamey",     iso: "ne", continent: "Afrika"),
                Country(name: "Mali",         capital: "Bamako",     iso: "ml", continent: "Afrika"),
                Country(name: "Sør-Sudan",    capital: "Juba",       iso: "ss", continent: "Afrika"),
                Country(name: "Lesotho",      capital: "Maseru",     iso: "ls", continent: "Afrika"),
                Country(name: "Eswatini",     capital: "Mbabane",    iso: "sz", continent: "Afrika")
            ]
        // MARK: Universitet (4) — Stillehavet & Karibia
        case 17:
            return [
                Country(name: "Fiji",         capital: "Suva",       iso: "fj", continent: "Oseania"),
                Country(name: "Vanuatu",      capital: "Port Vila",  iso: "vu", continent: "Oseania"),
                Country(name: "Samoa",        capital: "Apia",       iso: "ws", continent: "Oseania"),
                Country(name: "Tonga",        capital: "Nuku'alofa", iso: "to", continent: "Oseania"),
                Country(name: "Kiribati",     capital: "Tarawa",     iso: "ki", continent: "Oseania"),
                Country(name: "Tuvalu",       capital: "Funafuti",   iso: "tv", continent: "Oseania"),
                Country(name: "Nauru",        capital: "Yaren",      iso: "nr", continent: "Oseania"),
                Country(name: "Salomonøyene", capital: "Honiara",    iso: "sb", continent: "Oseania"),
                Country(name: "Marshalløyene", capital: "Majuro",    iso: "mh", continent: "Oseania"),
                Country(name: "Mikronesia",   capital: "Palikir",    iso: "fm", continent: "Oseania"),
                Country(name: "Palau",        capital: "Ngerulmud",  iso: "pw", continent: "Oseania")
            ]
        // MARK: Universitet (5) — Karibia & Sentral-Amerika
        case 18:
            return [
                Country(name: "Trinidad og Tobago", capital: "Port of Spain", iso: "tt", continent: "Nord-Amerika"),
                Country(name: "Barbados",     capital: "Bridgetown",  iso: "bb", continent: "Nord-Amerika"),
                Country(name: "Grenada",      capital: "Saint George's", iso: "gd", continent: "Nord-Amerika"),
                Country(name: "Saint Lucia",  capital: "Castries",    iso: "lc", continent: "Nord-Amerika"),
                Country(name: "Dominica",     capital: "Roseau",      iso: "dm", continent: "Nord-Amerika"),
                Country(name: "Antigua og Barbuda", capital: "Saint John's", iso: "ag", continent: "Nord-Amerika"),
                Country(name: "Saint Kitts og Nevis", capital: "Basseterre", iso: "kn", continent: "Nord-Amerika"),
                Country(name: "Belize",       capital: "Belmopan",    iso: "bz", continent: "Nord-Amerika"),
                Country(name: "Suriname",     capital: "Paramaribo",  iso: "sr", continent: "Sør-Amerika"),
                Country(name: "Guyana",       capital: "Georgetown",  iso: "gy", continent: "Sør-Amerika")
            ]
        // MARK: Universitet (6) — Mest obskure
        case 19:
            return [
                Country(name: "Komorene",     capital: "Moroni",      iso: "km", continent: "Afrika"),
                Country(name: "Sao Tome og Príncipe", capital: "São Tomé", iso: "st", continent: "Afrika"),
                Country(name: "Ekvatorial-Guinea", capital: "Malabo", iso: "gq", continent: "Afrika"),
                Country(name: "Djibouti",     capital: "Djibouti",    iso: "dj", continent: "Afrika"),
                Country(name: "Eritrea",      capital: "Asmara",      iso: "er", continent: "Afrika"),
                Country(name: "Bahrain",      capital: "Manama",      iso: "bh", continent: "Asia"),
                Country(name: "Qatar",        capital: "Doha",        iso: "qa", continent: "Asia"),
                Country(name: "Brunei",       capital: "Bandar Seri Begawan", iso: "bn", continent: "Asia"),
                Country(name: "Øst-Timor",    capital: "Dili",        iso: "tl", continent: "Asia"),
                Country(name: "Kapp Verde",   capital: "Praia",       iso: "cv", continent: "Afrika"),
                Country(name: "Seychellene",  capital: "Victoria",    iso: "sc", continent: "Afrika")
            ]
        default:
            return [
                Country(name: "Tuvalu",       capital: "Funafuti",    iso: "tv", continent: "Oseania"),
                Country(name: "Nauru",        capital: "Yaren",       iso: "nr", continent: "Oseania"),
                Country(name: "Vanuatu",      capital: "Port Vila",   iso: "vu", continent: "Oseania"),
                Country(name: "Liechtenstein", capital: "Vaduz",      iso: "li", continent: "Europa"),
                Country(name: "Andorra",      capital: "Andorra la Vella", iso: "ad", continent: "Europa"),
                Country(name: "Vatikanstaten", capital: "Vatikanstaten", iso: "va", continent: "Europa"),
                Country(name: "Bhutan",       capital: "Thimphu",     iso: "bt", continent: "Asia"),
                Country(name: "Maldivene",    capital: "Malé",        iso: "mv", continent: "Asia"),
                Country(name: "Komorene",     capital: "Moroni",      iso: "km", continent: "Afrika")
            ]
        }
    }
    // swiftlint:enable function_body_length file_length type_body_length

    static let allCountries: [Country] = (1...20).flatMap { countries(forLevel: $0) }
}
