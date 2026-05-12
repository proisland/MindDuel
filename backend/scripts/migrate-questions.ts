/**
 * Migrate questions from iOS Swift question banks.
 *
 * CSV mode (recommended — no credentials needed):
 *   cd backend
 *   npx tsx scripts/migrate-questions.ts --csv
 *   → writes grammar.csv, history.csv, … to scripts/csv/
 *   → import each file via the admin UI at /admin/questions
 *
 * Direct DB mode:
 *   DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts
 *   → inserts directly into the database (packs start inactive)
 *   → use --force to add a new version even if a pack already exists
 *
 * Notes on procedural modes:
 *   - math: 100 % procedural arithmetic — no static question list exists
 *   - brain: 100 % procedural sequences/patterns — cannot be exported
 *   - chem/geo: generated from hardcoded data in this script
 *   - pi: progressive digit memorisation — no static list
 */

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { PrismaClient } from '@prisma/client'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const APP_DIR   = path.resolve(__dirname, '../../MindDuel/Game')
const FORCE     = process.argv.includes('--force')
const CSV_MODE  = process.argv.includes('--csv')

interface Question {
  id:      string
  prompt:  string
  options: string[]
  answer:  string
  level:   number
}

// ─── Swift-bank parser (grammar / history / science / physics / sport) ───────

