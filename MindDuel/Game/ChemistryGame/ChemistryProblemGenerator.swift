import Foundation

/// Curriculum-aligned chemistry questions (#15, #43). Combines programmatic
/// element lookups (12+ elements per level × 4 question types each) with a
/// handcrafted pool of concept/state/reaction questions, so each level
/// reliably has 50+ unique prompts.
enum ChemistryProblemGenerator {

    /// Round-scoped seen-set so a question answered correctly never repeats
    /// the rest of the round, regardless of level (#64).
    private static var seenCorrects: Set<String> = []

    static func resetRoundHistory() {
        seenCorrects.removeAll()
    }

    static func generate(level: Int = 1) -> ChemistryProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        var candidates = pool.filter { !seenCorrects.contains($0.correct + ":" + $0.prompt) }
        if candidates.isEmpty {
            seenCorrects.subtract(pool.map { $0.correct + ":" + $0.prompt })
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        seenCorrects.insert(raw.correct + ":" + raw.prompt)
        return ChemistryProblem(
            prompt: raw.prompt,
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
        let correct: String
        let distractors: [String]
    }

    private static func pool(forLevel level: Int) -> [Raw] {
        let elements = ElementData.elements(forLevel: level)
        var pool: [Raw] = []
        for element in elements {
            pool.append(contentsOf: questions(for: element))
        }
        pool.append(contentsOf: specials(forLevel: level))
        return pool
    }

    /// Four programmatic questions per element. With 12+ elements per
    /// level this alone clears 48 questions; specials push us past 50.
    private static func questions(for e: ChemicalElement) -> [Raw] {
        let allOthers = ElementData.allElements.filter { $0.symbol != e.symbol }
        let otherSymbols = allOthers.map(\.symbol)
        let otherNames = allOthers.map(\.name)
        let otherNumbers = allOthers.map { String($0.atomicNumber) }
        let otherCategories = ["Metall", "Ikke-metall", "Edelgass", "Halogen", "Halvmetall", "Lantanid", "Aktinid"]
            .filter { $0 != e.category }

        return [
            Raw(prompt: "Hva er symbolet for \(e.name)?",
                correct: e.symbol,
                distractors: pick(otherSymbols, count: 3)),
            Raw(prompt: "Hvilket grunnstoff har symbolet \(e.symbol)?",
                correct: e.name,
                distractors: pick(otherNames, count: 3)),
            Raw(prompt: "Hva er atomnummeret til \(e.name)?",
                correct: String(e.atomicNumber),
                distractors: pick(otherNumbers, count: 3)),
            Raw(prompt: "Hvilken kategori er \(e.name) i?",
                correct: e.category,
                distractors: pick(otherCategories, count: 3))
        ]
    }

    private static func pick(_ pool: [String], count: Int) -> [String] {
        Array(Set(pool)).shuffled().prefix(count).map { $0 }
    }

    /// Handcrafted concept/state/reaction questions, layered by level.
    private static func specials(forLevel level: Int) -> [Raw] {
        switch level {
        case 1:
            return [
                Raw(prompt: "Hva er is?", correct: "Fast", distractors: ["Flytende", "Gass", "Damp"]),
                Raw(prompt: "Hva er vanndamp?", correct: "Gass", distractors: ["Fast", "Flytende", "Is"]),
                Raw(prompt: "Hva er vann?", correct: "Flytende", distractors: ["Fast", "Gass", "Stein"]),
                Raw(prompt: "Hva er luft?", correct: "Gass", distractors: ["Flytende", "Fast", "Vann"]),
                Raw(prompt: "Hva er stein?", correct: "Fast", distractors: ["Gass", "Flytende", "Damp"]),
                Raw(prompt: "Hva er melk?", correct: "Flytende", distractors: ["Fast", "Gass", "Damp"]),
                Raw(prompt: "Hva er røyk?", correct: "Gass", distractors: ["Fast", "Flytende", "Stein"]),
                Raw(prompt: "Hva er sand?", correct: "Fast", distractors: ["Gass", "Flytende", "Damp"]),
                Raw(prompt: "Hva er olje?", correct: "Flytende", distractors: ["Fast", "Gass", "Damp"]),
                Raw(prompt: "Hva er tåke?", correct: "Gass", distractors: ["Fast", "Flytende", "Stein"]),
                Raw(prompt: "Hvilken gass puster vi inn?", correct: "Oksygen", distractors: ["Karbondioksid", "Helium", "Hydrogen"]),
                Raw(prompt: "Hva består vann mest av?", correct: "Hydrogen og oksygen", distractors: ["Karbon og oksygen", "Nitrogen og hydrogen", "Salt og vann"]),
                Raw(prompt: "Hvilken farge har gull?", correct: "Gull/gul", distractors: ["Sølv", "Rød", "Blå"]),
                Raw(prompt: "Hvor lett er helium sammenlignet med luft?", correct: "Lettere", distractors: ["Tyngre", "Likt", "Helium har ikke vekt"]),
                Raw(prompt: "Hvor finner vi mest vann på jorda?", correct: "I havene", distractors: ["I innsjøer", "I skyer", "I elver"]),
                Raw(prompt: "Hva er det største kjente atomet (vanlig)?", correct: "Uran", distractors: ["Hydrogen", "Helium", "Oksygen"]),
                Raw(prompt: "Hvilket grunnstoff er det mest av i kroppen?", correct: "Oksygen", distractors: ["Karbon", "Hydrogen", "Nitrogen"]),
                Raw(prompt: "Hva blir vann til når det fryser?", correct: "Is", distractors: ["Damp", "Gass", "Tåke"]),
                Raw(prompt: "Hva er ofte i bobler?", correct: "Gass", distractors: ["Fast stoff", "Flytende stoff", "Stein"]),
                Raw(prompt: "Hva er metall?", correct: "Fast", distractors: ["Flytende", "Gass", "Damp"])
            ]
        case 2:
            return [
                Raw(prompt: "Hva får vi når salt løses i vann?", correct: "Saltvann", distractors: ["Sukkervann", "Olje", "Sand"]),
                Raw(prompt: "Hvordan skille sand fra vann?", correct: "Filtrere", distractors: ["Koke", "Fryse", "Riste"]),
                Raw(prompt: "Hva skjer med vann ved 0°C?", correct: "Fryser", distractors: ["Koker", "Fordamper", "Brenner"]),
                Raw(prompt: "Hva skjer med vann ved 100°C?", correct: "Koker", distractors: ["Fryser", "Smelter", "Stivner"]),
                Raw(prompt: "Hva er sukker i te et eksempel på?", correct: "Løsning", distractors: ["Røyk", "Tåke", "Damp"]),
                Raw(prompt: "Hvilken gass puster vi ut?", correct: "Karbondioksid", distractors: ["Oksygen", "Nitrogen", "Helium"]),
                Raw(prompt: "Hva er den vanligste gassen i luft?", correct: "Nitrogen", distractors: ["Oksygen", "Karbondioksid", "Hydrogen"]),
                Raw(prompt: "Hvordan kan vi skille olje fra vann?", correct: "Skilletrakt", distractors: ["Koke", "Fryse", "Filtrere"]),
                Raw(prompt: "Hva skjer når sukker varmes lenge?", correct: "Karamelliseres", distractors: ["Fryser", "Fordamper", "Eksploderer"]),
                Raw(prompt: "Hva er en blanding av flere stoffer?", correct: "Blanding", distractors: ["Grunnstoff", "Atom", "Molekyl"]),
                Raw(prompt: "Hva er et stoff som ikke kan brytes ned kjemisk?", correct: "Grunnstoff", distractors: ["Blanding", "Forbindelse", "Løsning"]),
                Raw(prompt: "Hvilken metode bruker vi for å rense skittent vann?", correct: "Filtrering", distractors: ["Koking", "Frysing", "Salting"]),
                Raw(prompt: "Hva får vi når sukker løses i vann?", correct: "Sukkervann", distractors: ["Saltvann", "Olje", "Stivelse"]),
                Raw(prompt: "Hva kalles damp som blir til væske?", correct: "Kondensering", distractors: ["Fordamping", "Frysing", "Smelting"]),
                Raw(prompt: "Hvor finner du mest oksygen?", correct: "I luften", distractors: ["I sand", "I metall", "I stein"]),
                Raw(prompt: "Hvilken gass bruker planter til fotosyntese?", correct: "Karbondioksid", distractors: ["Oksygen", "Nitrogen", "Helium"]),
                Raw(prompt: "Hva produseres av planter ved fotosyntese?", correct: "Oksygen", distractors: ["Karbondioksid", "Nitrogen", "Hydrogen"]),
                Raw(prompt: "Hva kalles vann i gassform?", correct: "Vanndamp", distractors: ["Is", "Skum", "Tåke"]),
                Raw(prompt: "Hva kalles tåke høyt oppe på himmelen?", correct: "Skyer", distractors: ["Damp", "Røyk", "Frost"]),
                Raw(prompt: "Hva kalles is som blir til vann?", correct: "Smelting", distractors: ["Frysing", "Fordamping", "Kondensering"])
            ]
        case 3, 4:
            return [
                Raw(prompt: "Hva kalles overgang fra fast til flytende?", correct: "Smelting",
                    distractors: ["Fordamping", "Frysing", "Sublimering"]),
                Raw(prompt: "Hva kalles overgang fra flytende til gass?", correct: "Fordamping",
                    distractors: ["Smelting", "Kondensering", "Sublimering"]),
                Raw(prompt: "Hva kalles overgang fra gass til flytende?", correct: "Kondensering",
                    distractors: ["Smelting", "Sublimering", "Fordamping"]),
                Raw(prompt: "Hva kalles direkte overgang fra fast til gass?", correct: "Sublimering",
                    distractors: ["Fordamping", "Kondensering", "Smelting"]),
                Raw(prompt: "Hvilken pH-verdi har rent vann?", correct: "7",
                    distractors: ["1", "10", "14"]),
                Raw(prompt: "Hva er den kjemiske formelen for vann?", correct: "H₂O",
                    distractors: ["CO₂", "O₂", "H₂"]),
                Raw(prompt: "Hva er den kjemiske formelen for karbondioksid?", correct: "CO₂",
                    distractors: ["CO", "C₂O", "CH₄"])
            ]
        case 5, 6:
            return [
                Raw(prompt: "Hva er den kjemiske formelen for ammoniakk?", correct: "NH₃",
                    distractors: ["NO₂", "N₂", "NaCl"]),
                Raw(prompt: "Hva er den kjemiske formelen for metan?", correct: "CH₄",
                    distractors: ["CO₂", "C₂H₆", "CH₃"]),
                Raw(prompt: "Hva er den kjemiske formelen for vanlig salt?", correct: "NaCl",
                    distractors: ["KCl", "MgCl₂", "CaCl₂"]),
                Raw(prompt: "Hva betyr en pH < 7?", correct: "Sur",
                    distractors: ["Basisk", "Nøytral", "Salt"]),
                Raw(prompt: "Hva betyr en pH > 7?", correct: "Basisk",
                    distractors: ["Sur", "Nøytral", "Salt"]),
                Raw(prompt: "Hva produserer planter ved fotosyntese?", correct: "Oksygen",
                    distractors: ["Karbondioksid", "Hydrogen", "Nitrogen"]),
                Raw(prompt: "Hva er det vanligste isotopet av hydrogen?", correct: "Protium",
                    distractors: ["Deuterium", "Tritium", "Helium-3"])
            ]
        case 7, 8:
            return [
                Raw(prompt: "Hvilken bindingstype har NaCl?", correct: "Ionebinding",
                    distractors: ["Kovalent", "Metallbinding", "Hydrogenbinding"]),
                Raw(prompt: "Hvilken bindingstype har H₂O?", correct: "Kovalent",
                    distractors: ["Ionebinding", "Metallbinding", "Van der Waals"]),
                Raw(prompt: "Hvor mange elektroner har et nøytralt karbon-atom?", correct: "6",
                    distractors: ["4", "8", "12"]),
                Raw(prompt: "Hvilken edelgass har lavest kokepunkt?", correct: "Helium",
                    distractors: ["Neon", "Argon", "Krypton"]),
                Raw(prompt: "Hva er Avogadros tall (omtrentlig)?", correct: "6.02 × 10²³",
                    distractors: ["3.14 × 10⁸", "1.6 × 10⁻¹⁹", "9.11 × 10⁻³¹"]),
                Raw(prompt: "Hva har en mol av et stoff?", correct: "Avogadros antall partikler",
                    distractors: ["1 gram", "1 liter", "100 partikler"]),
                Raw(prompt: "Hvilket grunnstoff finnes det mest av i universet?", correct: "Hydrogen",
                    distractors: ["Helium", "Oksygen", "Karbon"])
            ]
        case 9, 10:
            return [
                Raw(prompt: "Hva er en katalysator?", correct: "Stoff som øker reaksjonshastighet",
                    distractors: ["Stoff som forbrukes", "Reaksjonsprodukt", "Reaktant"]),
                Raw(prompt: "Hva kalles en reaksjon som avgir varme?", correct: "Eksoterm",
                    distractors: ["Endoterm", "Isoterm", "Adiabatisk"]),
                Raw(prompt: "Hva kalles en reaksjon som tar opp varme?", correct: "Endoterm",
                    distractors: ["Eksoterm", "Isoterm", "Adiabatisk"]),
                Raw(prompt: "Hva er den korrekte formelen for svovelsyre?", correct: "H₂SO₄",
                    distractors: ["HCl", "HNO₃", "H₂CO₃"]),
                Raw(prompt: "Hva er den korrekte formelen for saltsyre?", correct: "HCl",
                    distractors: ["H₂SO₄", "HNO₃", "HF"]),
                Raw(prompt: "Hva er den korrekte formelen for natriumhydroksid?", correct: "NaOH",
                    distractors: ["KOH", "Ca(OH)₂", "NH₄OH"]),
                Raw(prompt: "Hva er glukose sin formel?", correct: "C₆H₁₂O₆",
                    distractors: ["C₆H₆", "C₂H₆O", "CH₂O"])
            ]
        case 11, 12:
            return [
                Raw(prompt: "Hva er hovedtypen binding i diamant?", correct: "Kovalent",
                    distractors: ["Ionebinding", "Metallbinding", "Hydrogenbinding"]),
                Raw(prompt: "Hva kalles karbonets allotrop med 60 atomer?", correct: "Buckminsterfulleren",
                    distractors: ["Grafitt", "Diamant", "Grafén"]),
                Raw(prompt: "Hvilken syre finnes i magen?", correct: "Saltsyre",
                    distractors: ["Sitronsyre", "Eddiksyre", "Karbonsyre"]),
                Raw(prompt: "Hva er en halveringstid?", correct: "Tid det tar at halvparten henfaller",
                    distractors: ["Reaksjonshastighet", "Stoff som dannes", "Energimengde"]),
                Raw(prompt: "Hva er pH til ren maget syre (omtrentlig)?", correct: "1.5",
                    distractors: ["7", "5", "3"]),
                Raw(prompt: "Hvilket grunnstoff har symbolet Pb?", correct: "Bly",
                    distractors: ["Polonium", "Platina", "Plutonium"]),
                Raw(prompt: "Hva er en isotop?", correct: "Atomer med samme protontall, ulikt nøytrontall",
                    distractors: ["Atomer med ulik ladning", "Atomer i forskjellig tilstand", "Forskjellige grunnstoffer"])
            ]
        case 13, 14:
            return [
                Raw(prompt: "Hva produseres når en syre nøytraliseres med en base?", correct: "Salt og vann",
                    distractors: ["Kun vann", "Kun salt", "En gass"]),
                Raw(prompt: "Hva kalles en reaksjon der elektroner overføres?", correct: "Redoksreaksjon",
                    distractors: ["Syre-base", "Hydrolyse", "Polymerisering"]),
                Raw(prompt: "Hva betyr oksidasjon?", correct: "Tap av elektroner",
                    distractors: ["Tap av protoner", "Opptak av elektroner", "Opptak av nøytroner"]),
                Raw(prompt: "Hva betyr reduksjon?", correct: "Opptak av elektroner",
                    distractors: ["Tap av elektroner", "Opptak av protoner", "Tap av nøytroner"]),
                Raw(prompt: "Hva er den vanligste isotopen av karbon?", correct: "Karbon-12",
                    distractors: ["Karbon-13", "Karbon-14", "Karbon-11"]),
                Raw(prompt: "Hvilket organisk stoff har O-H-funksjonelle gruppe?", correct: "Alkohol",
                    distractors: ["Alkan", "Alken", "Aldehyd"]),
                Raw(prompt: "Hvilket organisk stoff har C=O i kjedeenden?", correct: "Aldehyd",
                    distractors: ["Keton", "Eter", "Alkohol"])
            ]
        case 15, 16:
            return [
                Raw(prompt: "Hvilken type reaksjon er forbrenning?", correct: "Eksoterm redoks",
                    distractors: ["Endoterm syre-base", "Polymerisering", "Hydrolyse"]),
                Raw(prompt: "Hva kalles en blanding av to ikke-blandbare væsker?", correct: "Emulsjon",
                    distractors: ["Suspensjon", "Løsning", "Kolloid"]),
                Raw(prompt: "Hva er Le Chateliers prinsipp om?", correct: "Likevektsforskyvning",
                    distractors: ["Reaksjonshastighet", "Energiinnhold", "Atomstruktur"]),
                Raw(prompt: "Hva kalles en gass som ikke følger ideell gasslov?", correct: "Reell gass",
                    distractors: ["Edelgass", "Halogen", "Plasma"]),
                Raw(prompt: "Hva betyr stereoisomeri?", correct: "Samme formel, ulik 3D-struktur",
                    distractors: ["Samme atomer, ulik rekkefølge", "Forskjellig formel", "Resonans"]),
                Raw(prompt: "Hvilken lov beskriver gassers volum og temperatur?", correct: "Charles' lov",
                    distractors: ["Boyles lov", "Avogadros lov", "Daltons lov"]),
                Raw(prompt: "Hva er en peptidbinding?", correct: "Binding mellom aminosyrer",
                    distractors: ["Binding mellom sukkere", "Hydrogenbinding i DNA", "Disulfidbinding"])
            ]
        case 17, 18:
            return [
                Raw(prompt: "Hva er en chiral forbindelse?", correct: "Asymmetrisk molekyl",
                    distractors: ["Symmetrisk molekyl", "Polart molekyl", "Aromatisk forbindelse"]),
                Raw(prompt: "Hvilken hybridisering har et sp³-karbon?", correct: "Tetraedrisk",
                    distractors: ["Trigonal plan", "Lineær", "Trigonal bipyramidal"]),
                Raw(prompt: "Hva betyr SN1-reaksjon?", correct: "Substitusjon, nukleofil, første ordens",
                    distractors: ["Sentral nøytral", "Symmetrisk neon", "Stereo nøytral"]),
                Raw(prompt: "Hva er en aromatisk forbindelse (eksempel)?", correct: "Benzen",
                    distractors: ["Cyklopropan", "Etan", "Aceton"]),
                Raw(prompt: "Hvilken gruppe karakteriserer estere?", correct: "-COO-",
                    distractors: ["-OH", "-NH₂", "-CHO"]),
                Raw(prompt: "Hva er Avogadros lov?", correct: "Like volum gass har like mange molekyler",
                    distractors: ["Trykk × volum konstant", "Volum × T konstant", "P × V = n × R × T"]),
                Raw(prompt: "Hva er ideell gasslov?", correct: "PV = nRT",
                    distractors: ["E = mc²", "F = ma", "V = IR"])
            ]
        default:
            return [
                Raw(prompt: "Hva er Schrödinger-ligningen brukt til?", correct: "Beskrive elektroners bølgefunksjon",
                    distractors: ["Beregne reaksjonshastighet", "Måle pH", "Beregne molekylvekt"]),
                Raw(prompt: "Hva betyr orbital?", correct: "Sannsynlighetsområde for elektron",
                    distractors: ["Eksakt elektronbane", "Atomkjerne", "Molekylformel"]),
                Raw(prompt: "Hvilken bindingsteori bruker MO-diagrammer?", correct: "Molekylorbital-teori",
                    distractors: ["VSEPR", "Krystallfeltteori", "Hückel-teori"]),
                Raw(prompt: "Hva er en katalysators rolle i reaksjon?", correct: "Senker aktiveringsenergien",
                    distractors: ["Forskyver likevekten", "Endrer reaksjonsproduktene", "Brukes opp"]),
                Raw(prompt: "Hva er Gibbs fri energi (G) brukt til?", correct: "Forutsi spontanitet",
                    distractors: ["Beregne entropi alene", "Måle reaksjonshastighet", "Bestemme molekylvekt"]),
                Raw(prompt: "Hva betyr ΔG < 0?", correct: "Spontan reaksjon",
                    distractors: ["Ikke-spontan", "I likevekt", "Rask reaksjon"]),
                Raw(prompt: "Hva beskriver entropi?", correct: "Uorden i et system",
                    distractors: ["Energiinnhold", "Trykk", "Reaksjonshastighet"])
            ]
        }
    }
}
