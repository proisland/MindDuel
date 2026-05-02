import Foundation

/// Country reference data used by `GeographyProblemGenerator` (#43, #45).
/// Each country yields ~4 programmatically-generated questions (capital,
/// reverse capital lookup, continent, flag) so a handful of countries per
/// level scales to 50+ unique questions without hand-writing every prompt.
struct Country {
    let name: String       // "Norge"
    let capital: String    // "Oslo"
    let iso: String        // "no" — for FlagView CDN lookup
    let continent: String  // "Europa"
}

/// Country data bucketed by level. Each level has 12+ countries so the
/// derived question pool comfortably exceeds the 50-per-level minimum.
enum CountryData {
    // swiftlint:disable function_body_length file_length type_body_length
    static func countries(forLevel level: Int) -> [Country] {
        switch max(1, min(20, level)) {
        // MARK: Grunnskolen — Norden & Vest-Europa
        case 1:
            return [
                Country(name: "Norge",        capital: "Oslo",       iso: "no", continent: "Europa"),
                Country(name: "Sverige",      capital: "Stockholm",  iso: "se", continent: "Europa"),
                Country(name: "Danmark",      capital: "København",  iso: "dk", continent: "Europa"),
                Country(name: "Finland",      capital: "Helsinki",   iso: "fi", continent: "Europa"),
                Country(name: "Island",       capital: "Reykjavík",  iso: "is", continent: "Europa"),
                Country(name: "Tyskland",     capital: "Berlin",     iso: "de", continent: "Europa"),
                Country(name: "Frankrike",    capital: "Paris",      iso: "fr", continent: "Europa"),
                Country(name: "Storbritannia", capital: "London",    iso: "gb", continent: "Europa"),
                Country(name: "Spania",       capital: "Madrid",     iso: "es", continent: "Europa"),
                Country(name: "Italia",       capital: "Roma",       iso: "it", continent: "Europa"),
                Country(name: "Nederland",    capital: "Amsterdam",  iso: "nl", continent: "Europa"),
                Country(name: "Belgia",       capital: "Brussel",    iso: "be", continent: "Europa")
            ]
        case 2:
            return [
                Country(name: "Portugal",     capital: "Lisboa",     iso: "pt", continent: "Europa"),
                Country(name: "Hellas",       capital: "Athen",      iso: "gr", continent: "Europa"),
                Country(name: "Polen",        capital: "Warszawa",   iso: "pl", continent: "Europa"),
                Country(name: "Østerrike",    capital: "Wien",       iso: "at", continent: "Europa"),
                Country(name: "Irland",       capital: "Dublin",     iso: "ie", continent: "Europa"),
                Country(name: "Tsjekkia",     capital: "Praha",      iso: "cz", continent: "Europa"),
                Country(name: "Ungarn",       capital: "Budapest",   iso: "hu", continent: "Europa"),
                Country(name: "Sveits",       capital: "Bern",       iso: "ch", continent: "Europa"),
                Country(name: "Romania",      capital: "Bucuresti",  iso: "ro", continent: "Europa"),
                Country(name: "Bulgaria",     capital: "Sofia",      iso: "bg", continent: "Europa"),
                Country(name: "Slovakia",     capital: "Bratislava", iso: "sk", continent: "Europa"),
                Country(name: "Kroatia",      capital: "Zagreb",     iso: "hr", continent: "Europa")
            ]
        case 3:
            return [
                Country(name: "Estland",      capital: "Tallinn",    iso: "ee", continent: "Europa"),
                Country(name: "Latvia",       capital: "Riga",       iso: "lv", continent: "Europa"),
                Country(name: "Litauen",      capital: "Vilnius",    iso: "lt", continent: "Europa"),
                Country(name: "Slovenia",     capital: "Ljubljana",  iso: "si", continent: "Europa"),
                Country(name: "Serbia",       capital: "Beograd",    iso: "rs", continent: "Europa"),
                Country(name: "Albania",      capital: "Tirana",     iso: "al", continent: "Europa"),
                Country(name: "Nord-Makedonia", capital: "Skopje",   iso: "mk", continent: "Europa"),
                Country(name: "Bosnia og Hercegovina", capital: "Sarajevo", iso: "ba", continent: "Europa"),
                Country(name: "Montenegro",   capital: "Podgorica",  iso: "me", continent: "Europa"),
                Country(name: "Ukraina",      capital: "Kyiv",       iso: "ua", continent: "Europa"),
                Country(name: "Belarus",      capital: "Minsk",      iso: "by", continent: "Europa"),
                Country(name: "Moldova",      capital: "Chisinau",   iso: "md", continent: "Europa"),
                Country(name: "Russland",     capital: "Moskva",     iso: "ru", continent: "Europa"),
                Country(name: "Tyrkia",       capital: "Ankara",     iso: "tr", continent: "Europa")
            ]
        // MARK: Nord-Amerika & Karibia
        case 4:
            return [
                Country(name: "USA",                capital: "Washington D.C.", iso: "us", continent: "Nord-Amerika"),
                Country(name: "Canada",             capital: "Ottawa",          iso: "ca", continent: "Nord-Amerika"),
                Country(name: "Mexico",             capital: "Mexico by",       iso: "mx", continent: "Nord-Amerika"),
                Country(name: "Cuba",               capital: "Havana",          iso: "cu", continent: "Nord-Amerika"),
                Country(name: "Jamaica",            capital: "Kingston",        iso: "jm", continent: "Nord-Amerika"),
                Country(name: "Haiti",              capital: "Port-au-Prince",  iso: "ht", continent: "Nord-Amerika"),
                Country(name: "Dominikanske republikk", capital: "Santo Domingo", iso: "do", continent: "Nord-Amerika"),
                Country(name: "Bahamas",            capital: "Nassau",          iso: "bs", continent: "Nord-Amerika"),
                Country(name: "Guatemala",          capital: "Guatemala by",    iso: "gt", continent: "Nord-Amerika"),
                Country(name: "Honduras",           capital: "Tegucigalpa",     iso: "hn", continent: "Nord-Amerika"),
                Country(name: "Costa Rica",         capital: "San José",        iso: "cr", continent: "Nord-Amerika"),
                Country(name: "Panama",             capital: "Panama by",       iso: "pa", continent: "Nord-Amerika"),
                Country(name: "El Salvador",        capital: "San Salvador",    iso: "sv", continent: "Nord-Amerika"),
                Country(name: "Nicaragua",          capital: "Managua",         iso: "ni", continent: "Nord-Amerika")
            ]
        // MARK: Sør-Amerika
        case 5:
            return [
                Country(name: "Brasil",     capital: "Brasília",       iso: "br", continent: "Sør-Amerika"),
                Country(name: "Argentina",  capital: "Buenos Aires",   iso: "ar", continent: "Sør-Amerika"),
                Country(name: "Chile",      capital: "Santiago",       iso: "cl", continent: "Sør-Amerika"),
                Country(name: "Colombia",   capital: "Bogotá",         iso: "co", continent: "Sør-Amerika"),
                Country(name: "Peru",       capital: "Lima",           iso: "pe", continent: "Sør-Amerika"),
                Country(name: "Venezuela",  capital: "Caracas",        iso: "ve", continent: "Sør-Amerika"),
                Country(name: "Ecuador",    capital: "Quito",          iso: "ec", continent: "Sør-Amerika"),
                Country(name: "Bolivia",    capital: "La Paz",         iso: "bo", continent: "Sør-Amerika"),
                Country(name: "Paraguay",   capital: "Asunción",       iso: "py", continent: "Sør-Amerika"),
                Country(name: "Uruguay",    capital: "Montevideo",     iso: "uy", continent: "Sør-Amerika"),
                Country(name: "Guyana",     capital: "Georgetown",     iso: "gy", continent: "Sør-Amerika"),
                Country(name: "Surinam",    capital: "Paramaribo",     iso: "sr", continent: "Sør-Amerika")
            ]
        // MARK: Øst-Asia
        case 6:
            return [
                Country(name: "Japan",        capital: "Tokyo",        iso: "jp", continent: "Asia"),
                Country(name: "Kina",         capital: "Beijing",      iso: "cn", continent: "Asia"),
                Country(name: "Sør-Korea",    capital: "Seoul",        iso: "kr", continent: "Asia"),
                Country(name: "Nord-Korea",   capital: "Pyongyang",    iso: "kp", continent: "Asia"),
                Country(name: "Mongolia",     capital: "Ulaanbaatar",  iso: "mn", continent: "Asia"),
                Country(name: "Taiwan",       capital: "Taipei",       iso: "tw", continent: "Asia"),
                Country(name: "Vietnam",      capital: "Hanoi",        iso: "vn", continent: "Asia"),
                Country(name: "Thailand",     capital: "Bangkok",      iso: "th", continent: "Asia"),
                Country(name: "Filippinene",  capital: "Manila",       iso: "ph", continent: "Asia"),
                Country(name: "Indonesia",    capital: "Jakarta",      iso: "id", continent: "Asia"),
                Country(name: "Malaysia",     capital: "Kuala Lumpur", iso: "my", continent: "Asia"),
                Country(name: "Singapore",    capital: "Singapore",    iso: "sg", continent: "Asia"),
                Country(name: "Kambodsja",    capital: "Phnom Penh",   iso: "kh", continent: "Asia"),
                Country(name: "Laos",         capital: "Vientiane",    iso: "la", continent: "Asia")
            ]
        // MARK: Sør-Asia & Sentral-Asia
        case 7:
            return [
                Country(name: "India",        capital: "New Delhi",    iso: "in", continent: "Asia"),
                Country(name: "Pakistan",     capital: "Islamabad",    iso: "pk", continent: "Asia"),
                Country(name: "Bangladesh",   capital: "Dhaka",        iso: "bd", continent: "Asia"),
                Country(name: "Sri Lanka",    capital: "Colombo",      iso: "lk", continent: "Asia"),
                Country(name: "Nepal",        capital: "Kathmandu",    iso: "np", continent: "Asia"),
                Country(name: "Bhutan",       capital: "Thimphu",      iso: "bt", continent: "Asia"),
                Country(name: "Maldivene",    capital: "Malé",         iso: "mv", continent: "Asia"),
                Country(name: "Afghanistan",  capital: "Kabul",        iso: "af", continent: "Asia"),
                Country(name: "Kasakhstan",   capital: "Astana",       iso: "kz", continent: "Asia"),
                Country(name: "Usbekistan",   capital: "Tasjkent",     iso: "uz", continent: "Asia"),
                Country(name: "Turkmenistan", capital: "Asjgabat",     iso: "tm", continent: "Asia"),
                Country(name: "Kirgisistan",  capital: "Bishkek",      iso: "kg", continent: "Asia"),
                Country(name: "Tadsjikistan", capital: "Dusjanbe",     iso: "tj", continent: "Asia"),
                Country(name: "Myanmar",      capital: "Naypyidaw",    iso: "mm", continent: "Asia")
            ]
        // MARK: Midtøsten
        case 8:
            return [
                Country(name: "Saudi-Arabia",    capital: "Riyadh",     iso: "sa", continent: "Asia"),
                Country(name: "Iran",            capital: "Teheran",    iso: "ir", continent: "Asia"),
                Country(name: "Irak",            capital: "Bagdad",     iso: "iq", continent: "Asia"),
                Country(name: "Israel",          capital: "Jerusalem",  iso: "il", continent: "Asia"),
                Country(name: "Jordan",          capital: "Amman",      iso: "jo", continent: "Asia"),
                Country(name: "Libanon",         capital: "Beirut",     iso: "lb", continent: "Asia"),
                Country(name: "Syria",           capital: "Damaskus",   iso: "sy", continent: "Asia"),
                Country(name: "Forenede arabiske emirater", capital: "Abu Dhabi", iso: "ae", continent: "Asia"),
                Country(name: "Qatar",           capital: "Doha",       iso: "qa", continent: "Asia"),
                Country(name: "Bahrain",         capital: "Manama",     iso: "bh", continent: "Asia"),
                Country(name: "Kuwait",          capital: "Kuwait by",  iso: "kw", continent: "Asia"),
                Country(name: "Oman",            capital: "Muscat",     iso: "om", continent: "Asia"),
                Country(name: "Jemen",           capital: "Sana'a",     iso: "ye", continent: "Asia"),
                Country(name: "Aserbajdsjan",    capital: "Baku",       iso: "az", continent: "Asia"),
                Country(name: "Armenia",         capital: "Jerevan",    iso: "am", continent: "Asia"),
                Country(name: "Georgia",         capital: "Tbilisi",    iso: "ge", continent: "Asia")
            ]
        // MARK: Nord-Afrika
        case 9:
            return [
                Country(name: "Egypt",     capital: "Kairo",     iso: "eg", continent: "Afrika"),
                Country(name: "Marokko",   capital: "Rabat",     iso: "ma", continent: "Afrika"),
                Country(name: "Algerie",   capital: "Alger",     iso: "dz", continent: "Afrika"),
                Country(name: "Tunisia",   capital: "Tunis",     iso: "tn", continent: "Afrika"),
                Country(name: "Libya",     capital: "Tripoli",   iso: "ly", continent: "Afrika"),
                Country(name: "Sudan",     capital: "Khartoum",  iso: "sd", continent: "Afrika"),
                Country(name: "Sør-Sudan", capital: "Juba",      iso: "ss", continent: "Afrika"),
                Country(name: "Etiopia",   capital: "Addis Abeba", iso: "et", continent: "Afrika"),
                Country(name: "Eritrea",   capital: "Asmara",    iso: "er", continent: "Afrika"),
                Country(name: "Djibouti",  capital: "Djibouti",  iso: "dj", continent: "Afrika"),
                Country(name: "Somalia",   capital: "Mogadishu", iso: "so", continent: "Afrika"),
                Country(name: "Mauritania", capital: "Nouakchott", iso: "mr", continent: "Afrika"),
                Country(name: "Mali",      capital: "Bamako",    iso: "ml", continent: "Afrika"),
                Country(name: "Niger",     capital: "Niamey",    iso: "ne", continent: "Afrika"),
                Country(name: "Tsjad",     capital: "N'Djamena", iso: "td", continent: "Afrika")
            ]
        // MARK: Vest-/Sentral-Afrika
        case 10:
            return [
                Country(name: "Nigeria",         capital: "Abuja",       iso: "ng", continent: "Afrika"),
                Country(name: "Ghana",           capital: "Accra",       iso: "gh", continent: "Afrika"),
                Country(name: "Senegal",         capital: "Dakar",       iso: "sn", continent: "Afrika"),
                Country(name: "Elfenbenskysten", capital: "Yamoussoukro", iso: "ci", continent: "Afrika"),
                Country(name: "Liberia",         capital: "Monrovia",    iso: "lr", continent: "Afrika"),
                Country(name: "Sierra Leone",    capital: "Freetown",    iso: "sl", continent: "Afrika"),
                Country(name: "Guinea",          capital: "Conakry",     iso: "gn", continent: "Afrika"),
                Country(name: "Burkina Faso",    capital: "Ouagadougou", iso: "bf", continent: "Afrika"),
                Country(name: "Benin",           capital: "Porto-Novo",  iso: "bj", continent: "Afrika"),
                Country(name: "Togo",            capital: "Lomé",        iso: "tg", continent: "Afrika"),
                Country(name: "Kamerun",         capital: "Yaoundé",     iso: "cm", continent: "Afrika"),
                Country(name: "Den sentralafrikanske republikk", capital: "Bangui", iso: "cf", continent: "Afrika"),
                Country(name: "Gabon",           capital: "Libreville",  iso: "ga", continent: "Afrika"),
                Country(name: "Republikken Kongo", capital: "Brazzaville", iso: "cg", continent: "Afrika"),
                Country(name: "DR Kongo",        capital: "Kinshasa",    iso: "cd", continent: "Afrika")
            ]
        // MARK: Øst-Afrika
        case 11:
            return [
                Country(name: "Kenya",       capital: "Nairobi",      iso: "ke", continent: "Afrika"),
                Country(name: "Uganda",      capital: "Kampala",      iso: "ug", continent: "Afrika"),
                Country(name: "Tanzania",    capital: "Dodoma",       iso: "tz", continent: "Afrika"),
                Country(name: "Rwanda",      capital: "Kigali",       iso: "rw", continent: "Afrika"),
                Country(name: "Burundi",     capital: "Gitega",       iso: "bi", continent: "Afrika"),
                Country(name: "Madagaskar",  capital: "Antananarivo", iso: "mg", continent: "Afrika"),
                Country(name: "Mauritius",   capital: "Port Louis",   iso: "mu", continent: "Afrika"),
                Country(name: "Komorene",    capital: "Moroni",       iso: "km", continent: "Afrika"),
                Country(name: "Seychellene", capital: "Victoria",     iso: "sc", continent: "Afrika"),
                Country(name: "Mosambik",    capital: "Maputo",       iso: "mz", continent: "Afrika"),
                Country(name: "Malawi",      capital: "Lilongwe",     iso: "mw", continent: "Afrika"),
                Country(name: "Zambia",      capital: "Lusaka",       iso: "zm", continent: "Afrika"),
                Country(name: "Zimbabwe",    capital: "Harare",       iso: "zw", continent: "Afrika")
            ]
        // MARK: Sørlige Afrika
        case 12:
            return [
                Country(name: "Sør-Afrika",   capital: "Pretoria",    iso: "za", continent: "Afrika"),
                Country(name: "Namibia",      capital: "Windhoek",    iso: "na", continent: "Afrika"),
                Country(name: "Botswana",     capital: "Gaborone",    iso: "bw", continent: "Afrika"),
                Country(name: "Lesotho",      capital: "Maseru",      iso: "ls", continent: "Afrika"),
                Country(name: "Eswatini",     capital: "Mbabane",     iso: "sz", continent: "Afrika"),
                Country(name: "Angola",       capital: "Luanda",      iso: "ao", continent: "Afrika"),
                Country(name: "Kapp Verde",   capital: "Praia",       iso: "cv", continent: "Afrika"),
                Country(name: "Gambia",       capital: "Banjul",      iso: "gm", continent: "Afrika"),
                Country(name: "Guinea-Bissau", capital: "Bissau",     iso: "gw", continent: "Afrika"),
                Country(name: "Ekvatorial-Guinea", capital: "Malabo", iso: "gq", continent: "Afrika"),
                Country(name: "Sao Tome og Príncipe", capital: "São Tomé", iso: "st", continent: "Afrika"),
                Country(name: "Sør-Sudan",    capital: "Juba",        iso: "ss", continent: "Afrika")
            ]
        // MARK: Oseania
        case 13:
            return [
                Country(name: "Australia",       capital: "Canberra",   iso: "au", continent: "Oseania"),
                Country(name: "New Zealand",     capital: "Wellington", iso: "nz", continent: "Oseania"),
                Country(name: "Papua Ny-Guinea", capital: "Port Moresby", iso: "pg", continent: "Oseania"),
                Country(name: "Fiji",            capital: "Suva",       iso: "fj", continent: "Oseania"),
                Country(name: "Salomonøyene",    capital: "Honiara",    iso: "sb", continent: "Oseania"),
                Country(name: "Vanuatu",         capital: "Port Vila",  iso: "vu", continent: "Oseania"),
                Country(name: "Samoa",           capital: "Apia",       iso: "ws", continent: "Oseania"),
                Country(name: "Tonga",           capital: "Nuku'alofa", iso: "to", continent: "Oseania"),
                Country(name: "Kiribati",        capital: "Tarawa",     iso: "ki", continent: "Oseania"),
                Country(name: "Tuvalu",          capital: "Funafuti",   iso: "tv", continent: "Oseania"),
                Country(name: "Nauru",           capital: "Yaren",      iso: "nr", continent: "Oseania"),
                Country(name: "Marshalløyene",   capital: "Majuro",     iso: "mh", continent: "Oseania"),
                Country(name: "Mikronesia",      capital: "Palikir",    iso: "fm", continent: "Oseania"),
                Country(name: "Palau",           capital: "Ngerulmud",  iso: "pw", continent: "Oseania")
            ]
        // MARK: Karibia og Mellom-Amerika
        case 14:
            return [
                Country(name: "Trinidad og Tobago", capital: "Port of Spain", iso: "tt", continent: "Nord-Amerika"),
                Country(name: "Barbados",        capital: "Bridgetown",   iso: "bb", continent: "Nord-Amerika"),
                Country(name: "Saint Lucia",     capital: "Castries",     iso: "lc", continent: "Nord-Amerika"),
                Country(name: "Grenada",         capital: "Saint George's", iso: "gd", continent: "Nord-Amerika"),
                Country(name: "Saint Vincent og Grenadinene", capital: "Kingstown", iso: "vc", continent: "Nord-Amerika"),
                Country(name: "Antigua og Barbuda", capital: "Saint John's", iso: "ag", continent: "Nord-Amerika"),
                Country(name: "Dominica",        capital: "Roseau",       iso: "dm", continent: "Nord-Amerika"),
                Country(name: "Saint Kitts og Nevis", capital: "Basseterre", iso: "kn", continent: "Nord-Amerika"),
                Country(name: "Belize",          capital: "Belmopan",     iso: "bz", continent: "Nord-Amerika"),
                Country(name: "Bahamas",         capital: "Nassau",       iso: "bs", continent: "Nord-Amerika"),
                Country(name: "Suriname",        capital: "Paramaribo",   iso: "sr", continent: "Sør-Amerika"),
                Country(name: "Guyana",          capital: "Georgetown",   iso: "gy", continent: "Sør-Amerika")
            ]
        // MARK: Mikrostater & spesielle land
        case 15:
            return [
                Country(name: "Vatikanstaten", capital: "Vatikanstaten", iso: "va", continent: "Europa"),
                Country(name: "Monaco",        capital: "Monaco",        iso: "mc", continent: "Europa"),
                Country(name: "San Marino",    capital: "San Marino",    iso: "sm", continent: "Europa"),
                Country(name: "Liechtenstein", capital: "Vaduz",         iso: "li", continent: "Europa"),
                Country(name: "Andorra",       capital: "Andorra la Vella", iso: "ad", continent: "Europa"),
                Country(name: "Malta",         capital: "Valletta",      iso: "mt", continent: "Europa"),
                Country(name: "Luxembourg",    capital: "Luxembourg",    iso: "lu", continent: "Europa"),
                Country(name: "Kypros",        capital: "Nikosia",       iso: "cy", continent: "Europa"),
                Country(name: "Brunei",        capital: "Bandar Seri Begawan", iso: "bn", continent: "Asia"),
                Country(name: "Øst-Timor",     capital: "Dili",          iso: "tl", continent: "Asia"),
                Country(name: "Singapore",     capital: "Singapore",     iso: "sg", continent: "Asia"),
                Country(name: "Bhutan",        capital: "Thimphu",       iso: "bt", continent: "Asia")
            ]
        // MARK: Resten av Europa & innlandsstater
        case 16:
            return [
                Country(name: "Kasakhstan",  capital: "Astana",     iso: "kz", continent: "Asia"),
                Country(name: "Mongolia",    capital: "Ulaanbaatar", iso: "mn", continent: "Asia"),
                Country(name: "Nepal",       capital: "Kathmandu",  iso: "np", continent: "Asia"),
                Country(name: "Bolivia",     capital: "La Paz",     iso: "bo", continent: "Sør-Amerika"),
                Country(name: "Paraguay",    capital: "Asunción",   iso: "py", continent: "Sør-Amerika"),
                Country(name: "Sveits",      capital: "Bern",       iso: "ch", continent: "Europa"),
                Country(name: "Østerrike",   capital: "Wien",       iso: "at", continent: "Europa"),
                Country(name: "Ungarn",      capital: "Budapest",   iso: "hu", continent: "Europa"),
                Country(name: "Tsjekkia",    capital: "Praha",      iso: "cz", continent: "Europa"),
                Country(name: "Slovakia",    capital: "Bratislava", iso: "sk", continent: "Europa"),
                Country(name: "Belarus",     capital: "Minsk",      iso: "by", continent: "Europa"),
                Country(name: "Moldova",     capital: "Chisinau",   iso: "md", continent: "Europa"),
                Country(name: "Tsjad",       capital: "N'Djamena",  iso: "td", continent: "Afrika"),
                Country(name: "Niger",       capital: "Niamey",     iso: "ne", continent: "Afrika"),
                Country(name: "Mali",        capital: "Bamako",     iso: "ml", continent: "Afrika")
            ]
        // MARK: Vanskelige asiatiske / afrikanske
        case 17:
            return [
                Country(name: "Myanmar",     capital: "Naypyidaw", iso: "mm", continent: "Asia"),
                Country(name: "Laos",        capital: "Vientiane", iso: "la", continent: "Asia"),
                Country(name: "Kambodsja",   capital: "Phnom Penh", iso: "kh", continent: "Asia"),
                Country(name: "Bhutan",      capital: "Thimphu",   iso: "bt", continent: "Asia"),
                Country(name: "Kirgisistan", capital: "Bishkek",   iso: "kg", continent: "Asia"),
                Country(name: "Tadsjikistan", capital: "Dusjanbe", iso: "tj", continent: "Asia"),
                Country(name: "Turkmenistan", capital: "Asjgabat", iso: "tm", continent: "Asia"),
                Country(name: "Mauritania",  capital: "Nouakchott", iso: "mr", continent: "Afrika"),
                Country(name: "Madagaskar",  capital: "Antananarivo", iso: "mg", continent: "Afrika"),
                Country(name: "Mosambik",    capital: "Maputo",    iso: "mz", continent: "Afrika"),
                Country(name: "Angola",      capital: "Luanda",    iso: "ao", continent: "Afrika"),
                Country(name: "Namibia",     capital: "Windhoek",  iso: "na", continent: "Afrika"),
                Country(name: "Botswana",    capital: "Gaborone",  iso: "bw", continent: "Afrika"),
                Country(name: "Lesotho",     capital: "Maseru",    iso: "ls", continent: "Afrika"),
                Country(name: "Eswatini",    capital: "Mbabane",   iso: "sz", continent: "Afrika")
            ]
        // MARK: Stillehavsøyer & Karibia
        case 18:
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
                Country(name: "Palau",        capital: "Ngerulmud",  iso: "pw", continent: "Oseania"),
                Country(name: "Trinidad og Tobago", capital: "Port of Spain", iso: "tt", continent: "Nord-Amerika"),
                Country(name: "Barbados",     capital: "Bridgetown", iso: "bb", continent: "Nord-Amerika"),
                Country(name: "Grenada",      capital: "Saint George's", iso: "gd", continent: "Nord-Amerika"),
                Country(name: "Saint Lucia",  capital: "Castries",   iso: "lc", continent: "Nord-Amerika")
            ]
        // MARK: Obskure mikrostater & territoriespesifikke
        case 19:
            return [
                Country(name: "Vatikanstaten",   capital: "Vatikanstaten",      iso: "va", continent: "Europa"),
                Country(name: "Monaco",          capital: "Monaco",             iso: "mc", continent: "Europa"),
                Country(name: "San Marino",      capital: "San Marino",         iso: "sm", continent: "Europa"),
                Country(name: "Liechtenstein",   capital: "Vaduz",              iso: "li", continent: "Europa"),
                Country(name: "Andorra",         capital: "Andorra la Vella",   iso: "ad", continent: "Europa"),
                Country(name: "Komorene",        capital: "Moroni",             iso: "km", continent: "Afrika"),
                Country(name: "Sao Tome og Príncipe", capital: "São Tomé",      iso: "st", continent: "Afrika"),
                Country(name: "Ekvatorial-Guinea", capital: "Malabo",           iso: "gq", continent: "Afrika"),
                Country(name: "Djibouti",        capital: "Djibouti",           iso: "dj", continent: "Afrika"),
                Country(name: "Eritrea",         capital: "Asmara",             iso: "er", continent: "Afrika"),
                Country(name: "Bahrain",         capital: "Manama",             iso: "bh", continent: "Asia"),
                Country(name: "Qatar",           capital: "Doha",               iso: "qa", continent: "Asia"),
                Country(name: "Brunei",          capital: "Bandar Seri Begawan", iso: "bn", continent: "Asia")
            ]
        default:
            return [
                Country(name: "Tuvalu",          capital: "Funafuti",     iso: "tv", continent: "Oseania"),
                Country(name: "Nauru",           capital: "Yaren",        iso: "nr", continent: "Oseania"),
                Country(name: "Vanuatu",         capital: "Port Vila",    iso: "vu", continent: "Oseania"),
                Country(name: "Kiribati",        capital: "Tarawa",       iso: "ki", continent: "Oseania"),
                Country(name: "Mikronesia",      capital: "Palikir",      iso: "fm", continent: "Oseania"),
                Country(name: "Marshalløyene",   capital: "Majuro",       iso: "mh", continent: "Oseania"),
                Country(name: "Palau",           capital: "Ngerulmud",    iso: "pw", continent: "Oseania"),
                Country(name: "Salomonøyene",    capital: "Honiara",      iso: "sb", continent: "Oseania"),
                Country(name: "Tonga",           capital: "Nuku'alofa",   iso: "to", continent: "Oseania"),
                Country(name: "Samoa",           capital: "Apia",         iso: "ws", continent: "Oseania"),
                Country(name: "Liechtenstein",   capital: "Vaduz",        iso: "li", continent: "Europa"),
                Country(name: "San Marino",      capital: "San Marino",   iso: "sm", continent: "Europa"),
                Country(name: "Andorra",         capital: "Andorra la Vella", iso: "ad", continent: "Europa"),
                Country(name: "Vatikanstaten",   capital: "Vatikanstaten", iso: "va", continent: "Europa"),
                Country(name: "Bhutan",          capital: "Thimphu",      iso: "bt", continent: "Asia")
            ]
        }
    }
    // swiftlint:enable function_body_length file_length type_body_length

    /// Flattened pool of all countries — used for distractor selection so
    /// wrong options come from across the whole world, not just the level.
    static let allCountries: [Country] = (1...20).flatMap { countries(forLevel: $0) }
}