function parseSwiftBank(filePath: string, slug: string): Question[] {
  const src = fs.readFileSync(filePath, 'utf-8')
  const questions: Question[] = []
  let currentLevel = 1
  const levelCounters: Record<number, number> = {}

  for (const line of src.split('\n')) {
    const levelMatch = line.match(/(?:Level|level)\s*(\d+)/)
    if (levelMatch && (line.includes('MARK') || line.includes('private static let level'))) {
      currentLevel = parseInt(levelMatch[1], 10)
      continue
    }

    const qMatch = line.match(
      /q\("((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/
    )
    if (qMatch) {
      const [, prompt, correct, d1, d2, d3] = qMatch
      levelCounters[currentLevel] = (levelCounters[currentLevel] ?? 0) + 1
      const idx = String(levelCounters[currentLevel]).padStart(3, '0')
      questions.push({
        id:      `${slug}-l${currentLevel}-${idx}`,
        prompt:  prompt.replace(/\\"/g, '"'),
        options: [correct, d1, d2, d3].map(s => s.replace(/\\"/g, '"')),
        answer:  correct.replace(/\\"/g, '"'),
        level:   currentLevel,
      })
    }
  }

  return questions
}

const MODES: Array<{ slug: string; file: string }> = [
  { slug: 'grammar', file: 'GrammarGame/GrammarQuestionBank.swift' },
  { slug: 'history', file: 'HistoryGame/HistoryQuestionBank.swift' },
  { slug: 'science', file: 'ScienceGame/ScienceQuestionBank.swift' },
  { slug: 'physics', file: 'PhysicsGame/PhysicsQuestionBank.swift' },
  { slug: 'sport',   file: 'SportGame/SportQuestionBank.swift' },
]

// ─── Helpers ─────────────────────────────────────────────────────────────────

function pickFirst<T>(arr: T[], exclude: T, count: number): T[] {
  return arr.filter(x => x !== exclude).slice(0, count)
}

function pickFirstMultiple<T>(arr: T[], excludeSet: Set<T>, count: number): T[] {
  return arr.filter(x => !excludeSet.has(x)).slice(0, count)
}

// ─── Chemistry ───────────────────────────────────────────────────────────────

interface ChemElement {
  name: string; symbol: string; atomicNumber: number; category: string
}

function chemElements(level: number): ChemElement[] {
  const l = Math.max(1, Math.min(20, level))
  if (l <= 2) return [
    { name: 'Hydrogen',  symbol: 'H',  atomicNumber: 1,  category: 'Ikke-metall' },
    { name: 'Oksygen',   symbol: 'O',  atomicNumber: 8,  category: 'Ikke-metall' },
    { name: 'Karbon',    symbol: 'C',  atomicNumber: 6,  category: 'Ikke-metall' },
    { name: 'Nitrogen',  symbol: 'N',  atomicNumber: 7,  category: 'Ikke-metall' },
    { name: 'Helium',    symbol: 'He', atomicNumber: 2,  category: 'Edelgass' },
    { name: 'Jern',      symbol: 'Fe', atomicNumber: 26, category: 'Metall' },
    { name: 'Gull',      symbol: 'Au', atomicNumber: 79, category: 'Metall' },
    { name: 'Sølv',      symbol: 'Ag', atomicNumber: 47, category: 'Metall' },
  ]
  if (l <= 4) return [
    { name: 'Hydrogen',  symbol: 'H',  atomicNumber: 1,  category: 'Ikke-metall' },
    { name: 'Helium',    symbol: 'He', atomicNumber: 2,  category: 'Edelgass' },
    { name: 'Litium',    symbol: 'Li', atomicNumber: 3,  category: 'Metall' },
    { name: 'Karbon',    symbol: 'C',  atomicNumber: 6,  category: 'Ikke-metall' },
    { name: 'Nitrogen',  symbol: 'N',  atomicNumber: 7,  category: 'Ikke-metall' },
    { name: 'Oksygen',   symbol: 'O',  atomicNumber: 8,  category: 'Ikke-metall' },
    { name: 'Fluor',     symbol: 'F',  atomicNumber: 9,  category: 'Halogen' },
    { name: 'Neon',      symbol: 'Ne', atomicNumber: 10, category: 'Edelgass' },
    { name: 'Natrium',   symbol: 'Na', atomicNumber: 11, category: 'Metall' },
    { name: 'Magnesium', symbol: 'Mg', atomicNumber: 12, category: 'Metall' },
    { name: 'Klor',      symbol: 'Cl', atomicNumber: 17, category: 'Halogen' },
    { name: 'Kalium',    symbol: 'K',  atomicNumber: 19, category: 'Metall' },
    { name: 'Kalsium',   symbol: 'Ca', atomicNumber: 20, category: 'Metall' },
    { name: 'Jern',      symbol: 'Fe', atomicNumber: 26, category: 'Metall' },
    { name: 'Kobber',    symbol: 'Cu', atomicNumber: 29, category: 'Metall' },
  ]
  if (l <= 6) return [
    { name: 'Bor',       symbol: 'B',  atomicNumber: 5,  category: 'Halvmetall' },
    { name: 'Aluminium', symbol: 'Al', atomicNumber: 13, category: 'Metall' },
    { name: 'Silisium',  symbol: 'Si', atomicNumber: 14, category: 'Halvmetall' },
    { name: 'Fosfor',    symbol: 'P',  atomicNumber: 15, category: 'Ikke-metall' },
    { name: 'Svovel',    symbol: 'S',  atomicNumber: 16, category: 'Ikke-metall' },
    { name: 'Argon',     symbol: 'Ar', atomicNumber: 18, category: 'Edelgass' },
    { name: 'Krom',      symbol: 'Cr', atomicNumber: 24, category: 'Metall' },
    { name: 'Mangan',    symbol: 'Mn', atomicNumber: 25, category: 'Metall' },
    { name: 'Kobolt',    symbol: 'Co', atomicNumber: 27, category: 'Metall' },
    { name: 'Nikkel',    symbol: 'Ni', atomicNumber: 28, category: 'Metall' },
    { name: 'Sink',      symbol: 'Zn', atomicNumber: 30, category: 'Metall' },
    { name: 'Brom',      symbol: 'Br', atomicNumber: 35, category: 'Halogen' },
    { name: 'Krypton',   symbol: 'Kr', atomicNumber: 36, category: 'Edelgass' },
    { name: 'Sølv',      symbol: 'Ag', atomicNumber: 47, category: 'Metall' },
    { name: 'Jod',       symbol: 'I',  atomicNumber: 53, category: 'Halogen' },
  ]
  if (l <= 8) return [
    { name: 'Titan',     symbol: 'Ti', atomicNumber: 22, category: 'Metall' },
    { name: 'Vanadium',  symbol: 'V',  atomicNumber: 23, category: 'Metall' },
    { name: 'Selen',     symbol: 'Se', atomicNumber: 34, category: 'Ikke-metall' },
    { name: 'Rubidium',  symbol: 'Rb', atomicNumber: 37, category: 'Metall' },
    { name: 'Strontium', symbol: 'Sr', atomicNumber: 38, category: 'Metall' },
    { name: 'Tinn',      symbol: 'Sn', atomicNumber: 50, category: 'Metall' },
    { name: 'Antimon',   symbol: 'Sb', atomicNumber: 51, category: 'Halvmetall' },
    { name: 'Cesium',    symbol: 'Cs', atomicNumber: 55, category: 'Metall' },
    { name: 'Barium',    symbol: 'Ba', atomicNumber: 56, category: 'Metall' },
    { name: 'Wolfram',   symbol: 'W',  atomicNumber: 74, category: 'Metall' },
    { name: 'Platina',   symbol: 'Pt', atomicNumber: 78, category: 'Metall' },
    { name: 'Gull',      symbol: 'Au', atomicNumber: 79, category: 'Metall' },
    { name: 'Kvikksølv', symbol: 'Hg', atomicNumber: 80, category: 'Metall' },
    { name: 'Bly',       symbol: 'Pb', atomicNumber: 82, category: 'Metall' },
    { name: 'Xenon',     symbol: 'Xe', atomicNumber: 54, category: 'Edelgass' },
  ]
  if (l <= 10) return [
    { name: 'Skandium',  symbol: 'Sc', atomicNumber: 21, category: 'Metall' },
    { name: 'Galium',    symbol: 'Ga', atomicNumber: 31, category: 'Metall' },
    { name: 'Germanium', symbol: 'Ge', atomicNumber: 32, category: 'Halvmetall' },
    { name: 'Arsen',     symbol: 'As', atomicNumber: 33, category: 'Halvmetall' },
    { name: 'Yttrium',   symbol: 'Y',  atomicNumber: 39, category: 'Metall' },
    { name: 'Zirkonium', symbol: 'Zr', atomicNumber: 40, category: 'Metall' },
    { name: 'Niob',      symbol: 'Nb', atomicNumber: 41, category: 'Metall' },
    { name: 'Molybden',  symbol: 'Mo', atomicNumber: 42, category: 'Metall' },
    { name: 'Palladium', symbol: 'Pd', atomicNumber: 46, category: 'Metall' },
    { name: 'Kadmium',   symbol: 'Cd', atomicNumber: 48, category: 'Metall' },
    { name: 'Indium',    symbol: 'In', atomicNumber: 49, category: 'Metall' },
    { name: 'Tellur',    symbol: 'Te', atomicNumber: 52, category: 'Halvmetall' },
    { name: 'Tantal',    symbol: 'Ta', atomicNumber: 73, category: 'Metall' },
    { name: 'Vismut',    symbol: 'Bi', atomicNumber: 83, category: 'Metall' },
    { name: 'Polonium',  symbol: 'Po', atomicNumber: 84, category: 'Halvmetall' },
  ]
  if (l <= 12) return [
    { name: 'Lantan',     symbol: 'La', atomicNumber: 57,  category: 'Lantanid' },
    { name: 'Cerium',     symbol: 'Ce', atomicNumber: 58,  category: 'Lantanid' },
    { name: 'Neodym',     symbol: 'Nd', atomicNumber: 60,  category: 'Lantanid' },
    { name: 'Samarium',   symbol: 'Sm', atomicNumber: 62,  category: 'Lantanid' },
    { name: 'Europium',   symbol: 'Eu', atomicNumber: 63,  category: 'Lantanid' },
    { name: 'Gadolinium', symbol: 'Gd', atomicNumber: 64,  category: 'Lantanid' },
    { name: 'Terbium',    symbol: 'Tb', atomicNumber: 65,  category: 'Lantanid' },
    { name: 'Dysprosium', symbol: 'Dy', atomicNumber: 66,  category: 'Lantanid' },
    { name: 'Holmium',    symbol: 'Ho', atomicNumber: 67,  category: 'Lantanid' },
    { name: 'Erbium',     symbol: 'Er', atomicNumber: 68,  category: 'Lantanid' },
    { name: 'Tulium',     symbol: 'Tm', atomicNumber: 69,  category: 'Lantanid' },
    { name: 'Ytterbium',  symbol: 'Yb', atomicNumber: 70,  category: 'Lantanid' },
    { name: 'Lutesium',   symbol: 'Lu', atomicNumber: 71,  category: 'Lantanid' },
    { name: 'Hafnium',    symbol: 'Hf', atomicNumber: 72,  category: 'Metall' },
    { name: 'Rhenium',    symbol: 'Re', atomicNumber: 75,  category: 'Metall' },
  ]
  if (l <= 14) return [
    { name: 'Osmium',       symbol: 'Os', atomicNumber: 76,  category: 'Metall' },
    { name: 'Iridium',      symbol: 'Ir', atomicNumber: 77,  category: 'Metall' },
    { name: 'Tallium',      symbol: 'Tl', atomicNumber: 81,  category: 'Metall' },
    { name: 'Astat',        symbol: 'At', atomicNumber: 85,  category: 'Halogen' },
    { name: 'Radon',        symbol: 'Rn', atomicNumber: 86,  category: 'Edelgass' },
    { name: 'Frankium',     symbol: 'Fr', atomicNumber: 87,  category: 'Metall' },
    { name: 'Radium',       symbol: 'Ra', atomicNumber: 88,  category: 'Metall' },
    { name: 'Aktinium',     symbol: 'Ac', atomicNumber: 89,  category: 'Aktinid' },
    { name: 'Torium',       symbol: 'Th', atomicNumber: 90,  category: 'Aktinid' },
    { name: 'Protaktinium', symbol: 'Pa', atomicNumber: 91,  category: 'Aktinid' },
    { name: 'Uran',         symbol: 'U',  atomicNumber: 92,  category: 'Aktinid' },
    { name: 'Neptunium',    symbol: 'Np', atomicNumber: 93,  category: 'Aktinid' },
    { name: 'Plutonium',    symbol: 'Pu', atomicNumber: 94,  category: 'Aktinid' },
    { name: 'Americium',    symbol: 'Am', atomicNumber: 95,  category: 'Aktinid' },
    { name: 'Curium',       symbol: 'Cm', atomicNumber: 96,  category: 'Aktinid' },
  ]
  if (l <= 16) return [
    { name: 'Berkelium',     symbol: 'Bk', atomicNumber: 97,  category: 'Aktinid' },
    { name: 'Californium',   symbol: 'Cf', atomicNumber: 98,  category: 'Aktinid' },
    { name: 'Einsteinium',   symbol: 'Es', atomicNumber: 99,  category: 'Aktinid' },
    { name: 'Fermium',       symbol: 'Fm', atomicNumber: 100, category: 'Aktinid' },
    { name: 'Mendelevium',   symbol: 'Md', atomicNumber: 101, category: 'Aktinid' },
    { name: 'Nobelium',      symbol: 'No', atomicNumber: 102, category: 'Aktinid' },
    { name: 'Lawrencium',    symbol: 'Lr', atomicNumber: 103, category: 'Aktinid' },
    { name: 'Rutherfordium', symbol: 'Rf', atomicNumber: 104, category: 'Metall' },
    { name: 'Dubnium',       symbol: 'Db', atomicNumber: 105, category: 'Metall' },
    { name: 'Seaborgium',    symbol: 'Sg', atomicNumber: 106, category: 'Metall' },
    { name: 'Bohrium',       symbol: 'Bh', atomicNumber: 107, category: 'Metall' },
    { name: 'Hassium',       symbol: 'Hs', atomicNumber: 108, category: 'Metall' },
    { name: 'Meitnerium',    symbol: 'Mt', atomicNumber: 109, category: 'Metall' },
    { name: 'Darmstadtium',  symbol: 'Ds', atomicNumber: 110, category: 'Metall' },
    { name: 'Røntgenium',    symbol: 'Rg', atomicNumber: 111, category: 'Metall' },
  ]
  // default: levels 17-20
  return [
    { name: 'Copernicium',  symbol: 'Cn', atomicNumber: 112, category: 'Metall' },
    { name: 'Nihonium',     symbol: 'Nh', atomicNumber: 113, category: 'Metall' },
    { name: 'Flerovium',    symbol: 'Fl', atomicNumber: 114, category: 'Metall' },
    { name: 'Moscovium',    symbol: 'Mc', atomicNumber: 115, category: 'Metall' },
    { name: 'Livermorium',  symbol: 'Lv', atomicNumber: 116, category: 'Metall' },
    { name: 'Tennessin',    symbol: 'Ts', atomicNumber: 117, category: 'Halogen' },
    { name: 'Oganesson',    symbol: 'Og', atomicNumber: 118, category: 'Edelgass' },
    { name: 'Praseodym',    symbol: 'Pr', atomicNumber: 59,  category: 'Lantanid' },
    { name: 'Promethium',   symbol: 'Pm', atomicNumber: 61,  category: 'Lantanid' },
    { name: 'Beryllium',    symbol: 'Be', atomicNumber: 4,   category: 'Metall' },
    { name: 'Technetium',   symbol: 'Tc', atomicNumber: 43,  category: 'Metall' },
    { name: 'Ruthenium',    symbol: 'Ru', atomicNumber: 44,  category: 'Metall' },
    { name: 'Rhodium',      symbol: 'Rh', atomicNumber: 45,  category: 'Metall' },
  ]
}

const ALL_CHEM_ELEMENTS: ChemElement[] = (() => {
  const seen = new Set<string>()
  const all: ChemElement[] = []
  for (let l = 1; l <= 20; l++) {
    for (const e of chemElements(l)) {
      if (!seen.has(e.symbol)) { seen.add(e.symbol); all.push(e) }
    }
  }
  return all.sort((a, b) => a.symbol.localeCompare(b.symbol))
})()

const ALL_CHEM_CATEGORIES = ['Metall', 'Ikke-metall', 'Edelgass', 'Halogen', 'Halvmetall', 'Lantanid', 'Aktinid']

interface ChemRaw { prompt: string; correct: string; distractors: string[] }

function chemSpecials(level: number): ChemRaw[] {
  const l = Math.max(1, Math.min(20, level))
  if (l === 1) return [
    { prompt: 'Hva er is?', correct: 'Fast', distractors: ['Flytende', 'Gass', 'Damp'] },
    { prompt: 'Hva er vanndamp?', correct: 'Gass', distractors: ['Fast', 'Flytende', 'Is'] },
    { prompt: 'Hva er vann?', correct: 'Flytende', distractors: ['Fast', 'Gass', 'Stein'] },
    { prompt: 'Hva er luft?', correct: 'Gass', distractors: ['Flytende', 'Fast', 'Vann'] },
    { prompt: 'Hva er stein?', correct: 'Fast', distractors: ['Gass', 'Flytende', 'Damp'] },
    { prompt: 'Hva er melk?', correct: 'Flytende', distractors: ['Fast', 'Gass', 'Damp'] },
    { prompt: 'Hva er røyk?', correct: 'Gass', distractors: ['Fast', 'Flytende', 'Stein'] },
    { prompt: 'Hva er sand?', correct: 'Fast', distractors: ['Gass', 'Flytende', 'Damp'] },
    { prompt: 'Hva er olje?', correct: 'Flytende', distractors: ['Fast', 'Gass', 'Damp'] },
    { prompt: 'Hva er tåke?', correct: 'Gass', distractors: ['Fast', 'Flytende', 'Stein'] },
    { prompt: 'Hvilken gass puster vi inn?', correct: 'Oksygen', distractors: ['Karbondioksid', 'Helium', 'Hydrogen'] },
    { prompt: 'Hva består vann mest av?', correct: 'Hydrogen og oksygen', distractors: ['Karbon og oksygen', 'Nitrogen og hydrogen', 'Salt og vann'] },
    { prompt: 'Hvilken farge har gull?', correct: 'Gull/gul', distractors: ['Sølv', 'Rød', 'Blå'] },
    { prompt: 'Hvor lett er helium sammenlignet med luft?', correct: 'Lettere', distractors: ['Tyngre', 'Likt', 'Helium har ikke vekt'] },
    { prompt: 'Hvor finner vi mest vann på jorda?', correct: 'I havene', distractors: ['I innsjøer', 'I skyer', 'I elver'] },
    { prompt: 'Hva er det største kjente atomet (vanlig)?', correct: 'Uran', distractors: ['Hydrogen', 'Helium', 'Oksygen'] },
    { prompt: 'Hvilket grunnstoff er det mest av i kroppen?', correct: 'Oksygen', distractors: ['Karbon', 'Hydrogen', 'Nitrogen'] },
    { prompt: 'Hva blir vann til når det fryser?', correct: 'Is', distractors: ['Damp', 'Gass', 'Tåke'] },
    { prompt: 'Hva er ofte i bobler?', correct: 'Gass', distractors: ['Fast stoff', 'Flytende stoff', 'Stein'] },
    { prompt: 'Hva er metall?', correct: 'Fast', distractors: ['Flytende', 'Gass', 'Damp'] },
  ]
  if (l === 2) return [
    { prompt: 'Hva får vi når salt løses i vann?', correct: 'Saltvann', distractors: ['Sukkervann', 'Olje', 'Sand'] },
    { prompt: 'Hvordan skille sand fra vann?', correct: 'Filtrere', distractors: ['Koke', 'Fryse', 'Riste'] },
    { prompt: 'Hva skjer med vann ved 0°C?', correct: 'Fryser', distractors: ['Koker', 'Fordamper', 'Brenner'] },
    { prompt: 'Hva skjer med vann ved 100°C?', correct: 'Koker', distractors: ['Fryser', 'Smelter', 'Stivner'] },
    { prompt: 'Hva er sukker i te et eksempel på?', correct: 'Løsning', distractors: ['Røyk', 'Tåke', 'Damp'] },
    { prompt: 'Hvilken gass puster vi ut?', correct: 'Karbondioksid', distractors: ['Oksygen', 'Nitrogen', 'Helium'] },
    { prompt: 'Hva er den vanligste gassen i luft?', correct: 'Nitrogen', distractors: ['Oksygen', 'Karbondioksid', 'Hydrogen'] },
    { prompt: 'Hvordan kan vi skille olje fra vann?', correct: 'Skilletrakt', distractors: ['Koke', 'Fryse', 'Filtrere'] },
    { prompt: 'Hva skjer når sukker varmes lenge?', correct: 'Karamelliseres', distractors: ['Fryser', 'Fordamper', 'Eksploderer'] },
    { prompt: 'Hva er en blanding av flere stoffer?', correct: 'Blanding', distractors: ['Grunnstoff', 'Atom', 'Molekyl'] },
    { prompt: 'Hva er et stoff som ikke kan brytes ned kjemisk?', correct: 'Grunnstoff', distractors: ['Blanding', 'Forbindelse', 'Løsning'] },
    { prompt: 'Hvilken metode bruker vi for å rense skittent vann?', correct: 'Filtrering', distractors: ['Koking', 'Frysing', 'Salting'] },
    { prompt: 'Hva får vi når sukker løses i vann?', correct: 'Sukkervann', distractors: ['Saltvann', 'Olje', 'Stivelse'] },
    { prompt: 'Hva kalles damp som blir til væske?', correct: 'Kondensering', distractors: ['Fordamping', 'Frysing', 'Smelting'] },
    { prompt: 'Hvor finner du mest oksygen?', correct: 'I luften', distractors: ['I sand', 'I metall', 'I stein'] },
    { prompt: 'Hvilken gass bruker planter til fotosyntese?', correct: 'Karbondioksid', distractors: ['Oksygen', 'Nitrogen', 'Helium'] },
    { prompt: 'Hva produseres av planter ved fotosyntese?', correct: 'Oksygen', distractors: ['Karbondioksid', 'Nitrogen', 'Hydrogen'] },
    { prompt: 'Hva kalles vann i gassform?', correct: 'Vanndamp', distractors: ['Is', 'Skum', 'Tåke'] },
    { prompt: 'Hva kalles tåke høyt oppe på himmelen?', correct: 'Skyer', distractors: ['Damp', 'Røyk', 'Frost'] },
    { prompt: 'Hva kalles is som blir til vann?', correct: 'Smelting', distractors: ['Frysing', 'Fordamping', 'Kondensering'] },
  ]
  if (l <= 4) return [
    { prompt: 'Hva kalles overgang fra fast til flytende?', correct: 'Smelting', distractors: ['Fordamping', 'Frysing', 'Sublimering'] },
    { prompt: 'Hva kalles overgang fra flytende til gass?', correct: 'Fordamping', distractors: ['Smelting', 'Kondensering', 'Sublimering'] },
    { prompt: 'Hva kalles overgang fra gass til flytende?', correct: 'Kondensering', distractors: ['Smelting', 'Sublimering', 'Fordamping'] },
    { prompt: 'Hva kalles direkte overgang fra fast til gass?', correct: 'Sublimering', distractors: ['Fordamping', 'Kondensering', 'Smelting'] },
    { prompt: 'Hvilken pH-verdi har rent vann?', correct: '7', distractors: ['1', '10', '14'] },
    { prompt: 'Hva er den kjemiske formelen for vann?', correct: 'H₂O', distractors: ['CO₂', 'O₂', 'H₂'] },
    { prompt: 'Hva er den kjemiske formelen for karbondioksid?', correct: 'CO₂', distractors: ['CO', 'C₂O', 'CH₄'] },
  ]
  if (l <= 6) return [
    { prompt: 'Hva er den kjemiske formelen for ammoniakk?', correct: 'NH₃', distractors: ['NO₂', 'N₂', 'NaCl'] },
    { prompt: 'Hva er den kjemiske formelen for metan?', correct: 'CH₄', distractors: ['CO₂', 'C₂H₆', 'CH₃'] },
    { prompt: 'Hva er den kjemiske formelen for vanlig salt?', correct: 'NaCl', distractors: ['KCl', 'MgCl₂', 'CaCl₂'] },
    { prompt: 'Hva betyr en pH < 7?', correct: 'Sur', distractors: ['Basisk', 'Nøytral', 'Salt'] },
    { prompt: 'Hva betyr en pH > 7?', correct: 'Basisk', distractors: ['Sur', 'Nøytral', 'Salt'] },
    { prompt: 'Hva produserer planter ved fotosyntese?', correct: 'Oksygen', distractors: ['Karbondioksid', 'Hydrogen', 'Nitrogen'] },
    { prompt: 'Hva er det vanligste isotopet av hydrogen?', correct: 'Protium', distractors: ['Deuterium', 'Tritium', 'Helium-3'] },
  ]
  if (l <= 8) return [
    { prompt: 'Hvilken bindingstype har NaCl?', correct: 'Ionebinding', distractors: ['Kovalent', 'Metallbinding', 'Hydrogenbinding'] },
    { prompt: 'Hvilken bindingstype har H₂O?', correct: 'Kovalent', distractors: ['Ionebinding', 'Metallbinding', 'Van der Waals'] },
    { prompt: 'Hvor mange elektroner har et nøytralt karbon-atom?', correct: '6', distractors: ['4', '8', '12'] },
    { prompt: 'Hvilken edelgass har lavest kokepunkt?', correct: 'Helium', distractors: ['Neon', 'Argon', 'Krypton'] },
    { prompt: 'Hva er Avogadros tall (omtrentlig)?', correct: '6.02 × 10²³', distractors: ['3.14 × 10⁸', '1.6 × 10⁻¹⁹', '9.11 × 10⁻³¹'] },
    { prompt: 'Hva har en mol av et stoff?', correct: 'Avogadros antall partikler', distractors: ['1 gram', '1 liter', '100 partikler'] },
    { prompt: 'Hvilket grunnstoff finnes det mest av i universet?', correct: 'Hydrogen', distractors: ['Helium', 'Oksygen', 'Karbon'] },
  ]
  if (l <= 10) return [
    { prompt: 'Hva er en katalysator?', correct: 'Stoff som øker reaksjonshastighet', distractors: ['Stoff som forbrukes', 'Reaksjonsprodukt', 'Reaktant'] },
    { prompt: 'Hva kalles en reaksjon som avgir varme?', correct: 'Eksoterm', distractors: ['Endoterm', 'Isoterm', 'Adiabatisk'] },
    { prompt: 'Hva kalles en reaksjon som tar opp varme?', correct: 'Endoterm', distractors: ['Eksoterm', 'Isoterm', 'Adiabatisk'] },
    { prompt: 'Hva er den korrekte formelen for svovelsyre?', correct: 'H₂SO₄', distractors: ['HCl', 'HNO₃', 'H₂CO₃'] },
    { prompt: 'Hva er den korrekte formelen for saltsyre?', correct: 'HCl', distractors: ['H₂SO₄', 'HNO₃', 'HF'] },
    { prompt: 'Hva er den korrekte formelen for natriumhydroksid?', correct: 'NaOH', distractors: ['KOH', 'Ca(OH)₂', 'NH₄OH'] },
    { prompt: 'Hva er glukose sin formel?', correct: 'C₆H₁₂O₆', distractors: ['C₆H₆', 'C₂H₆O', 'CH₂O'] },
  ]
  if (l <= 12) return [
    { prompt: 'Hva er hovedtypen binding i diamant?', correct: 'Kovalent', distractors: ['Ionebinding', 'Metallbinding', 'Hydrogenbinding'] },
    { prompt: 'Hva kalles karbonets allotrop med 60 atomer?', correct: 'Buckminsterfulleren', distractors: ['Grafitt', 'Diamant', 'Grafén'] },
    { prompt: 'Hvilken syre finnes i magen?', correct: 'Saltsyre', distractors: ['Sitronsyre', 'Eddiksyre', 'Karbonsyre'] },
    { prompt: 'Hva er en halveringstid?', correct: 'Tid det tar at halvparten henfaller', distractors: ['Reaksjonshastighet', 'Stoff som dannes', 'Energimengde'] },
    { prompt: 'Hva er pH til ren maged syre (omtrentlig)?', correct: '1.5', distractors: ['7', '5', '3'] },
    { prompt: 'Hvilket grunnstoff har symbolet Pb?', correct: 'Bly', distractors: ['Polonium', 'Platina', 'Plutonium'] },
    { prompt: 'Hva er en isotop?', correct: 'Atomer med samme protontall, ulikt nøytrontall', distractors: ['Atomer med ulik ladning', 'Atomer i forskjellig tilstand', 'Forskjellige grunnstoffer'] },
  ]
  if (l <= 14) return [
    { prompt: 'Hva produseres når en syre nøytraliseres med en base?', correct: 'Salt og vann', distractors: ['Kun vann', 'Kun salt', 'En gass'] },
    { prompt: 'Hva kalles en reaksjon der elektroner overføres?', correct: 'Redoksreaksjon', distractors: ['Syre-base', 'Hydrolyse', 'Polymerisering'] },
    { prompt: 'Hva betyr oksidasjon?', correct: 'Tap av elektroner', distractors: ['Tap av protoner', 'Opptak av elektroner', 'Opptak av nøytroner'] },
    { prompt: 'Hva betyr reduksjon?', correct: 'Opptak av elektroner', distractors: ['Tap av elektroner', 'Opptak av protoner', 'Tap av nøytroner'] },
    { prompt: 'Hva er den vanligste isotopen av karbon?', correct: 'Karbon-12', distractors: ['Karbon-13', 'Karbon-14', 'Karbon-11'] },
    { prompt: 'Hvilket organisk stoff har O-H-funksjonelle gruppe?', correct: 'Alkohol', distractors: ['Alkan', 'Alken', 'Aldehyd'] },
    { prompt: 'Hvilket organisk stoff har C=O i kjedeenden?', correct: 'Aldehyd', distractors: ['Keton', 'Eter', 'Alkohol'] },
  ]
  if (l <= 16) return [
    { prompt: 'Hvilken type reaksjon er forbrenning?', correct: 'Eksoterm redoks', distractors: ['Endoterm syre-base', 'Polymerisering', 'Hydrolyse'] },
    { prompt: 'Hva kalles en blanding av to ikke-blandbare væsker?', correct: 'Emulsjon', distractors: ['Suspensjon', 'Løsning', 'Kolloid'] },
    { prompt: 'Hva er Le Chateliers prinsipp om?', correct: 'Likevektsforskyvning', distractors: ['Reaksjonshastighet', 'Energiinnhold', 'Atomstruktur'] },
    { prompt: 'Hva kalles en gass som ikke følger ideell gasslov?', correct: 'Reell gass', distractors: ['Edelgass', 'Halogen', 'Plasma'] },
    { prompt: 'Hva betyr stereoisomeri?', correct: 'Samme formel, ulik 3D-struktur', distractors: ['Samme atomer, ulik rekkefølge', 'Forskjellig formel', 'Resonans'] },
    { prompt: 'Hvilken lov beskriver gassers volum og temperatur?', correct: 'Charles\' lov', distractors: ['Boyles lov', 'Avogadros lov', 'Daltons lov'] },
    { prompt: 'Hva er en peptidbinding?', correct: 'Binding mellom aminosyrer', distractors: ['Binding mellom sukkere', 'Hydrogenbinding i DNA', 'Disulfidbinding'] },
  ]
  if (l <= 18) return [
    { prompt: 'Hva er en chiral forbindelse?', correct: 'Asymmetrisk molekyl', distractors: ['Symmetrisk molekyl', 'Polart molekyl', 'Aromatisk forbindelse'] },
    { prompt: 'Hvilken hybridisering har et sp³-karbon?', correct: 'Tetraedrisk', distractors: ['Trigonal plan', 'Lineær', 'Trigonal bipyramidal'] },
    { prompt: 'Hva betyr SN1-reaksjon?', correct: 'Substitusjon, nukleofil, første ordens', distractors: ['Sentral nøytral', 'Symmetrisk neon', 'Stereo nøytral'] },
    { prompt: 'Hva er en aromatisk forbindelse (eksempel)?', correct: 'Benzen', distractors: ['Cyklopropan', 'Etan', 'Aceton'] },
    { prompt: 'Hvilken gruppe karakteriserer estere?', correct: '-COO-', distractors: ['-OH', '-NH₂', '-CHO'] },
    { prompt: 'Hva er Avogadros lov?', correct: 'Like volum gass har like mange molekyler', distractors: ['Trykk × volum konstant', 'Volum × T konstant', 'P × V = n × R × T'] },
    { prompt: 'Hva er ideell gasslov?', correct: 'PV = nRT', distractors: ['E = mc²', 'F = ma', 'V = IR'] },
  ]
  // levels 19-20
  return [
    { prompt: 'Hva er Schrödinger-ligningen brukt til?', correct: 'Beskrive elektroners bølgefunksjon', distractors: ['Beregne reaksjonshastighet', 'Måle pH', 'Beregne molekylvekt'] },
    { prompt: 'Hva betyr orbital?', correct: 'Sannsynlighetsområde for elektron', distractors: ['Eksakt elektronbane', 'Atomkjerne', 'Molekylformel'] },
    { prompt: 'Hvilken bindingsteori bruker MO-diagrammer?', correct: 'Molekylorbital-teori', distractors: ['VSEPR', 'Krystallfeltteori', 'Hückel-teori'] },
    { prompt: 'Hva er en katalysators rolle i reaksjon?', correct: 'Senker aktiveringsenergien', distractors: ['Forskyver likevekten', 'Endrer reaksjonsproduktene', 'Brukes opp'] },
    { prompt: 'Hva er Gibbs fri energi (G) brukt til?', correct: 'Forutsi spontanitet', distractors: ['Beregne entropi alene', 'Måle reaksjonshastighet', 'Bestemme molekylvekt'] },
    { prompt: 'Hva betyr ΔG < 0?', correct: 'Spontan reaksjon', distractors: ['Ikke-spontan', 'I likevekt', 'Rask reaksjon'] },
    { prompt: 'Hva beskriver entropi?', correct: 'Uorden i et system', distractors: ['Energiinnhold', 'Trykk', 'Reaksjonshastighet'] },
  ]
}

function generateChemistryLevel(level: number): Question[] {
  const elements = chemElements(level)
  const questions: Question[] = []

  const allSymbols   = ALL_CHEM_ELEMENTS.map(e => e.symbol).sort()
  const allNames     = ALL_CHEM_ELEMENTS.map(e => e.name).sort()
  const allNumbers   = ALL_CHEM_ELEMENTS.map(e => String(e.atomicNumber)).sort((a, b) => Number(a) - Number(b))

  let idx = 0
  for (const e of elements) {
    const pre = `chem-l${level}-${String(++idx).padStart(3, '0')}`
    questions.push({
      id: `${pre}a`, level, prompt: `Hva er symbolet for ${e.name}?`,
      answer: e.symbol, options: [e.symbol, ...pickFirst(allSymbols, e.symbol, 3)],
    })
    questions.push({
      id: `${pre}b`, level, prompt: `Hvilket grunnstoff har symbolet ${e.symbol}?`,
      answer: e.name, options: [e.name, ...pickFirst(allNames, e.name, 3)],
    })
    questions.push({
      id: `${pre}c`, level, prompt: `Hva er atomnummeret til ${e.name}?`,
      answer: String(e.atomicNumber), options: [String(e.atomicNumber), ...pickFirst(allNumbers, String(e.atomicNumber), 3)],
    })
    questions.push({
      id: `${pre}d`, level, prompt: `Hvilken kategori er ${e.name} i?`,
      answer: e.category, options: [e.category, ...pickFirst(ALL_CHEM_CATEGORIES, e.category, 3)],
    })
  }

  const specials = chemSpecials(level)
  for (const s of specials) {
    questions.push({
      id: `chem-l${level}-sp${String(++idx).padStart(3, '0')}`,
      level, prompt: s.prompt, answer: s.correct,
      options: [s.correct, ...s.distractors.slice(0, 3)],
    })
  }

  return questions
}

function generateChemistry(): Question[] {
  const all: Question[] = []
  for (let l = 1; l <= 20; l++) all.push(...generateChemistryLevel(l))
  return all
}

// ─── Geography ───────────────────────────────────────────────────────────────

interface GeoCountry { name: string; capital: string; iso: string; continent: string }

function geoCountries(level: number): GeoCountry[] {
  const l = Math.max(1, Math.min(20, level))
  if (l === 1) return [
    { name: 'Norge',   capital: 'Oslo',      iso: 'no', continent: 'Europa' },
    { name: 'Sverige', capital: 'Stockholm', iso: 'se', continent: 'Europa' },
    { name: 'Danmark', capital: 'København', iso: 'dk', continent: 'Europa' },
  ]
  if (l === 2) return [
    { name: 'Norge',   capital: 'Oslo',      iso: 'no', continent: 'Europa' },
    { name: 'Sverige', capital: 'Stockholm', iso: 'se', continent: 'Europa' },
    { name: 'Danmark', capital: 'København', iso: 'dk', continent: 'Europa' },
    { name: 'Finland', capital: 'Helsinki',  iso: 'fi', continent: 'Europa' },
    { name: 'Island',  capital: 'Reykjavík', iso: 'is', continent: 'Europa' },
  ]
  if (l === 3) return [
    { name: 'Norge',         capital: 'Oslo',      iso: 'no', continent: 'Europa' },
    { name: 'Sverige',       capital: 'Stockholm', iso: 'se', continent: 'Europa' },
    { name: 'Danmark',       capital: 'København', iso: 'dk', continent: 'Europa' },
    { name: 'Finland',       capital: 'Helsinki',  iso: 'fi', continent: 'Europa' },
    { name: 'Island',        capital: 'Reykjavík', iso: 'is', continent: 'Europa' },
    { name: 'Tyskland',      capital: 'Berlin',    iso: 'de', continent: 'Europa' },
    { name: 'Storbritannia', capital: 'London',    iso: 'gb', continent: 'Europa' },
    { name: 'Russland',      capital: 'Moskva',    iso: 'ru', continent: 'Europa' },
  ]
  if (l === 4) return [
    { name: 'Tyskland',      capital: 'Berlin',    iso: 'de', continent: 'Europa' },
    { name: 'Frankrike',     capital: 'Paris',     iso: 'fr', continent: 'Europa' },
    { name: 'Storbritannia', capital: 'London',    iso: 'gb', continent: 'Europa' },
    { name: 'Spania',        capital: 'Madrid',    iso: 'es', continent: 'Europa' },
    { name: 'Italia',        capital: 'Roma',      iso: 'it', continent: 'Europa' },
    { name: 'Nederland',     capital: 'Amsterdam', iso: 'nl', continent: 'Europa' },
    { name: 'Belgia',        capital: 'Brussel',   iso: 'be', continent: 'Europa' },
    { name: 'Sveits',        capital: 'Bern',      iso: 'ch', continent: 'Europa' },
    { name: 'Østerrike',     capital: 'Wien',      iso: 'at', continent: 'Europa' },
    { name: 'Portugal',      capital: 'Lisboa',    iso: 'pt', continent: 'Europa' },
    { name: 'Irland',        capital: 'Dublin',    iso: 'ie', continent: 'Europa' },
    { name: 'Hellas',        capital: 'Athen',     iso: 'gr', continent: 'Europa' },
  ]
  if (l === 5) return [
    { name: 'Polen',    capital: 'Warszawa',  iso: 'pl', continent: 'Europa' },
    { name: 'Tsjekkia', capital: 'Praha',     iso: 'cz', continent: 'Europa' },
    { name: 'Ungarn',   capital: 'Budapest',  iso: 'hu', continent: 'Europa' },
    { name: 'Romania',  capital: 'Bucuresti', iso: 'ro', continent: 'Europa' },
    { name: 'Bulgaria', capital: 'Sofia',     iso: 'bg', continent: 'Europa' },
    { name: 'Slovakia', capital: 'Bratislava',iso: 'sk', continent: 'Europa' },
    { name: 'Kroatia',  capital: 'Zagreb',    iso: 'hr', continent: 'Europa' },
    { name: 'Serbia',   capital: 'Beograd',   iso: 'rs', continent: 'Europa' },
    { name: 'Estland',  capital: 'Tallinn',   iso: 'ee', continent: 'Europa' },
    { name: 'Latvia',   capital: 'Riga',      iso: 'lv', continent: 'Europa' },
    { name: 'Litauen',  capital: 'Vilnius',   iso: 'lt', continent: 'Europa' },
    { name: 'Ukraina',  capital: 'Kyiv',      iso: 'ua', continent: 'Europa' },
    { name: 'Russland', capital: 'Moskva',    iso: 'ru', continent: 'Europa' },
    { name: 'Tyrkia',   capital: 'Ankara',    iso: 'tr', continent: 'Europa' },
  ]
  if (l === 6) return [
    { name: 'USA',         capital: 'Washington D.C.', iso: 'us', continent: 'Nord-Amerika' },
    { name: 'Canada',      capital: 'Ottawa',    iso: 'ca', continent: 'Nord-Amerika' },
    { name: 'Mexico',      capital: 'Mexico by', iso: 'mx', continent: 'Nord-Amerika' },
    { name: 'Brasil',      capital: 'Brasília',  iso: 'br', continent: 'Sør-Amerika' },
    { name: 'Argentina',   capital: 'Buenos Aires', iso: 'ar', continent: 'Sør-Amerika' },
    { name: 'Kina',        capital: 'Beijing',   iso: 'cn', continent: 'Asia' },
    { name: 'Japan',       capital: 'Tokyo',     iso: 'jp', continent: 'Asia' },
    { name: 'India',       capital: 'New Delhi', iso: 'in', continent: 'Asia' },
    { name: 'Egypt',       capital: 'Kairo',     iso: 'eg', continent: 'Afrika' },
    { name: 'Sør-Afrika',  capital: 'Pretoria',  iso: 'za', continent: 'Afrika' },
    { name: 'Australia',   capital: 'Canberra',  iso: 'au', continent: 'Oseania' },
    { name: 'New Zealand', capital: 'Wellington',iso: 'nz', continent: 'Oseania' },
  ]
  if (l === 7) return [
    { name: 'Brasil',      capital: 'Brasília',      iso: 'br', continent: 'Sør-Amerika' },
    { name: 'Colombia',    capital: 'Bogotá',        iso: 'co', continent: 'Sør-Amerika' },
    { name: 'Peru',        capital: 'Lima',          iso: 'pe', continent: 'Sør-Amerika' },
    { name: 'Chile',       capital: 'Santiago',      iso: 'cl', continent: 'Sør-Amerika' },
    { name: 'Venezuela',   capital: 'Caracas',       iso: 've', continent: 'Sør-Amerika' },
    { name: 'Sør-Korea',   capital: 'Seoul',         iso: 'kr', continent: 'Asia' },
    { name: 'Thailand',    capital: 'Bangkok',       iso: 'th', continent: 'Asia' },
    { name: 'Vietnam',     capital: 'Hanoi',         iso: 'vn', continent: 'Asia' },
    { name: 'Indonesia',   capital: 'Jakarta',       iso: 'id', continent: 'Asia' },
    { name: 'Filippinene', capital: 'Manila',        iso: 'ph', continent: 'Asia' },
    { name: 'Malaysia',    capital: 'Kuala Lumpur',  iso: 'my', continent: 'Asia' },
    { name: 'Singapore',   capital: 'Singapore',     iso: 'sg', continent: 'Asia' },
  ]
  if (l === 8) return [
    { name: 'Saudi-Arabia',                   capital: 'Riyadh',      iso: 'sa', continent: 'Asia' },
    { name: 'Iran',                           capital: 'Teheran',     iso: 'ir', continent: 'Asia' },
    { name: 'Irak',                           capital: 'Bagdad',      iso: 'iq', continent: 'Asia' },
    { name: 'Israel',                         capital: 'Jerusalem',   iso: 'il', continent: 'Asia' },
    { name: 'Jordan',                         capital: 'Amman',       iso: 'jo', continent: 'Asia' },
    { name: 'Libanon',                        capital: 'Beirut',      iso: 'lb', continent: 'Asia' },
    { name: 'Syria',                          capital: 'Damaskus',    iso: 'sy', continent: 'Asia' },
    { name: 'Forenede arabiske emirater',     capital: 'Abu Dhabi',   iso: 'ae', continent: 'Asia' },
    { name: 'Pakistan',                       capital: 'Islamabad',   iso: 'pk', continent: 'Asia' },
    { name: 'Bangladesh',                     capital: 'Dhaka',       iso: 'bd', continent: 'Asia' },
    { name: 'Afghanistan',                    capital: 'Kabul',       iso: 'af', continent: 'Asia' },
    { name: 'Mongolia',                       capital: 'Ulaanbaatar', iso: 'mn', continent: 'Asia' },
  ]
  if (l === 9) return [
    { name: 'Egypt',      capital: 'Kairo',       iso: 'eg', continent: 'Afrika' },
    { name: 'Marokko',    capital: 'Rabat',       iso: 'ma', continent: 'Afrika' },
    { name: 'Algerie',    capital: 'Alger',       iso: 'dz', continent: 'Afrika' },
    { name: 'Tunisia',    capital: 'Tunis',       iso: 'tn', continent: 'Afrika' },
    { name: 'Libya',      capital: 'Tripoli',     iso: 'ly', continent: 'Afrika' },
    { name: 'Sudan',      capital: 'Khartoum',    iso: 'sd', continent: 'Afrika' },
    { name: 'Etiopia',    capital: 'Addis Abeba', iso: 'et', continent: 'Afrika' },
    { name: 'Kenya',      capital: 'Nairobi',     iso: 'ke', continent: 'Afrika' },
    { name: 'Tanzania',   capital: 'Dodoma',      iso: 'tz', continent: 'Afrika' },
    { name: 'Nigeria',    capital: 'Abuja',       iso: 'ng', continent: 'Afrika' },
    { name: 'Ghana',      capital: 'Accra',       iso: 'gh', continent: 'Afrika' },
    { name: 'Senegal',    capital: 'Dakar',       iso: 'sn', continent: 'Afrika' },
    { name: 'Sør-Afrika', capital: 'Pretoria',    iso: 'za', continent: 'Afrika' },
    { name: 'DR Kongo',   capital: 'Kinshasa',    iso: 'cd', continent: 'Afrika' },
  ]
  if (l === 10) return [
    { name: 'Norge',         capital: 'Oslo',             iso: 'no', continent: 'Europa' },
    { name: 'USA',           capital: 'Washington D.C.',  iso: 'us', continent: 'Nord-Amerika' },
    { name: 'Kina',          capital: 'Beijing',          iso: 'cn', continent: 'Asia' },
    { name: 'Russland',      capital: 'Moskva',           iso: 'ru', continent: 'Europa' },
    { name: 'Brasil',        capital: 'Brasília',         iso: 'br', continent: 'Sør-Amerika' },
    { name: 'India',         capital: 'New Delhi',        iso: 'in', continent: 'Asia' },
    { name: 'Tyskland',      capital: 'Berlin',           iso: 'de', continent: 'Europa' },
    { name: 'Frankrike',     capital: 'Paris',            iso: 'fr', continent: 'Europa' },
    { name: 'Storbritannia', capital: 'London',           iso: 'gb', continent: 'Europa' },
    { name: 'Japan',         capital: 'Tokyo',            iso: 'jp', continent: 'Asia' },
    { name: 'Australia',     capital: 'Canberra',         iso: 'au', continent: 'Oseania' },
    { name: 'Canada',        capital: 'Ottawa',           iso: 'ca', continent: 'Nord-Amerika' },
    { name: 'Sør-Afrika',    capital: 'Pretoria',         iso: 'za', continent: 'Afrika' },
    { name: 'Egypt',         capital: 'Kairo',            iso: 'eg', continent: 'Afrika' },
  ]
  if (l === 11) return [
    { name: 'Island',       capital: 'Reykjavík', iso: 'is', continent: 'Europa' },
    { name: 'Indonesia',    capital: 'Jakarta',   iso: 'id', continent: 'Asia' },
    { name: 'Japan',        capital: 'Tokyo',     iso: 'jp', continent: 'Asia' },
    { name: 'Filippinene',  capital: 'Manila',    iso: 'ph', continent: 'Asia' },
    { name: 'Chile',        capital: 'Santiago',  iso: 'cl', continent: 'Sør-Amerika' },
    { name: 'New Zealand',  capital: 'Wellington',iso: 'nz', continent: 'Oseania' },
    { name: 'Italia',       capital: 'Roma',      iso: 'it', continent: 'Europa' },
    { name: 'Tyrkia',       capital: 'Ankara',    iso: 'tr', continent: 'Europa' },
    { name: 'Hellas',       capital: 'Athen',     iso: 'gr', continent: 'Europa' },
    { name: 'Sveits',       capital: 'Bern',      iso: 'ch', continent: 'Europa' },
    { name: 'Nepal',        capital: 'Kathmandu', iso: 'np', continent: 'Asia' },
    { name: 'Bolivia',      capital: 'La Paz',    iso: 'bo', continent: 'Sør-Amerika' },
  ]
  if (l === 12) return [
    { name: 'Brasil',       capital: 'Brasília',     iso: 'br', continent: 'Sør-Amerika' },
    { name: 'Indonesia',    capital: 'Jakarta',      iso: 'id', continent: 'Asia' },
    { name: 'Saudi-Arabia', capital: 'Riyadh',       iso: 'sa', continent: 'Asia' },
    { name: 'Australia',    capital: 'Canberra',     iso: 'au', continent: 'Oseania' },
    { name: 'Canada',       capital: 'Ottawa',       iso: 'ca', continent: 'Nord-Amerika' },
    { name: 'Russland',     capital: 'Moskva',       iso: 'ru', continent: 'Europa' },
    { name: 'DR Kongo',     capital: 'Kinshasa',     iso: 'cd', continent: 'Afrika' },
    { name: 'Egypt',        capital: 'Kairo',        iso: 'eg', continent: 'Afrika' },
    { name: 'Mongolia',     capital: 'Ulaanbaatar',  iso: 'mn', continent: 'Asia' },
    { name: 'Argentina',    capital: 'Buenos Aires', iso: 'ar', continent: 'Sør-Amerika' },
    { name: 'Norge',        capital: 'Oslo',         iso: 'no', continent: 'Europa' },
    { name: 'Etiopia',      capital: 'Addis Abeba',  iso: 'et', continent: 'Afrika' },
  ]
  if (l === 13) return [
    { name: 'India',      capital: 'New Delhi',        iso: 'in', continent: 'Asia' },
    { name: 'Kina',       capital: 'Beijing',          iso: 'cn', continent: 'Asia' },
    { name: 'Nigeria',    capital: 'Abuja',            iso: 'ng', continent: 'Afrika' },
    { name: 'Bangladesh', capital: 'Dhaka',            iso: 'bd', continent: 'Asia' },
    { name: 'Pakistan',   capital: 'Islamabad',        iso: 'pk', continent: 'Asia' },
    { name: 'Indonesia',  capital: 'Jakarta',          iso: 'id', continent: 'Asia' },
    { name: 'USA',        capital: 'Washington D.C.',  iso: 'us', continent: 'Nord-Amerika' },
    { name: 'Brasil',     capital: 'Brasília',         iso: 'br', continent: 'Sør-Amerika' },
    { name: 'Mexico',     capital: 'Mexico by',        iso: 'mx', continent: 'Nord-Amerika' },
    { name: 'Tyskland',   capital: 'Berlin',           iso: 'de', continent: 'Europa' },
    { name: 'Tyrkia',     capital: 'Ankara',           iso: 'tr', continent: 'Europa' },
    { name: 'Egypt',      capital: 'Kairo',            iso: 'eg', continent: 'Afrika' },
  ]
  if (l === 14) return [
    { name: 'Russland',              capital: 'Moskva',           iso: 'ru', continent: 'Europa' },
    { name: 'USA',                   capital: 'Washington D.C.',  iso: 'us', continent: 'Nord-Amerika' },
    { name: 'Kina',                  capital: 'Beijing',          iso: 'cn', continent: 'Asia' },
    { name: 'EU-medlem: Frankrike',  capital: 'Paris',            iso: 'fr', continent: 'Europa' },
    { name: 'Tyskland',              capital: 'Berlin',           iso: 'de', continent: 'Europa' },
    { name: 'Storbritannia',         capital: 'London',           iso: 'gb', continent: 'Europa' },
    { name: 'Japan',                 capital: 'Tokyo',            iso: 'jp', continent: 'Asia' },
    { name: 'India',                 capital: 'New Delhi',        iso: 'in', continent: 'Asia' },
    { name: 'Saudi-Arabia',          capital: 'Riyadh',           iso: 'sa', continent: 'Asia' },
    { name: 'Iran',                  capital: 'Teheran',          iso: 'ir', continent: 'Asia' },
    { name: 'Brasil',                capital: 'Brasília',         iso: 'br', continent: 'Sør-Amerika' },
  ]
  if (l === 15) return [
    { name: 'Vatikanstaten', capital: 'Vatikanstaten',       iso: 'va', continent: 'Europa' },
    { name: 'Monaco',        capital: 'Monaco',              iso: 'mc', continent: 'Europa' },
    { name: 'San Marino',    capital: 'San Marino',          iso: 'sm', continent: 'Europa' },
    { name: 'Liechtenstein', capital: 'Vaduz',               iso: 'li', continent: 'Europa' },
    { name: 'Andorra',       capital: 'Andorra la Vella',    iso: 'ad', continent: 'Europa' },
    { name: 'Malta',         capital: 'Valletta',            iso: 'mt', continent: 'Europa' },
    { name: 'Luxembourg',    capital: 'Luxembourg',          iso: 'lu', continent: 'Europa' },
    { name: 'Brunei',        capital: 'Bandar Seri Begawan', iso: 'bn', continent: 'Asia' },
    { name: 'Bhutan',        capital: 'Thimphu',             iso: 'bt', continent: 'Asia' },
    { name: 'Maldivene',     capital: 'Malé',                iso: 'mv', continent: 'Asia' },
  ]
  if (l === 16) return [
    { name: 'Kasakhstan', capital: 'Astana',      iso: 'kz', continent: 'Asia' },
    { name: 'Mongolia',   capital: 'Ulaanbaatar', iso: 'mn', continent: 'Asia' },
    { name: 'Nepal',      capital: 'Kathmandu',   iso: 'np', continent: 'Asia' },
    { name: 'Bolivia',    capital: 'La Paz',      iso: 'bo', continent: 'Sør-Amerika' },
    { name: 'Paraguay',   capital: 'Asunción',    iso: 'py', continent: 'Sør-Amerika' },
    { name: 'Tsjad',      capital: 'N\'Djamena',  iso: 'td', continent: 'Afrika' },
    { name: 'Niger',      capital: 'Niamey',      iso: 'ne', continent: 'Afrika' },
    { name: 'Mali',       capital: 'Bamako',      iso: 'ml', continent: 'Afrika' },
    { name: 'Sør-Sudan',  capital: 'Juba',        iso: 'ss', continent: 'Afrika' },
    { name: 'Lesotho',    capital: 'Maseru',      iso: 'ls', continent: 'Afrika' },
    { name: 'Eswatini',   capital: 'Mbabane',     iso: 'sz', continent: 'Afrika' },
  ]
  if (l === 17) return [
    { name: 'Fiji',          capital: 'Suva',       iso: 'fj', continent: 'Oseania' },
    { name: 'Vanuatu',       capital: 'Port Vila',  iso: 'vu', continent: 'Oseania' },
    { name: 'Samoa',         capital: 'Apia',       iso: 'ws', continent: 'Oseania' },
    { name: 'Tonga',         capital: 'Nuku\'alofa',iso: 'to', continent: 'Oseania' },
    { name: 'Kiribati',      capital: 'Tarawa',     iso: 'ki', continent: 'Oseania' },
    { name: 'Tuvalu',        capital: 'Funafuti',   iso: 'tv', continent: 'Oseania' },
    { name: 'Nauru',         capital: 'Yaren',      iso: 'nr', continent: 'Oseania' },
    { name: 'Salomonøyene',  capital: 'Honiara',    iso: 'sb', continent: 'Oseania' },
    { name: 'Marshalløyene', capital: 'Majuro',     iso: 'mh', continent: 'Oseania' },
    { name: 'Mikronesia',    capital: 'Palikir',    iso: 'fm', continent: 'Oseania' },
    { name: 'Palau',         capital: 'Ngerulmud',  iso: 'pw', continent: 'Oseania' },
  ]
  if (l === 18) return [
    { name: 'Trinidad og Tobago',    capital: 'Port of Spain',   iso: 'tt', continent: 'Nord-Amerika' },
    { name: 'Barbados',              capital: 'Bridgetown',      iso: 'bb', continent: 'Nord-Amerika' },
    { name: 'Grenada',               capital: 'Saint George\'s', iso: 'gd', continent: 'Nord-Amerika' },
    { name: 'Saint Lucia',           capital: 'Castries',        iso: 'lc', continent: 'Nord-Amerika' },
    { name: 'Dominica',              capital: 'Roseau',          iso: 'dm', continent: 'Nord-Amerika' },
    { name: 'Antigua og Barbuda',    capital: 'Saint John\'s',   iso: 'ag', continent: 'Nord-Amerika' },
    { name: 'Saint Kitts og Nevis',  capital: 'Basseterre',      iso: 'kn', continent: 'Nord-Amerika' },
    { name: 'Belize',                capital: 'Belmopan',        iso: 'bz', continent: 'Nord-Amerika' },
    { name: 'Suriname',              capital: 'Paramaribo',      iso: 'sr', continent: 'Sør-Amerika' },
    { name: 'Guyana',                capital: 'Georgetown',      iso: 'gy', continent: 'Sør-Amerika' },
  ]
  if (l === 19) return [
    { name: 'Komorene',              capital: 'Moroni',      iso: 'km', continent: 'Afrika' },
    { name: 'Sao Tome og Príncipe',  capital: 'São Tomé',    iso: 'st', continent: 'Afrika' },
    { name: 'Ekvatorial-Guinea',     capital: 'Malabo',      iso: 'gq', continent: 'Afrika' },
    { name: 'Djibouti',              capital: 'Djibouti',    iso: 'dj', continent: 'Afrika' },
    { name: 'Eritrea',               capital: 'Asmara',      iso: 'er', continent: 'Afrika' },
    { name: 'Bahrain',               capital: 'Manama',      iso: 'bh', continent: 'Asia' },
    { name: 'Qatar',                 capital: 'Doha',        iso: 'qa', continent: 'Asia' },
    { name: 'Brunei',                capital: 'Bandar Seri Begawan', iso: 'bn', continent: 'Asia' },
    { name: 'Øst-Timor',             capital: 'Dili',        iso: 'tl', continent: 'Asia' },
    { name: 'Kapp Verde',            capital: 'Praia',       iso: 'cv', continent: 'Afrika' },
    { name: 'Seychellene',           capital: 'Victoria',    iso: 'sc', continent: 'Afrika' },
  ]
  // default: level 20
  return [
    { name: 'Tuvalu',        capital: 'Funafuti',          iso: 'tv', continent: 'Oseania' },
    { name: 'Nauru',         capital: 'Yaren',             iso: 'nr', continent: 'Oseania' },
    { name: 'Vanuatu',       capital: 'Port Vila',         iso: 'vu', continent: 'Oseania' },
    { name: 'Liechtenstein', capital: 'Vaduz',             iso: 'li', continent: 'Europa' },
    { name: 'Andorra',       capital: 'Andorra la Vella',  iso: 'ad', continent: 'Europa' },
    { name: 'Vatikanstaten', capital: 'Vatikanstaten',     iso: 'va', continent: 'Europa' },
    { name: 'Bhutan',        capital: 'Thimphu',           iso: 'bt', continent: 'Asia' },
    { name: 'Maldivene',     capital: 'Malé',              iso: 'mv', continent: 'Asia' },
    { name: 'Komorene',      capital: 'Moroni',            iso: 'km', continent: 'Afrika' },
  ]
}

const ALL_GEO_COUNTRIES: GeoCountry[] = (() => {
  const seen = new Set<string>()
  const all: GeoCountry[] = []
  for (let l = 1; l <= 20; l++) {
    for (const c of geoCountries(l)) {
      if (!seen.has(c.name)) { seen.add(c.name); all.push(c) }
    }
  }
  return all.sort((a, b) => a.name.localeCompare(a.name, 'nb'))
})()

const ALL_CONTINENTS = ['Europa', 'Asia', 'Afrika', 'Nord-Amerika', 'Sør-Amerika', 'Oseania']

function regionalIndicator(iso: string): string {
  return iso.toUpperCase().split('').map(c => {
    const offset = c.charCodeAt(0) - 'A'.charCodeAt(0)
    return String.fromCodePoint(0x1F1E6 + offset)
  }).join('')
}

interface GeoRaw { prompt: string; correct: string; distractors: string[] }

function geoSpecials(level: number): GeoRaw[] {
  const l = Math.max(1, Math.min(20, level))
  if (l === 1) return [
    { prompt: 'Hvilken himmelretning peker en kompassnål mot?', correct: 'Nord', distractors: ['Sør', 'Øst', 'Vest'] },
    { prompt: 'Hvor står sola opp?', correct: 'Øst', distractors: ['Vest', 'Nord', 'Sør'] },
    { prompt: 'Hvor går sola ned?', correct: 'Vest', distractors: ['Øst', 'Nord', 'Sør'] },
    { prompt: 'Hvilken himmelretning ligger Sverige fra Norge?', correct: 'Øst', distractors: ['Vest', 'Nord', 'Sør'] },
    { prompt: 'Hvilken himmelretning ligger Danmark fra Norge?', correct: 'Sør', distractors: ['Nord', 'Øst', 'Vest'] },
    { prompt: 'Hvilken himmelretning ligger havet (Atlanterhavet) fra Norge?', correct: 'Vest', distractors: ['Øst', 'Sør', 'Nord'] },
    { prompt: 'Hvor mange hovedretninger har et kompass?', correct: '4', distractors: ['2', '6', '8'] },
    { prompt: 'Hva er hovedstaden i Norge?', correct: 'Oslo', distractors: ['Bergen', 'Trondheim', 'Stavanger'] },
    { prompt: 'Hvilken by ligger lengst nord i Norge (av disse)?', correct: 'Tromsø', distractors: ['Bergen', 'Oslo', 'Trondheim'] },
    { prompt: 'Hvilken by er kjent for olje og kalles oljehovedstaden?', correct: 'Stavanger', distractors: ['Bergen', 'Oslo', 'Trondheim'] },
    { prompt: 'Hvilken by ligger på Vestlandet og er kjent for fiske?', correct: 'Bergen', distractors: ['Oslo', 'Tromsø', 'Hamar'] },
    { prompt: 'Hvilken by ligger ved Trondheimsfjorden?', correct: 'Trondheim', distractors: ['Bodø', 'Tromsø', 'Bergen'] },
    { prompt: 'Hvilken by ligger lengst sør i Norge?', correct: 'Kristiansand', distractors: ['Stavanger', 'Bergen', 'Oslo'] },
    { prompt: 'Hva er Norges høyeste fjell?', correct: 'Galdhøpiggen', distractors: ['Glittertind', 'Snøhetta', 'Romsdalshorn'] },
    { prompt: 'Hva er Norges lengste fjord?', correct: 'Sognefjorden', distractors: ['Hardangerfjorden', 'Geirangerfjorden', 'Trondheimsfjorden'] },
    { prompt: 'Hva er Norges lengste elv?', correct: 'Glomma', distractors: ['Lågen', 'Numedalslågen', 'Drammenselva'] },
    { prompt: 'Hvilken øygruppe ligger nord i Norge og er kjent for fjell og fiske?', correct: 'Lofoten', distractors: ['Vesterålen', 'Færøyene', 'Shetland'] },
    { prompt: 'Hvilken øygruppe ligger lengst nord under Norge?', correct: 'Svalbard', distractors: ['Lofoten', 'Færøyene', 'Bjørnøya'] },
    { prompt: 'Hvilket hav ligger vest for Norge?', correct: 'Norskehavet', distractors: ['Nordsjøen', 'Østersjøen', 'Barentshavet'] },
    { prompt: 'Hvilket hav ligger nord for Norge?', correct: 'Barentshavet', distractors: ['Norskehavet', 'Nordsjøen', 'Atlanterhavet'] },
    { prompt: 'Hvilket hav ligger sør for Norge (mellom Norge og UK)?', correct: 'Nordsjøen', distractors: ['Norskehavet', 'Østersjøen', 'Skagerrak'] },
    { prompt: 'Hvilket land grenser til Norge i øst (sør for Trondheim)?', correct: 'Sverige', distractors: ['Finland', 'Russland', 'Danmark'] },
    { prompt: 'Hvilket land grenser til Norge nord i Finnmark?', correct: 'Russland', distractors: ['Sverige', 'Finland', 'Estland'] },
    { prompt: 'Hvilket land ligger sør for Norge (over havet)?', correct: 'Danmark', distractors: ['Tyskland', 'Polen', 'Nederland'] },
    { prompt: 'Hvor mange land grenser til Norge på fastlandet?', correct: '3', distractors: ['1', '2', '4'] },
    { prompt: 'Hvilket land grenser til Norge i Nord-Norge (mellom Sverige og Russland)?', correct: 'Finland', distractors: ['Sverige', 'Estland', 'Russland'] },
    { prompt: 'Hvilke farger har det norske flagget?', correct: 'Rød, hvit, blå', distractors: ['Rød, hvit, gul', 'Blå, hvit, grønn', 'Rød, gul, blå'] },
    { prompt: 'Når er Norges nasjonaldag?', correct: '17. mai', distractors: ['1. mai', '8. mai', '1. juni'] },
    { prompt: 'Hva heter Norges nasjonalsang?', correct: 'Ja, vi elsker dette landet', distractors: ['Gud signe vårt dyre fedreland', 'Mellom bakkar og berg', 'Fagert er landet'] },
    { prompt: 'Hva er Norges nasjonalfjell?', correct: 'Stetind', distractors: ['Galdhøpiggen', 'Romsdalshorn', 'Trolltindane'] },
    { prompt: 'Hva er Norges nasjonalfugl?', correct: 'Fossekall', distractors: ['Ørn', 'Måke', 'Kråke'] },
    { prompt: 'Hva kalles en tegning av et område sett ovenfra?', correct: 'Kart', distractors: ['Bilde', 'Tegning', 'Modell'] },
    { prompt: 'Hvilken form har jorden?', correct: 'Rund (kule)', distractors: ['Flat', 'Firkantet', 'Trekantet'] },
    { prompt: 'Hva kalles den varme delen av jorden midt på?', correct: 'Ekvator', distractors: ['Polene', 'Tropene', 'Soner'] },
    { prompt: 'Hvor mange verdensdeler finnes det?', correct: '7', distractors: ['5', '6', '8'] },
    { prompt: 'Hvilken verdensdel ligger Norge i?', correct: 'Europa', distractors: ['Asia', 'Afrika', 'Nord-Amerika'] },
  ]
  if (l === 2) return [
    { prompt: 'Hvilke 5 land utgjør Norden?', correct: 'Norge, Sverige, Danmark, Finland, Island', distractors: ['Norge, Sverige, Danmark, Tyskland, Island', 'Norge, Sverige, Polen, Finland, Island', 'Norge, Sverige, Danmark, Finland, Færøyene'] },
    { prompt: 'Hvilket nordisk land har bare ett naboland?', correct: 'Danmark', distractors: ['Norge', 'Finland', 'Sverige'] },
    { prompt: 'Hvilket nordisk land er en øy uten naboland?', correct: 'Island', distractors: ['Færøyene', 'Grønland', 'Svalbard'] },
    { prompt: 'Hvilket nordisk land grenser ikke til Norge?', correct: 'Danmark', distractors: ['Sverige', 'Finland', 'Russland'] },
    { prompt: 'Hvilket nordisk språk er ikke skandinavisk?', correct: 'Finsk', distractors: ['Svensk', 'Dansk', 'Norsk'] },
    { prompt: 'I hvilket fylke ligger Bergen?', correct: 'Vestland', distractors: ['Rogaland', 'Møre og Romsdal', 'Trøndelag'] },
    { prompt: 'I hvilket fylke ligger Trondheim?', correct: 'Trøndelag', distractors: ['Nordland', 'Møre og Romsdal', 'Innlandet'] },
    { prompt: 'I hvilket fylke ligger Stavanger?', correct: 'Rogaland', distractors: ['Vestland', 'Agder', 'Vestfold'] },
    { prompt: 'I hvilket fylke ligger Tromsø?', correct: 'Troms', distractors: ['Finnmark', 'Nordland', 'Trøndelag'] },
    { prompt: 'Hvor mange fylker har Norge (etter 2024)?', correct: '15', distractors: ['11', '13', '19'] },
    { prompt: 'Hvilket land grenser til både Norge og Finland?', correct: 'Sverige', distractors: ['Russland', 'Estland', 'Danmark'] },
    { prompt: 'Hvilket nordisk land grenser til Tyskland?', correct: 'Danmark', distractors: ['Sverige', 'Norge', 'Finland'] },
    { prompt: 'Hovedstaden i Sverige?', correct: 'Stockholm', distractors: ['Göteborg', 'Malmö', 'Uppsala'] },
    { prompt: 'Hovedstaden i Danmark?', correct: 'København', distractors: ['Aarhus', 'Odense', 'Aalborg'] },
    { prompt: 'Hovedstaden i Finland?', correct: 'Helsinki', distractors: ['Turku', 'Tampere', 'Espoo'] },
    { prompt: 'Hovedstaden i Island?', correct: 'Reykjavík', distractors: ['Akureyri', 'Tórshavn', 'Nuuk'] },
    { prompt: 'Hvor ligger Geirangerfjorden?', correct: 'Møre og Romsdal', distractors: ['Vestland', 'Rogaland', 'Sogn og Fjordane'] },
    { prompt: 'Hvor ligger Preikestolen?', correct: 'Rogaland', distractors: ['Vestland', 'Agder', 'Trøndelag'] },
    { prompt: 'Hva er midnattssol?', correct: 'At sola ikke går ned om sommeren', distractors: ['At det er mørkt om sommeren', 'Sterk sol om vinteren', 'Et fenomen kun i Asia'] },
    { prompt: 'Hva er polarnatt?', correct: 'At sola ikke kommer over horisonten om vinteren', distractors: ['Sterk sol om vinteren', 'At det er lyst hele døgnet', 'Stjerneklart hele året'] },
    { prompt: 'Hva heter den øygruppen som hører til Danmark og ligger i Atlanterhavet?', correct: 'Færøyene', distractors: ['Lofoten', 'Shetland', 'Hebridene'] },
    { prompt: 'Hvilken stor øy nord-vest for Island tilhører Danmark?', correct: 'Grønland', distractors: ['Island', 'Færøyene', 'Spitsbergen'] },
  ]
  if (l === 3) return [
    { prompt: 'Hvilket hav skiller Norden fra Tyskland?', correct: 'Østersjøen', distractors: ['Nordsjøen', 'Atlanterhavet', 'Middelhavet'] },
    { prompt: 'Hvilket hav skiller Norge fra Storbritannia?', correct: 'Nordsjøen', distractors: ['Norskehavet', 'Østersjøen', 'Atlanterhavet'] },
    { prompt: 'Hvilken fjellkjede ligger mellom Norge og Sverige?', correct: 'Skandinaviske fjellkjede', distractors: ['Alpene', 'Pyreneene', 'Karpatene'] },
    { prompt: 'Hvilken elv renner gjennom Berlin?', correct: 'Spree', distractors: ['Rhinen', 'Donau', 'Elben'] },
    { prompt: 'Hvilken elv renner gjennom London?', correct: 'Themsen', distractors: ['Severn', 'Mersey', 'Seinen'] },
    { prompt: 'Hvilken elv renner gjennom Moskva?', correct: 'Moskvaelven', distractors: ['Volga', 'Don', 'Dnepr'] },
    { prompt: 'Hvor ligger Stonehenge?', correct: 'Storbritannia', distractors: ['Tyskland', 'Frankrike', 'Irland'] },
    { prompt: 'Hvilken type klima har Norge?', correct: 'Tempererte (tempererte breddegrader)', distractors: ['Tropisk', 'Polart', 'Ørken'] },
    { prompt: 'Hva kalles klimaet i Sahara?', correct: 'Ørkenklima', distractors: ['Tropisk', 'Tempererte', 'Polart'] },
    { prompt: 'Hva kalles klimaet ved Nordpolen?', correct: 'Polart', distractors: ['Tropisk', 'Tempererte', 'Ørken'] },
    { prompt: 'Hvilket hav er størst i verden?', correct: 'Stillehavet', distractors: ['Atlanterhavet', 'Indiske hav', 'Polhavet'] },
    { prompt: 'Hvor mange hav (verdenshav) finnes det?', correct: '5', distractors: ['3', '4', '7'] },
  ]
  if (l === 4) return [
    { prompt: 'Hvor ligger Frihetsgudinnen?', correct: 'New York', distractors: ['Washington D.C.', 'Boston', 'Chicago'] },
    { prompt: 'Hvor ligger Golden Gate Bridge?', correct: 'San Francisco', distractors: ['New York', 'Seattle', 'Los Angeles'] },
    { prompt: 'Hvor ligger Mount Rushmore?', correct: 'South Dakota', distractors: ['Wyoming', 'Montana', 'Colorado'] },
    { prompt: 'Hvor ligger Niagarafallene?', correct: 'Mellom USA og Canada', distractors: ['I USA', 'I Canada', 'Mellom USA og Mexico'] },
    { prompt: 'Hvor ligger Grand Canyon?', correct: 'Arizona', distractors: ['Utah', 'Nevada', 'New Mexico'] },
  ]
  if (l === 5) return [
    { prompt: 'Hvor ligger Machu Picchu?', correct: 'Peru', distractors: ['Bolivia', 'Ecuador', 'Chile'] },
    { prompt: 'Hvor står Christ the Redeemer?', correct: 'Rio de Janeiro', distractors: ['São Paulo', 'Buenos Aires', 'Lima'] },
    { prompt: 'Hvilken elv er lengst i Sør-Amerika?', correct: 'Amazonas', distractors: ['Paraná', 'Orinoco', 'São Francisco'] },
    { prompt: 'Hvor ligger Atacama-ørkenen?', correct: 'Chile', distractors: ['Peru', 'Argentina', 'Bolivia'] },
    { prompt: 'Hvor ligger Iguazú-fossene?', correct: 'Mellom Argentina og Brasil', distractors: ['Mellom Peru og Brasil', 'Mellom Bolivia og Argentina', 'Mellom Chile og Argentina'] },
  ]
  if (l === 6) return [
    { prompt: 'Hvor ligger Den kinesiske mur?', correct: 'Kina', distractors: ['Japan', 'Mongolia', 'Korea'] },
    { prompt: 'Hvor ligger Mount Fuji?', correct: 'Japan', distractors: ['Sør-Korea', 'Kina', 'Filippinene'] },
    { prompt: 'Hvor ligger Angkor Wat?', correct: 'Kambodsja', distractors: ['Thailand', 'Vietnam', 'Laos'] },
    { prompt: 'Hvor ligger Petronas-tårnene?', correct: 'Kuala Lumpur', distractors: ['Singapore', 'Bangkok', 'Manila'] },
    { prompt: 'Hvor ligger Marina Bay Sands?', correct: 'Singapore', distractors: ['Hong Kong', 'Kuala Lumpur', 'Bangkok'] },
    { prompt: 'Hvor ligger Forbidden City?', correct: 'Beijing', distractors: ['Xi\'an', 'Nanjing', 'Shanghai'] },
  ]
  if (l === 7) return [
    { prompt: 'Hvor ligger Taj Mahal?', correct: 'India', distractors: ['Pakistan', 'Bangladesh', 'Iran'] },
    { prompt: 'Hvor ligger Mount Everest (på grensen mellom)?', correct: 'Nepal og Kina', distractors: ['Nepal og India', 'India og Kina', 'Bhutan og Kina'] },
    { prompt: 'Hvor ligger K2?', correct: 'Pakistan', distractors: ['India', 'Nepal', 'Kina'] },
    { prompt: 'Hvilken elv renner gjennom Bagdad?', correct: 'Tigris', distractors: ['Eufrat', 'Jordan', 'Karun'] },
    { prompt: 'Hvilken elv munner ut i Det kaspiske hav?', correct: 'Volga', distractors: ['Ural', 'Don', 'Dnepr'] },
  ]
  if (l === 8) return [
    { prompt: 'Hvor ligger Petra?', correct: 'Jordan', distractors: ['Egypt', 'Israel', 'Saudi-Arabia'] },
    { prompt: 'Hvor ligger Burj Khalifa?', correct: 'Dubai', distractors: ['Abu Dhabi', 'Riyadh', 'Doha'] },
    { prompt: 'Hvor ligger Den arabiske halvøy?', correct: 'Sørvest-Asia', distractors: ['Nordøst-Afrika', 'Sentral-Asia', 'Sør-Asia'] },
    { prompt: 'Hvor står Sheikh Zayed-moskeen?', correct: 'Abu Dhabi', distractors: ['Dubai', 'Doha', 'Muscat'] },
    { prompt: 'Hvor står Hagia Sophia?', correct: 'Istanbul', distractors: ['Athen', 'Jerusalem', 'Roma'] },
  ]
  if (l === 9) return [
    { prompt: 'Verdens lengste elv?', correct: 'Nilen', distractors: ['Amazonas', 'Yangtze', 'Mississippi'] },
    { prompt: 'Hvor ligger Sahara-ørkenen?', correct: 'Nord-Afrika', distractors: ['Sør-Afrika', 'Øst-Afrika', 'Sentral-Afrika'] },
    { prompt: 'Hvor ligger Pyramidene i Giza?', correct: 'Egypt', distractors: ['Sudan', 'Libya', 'Saudi-Arabia'] },
    { prompt: 'Hvilken elv renner gjennom Kairo og Khartoum?', correct: 'Nilen', distractors: ['Kongo', 'Niger', 'Zambezi'] },
    { prompt: 'Hvor ligger Atlasfjellene?', correct: 'Nordvest-Afrika', distractors: ['Sør-Afrika', 'Øst-Afrika', 'Sahara'] },
  ]
  if (l === 10) return [
    { prompt: 'Hvilken elv er Afrikas nest lengste?', correct: 'Kongo', distractors: ['Niger', 'Zambezi', 'Limpopo'] },
    { prompt: 'Hvor ligger Timbuktu?', correct: 'Mali', distractors: ['Niger', 'Mauritania', 'Burkina Faso'] },
    { prompt: 'Hvor ligger Sahel-regionen?', correct: 'Sør for Sahara', distractors: ['Nord for Sahara', 'Øst-Afrika', 'Sør-Afrika'] },
    { prompt: 'Hvilken elv renner gjennom Mali?', correct: 'Niger', distractors: ['Senegal', 'Volta', 'Kongo'] },
    { prompt: 'Hvilket land har lengst kystlinje i Vest-Afrika?', correct: 'Nigeria', distractors: ['Ghana', 'Senegal', 'Liberia'] },
  ]
  if (l === 11) return [
    { prompt: 'Hvor ligger Kilimanjaro?', correct: 'Tanzania', distractors: ['Kenya', 'Uganda', 'Etiopia'] },
    { prompt: 'Verdens dypeste innsjø?', correct: 'Bajkalsjøen', distractors: ['Tanganyikasjøen', 'Kaspihavet', 'Lake Superior'] },
    { prompt: 'Hvor er kilden til Nilen?', correct: 'Victoriasjøen', distractors: ['Tanganyikasjøen', 'Tana-sjøen', 'Albertsjøen'] },
    { prompt: 'Hvor ligger Serengeti?', correct: 'Tanzania', distractors: ['Kenya', 'Uganda', 'Sør-Afrika'] },
    { prompt: 'Hvor renner elva Limpopo?', correct: 'Sør-Afrika', distractors: ['Tanzania', 'Angola', 'Namibia'] },
  ]
  if (l === 12) return [
    { prompt: 'Hvor ligger Victoria-fossene?', correct: 'Mellom Zambia og Zimbabwe', distractors: ['Mellom Kenya og Tanzania', 'Mellom Sør-Afrika og Mosambik', 'Mellom Botswana og Namibia'] },
    { prompt: 'Hvilken stat er omsluttet av Sør-Afrika?', correct: 'Lesotho', distractors: ['Eswatini', 'Botswana', 'Zimbabwe'] },
    { prompt: 'Hvor ligger Kalahariørkenen?', correct: 'Sørlige Afrika', distractors: ['Nord-Afrika', 'Øst-Afrika', 'Vest-Afrika'] },
    { prompt: 'Hvor ligger Kapp det gode håp?', correct: 'Sør-Afrika', distractors: ['Namibia', 'Mosambik', 'Angola'] },
    { prompt: 'Hvilken elv danner grensen mellom Zambia og Zimbabwe?', correct: 'Zambezi', distractors: ['Limpopo', 'Kongo', 'Orange'] },
  ]
  if (l === 13) return [
    { prompt: 'Hvor ligger Uluru (Ayers Rock)?', correct: 'Australia', distractors: ['New Zealand', 'Sør-Afrika', 'Argentina'] },
    { prompt: 'Hvor står Sydney Opera House?', correct: 'Sydney', distractors: ['Melbourne', 'Brisbane', 'Auckland'] },
    { prompt: 'Hvor ligger Great Barrier Reef?', correct: 'Australia', distractors: ['Indonesia', 'Filippinene', 'Fiji'] },
    { prompt: 'Hvor ligger Tasmania?', correct: 'Australia', distractors: ['New Zealand', 'Indonesia', 'Papua Ny-Guinea'] },
    { prompt: 'Hvor ligger Tongariro nasjonalpark?', correct: 'New Zealand', distractors: ['Australia', 'Fiji', 'Samoa'] },
  ]
  if (l === 14) return [
    { prompt: 'Hvor ligger Galápagos-øyene?', correct: 'Ecuador', distractors: ['Peru', 'Chile', 'Colombia'] },
    { prompt: 'Hvor ligger Påskeøya?', correct: 'Chile', distractors: ['Peru', 'Fransk Polynesia', 'Argentina'] },
    { prompt: 'Hvilket land deler øya Hispaniola med Haiti?', correct: 'Dominikanske republikk', distractors: ['Cuba', 'Jamaica', 'Puerto Rico'] },
    { prompt: 'Hvor ligger Karibhavet?', correct: 'Mellom Mellom-Amerika og Sør-Amerika', distractors: ['Vest for Stillehavet', 'Nord for Atlanterhavet', 'Mellom Afrika og Sør-Amerika'] },
    { prompt: 'Hvilket land er størst i Karibia?', correct: 'Cuba', distractors: ['Jamaica', 'Bahamas', 'Dominikanske republikk'] },
  ]
  if (l === 15) return [
    { prompt: 'Verdens minste land etter areal?', correct: 'Vatikanstaten', distractors: ['Monaco', 'San Marino', 'Tuvalu'] },
    { prompt: 'Hvilken by kalles "den evige stad"?', correct: 'Roma', distractors: ['Athen', 'Jerusalem', 'Istanbul'] },
    { prompt: 'Hvilket land er omsluttet av Italia?', correct: 'San Marino', distractors: ['Vatikanstaten', 'Monaco', 'Andorra'] },
    { prompt: 'Hvor ligger Andorra?', correct: 'Mellom Spania og Frankrike', distractors: ['Mellom Italia og Sveits', 'Mellom Tyskland og Polen', 'Mellom Hellas og Tyrkia'] },
    { prompt: 'Hvor ligger Alhambra?', correct: 'Granada', distractors: ['Córdoba', 'Sevilla', 'Toledo'] },
  ]
  if (l === 16) return [
    { prompt: 'Verdens høyest beliggende hovedstad?', correct: 'La Paz', distractors: ['Quito', 'Bogotá', 'Lhasa'] },
    { prompt: 'Verdens største innlandsstat etter areal?', correct: 'Kasakhstan', distractors: ['Mongolia', 'Bolivia', 'Tsjad'] },
    { prompt: 'Hvor ligger Uralfjellene?', correct: 'Russland', distractors: ['Kasakhstan', 'Mongolia', 'Ukraina'] },
    { prompt: 'Hvor ligger Patagonia?', correct: 'Argentina og Chile', distractors: ['Peru og Bolivia', 'Brasil og Paraguay', 'Uruguay og Argentina'] },
    { prompt: 'Hvor ligger Sibir?', correct: 'Russland', distractors: ['Kasakhstan', 'Mongolia', 'Kina'] },
  ]
  if (l === 17) return [
    { prompt: 'Hvilket land het tidligere Burma?', correct: 'Myanmar', distractors: ['Thailand', 'Vietnam', 'Bangladesh'] },
    { prompt: 'Hvilket land het tidligere Ceylon?', correct: 'Sri Lanka', distractors: ['Maldivene', 'Bangladesh', 'India'] },
    { prompt: 'Hvilket land het tidligere Zaire?', correct: 'DR Kongo', distractors: ['Republikken Kongo', 'Angola', 'Sør-Sudan'] },
    { prompt: 'Hvilket land ble dannet i 2011?', correct: 'Sør-Sudan', distractors: ['Eritrea', 'Kosovo', 'Sør-Ossetia'] },
    { prompt: 'Hvor ligger Madagaskar?', correct: 'Sørøst-Afrika', distractors: ['Vest-Afrika', 'Det indiske hav (vest for India)', 'Stillehavet'] },
  ]
  if (l === 18) return [
    { prompt: 'Hvor mange land er medlemmer av FN (per 2020)?', correct: '193', distractors: ['180', '200', '250'] },
    { prompt: 'Hvilket land har flest tidssoner?', correct: 'Frankrike', distractors: ['Russland', 'USA', 'Storbritannia'] },
    { prompt: 'Hvor ligger Bora Bora?', correct: 'Fransk Polynesia', distractors: ['Fiji', 'Samoa', 'Tonga'] },
    { prompt: 'Hvilket land er kjent for Maori-kulturen?', correct: 'New Zealand', distractors: ['Australia', 'Fiji', 'Samoa'] },
    { prompt: 'Hvilken stat er omsluttet av Italia?', correct: 'San Marino', distractors: ['Monaco', 'Vatikanstaten', 'Andorra'] },
  ]
  if (l === 19) return [
    { prompt: 'Hvilket hav er saltest?', correct: 'Dødehavet', distractors: ['Rødehavet', 'Middelhavet', 'Karibhavet'] },
    { prompt: 'Verdens største kontinent?', correct: 'Asia', distractors: ['Afrika', 'Nord-Amerika', 'Europa'] },
    { prompt: 'Verdens minste kontinent?', correct: 'Oseania', distractors: ['Europa', 'Antarktis', 'Sør-Amerika'] },
    { prompt: 'Hvilket land har størst flateareal?', correct: 'Russland', distractors: ['Canada', 'Kina', 'USA'] },
    { prompt: 'Hvilket land har størst befolkning?', correct: 'India', distractors: ['Kina', 'USA', 'Indonesia'] },
  ]
  // level 20
  return [
    { prompt: 'Hvor ligger Socotra-øya?', correct: 'Jemen', distractors: ['Oman', 'Somalia', 'Eritrea'] },
    { prompt: 'Hvor renner elva Lena?', correct: 'Russland', distractors: ['Kasakhstan', 'Kina', 'Mongolia'] },
    { prompt: 'Hvilket land grenser til flest land i verden?', correct: 'Kina', distractors: ['Russland', 'Brasil', 'USA'] },
    { prompt: 'Hvilken elv krysser flest land?', correct: 'Donau', distractors: ['Nilen', 'Kongo', 'Mekong'] },
    { prompt: 'Hvor ligger Borobudur?', correct: 'Indonesia', distractors: ['Malaysia', 'Thailand', 'Filippinene'] },
  ]
}

function generateGeographyLevel(level: number): Question[] {
  const countries = geoCountries(level)
  const questions: Question[] = []

  const allCapitals   = [...new Set(ALL_GEO_COUNTRIES.map(c => c.capital))].sort()
  const allNames      = [...new Set(ALL_GEO_COUNTRIES.map(c => c.name))].sort()

  let idx = 0
  for (const c of countries) {
    const pre = `geo-l${level}-${String(++idx).padStart(3, '0')}`
    const flag = regionalIndicator(c.iso)

    questions.push({
      id: `${pre}a`, level, prompt: `Hovedstaden i ${c.name}?`,
      answer: c.capital, options: [c.capital, ...pickFirst(allCapitals, c.capital, 3)],
    })
    questions.push({
      id: `${pre}b`, level, prompt: `I hvilket land ligger ${c.capital}?`,
      answer: c.name, options: [c.name, ...pickFirst(allNames, c.name, 3)],
    })
    questions.push({
      id: `${pre}c`, level, prompt: `Hvilken kontinent ligger ${c.name} i?`,
      answer: c.continent, options: [c.continent, ...pickFirst(ALL_CONTINENTS, c.continent, 3)],
    })
    questions.push({
      id: `${pre}d`, level, prompt: `Hvilket land har dette flagget? ${flag}`,
      answer: c.name, options: [c.name, ...pickFirst(allNames, c.name, 3)],
    })
  }

  const specials = geoSpecials(level)
  for (const s of specials) {
    questions.push({
      id: `geo-l${level}-sp${String(++idx).padStart(3, '0')}`,
      level, prompt: s.prompt, answer: s.correct,
      options: [s.correct, ...s.distractors.slice(0, 3)],
    })
  }

  return questions
}

function generateGeography(): Question[] {
  const all: Question[] = []
  for (let l = 1; l <= 20; l++) all.push(...generateGeographyLevel(l))
  return all
}

// ─── CSV / DB helpers ─────────────────────────────────────────────────────────

function toCsv(questions: Question[]): string {
  const esc = (s: string) => `"${s.replace(/"/g, '""')}"`
  const header = 'id,level,prompt,correct,distractor1,distractor2,distractor3'
  const rows = questions.map(q => {
    const [d1, d2, d3] = q.options.filter(o => o !== q.answer)
    return [q.id, q.level, esc(q.prompt), esc(q.answer), esc(d1 ?? ''), esc(d2 ?? ''), esc(d3 ?? '')].join(',')
  })
  return header + '\n' + rows.join('\n')
}

function levelSummary(questions: Question[]): string {
  const byLevel = questions.reduce<Record<number, number>>((acc, q) => {
    acc[q.level] = (acc[q.level] ?? 0) + 1; return acc
  }, {})
  return Object.entries(byLevel)
    .sort((a, b) => Number(a[0]) - Number(b[0]))
    .map(([l, n]) => `L${l}:${n}`)
    .join(' ')
}

// ─── CSV mode ────────────────────────────────────────────────────────────────

async function runCsvMode() {
  const outDir = path.join(__dirname, 'csv')
  fs.mkdirSync(outDir, { recursive: true })
  let total = 0

  // Swift-bank modes
  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) { console.warn(`⚠  Not found: ${filePath}`); continue }

    const questions = parseSwiftBank(filePath, slug)
    const outPath   = path.join(outDir, `${slug}.csv`)
    fs.writeFileSync(outPath, toCsv(questions), 'utf-8')

    console.log(`✓  ${slug}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    console.log(`   → ${outPath}`)
    total += questions.length
  }

  // Generated modes
  const generated: Array<{ slug: string; questions: Question[] }> = [
    { slug: 'chem', questions: generateChemistry() },
    { slug: 'geo',  questions: generateGeography() },
  ]

  for (const { slug, questions } of generated) {
    const outPath = path.join(outDir, `${slug}.csv`)
    fs.writeFileSync(outPath, toCsv(questions), 'utf-8')
    console.log(`✓  ${slug}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    console.log(`   → ${outPath}`)
    total += questions.length
  }

  console.log(`\n${total} spørsmål eksportert til scripts/csv/`)
  console.log('\nProsedyriske modus (ingen CSV):')
  console.log('  • math  — 100 % prosedyrisk aritmetikk')
  console.log('  • brain — 100 % prosedyriske sekvenser/mønstre')
  console.log('  • pi    — progressiv siffermemorering')
  console.log('\nNeste steg:')
  console.log('  1. Gå til admin-UI → Questions')
  console.log('  2. Velg modus, lim inn CSV-innhold, klikk "Last opp"')
  console.log('  3. Aktiver pakken etter verifisering')
}

// ─── DB mode ─────────────────────────────────────────────────────────────────

async function runDbMode() {
  if (!process.env.DATABASE_URL) {
    console.error('ERROR: DATABASE_URL er påkrevd\n')
    console.error('  DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts')
    console.error('  eller bruk --csv for å eksportere til filer i stedet')
    process.exit(1)
  }

  const prisma = new PrismaClient()
  await prisma.$connect()
  let total = 0

  // Swift-bank modes
  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) { console.warn(`⚠  Not found: ${filePath}`); continue }

    const existing = await prisma.questionPack.findFirst({
      where: { mode: slug },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    if (existing && !FORCE) {
      console.log(`⏭  ${slug}: har allerede v${existing.version} — hopper over (bruk --force for ny versjon)`)
      continue
    }

    const questions = parseSwiftBank(filePath, slug)
    const version   = (existing?.version ?? 0) + 1
    await prisma.questionPack.create({
      data: { mode: slug, version, data: questions as any, isActive: false },
    })

    console.log(`✓  ${slug} v${version}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    total += questions.length
  }

  // Generated modes
  const generated: Array<{ slug: string; questions: Question[] }> = [
    { slug: 'chem', questions: generateChemistry() },
    { slug: 'geo',  questions: generateGeography() },
  ]

  for (const { slug, questions } of generated) {
    const existing = await prisma.questionPack.findFirst({
      where: { mode: slug },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    if (existing && !FORCE) {
      console.log(`⏭  ${slug}: har allerede v${existing.version} — hopper over (bruk --force for ny versjon)`)
      continue
    }

    const version = (existing?.version ?? 0) + 1
    await prisma.questionPack.create({
      data: { mode: slug, version, data: questions as any, isActive: false },
    })

    console.log(`✓  ${slug} v${version}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    total += questions.length
  }

  await prisma.$disconnect()
  console.log(`\nFerdig. ${total} spørsmål lagt inn (inaktive — aktiver i admin-UI).`)
}

async function main() {
  if (CSV_MODE) await runCsvMode()
  else await runDbMode()
}

main().catch(err => { console.error(err); process.exit(1) })
