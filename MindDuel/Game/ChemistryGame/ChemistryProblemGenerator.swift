import Foundation

/// Curriculum-aligned chemistry questions (issue #15). Mirrors the math
/// generator's level-mapping (#27):
///   • L1–L10  → grunnskolen 1.–10. klasse
///   • L11–L13 → videregående (Kjemi 1 / Kjemi 2)
///   • L14–L20 → universitetsnivå (innføring → forskning)
///
/// Implementation: handcrafted multiple-choice pools per level. The generator
/// picks one entry at random and shuffles the distractors so the correct
/// option's index varies. All strings are Norwegian to match curriculum
/// vocabulary (the rest of the app is bilingual but chemistry terminology
/// is taught in Norwegian in the school context the issue calls out).
enum ChemistryProblemGenerator {

    static func generate(level: Int = 1) -> ChemistryProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        let raw = pool.randomElement() ?? pool[0]
        return ChemistryProblem(
            prompt: raw.prompt,
            correctAnswer: raw.correct,
            options: ([raw.correct] + raw.distractors).shuffled()
        )
    }

    /// Curriculum label — same scheme as MathProblemGenerator.
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

    // MARK: – Question pools

    private struct Raw {
        let prompt: String
        let correct: String
        let distractors: [String]
    }

    // swiftlint:disable function_body_length
    private static func pool(forLevel level: Int) -> [Raw] {
        switch level {

        // MARK: Grunnskolen

        case 1: // 1. klasse: faste, flytende, gass
            return [
                Raw(prompt: "Hva er is?", correct: "Fast",
                    distractors: ["Flytende", "Gass", "Damp"]),
                Raw(prompt: "Hva er vanndamp?", correct: "Gass",
                    distractors: ["Fast", "Flytende", "Is"]),
                Raw(prompt: "Hva er vann?", correct: "Flytende",
                    distractors: ["Fast", "Gass", "Stein"]),
                Raw(prompt: "Hva er luft?", correct: "Gass",
                    distractors: ["Flytende", "Fast", "Vann"]),
                Raw(prompt: "Hva er stein?", correct: "Fast",
                    distractors: ["Gass", "Flytende", "Damp"])
            ]

        case 2: // 2. klasse: enkle blandinger og separasjoner
            return [
                Raw(prompt: "Hva får vi når salt løses i vann?", correct: "Saltvann",
                    distractors: ["Sukkervann", "Olje", "Sand"]),
                Raw(prompt: "Hvordan skille sand fra vann?", correct: "Filtrere",
                    distractors: ["Koke", "Fryse", "Riste"]),
                Raw(prompt: "Hva skjer med vann ved 0°C?", correct: "Fryser",
                    distractors: ["Koker", "Fordamper", "Brenner"]),
                Raw(prompt: "Hva skjer med vann ved 100°C?", correct: "Koker",
                    distractors: ["Fryser", "Smelter", "Stivner"]),
                Raw(prompt: "Hva er sukker i te et eksempel på?", correct: "Løsning",
                    distractors: ["Røyk", "Tåke", "Damp"])
            ]

        case 3: // 3. klasse: luft, vann, vanlige stoffer
            return [
                Raw(prompt: "Hvilken gass puster vi inn?", correct: "Oksygen",
                    distractors: ["Karbondioksid", "Helium", "Hydrogen"]),
                Raw(prompt: "Hvilken gass puster vi ut?", correct: "Karbondioksid",
                    distractors: ["Oksygen", "Nitrogen", "Helium"]),
                Raw(prompt: "Hva består vann mest av?", correct: "Hydrogen og oksygen",
                    distractors: ["Karbon og oksygen", "Nitrogen og hydrogen", "Salt og vann"]),
                Raw(prompt: "Hva er den vanligste gassen i luft?", correct: "Nitrogen",
                    distractors: ["Oksygen", "Karbondioksid", "Hydrogen"]),
                Raw(prompt: "Hvilket kjent stoff er saltet på maten?", correct: "Natriumklorid",
                    distractors: ["Sukker", "Eddik", "Vann"])
            ]

        case 4: // 4. klasse: tilstandsformer, smelte/fryse
            return [
                Raw(prompt: "Hva kalles overgang fra fast til flytende?", correct: "Smelting",
                    distractors: ["Fordamping", "Frysing", "Sublimering"]),
                Raw(prompt: "Hva kalles overgang fra flytende til gass?", correct: "Fordamping",
                    distractors: ["Smelting", "Kondensering", "Sublimering"]),
                Raw(prompt: "Hva kalles overgang fra gass til flytende?", correct: "Kondensering",
                    distractors: ["Fordamping", "Smelting", "Frysing"]),
                Raw(prompt: "Hva er røyk hovedsakelig?", correct: "Små partikler i gass",
                    distractors: ["Bare vann", "Stein", "Olje"]),
                Raw(prompt: "Hva er tettheten til ferskvann (g/cm³)?", correct: "1",
                    distractors: ["10", "0.1", "100"])
            ]

        case 5: // 5. klasse: syrer, baser, indikator
            return [
                Raw(prompt: "Eddik er ...", correct: "Syre",
                    distractors: ["Base", "Salt", "Nøytralt"]),
                Raw(prompt: "Såpe er typisk ...", correct: "Base",
                    distractors: ["Syre", "Salt", "Nøytralt"]),
                Raw(prompt: "Hva blir lakmuspapir i syre?", correct: "Rødt",
                    distractors: ["Blått", "Grønt", "Gult"]),
                Raw(prompt: "Hva blir lakmuspapir i base?", correct: "Blått",
                    distractors: ["Rødt", "Grønt", "Hvitt"]),
                Raw(prompt: "Hva er pH for nøytralt vann?", correct: "7",
                    distractors: ["1", "14", "10"])
            ]

        case 6: // 6. klasse: grunnstoffer og symboler
            return [
                Raw(prompt: "Symbol for hydrogen?", correct: "H",
                    distractors: ["He", "Hg", "Hy"]),
                Raw(prompt: "Symbol for oksygen?", correct: "O",
                    distractors: ["Ox", "Og", "O₂"]),
                Raw(prompt: "Symbol for karbon?", correct: "C",
                    distractors: ["K", "Ca", "Co"]),
                Raw(prompt: "Symbol for natrium?", correct: "Na",
                    distractors: ["N", "Ne", "K"]),
                Raw(prompt: "Symbol for jern?", correct: "Fe",
                    distractors: ["Je", "Ir", "Au"]),
                Raw(prompt: "Symbol for gull?", correct: "Au",
                    distractors: ["Ag", "Gu", "Go"]),
                Raw(prompt: "Symbol for sølv?", correct: "Ag",
                    distractors: ["Si", "Au", "S"])
            ]

        case 7: // 7. klasse: enkle formler
            return [
                Raw(prompt: "Vann har formel ...", correct: "H₂O",
                    distractors: ["HO", "H₂O₂", "OH₂"]),
                Raw(prompt: "Karbondioksid har formel ...", correct: "CO₂",
                    distractors: ["CO", "C₂O", "C₂O₂"]),
                Raw(prompt: "Bordsalt har formel ...", correct: "NaCl",
                    distractors: ["NaC", "NCl", "Na₂Cl"]),
                Raw(prompt: "Metan har formel ...", correct: "CH₄",
                    distractors: ["CH₂", "C₂H₄", "CH₃"]),
                Raw(prompt: "Ammoniakk har formel ...", correct: "NH₃",
                    distractors: ["NH₄", "N₂H₃", "NH"])
            ]

        case 8: // 8. klasse: atomstruktur
            return [
                Raw(prompt: "Hvor mange protoner har hydrogen?", correct: "1",
                    distractors: ["0", "2", "7"]),
                Raw(prompt: "Hvor mange protoner har karbon?", correct: "6",
                    distractors: ["4", "8", "12"]),
                Raw(prompt: "Hvor mange protoner har oksygen?", correct: "8",
                    distractors: ["6", "16", "2"]),
                Raw(prompt: "Hva har positiv ladning i atomet?", correct: "Proton",
                    distractors: ["Elektron", "Nøytron", "Foton"]),
                Raw(prompt: "Hva har ingen ladning?", correct: "Nøytron",
                    distractors: ["Proton", "Elektron", "Ion"]),
                Raw(prompt: "Atomnummer = antall ...", correct: "Protoner",
                    distractors: ["Nøytroner", "Elektronskall", "Molekyler"])
            ]

        case 9: // 9. klasse: enkle reaksjoner og ioner
            return [
                Raw(prompt: "Balanser: 2H₂ + O₂ → ?", correct: "2H₂O",
                    distractors: ["H₂O", "H₂O₂", "HO₂"]),
                Raw(prompt: "Hva er ladningen til Na⁺-ionet?", correct: "+1",
                    distractors: ["−1", "+2", "0"]),
                Raw(prompt: "Hva er ladningen til klorid (Cl)?", correct: "−1",
                    distractors: ["+1", "−2", "+2"]),
                Raw(prompt: "Hva er ladningen til Mg²⁺?", correct: "+2",
                    distractors: ["+1", "−2", "+3"]),
                Raw(prompt: "Hva produseres når en syre reagerer med metall?", correct: "Hydrogen",
                    distractors: ["Oksygen", "Klor", "Vann"])
            ]

        case 10: // 10. klasse: mol og enkle støkiometri
            return [
                Raw(prompt: "Avogadros tall i 10⁻²³ er omtrent ...", correct: "6,02·10²³",
                    distractors: ["3,14·10²³", "9,81·10²³", "1,60·10²³"]),
                Raw(prompt: "Molar masse av vann (g/mol)?", correct: "18",
                    distractors: ["16", "20", "32"]),
                Raw(prompt: "Molar masse av CO₂ (g/mol)?", correct: "44",
                    distractors: ["28", "32", "16"]),
                Raw(prompt: "Hvor mange mol er 36 g vann?", correct: "2",
                    distractors: ["1", "4", "0.5"]),
                Raw(prompt: "1 mol av et stoff inneholder ... partikler", correct: "6,02·10²³",
                    distractors: ["10²³", "10²⁴", "1000"])
            ]

        // MARK: Videregående

        case 11: // 1VGS / Kjemi-grunnkurs: termokjemi-konsepter
            return [
                Raw(prompt: "Eksoterm reaksjon ...", correct: "Frigjør varme",
                    distractors: ["Tar opp varme", "Endrer ikke energi", "Senker temperatur"]),
                Raw(prompt: "Endoterm reaksjon ...", correct: "Tar opp varme",
                    distractors: ["Frigjør varme", "Frigjør lys", "Konsumerer ikke energi"]),
                Raw(prompt: "Forbrenning er typisk ...", correct: "Eksoterm",
                    distractors: ["Endoterm", "Nøytral", "Adiabatisk"]),
                Raw(prompt: "Aktiveringsenergi er ...", correct: "Energibarriere for reaksjon",
                    distractors: ["Total reaksjonsenergi", "Energi i produktene", "Konstant for alle reaksjoner"]),
                Raw(prompt: "Katalysator endrer ...", correct: "Reaksjonshastigheten",
                    distractors: ["Likevektsposisjonen", "Antall produkter", "Trykk"])
            ]

        case 12: // 2VGS / Kjemi 1: likevekt, Le Chatelier
            return [
                Raw(prompt: "Le Chateliers prinsipp gjelder ...", correct: "Likevekt",
                    distractors: ["Reaksjonshastighet", "Aktiveringsenergi", "Entropi"]),
                Raw(prompt: "Økt trykk i N₂+3H₂⇌2NH₃ flytter mot ...", correct: "Produktene",
                    distractors: ["Reaktantene", "Ingen endring", "Kun reaktantene øker"]),
                Raw(prompt: "Likevektskonstanten K endres med ...", correct: "Temperatur",
                    distractors: ["Trykk", "Konsentrasjon", "Volum"]),
                Raw(prompt: "Hvis K ≫ 1 dominerer ...", correct: "Produktene",
                    distractors: ["Reaktantene", "Like mengder", "Ingen reaksjon"]),
                Raw(prompt: "Q < K betyr ...", correct: "Reaksjonen går mot produkter",
                    distractors: ["Reaksjonen går mot reaktanter", "Likevekt nådd", "Reaksjonen stopper"])
            ]

        case 13: // 3VGS / Kjemi 2: organiske funksjonelle grupper
            return [
                Raw(prompt: "−OH er funksjonell gruppe i ...", correct: "Alkohol",
                    distractors: ["Alkan", "Aldehyd", "Eter"]),
                Raw(prompt: "−COOH er funksjonell gruppe i ...", correct: "Karboksylsyre",
                    distractors: ["Aldehyd", "Keton", "Ester"]),
                Raw(prompt: "−CHO er ...", correct: "Aldehyd",
                    distractors: ["Keton", "Alkohol", "Eter"]),
                Raw(prompt: "C=O midt i kjede er ...", correct: "Keton",
                    distractors: ["Aldehyd", "Karboksylsyre", "Alkohol"]),
                Raw(prompt: "Etanol har formel ...", correct: "C₂H₅OH",
                    distractors: ["CH₃OH", "C₃H₇OH", "CH₄O₂"])
            ]

        // MARK: Universitet

        case 14: // Univ. innføring: elektronkonfigurasjon
            return [
                Raw(prompt: "Elektronkonfigurasjon for C?", correct: "1s² 2s² 2p²",
                    distractors: ["1s² 2s² 2p⁴", "1s² 2s² 2p¹", "1s² 2s¹ 2p³"]),
                Raw(prompt: "Antall valenselektroner i N?", correct: "5",
                    distractors: ["3", "7", "8"]),
                Raw(prompt: "Hovedkvantetallet n bestemmer ...", correct: "Skall",
                    distractors: ["Spinn", "Form på orbital", "Magnetisk retning"]),
                Raw(prompt: "Maks elektroner i et p-underskall?", correct: "6",
                    distractors: ["2", "10", "14"]),
                Raw(prompt: "Hund's regel handler om ...", correct: "Maks parallelle spinn",
                    distractors: ["Pauli-prinsippet", "Aufbau-orden", "Elektronegativitet"])
            ]

        case 15: // Univ. grunnleggende: kinetikk
            return [
                Raw(prompt: "Hastighetslov for første orden: r = k·[A]ⁿ, n = ?", correct: "1",
                    distractors: ["0", "2", "−1"]),
                Raw(prompt: "Halveringstid t½ for 1. orden er ...", correct: "ln 2 / k",
                    distractors: ["1/(k·[A]₀)", "k·ln 2", "[A]₀/2k"]),
                Raw(prompt: "Arrhenius: k = A·exp(...)", correct: "−Eₐ/RT",
                    distractors: ["Eₐ/RT", "−RT/Eₐ", "ln(Eₐ)"]),
                Raw(prompt: "Reaksjonens orden er ...", correct: "Sum av eksponenter i hastighetslov",
                    distractors: ["Antall reaktanter", "Antall produkter", "Molforholdet"]),
                Raw(prompt: "Doblet T øker k typisk ...", correct: "Mye (eksponentielt)",
                    distractors: ["Lite", "Lineært", "Halverer k"])
            ]

        case 16: // Univ. mellom: termodynamikk
            return [
                Raw(prompt: "Gibbs energi: ΔG = ΔH − ?", correct: "TΔS",
                    distractors: ["ΔS/T", "T·ΔH", "ΔH/T"]),
                Raw(prompt: "Spontan reaksjon krever ...", correct: "ΔG < 0",
                    distractors: ["ΔG > 0", "ΔH < 0 alltid", "ΔS < 0"]),
                Raw(prompt: "Ved likevekt er ΔG = ?", correct: "0",
                    distractors: ["ΔH", "−TΔS", "RT"]),
                Raw(prompt: "ΔS for fasechange fast→gass er ...", correct: "Positiv",
                    distractors: ["Negativ", "Null", "Avhenger av stoff"]),
                Raw(prompt: "ΔG° = −RT ln ?", correct: "K",
                    distractors: ["Q", "Eₐ", "k"])
            ]

        case 17: // Univ. høy: spektroskopi
            return [
                Raw(prompt: "IR måler ...", correct: "Vibrasjoner",
                    distractors: ["Spinn", "Elektronoverganger", "Kjernemasse"]),
                Raw(prompt: "¹H-NMR informerer om ...", correct: "Hydrogen-miljø",
                    distractors: ["Massetall", "Bindingsenergi", "Smeltepunkt"]),
                Raw(prompt: "MS gir oss ...", correct: "Masse/ladning-forhold",
                    distractors: ["Bindingsenergi", "pH", "Volum"]),
                Raw(prompt: "UV-Vis brukes for ...", correct: "Elektronoverganger",
                    distractors: ["Vibrasjoner", "Kjernespinn", "Atomradius"]),
                Raw(prompt: "Bølgetall i IR har enhet ...", correct: "cm⁻¹",
                    distractors: ["Hz", "ppm", "nm"])
            ]

        case 18: // Univ. avansert: organiske mekanismer
            return [
                Raw(prompt: "SN2 har ... overgang", correct: "Konsertert (én trinn)",
                    distractors: ["To trinn", "Tre trinn", "Radikalsk"]),
                Raw(prompt: "SN1 produserer typisk ...", correct: "Karbokation-intermediat",
                    distractors: ["Karbanion", "Radikal", "Singlett"]),
                Raw(prompt: "E2-eliminering favoriseres av ...", correct: "Sterke baser",
                    distractors: ["Svake nukleofiler", "Vann", "Lave temperaturer"]),
                Raw(prompt: "Markovnikovs regel handler om ...", correct: "H til C med flest H",
                    distractors: ["H til C med færrest H", "Halogenposisjon", "Elektronegativitet"]),
                Raw(prompt: "Tertiær karbokation er mer stabil enn ...", correct: "Primær",
                    distractors: ["Aromatisk", "Allylisk", "Benzyl"])
            ]

        case 19: // Univ. master: koordinasjonskjemi
            return [
                Raw(prompt: "Oksidasjonstall til Fe i [Fe(CN)₆]³⁻?", correct: "+3",
                    distractors: ["+2", "+6", "0"]),
                Raw(prompt: "Vanlig koordinasjonstall for oktaedrisk kompleks?", correct: "6",
                    distractors: ["4", "2", "8"]),
                Raw(prompt: "Hva er en chelatligand?", correct: "Binder med flere atomer",
                    distractors: ["Bare ett atom", "Ikke til metall", "Ladd metallion"]),
                Raw(prompt: "Krystallfeltteorien forklarer ...", correct: "d-orbital splitting",
                    distractors: ["Bindingsorden", "Hybridisering", "Resonans"]),
                Raw(prompt: "Sterk-felt ligand gir ...", correct: "Lavspinn",
                    distractors: ["Høyspinn", "Ingen spinn", "Diamagnet kun"])
            ]

        default: // Level 20: Forskningsnivå — MO og avansert
            return [
                Raw(prompt: "Antall MO fra n AO?", correct: "n",
                    distractors: ["n²", "2n", "n/2"]),
                Raw(prompt: "Bindingsorden i N₂?", correct: "3",
                    distractors: ["1", "2", "4"]),
                Raw(prompt: "HOMO står for ...", correct: "Highest occupied MO",
                    distractors: ["High order MO", "Half occupied", "Hund's MO"]),
                Raw(prompt: "Diels-Alder er ... reaksjon", correct: "[4+2]-cykloaddisjon",
                    distractors: ["[2+2]", "Friedel-Crafts", "Aldol"]),
                Raw(prompt: "Hückels regel for aromatisitet: 4n + ?", correct: "2",
                    distractors: ["1", "3", "0"])
            ]
        }
    }
    // swiftlint:enable function_body_length
}
