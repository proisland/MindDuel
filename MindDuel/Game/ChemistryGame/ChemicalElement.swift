import Foundation

/// Periodic-table reference data used by `ChemistryProblemGenerator`.
/// Each element yields ~4 derived questions (symbol, name-from-symbol,
/// atomic number, category) so a 12-element level expands to 48+
/// programmatic questions before any handcrafted specials.
struct ChemicalElement {
    let name: String        // "Oksygen"
    let symbol: String      // "O"
    let atomicNumber: Int   // 8
    let category: String    // "Ikke-metall"
}

enum ElementData {
    // swiftlint:disable function_body_length
    static func elements(forLevel level: Int) -> [ChemicalElement] {
        switch max(1, min(20, level)) {
        // Levels 1–2 keep concept questions; we still expose a few elements
        // so the programmatic question types can fire.
        case 1, 2:
            return [
                ChemicalElement(name: "Hydrogen",  symbol: "H",  atomicNumber: 1,  category: "Ikke-metall"),
                ChemicalElement(name: "Oksygen",   symbol: "O",  atomicNumber: 8,  category: "Ikke-metall"),
                ChemicalElement(name: "Karbon",    symbol: "C",  atomicNumber: 6,  category: "Ikke-metall"),
                ChemicalElement(name: "Nitrogen",  symbol: "N",  atomicNumber: 7,  category: "Ikke-metall"),
                ChemicalElement(name: "Helium",    symbol: "He", atomicNumber: 2,  category: "Edelgass"),
                ChemicalElement(name: "Jern",      symbol: "Fe", atomicNumber: 26, category: "Metall"),
                ChemicalElement(name: "Gull",      symbol: "Au", atomicNumber: 79, category: "Metall"),
                ChemicalElement(name: "Sølv",      symbol: "Ag", atomicNumber: 47, category: "Metall")
            ]
        case 3, 4:
            return [
                ChemicalElement(name: "Hydrogen",  symbol: "H",  atomicNumber: 1,  category: "Ikke-metall"),
                ChemicalElement(name: "Helium",    symbol: "He", atomicNumber: 2,  category: "Edelgass"),
                ChemicalElement(name: "Litium",    symbol: "Li", atomicNumber: 3,  category: "Metall"),
                ChemicalElement(name: "Karbon",    symbol: "C",  atomicNumber: 6,  category: "Ikke-metall"),
                ChemicalElement(name: "Nitrogen",  symbol: "N",  atomicNumber: 7,  category: "Ikke-metall"),
                ChemicalElement(name: "Oksygen",   symbol: "O",  atomicNumber: 8,  category: "Ikke-metall"),
                ChemicalElement(name: "Fluor",     symbol: "F",  atomicNumber: 9,  category: "Halogen"),
                ChemicalElement(name: "Neon",      symbol: "Ne", atomicNumber: 10, category: "Edelgass"),
                ChemicalElement(name: "Natrium",   symbol: "Na", atomicNumber: 11, category: "Metall"),
                ChemicalElement(name: "Magnesium", symbol: "Mg", atomicNumber: 12, category: "Metall"),
                ChemicalElement(name: "Klor",      symbol: "Cl", atomicNumber: 17, category: "Halogen"),
                ChemicalElement(name: "Kalium",    symbol: "K",  atomicNumber: 19, category: "Metall"),
                ChemicalElement(name: "Kalsium",   symbol: "Ca", atomicNumber: 20, category: "Metall"),
                ChemicalElement(name: "Jern",      symbol: "Fe", atomicNumber: 26, category: "Metall"),
                ChemicalElement(name: "Kobber",    symbol: "Cu", atomicNumber: 29, category: "Metall")
            ]
        case 5, 6:
            return [
                ChemicalElement(name: "Bor",       symbol: "B",  atomicNumber: 5,  category: "Halvmetall"),
                ChemicalElement(name: "Aluminium", symbol: "Al", atomicNumber: 13, category: "Metall"),
                ChemicalElement(name: "Silisium",  symbol: "Si", atomicNumber: 14, category: "Halvmetall"),
                ChemicalElement(name: "Fosfor",    symbol: "P",  atomicNumber: 15, category: "Ikke-metall"),
                ChemicalElement(name: "Svovel",    symbol: "S",  atomicNumber: 16, category: "Ikke-metall"),
                ChemicalElement(name: "Argon",     symbol: "Ar", atomicNumber: 18, category: "Edelgass"),
                ChemicalElement(name: "Krom",      symbol: "Cr", atomicNumber: 24, category: "Metall"),
                ChemicalElement(name: "Mangan",    symbol: "Mn", atomicNumber: 25, category: "Metall"),
                ChemicalElement(name: "Kobolt",    symbol: "Co", atomicNumber: 27, category: "Metall"),
                ChemicalElement(name: "Nikkel",    symbol: "Ni", atomicNumber: 28, category: "Metall"),
                ChemicalElement(name: "Sink",      symbol: "Zn", atomicNumber: 30, category: "Metall"),
                ChemicalElement(name: "Brom",      symbol: "Br", atomicNumber: 35, category: "Halogen"),
                ChemicalElement(name: "Krypton",   symbol: "Kr", atomicNumber: 36, category: "Edelgass"),
                ChemicalElement(name: "Sølv",      symbol: "Ag", atomicNumber: 47, category: "Metall"),
                ChemicalElement(name: "Jod",       symbol: "I",  atomicNumber: 53, category: "Halogen")
            ]
        case 7, 8:
            return [
                ChemicalElement(name: "Titan",     symbol: "Ti", atomicNumber: 22, category: "Metall"),
                ChemicalElement(name: "Vanadium",  symbol: "V",  atomicNumber: 23, category: "Metall"),
                ChemicalElement(name: "Selen",     symbol: "Se", atomicNumber: 34, category: "Ikke-metall"),
                ChemicalElement(name: "Rubidium",  symbol: "Rb", atomicNumber: 37, category: "Metall"),
                ChemicalElement(name: "Strontium", symbol: "Sr", atomicNumber: 38, category: "Metall"),
                ChemicalElement(name: "Tinn",      symbol: "Sn", atomicNumber: 50, category: "Metall"),
                ChemicalElement(name: "Antimon",   symbol: "Sb", atomicNumber: 51, category: "Halvmetall"),
                ChemicalElement(name: "Cesium",    symbol: "Cs", atomicNumber: 55, category: "Metall"),
                ChemicalElement(name: "Barium",    symbol: "Ba", atomicNumber: 56, category: "Metall"),
                ChemicalElement(name: "Wolfram",   symbol: "W",  atomicNumber: 74, category: "Metall"),
                ChemicalElement(name: "Platina",   symbol: "Pt", atomicNumber: 78, category: "Metall"),
                ChemicalElement(name: "Gull",      symbol: "Au", atomicNumber: 79, category: "Metall"),
                ChemicalElement(name: "Kvikksølv", symbol: "Hg", atomicNumber: 80, category: "Metall"),
                ChemicalElement(name: "Bly",       symbol: "Pb", atomicNumber: 82, category: "Metall"),
                ChemicalElement(name: "Xenon",     symbol: "Xe", atomicNumber: 54, category: "Edelgass")
            ]
        case 9, 10:
            return [
                ChemicalElement(name: "Skandium",  symbol: "Sc", atomicNumber: 21, category: "Metall"),
                ChemicalElement(name: "Galium",    symbol: "Ga", atomicNumber: 31, category: "Metall"),
                ChemicalElement(name: "Germanium", symbol: "Ge", atomicNumber: 32, category: "Halvmetall"),
                ChemicalElement(name: "Arsen",     symbol: "As", atomicNumber: 33, category: "Halvmetall"),
                ChemicalElement(name: "Yttrium",   symbol: "Y",  atomicNumber: 39, category: "Metall"),
                ChemicalElement(name: "Zirkonium", symbol: "Zr", atomicNumber: 40, category: "Metall"),
                ChemicalElement(name: "Niob",      symbol: "Nb", atomicNumber: 41, category: "Metall"),
                ChemicalElement(name: "Molybden",  symbol: "Mo", atomicNumber: 42, category: "Metall"),
                ChemicalElement(name: "Palladium", symbol: "Pd", atomicNumber: 46, category: "Metall"),
                ChemicalElement(name: "Kadmium",   symbol: "Cd", atomicNumber: 48, category: "Metall"),
                ChemicalElement(name: "Indium",    symbol: "In", atomicNumber: 49, category: "Metall"),
                ChemicalElement(name: "Tellur",    symbol: "Te", atomicNumber: 52, category: "Halvmetall"),
                ChemicalElement(name: "Tantal",    symbol: "Ta", atomicNumber: 73, category: "Metall"),
                ChemicalElement(name: "Vismut",    symbol: "Bi", atomicNumber: 83, category: "Metall"),
                ChemicalElement(name: "Polonium",  symbol: "Po", atomicNumber: 84, category: "Halvmetall")
            ]
        case 11, 12:
            return [
                ChemicalElement(name: "Lantan",    symbol: "La", atomicNumber: 57, category: "Lantanid"),
                ChemicalElement(name: "Cerium",    symbol: "Ce", atomicNumber: 58, category: "Lantanid"),
                ChemicalElement(name: "Neodym",    symbol: "Nd", atomicNumber: 60, category: "Lantanid"),
                ChemicalElement(name: "Samarium",  symbol: "Sm", atomicNumber: 62, category: "Lantanid"),
                ChemicalElement(name: "Europium",  symbol: "Eu", atomicNumber: 63, category: "Lantanid"),
                ChemicalElement(name: "Gadolinium", symbol: "Gd", atomicNumber: 64, category: "Lantanid"),
                ChemicalElement(name: "Terbium",   symbol: "Tb", atomicNumber: 65, category: "Lantanid"),
                ChemicalElement(name: "Dysprosium", symbol: "Dy", atomicNumber: 66, category: "Lantanid"),
                ChemicalElement(name: "Holmium",   symbol: "Ho", atomicNumber: 67, category: "Lantanid"),
                ChemicalElement(name: "Erbium",    symbol: "Er", atomicNumber: 68, category: "Lantanid"),
                ChemicalElement(name: "Tulium",    symbol: "Tm", atomicNumber: 69, category: "Lantanid"),
                ChemicalElement(name: "Ytterbium", symbol: "Yb", atomicNumber: 70, category: "Lantanid"),
                ChemicalElement(name: "Lutesium",  symbol: "Lu", atomicNumber: 71, category: "Lantanid"),
                ChemicalElement(name: "Hafnium",   symbol: "Hf", atomicNumber: 72, category: "Metall"),
                ChemicalElement(name: "Rhenium",   symbol: "Re", atomicNumber: 75, category: "Metall")
            ]
        case 13, 14:
            return [
                ChemicalElement(name: "Osmium",    symbol: "Os", atomicNumber: 76, category: "Metall"),
                ChemicalElement(name: "Iridium",   symbol: "Ir", atomicNumber: 77, category: "Metall"),
                ChemicalElement(name: "Tallium",   symbol: "Tl", atomicNumber: 81, category: "Metall"),
                ChemicalElement(name: "Astat",     symbol: "At", atomicNumber: 85, category: "Halogen"),
                ChemicalElement(name: "Radon",     symbol: "Rn", atomicNumber: 86, category: "Edelgass"),
                ChemicalElement(name: "Frankium",  symbol: "Fr", atomicNumber: 87, category: "Metall"),
                ChemicalElement(name: "Radium",    symbol: "Ra", atomicNumber: 88, category: "Metall"),
                ChemicalElement(name: "Aktinium",  symbol: "Ac", atomicNumber: 89, category: "Aktinid"),
                ChemicalElement(name: "Torium",    symbol: "Th", atomicNumber: 90, category: "Aktinid"),
                ChemicalElement(name: "Protaktinium", symbol: "Pa", atomicNumber: 91, category: "Aktinid"),
                ChemicalElement(name: "Uran",      symbol: "U",  atomicNumber: 92, category: "Aktinid"),
                ChemicalElement(name: "Neptunium", symbol: "Np", atomicNumber: 93, category: "Aktinid"),
                ChemicalElement(name: "Plutonium", symbol: "Pu", atomicNumber: 94, category: "Aktinid"),
                ChemicalElement(name: "Americium", symbol: "Am", atomicNumber: 95, category: "Aktinid"),
                ChemicalElement(name: "Curium",    symbol: "Cm", atomicNumber: 96, category: "Aktinid")
            ]
        case 15, 16:
            return [
                ChemicalElement(name: "Berkelium", symbol: "Bk", atomicNumber: 97, category: "Aktinid"),
                ChemicalElement(name: "Californium", symbol: "Cf", atomicNumber: 98, category: "Aktinid"),
                ChemicalElement(name: "Einsteinium", symbol: "Es", atomicNumber: 99, category: "Aktinid"),
                ChemicalElement(name: "Fermium",   symbol: "Fm", atomicNumber: 100, category: "Aktinid"),
                ChemicalElement(name: "Mendelevium", symbol: "Md", atomicNumber: 101, category: "Aktinid"),
                ChemicalElement(name: "Nobelium",  symbol: "No", atomicNumber: 102, category: "Aktinid"),
                ChemicalElement(name: "Lawrencium", symbol: "Lr", atomicNumber: 103, category: "Aktinid"),
                ChemicalElement(name: "Rutherfordium", symbol: "Rf", atomicNumber: 104, category: "Metall"),
                ChemicalElement(name: "Dubnium",   symbol: "Db", atomicNumber: 105, category: "Metall"),
                ChemicalElement(name: "Seaborgium", symbol: "Sg", atomicNumber: 106, category: "Metall"),
                ChemicalElement(name: "Bohrium",   symbol: "Bh", atomicNumber: 107, category: "Metall"),
                ChemicalElement(name: "Hassium",   symbol: "Hs", atomicNumber: 108, category: "Metall"),
                ChemicalElement(name: "Meitnerium", symbol: "Mt", atomicNumber: 109, category: "Metall"),
                ChemicalElement(name: "Darmstadtium", symbol: "Ds", atomicNumber: 110, category: "Metall"),
                ChemicalElement(name: "Røntgenium", symbol: "Rg", atomicNumber: 111, category: "Metall")
            ]
        default:
            return [
                ChemicalElement(name: "Copernicium", symbol: "Cn", atomicNumber: 112, category: "Metall"),
                ChemicalElement(name: "Nihonium",  symbol: "Nh", atomicNumber: 113, category: "Metall"),
                ChemicalElement(name: "Flerovium", symbol: "Fl", atomicNumber: 114, category: "Metall"),
                ChemicalElement(name: "Moscovium", symbol: "Mc", atomicNumber: 115, category: "Metall"),
                ChemicalElement(name: "Livermorium", symbol: "Lv", atomicNumber: 116, category: "Metall"),
                ChemicalElement(name: "Tennessin", symbol: "Ts", atomicNumber: 117, category: "Halogen"),
                ChemicalElement(name: "Oganesson", symbol: "Og", atomicNumber: 118, category: "Edelgass"),
                ChemicalElement(name: "Praseodym", symbol: "Pr", atomicNumber: 59, category: "Lantanid"),
                ChemicalElement(name: "Promethium", symbol: "Pm", atomicNumber: 61, category: "Lantanid"),
                ChemicalElement(name: "Beryllium", symbol: "Be", atomicNumber: 4,  category: "Metall"),
                ChemicalElement(name: "Technetium", symbol: "Tc", atomicNumber: 43, category: "Metall"),
                ChemicalElement(name: "Ruthenium", symbol: "Ru", atomicNumber: 44, category: "Metall"),
                ChemicalElement(name: "Rhodium",   symbol: "Rh", atomicNumber: 45, category: "Metall")
            ]
        }
    }
    // swiftlint:enable function_body_length

    static let allElements: [ChemicalElement] = (1...20).flatMap { elements(forLevel: $0) }
}
