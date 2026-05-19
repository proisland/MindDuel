/**
 * Seed 20 preset avatars into the database and R2/S3 storage.
 *
 * Usage (from the backend/ directory):
 *   DATABASE_URL="..." S3_ENDPOINT="..." S3_BUCKET="..." \
 *   S3_ACCESS_KEY="..." S3_SECRET_KEY="..." S3_PUBLIC_URL="..." \
 *   npx tsx scripts/seed-avatars.ts
 *
 * Env vars are loaded from .env automatically if present.
 * Existing avatars (matched by labelNo) are skipped.
 */

import { PrismaClient } from '@prisma/client'
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'
import { randomUUID } from 'node:crypto'

// ── Palette (matches app design system) ───────────────────────────────────────
const C = {
  bg:       '#151226',
  accent:   '#6366F1',
  pink:     '#EC4899',
  green:    '#10B981',
  amber:    '#F59E0B',
  red:      '#EF4444',
  // dark bg variants per avatar
  dIndigo:  '#1E1B4B',
  dPink:    '#4A0720',
  dGreen:   '#052E16',
  dAmber:   '#451A03',
  dRed:     '#450A0A',
  dTeal:    '#042F2E',
  dBlue:    '#0C1445',
  dPurple:  '#2E1065',
  dSlate:   '#0F172A',
  dBrown:   '#1C0A00',
  dNavy:    '#0C0A1E',
}

// ── SVG helpers ───────────────────────────────────────────────────────────────
function svg(bg: string, body: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="50" fill="${bg}"/>${body}</svg>`
}

// ── Avatar definitions ────────────────────────────────────────────────────────
interface Avatar { labelNo: string; labelEn: string; svgBody: () => string }

const avatars: Avatar[] = [
  // 1 – Fox
  {
    labelNo: 'Rev', labelEn: 'Fox',
    svgBody: () => svg(C.dAmber, `
      <polygon points="22,44 33,16 44,44" fill="${C.amber}"/>
      <polygon points="56,44 67,16 78,44" fill="${C.amber}"/>
      <polygon points="26,42 33,21 40,42" fill="${C.pink}" opacity="0.7"/>
      <polygon points="60,42 67,21 74,42" fill="${C.pink}" opacity="0.7"/>
      <circle cx="50" cy="57" r="26" fill="${C.amber}"/>
      <ellipse cx="50" cy="65" rx="11" ry="8" fill="#FDE68A"/>
      <ellipse cx="50" cy="61" rx="3.5" ry="2.5" fill="${C.bg}"/>
      <circle cx="40" cy="51" r="4.5" fill="${C.bg}"/>
      <circle cx="60" cy="51" r="4.5" fill="${C.bg}"/>
      <circle cx="41.5" cy="49.5" r="1.5" fill="white"/>
      <circle cx="61.5" cy="49.5" r="1.5" fill="white"/>
    `),
  },
  // 2 – Bear
  {
    labelNo: 'Bjørn', labelEn: 'Bear',
    svgBody: () => svg(C.dBrown, `
      <circle cx="27" cy="29" r="15" fill="#92400E"/>
      <circle cx="73" cy="29" r="15" fill="#92400E"/>
      <circle cx="27" cy="29" r="9" fill="#B45309"/>
      <circle cx="73" cy="29" r="9" fill="#B45309"/>
      <circle cx="50" cy="56" r="29" fill="#92400E"/>
      <ellipse cx="50" cy="65" rx="14" ry="10" fill="#B45309"/>
      <ellipse cx="50" cy="61" rx="5" ry="3.5" fill="${C.bg}"/>
      <circle cx="39" cy="50" r="5" fill="${C.bg}"/>
      <circle cx="61" cy="50" r="5" fill="${C.bg}"/>
      <circle cx="40.5" cy="48.5" r="1.8" fill="white"/>
      <circle cx="62.5" cy="48.5" r="1.8" fill="white"/>
    `),
  },
  // 3 – Wolf
  {
    labelNo: 'Ulv', labelEn: 'Wolf',
    svgBody: () => svg(C.dIndigo, `
      <polygon points="28,46 37,18 46,46" fill="#94A3B8"/>
      <polygon points="54,46 63,18 72,46" fill="#94A3B8"/>
      <polygon points="31,44 37,22 43,44" fill="#CBD5E1" opacity="0.5"/>
      <polygon points="57,44 63,22 69,44" fill="#CBD5E1" opacity="0.5"/>
      <circle cx="50" cy="56" r="27" fill="#94A3B8"/>
      <ellipse cx="50" cy="64" rx="12" ry="9" fill="#CBD5E1"/>
      <ellipse cx="50" cy="60" rx="3" ry="2" fill="${C.bg}"/>
      <circle cx="40" cy="50" r="4.5" fill="${C.accent}"/>
      <circle cx="60" cy="50" r="4.5" fill="${C.accent}"/>
      <circle cx="40" cy="50" r="2" fill="${C.bg}"/>
      <circle cx="60" cy="50" r="2" fill="${C.bg}"/>
    `),
  },
  // 4 – Owl
  {
    labelNo: 'Ugle', labelEn: 'Owl',
    svgBody: () => svg(C.dPurple, `
      <circle cx="34" cy="26" r="13" fill="#78350F"/>
      <circle cx="66" cy="26" r="13" fill="#78350F"/>
      <circle cx="50" cy="55" r="28" fill="#78350F"/>
      <circle cx="39" cy="52" r="12" fill="${C.bg}"/>
      <circle cx="61" cy="52" r="12" fill="${C.bg}"/>
      <circle cx="39" cy="52" r="8" fill="${C.amber}"/>
      <circle cx="61" cy="52" r="8" fill="${C.amber}"/>
      <circle cx="39" cy="52" r="4.5" fill="${C.bg}"/>
      <circle cx="61" cy="52" r="4.5" fill="${C.bg}"/>
      <circle cx="40.5" cy="50.5" r="1.5" fill="white"/>
      <circle cx="62.5" cy="50.5" r="1.5" fill="white"/>
      <polygon points="47,62 53,62 50,68" fill="${C.amber}"/>
    `),
  },
  // 5 – Moose
  {
    labelNo: 'Elg', labelEn: 'Moose',
    svgBody: () => svg(C.dGreen, `
      <path d="M33 38 L27 20 L22 26 L30 36" fill="#92400E" stroke="none"/>
      <path d="M67 38 L73 20 L78 26 L70 36" fill="#92400E" stroke="none"/>
      <path d="M27 20 L24 12 M27 20 L31 13" stroke="#92400E" stroke-width="3" stroke-linecap="round" fill="none"/>
      <path d="M73 20 L70 12 M73 20 L76 13" stroke="#92400E" stroke-width="3" stroke-linecap="round" fill="none"/>
      <circle cx="50" cy="58" r="27" fill="#92400E"/>
      <ellipse cx="50" cy="67" rx="14" ry="9" fill="#B45309"/>
      <ellipse cx="50" cy="63" rx="5" ry="3.5" fill="${C.bg}"/>
      <circle cx="40" cy="51" r="5" fill="${C.bg}"/>
      <circle cx="60" cy="51" r="5" fill="${C.bg}"/>
      <circle cx="41.5" cy="49.5" r="1.8" fill="white"/>
      <circle cx="61.5" cy="49.5" r="1.8" fill="white"/>
    `),
  },
  // 6 – Lion
  {
    labelNo: 'Løve', labelEn: 'Lion',
    svgBody: () => svg(C.dAmber, `
      <circle cx="50" cy="52" r="36" fill="#B45309" opacity="0.8"/>
      <circle cx="50" cy="52" r="26" fill="#F59E0B"/>
      <ellipse cx="50" cy="63" rx="11" ry="8" fill="#FDE68A"/>
      <ellipse cx="50" cy="59" rx="3.5" ry="2.5" fill="${C.bg}"/>
      <circle cx="40" cy="49" r="4.5" fill="${C.bg}"/>
      <circle cx="60" cy="49" r="4.5" fill="${C.bg}"/>
      <circle cx="41.5" cy="47.5" r="1.5" fill="white"/>
      <circle cx="61.5" cy="47.5" r="1.5" fill="white"/>
      <path d="M44 70 Q50 75 56 70" stroke="${C.bg}" stroke-width="1.5" fill="none" stroke-linecap="round"/>
    `),
  },
  // 7 – Penguin
  {
    labelNo: 'Pingvin', labelEn: 'Penguin',
    svgBody: () => svg(C.dSlate, `
      <ellipse cx="50" cy="58" rx="24" ry="28" fill="${C.bg}"/>
      <ellipse cx="50" cy="60" rx="14" ry="20" fill="white" opacity="0.9"/>
      <circle cx="50" cy="35" r="16" fill="${C.bg}"/>
      <circle cx="43" cy="33" r="4.5" fill="white"/>
      <circle cx="57" cy="33" r="4.5" fill="white"/>
      <circle cx="43" cy="33" r="2.5" fill="${C.bg}"/>
      <circle cx="57" cy="33" r="2.5" fill="${C.bg}"/>
      <polygon points="44,42 56,42 50,49" fill="${C.amber}"/>
      <ellipse cx="34" cy="62" rx="6" ry="3" fill="${C.amber}" transform="rotate(-30 34 62)"/>
      <ellipse cx="66" cy="62" rx="6" ry="3" fill="${C.amber}" transform="rotate(30 66 62)"/>
    `),
  },
  // 8 – Panda
  {
    labelNo: 'Panda', labelEn: 'Panda',
    svgBody: () => svg(C.dSlate, `
      <circle cx="29" cy="28" r="13" fill="#1E293B"/>
      <circle cx="71" cy="28" r="13" fill="#1E293B"/>
      <circle cx="50" cy="55" r="29" fill="#E2E8F0"/>
      <ellipse cx="37" cy="50" rx="10" ry="11" fill="#1E293B"/>
      <ellipse cx="63" cy="50" rx="10" ry="11" fill="#1E293B"/>
      <circle cx="37" cy="50" r="5" fill="white"/>
      <circle cx="63" cy="50" r="5" fill="white"/>
      <circle cx="37" cy="50" r="3" fill="${C.bg}"/>
      <circle cx="63" cy="50" r="3" fill="${C.bg}"/>
      <circle cx="38" cy="49" r="1" fill="white"/>
      <circle cx="64" cy="49" r="1" fill="white"/>
      <ellipse cx="50" cy="64" rx="6" ry="4" fill="#CBD5E1"/>
      <ellipse cx="50" cy="62" rx="3" ry="2" fill="${C.bg}"/>
    `),
  },
  // 9 – Robot
  {
    labelNo: 'Robot', labelEn: 'Robot',
    svgBody: () => svg(C.dIndigo, `
      <line x1="50" y1="8" x2="50" y2="18" stroke="${C.accent}" stroke-width="3" stroke-linecap="round"/>
      <circle cx="50" cy="6" r="4" fill="${C.green}"/>
      <rect x="24" y="18" width="52" height="46" rx="8" fill="#334155"/>
      <rect x="30" y="25" width="16" height="14" rx="4" fill="${C.accent}" opacity="0.9"/>
      <rect x="54" y="25" width="16" height="14" rx="4" fill="${C.accent}" opacity="0.9"/>
      <circle cx="38" cy="32" r="5" fill="${C.bg}"/>
      <circle cx="62" cy="32" r="5" fill="${C.bg}"/>
      <circle cx="39" cy="31" r="2" fill="white"/>
      <circle cx="63" cy="31" r="2" fill="white"/>
      <rect x="34" y="46" width="32" height="6" rx="3" fill="${C.green}" opacity="0.8"/>
      <rect x="30" y="64" width="40" height="20" rx="6" fill="#334155"/>
      <rect x="37" y="70" width="26" height="8" rx="3" fill="${C.accent}" opacity="0.5"/>
    `),
  },
  // 10 – Astronaut
  {
    labelNo: 'Astronaut', labelEn: 'Astronaut',
    svgBody: () => svg(C.dBlue, `
      <circle cx="50" cy="46" r="30" fill="#475569"/>
      <circle cx="50" cy="46" r="24" fill="#0F172A"/>
      <ellipse cx="50" cy="44" rx="17" ry="15" fill="#1E3A5F" opacity="0.9"/>
      <circle cx="43" cy="42" r="3.5" fill="${C.accent}" opacity="0.7"/>
      <circle cx="56" cy="41" r="3.5" fill="${C.green}" opacity="0.7"/>
      <ellipse cx="50" cy="50" rx="7" ry="5" fill="white" opacity="0.15"/>
      <ellipse cx="50" cy="76" rx="22" ry="10" fill="#334155"/>
      <rect x="38" y="65" width="24" height="14" rx="4" fill="#475569"/>
      <circle cx="30" cy="46" r="5" fill="#64748B"/>
      <circle cx="70" cy="46" r="5" fill="#64748B"/>
      <rect x="23" y="40" width="6" height="12" rx="3" fill="#64748B"/>
      <rect x="71" y="40" width="6" height="12" rx="3" fill="#64748B"/>
    `),
  },
  // 11 – Ninja
  {
    labelNo: 'Ninja', labelEn: 'Ninja',
    svgBody: () => svg(C.dRed, `
      <circle cx="50" cy="50" r="30" fill="#1E293B"/>
      <rect x="20" y="43" width="60" height="14" rx="3" fill="${C.red}" opacity="0.9"/>
      <circle cx="40" cy="49" r="5" fill="white"/>
      <circle cx="60" cy="49" r="5" fill="white"/>
      <circle cx="40" cy="49" r="2.8" fill="${C.bg}"/>
      <circle cx="60" cy="49" r="2.8" fill="${C.bg}"/>
      <circle cx="41" cy="48" r="1" fill="white"/>
      <circle cx="61" cy="48" r="1" fill="white"/>
      <path d="M20 43 Q50 38 80 43" stroke="${C.red}" stroke-width="2" fill="none"/>
      <rect x="22" y="56" width="56" height="10" rx="3" fill="${C.red}" opacity="0.5"/>
    `),
  },
  // 12 – Viking
  {
    labelNo: 'Viking', labelEn: 'Viking',
    svgBody: () => svg(C.dAmber, `
      <rect x="28" y="26" width="44" height="30" rx="10" fill="#94A3B8"/>
      <path d="M18 38 Q14 50 18 58" stroke="#94A3B8" stroke-width="6" stroke-linecap="round" fill="none"/>
      <path d="M82 38 Q86 50 82 58" stroke="#94A3B8" stroke-width="6" stroke-linecap="round" fill="none"/>
      <path d="M14 58 Q16 66 22 64" stroke="#F59E0B" stroke-width="4" stroke-linecap="round" fill="none"/>
      <path d="M86 58 Q84 66 78 64" stroke="#F59E0B" stroke-width="4" stroke-linecap="round" fill="none"/>
      <circle cx="50" cy="60" r="25" fill="#F5CBA7"/>
      <rect x="30" y="40" width="40" height="18" rx="3" fill="#64748B"/>
      <ellipse cx="50" cy="69" rx="12" ry="8" fill="#F5CBA7"/>
      <ellipse cx="50" cy="65" rx="3.5" ry="2.5" fill="#A0522D"/>
      <circle cx="40" cy="57" r="4.5" fill="${C.bg}"/>
      <circle cx="60" cy="57" r="4.5" fill="${C.bg}"/>
      <circle cx="41.5" cy="55.5" r="1.5" fill="white"/>
      <circle cx="61.5" cy="55.5" r="1.5" fill="white"/>
    `),
  },
  // 13 – Octopus
  {
    labelNo: 'Blekksprut', labelEn: 'Octopus',
    svgBody: () => svg(C.dPink, `
      <path d="M28 65 Q22 80 26 88" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" fill="none"/>
      <path d="M38 70 Q34 84 38 92" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" fill="none"/>
      <path d="M62 70 Q66 84 62 92" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" fill="none"/>
      <path d="M72 65 Q78 80 74 88" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" fill="none"/>
      <path d="M50 68 Q52 84 50 92" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" fill="none"/>
      <circle cx="50" cy="46" r="30" fill="${C.pink}"/>
      <circle cx="38" cy="43" r="8" fill="white"/>
      <circle cx="62" cy="43" r="8" fill="white"/>
      <circle cx="38" cy="43" r="4.5" fill="${C.bg}"/>
      <circle cx="62" cy="43" r="4.5" fill="${C.bg}"/>
      <circle cx="39.5" cy="41.5" r="1.5" fill="white"/>
      <circle cx="63.5" cy="41.5" r="1.5" fill="white"/>
      <path d="M42 57 Q50 63 58 57" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.7"/>
    `),
  },
  // 14 – Dragon
  {
    labelNo: 'Drage', labelEn: 'Dragon',
    svgBody: () => svg(C.dGreen, `
      <polygon points="70,20 82,12 78,28" fill="${C.green}"/>
      <polygon points="30,20 18,12 22,28" fill="${C.green}"/>
      <circle cx="50" cy="54" r="28" fill="${C.green}"/>
      <ellipse cx="50" cy="65" rx="16" ry="10" fill="#059669"/>
      <polygon points="38,26 44,14 50,26" fill="${C.green}"/>
      <polygon points="50,26 56,14 62,26" fill="${C.green}"/>
      <ellipse cx="50" cy="61" rx="4" ry="3" fill="${C.bg}"/>
      <circle cx="39" cy="47" r="6" fill="${C.amber}"/>
      <circle cx="61" cy="47" r="6" fill="${C.amber}"/>
      <circle cx="39" cy="47" r="3" fill="${C.bg}"/>
      <circle cx="61" cy="47" r="3" fill="${C.bg}"/>
      <circle cx="40" cy="46" r="1" fill="white"/>
      <circle cx="62" cy="46" r="1" fill="white"/>
    `),
  },
  // 15 – Cat
  {
    labelNo: 'Katt', labelEn: 'Cat',
    svgBody: () => svg(C.dPink, `
      <polygon points="22,46 32,22 42,46" fill="${C.pink}"/>
      <polygon points="58,46 68,22 78,46" fill="${C.pink}"/>
      <polygon points="25,44 32,25 39,44" fill="#FDE68A" opacity="0.6"/>
      <polygon points="61,44 68,25 75,44" fill="#FDE68A" opacity="0.6"/>
      <circle cx="50" cy="57" r="27" fill="${C.pink}"/>
      <ellipse cx="50" cy="66" rx="10" ry="7" fill="#FDE68A" opacity="0.7"/>
      <ellipse cx="50" cy="63" rx="3" ry="2" fill="#A21CAF"/>
      <circle cx="39" cy="51" r="5" fill="${C.bg}"/>
      <circle cx="61" cy="51" r="5" fill="${C.bg}"/>
      <circle cx="39" cy="51" r="2.5" fill="${C.accent}"/>
      <circle cx="61" cy="51" r="2.5" fill="${C.accent}"/>
      <line x1="34" y1="61" x2="20" y2="58" stroke="#FDE68A" stroke-width="1.5" opacity="0.7"/>
      <line x1="34" y1="63" x2="20" y2="63" stroke="#FDE68A" stroke-width="1.5" opacity="0.7"/>
      <line x1="66" y1="61" x2="80" y2="58" stroke="#FDE68A" stroke-width="1.5" opacity="0.7"/>
      <line x1="66" y1="63" x2="80" y2="63" stroke="#FDE68A" stroke-width="1.5" opacity="0.7"/>
    `),
  },
  // 16 – Dog
  {
    labelNo: 'Hund', labelEn: 'Dog',
    svgBody: () => svg(C.dBrown, `
      <ellipse cx="25" cy="55" rx="11" ry="16" fill="#B45309" transform="rotate(-15 25 55)"/>
      <ellipse cx="75" cy="55" rx="11" ry="16" fill="#B45309" transform="rotate(15 75 55)"/>
      <circle cx="50" cy="52" r="28" fill="#B45309"/>
      <ellipse cx="50" cy="63" rx="13" ry="9" fill="#FDE68A"/>
      <ellipse cx="50" cy="58" rx="4" ry="3" fill="#7C2D12"/>
      <path d="M44 68 Q50 74 56 68" stroke="${C.red}" stroke-width="3" fill="none" stroke-linecap="round"/>
      <ellipse cx="52" cy="72" rx="6" ry="4" fill="${C.red}" opacity="0.8"/>
      <circle cx="39" cy="46" r="5" fill="${C.bg}"/>
      <circle cx="61" cy="46" r="5" fill="${C.bg}"/>
      <circle cx="40.5" cy="44.5" r="1.8" fill="white"/>
      <circle cx="62.5" cy="44.5" r="1.8" fill="white"/>
    `),
  },
  // 17 – Shark
  {
    labelNo: 'Hai', labelEn: 'Shark',
    svgBody: () => svg(C.dBlue, `
      <polygon points="50,8 44,28 56,28" fill="#94A3B8"/>
      <circle cx="50" cy="58" r="30" fill="#94A3B8"/>
      <ellipse cx="50" cy="72" rx="24" ry="10" fill="#CBD5E1"/>
      <path d="M34 68 L38 76 L42 68 L46 76 L50 68 L54 76 L58 68 L62 76 L66 68" stroke="${C.bg}" stroke-width="1.5" fill="none"/>
      <circle cx="38" cy="52" r="6" fill="white"/>
      <circle cx="62" cy="52" r="6" fill="white"/>
      <circle cx="38" cy="52" r="3.5" fill="${C.bg}"/>
      <circle cx="62" cy="52" r="3.5" fill="${C.bg}"/>
      <circle cx="39" cy="51" r="1.2" fill="white"/>
      <circle cx="63" cy="51" r="1.2" fill="white"/>
      <ellipse cx="50" cy="62" rx="4" ry="2.5" fill="#64748B"/>
    `),
  },
  // 18 – Frog
  {
    labelNo: 'Frosk', labelEn: 'Frog',
    svgBody: () => svg(C.dGreen, `
      <circle cx="32" cy="28" r="14" fill="${C.green}"/>
      <circle cx="68" cy="28" r="14" fill="${C.green}"/>
      <circle cx="32" cy="26" r="9" fill="white"/>
      <circle cx="68" cy="26" r="9" fill="white"/>
      <circle cx="32" cy="26" r="5.5" fill="${C.bg}"/>
      <circle cx="68" cy="26" r="5.5" fill="${C.bg}"/>
      <circle cx="33.5" cy="24.5" r="1.8" fill="white"/>
      <circle cx="69.5" cy="24.5" r="1.8" fill="white"/>
      <circle cx="50" cy="58" r="28" fill="${C.green}"/>
      <ellipse cx="50" cy="67" rx="16" ry="9" fill="#059669"/>
      <path d="M35 67 Q50 76 65 67" stroke="white" stroke-width="2.5" fill="none" stroke-linecap="round" opacity="0.8"/>
      <circle cx="44" cy="52" r="3" fill="${C.bg}" opacity="0.4"/>
      <circle cx="56" cy="52" r="3" fill="${C.bg}" opacity="0.4"/>
    `),
  },
  // 19 – Superhero
  {
    labelNo: 'Superhelt', labelEn: 'Superhero',
    svgBody: () => svg(C.dIndigo, `
      <path d="M50 68 Q72 60 82 80 Q70 90 50 95 Q30 90 18 80 Q28 60 50 68Z" fill="${C.red}"/>
      <circle cx="50" cy="42" r="22" fill="#F5CBA7"/>
      <rect x="28" y="30" width="44" height="20" rx="6" fill="${C.accent}" opacity="0.9"/>
      <ellipse cx="38" cy="38" rx="6" ry="5" fill="white" opacity="0.2"/>
      <ellipse cx="62" cy="38" rx="6" ry="5" fill="white" opacity="0.2"/>
      <circle cx="39" cy="42" r="4.5" fill="${C.bg}"/>
      <circle cx="61" cy="42" r="4.5" fill="${C.bg}"/>
      <circle cx="40.5" cy="40.5" r="1.5" fill="white"/>
      <circle cx="62.5" cy="40.5" r="1.5" fill="white"/>
      <polygon points="47,74 50,68 53,74 50,72" fill="#FDE68A" opacity="0.9"/>
    `),
  },
  // 20 – Seahorse
  {
    labelNo: 'Sjøhest', labelEn: 'Seahorse',
    svgBody: () => svg(C.dTeal, `
      <circle cx="50" cy="22" r="14" fill="${C.accent}"/>
      <polygon points="38,14 50,5 50,14" fill="${C.accent}" opacity="0.7"/>
      <path d="M50 36 Q62 42 62 52 Q62 62 55 66 Q62 70 60 80 Q58 90 50 90 Q42 88 42 80 Q40 72 48 70 Q40 66 40 54 Q40 42 50 36Z" fill="${C.accent}"/>
      <circle cx="44" cy="20" r="4" fill="white"/>
      <circle cx="44" cy="20" r="2.2" fill="${C.bg}"/>
      <circle cx="44.8" cy="19.2" r="0.8" fill="white"/>
      <path d="M62 52 Q72 48 74 54 Q72 60 62 58" fill="${C.green}" opacity="0.7"/>
      <path d="M60 44 Q68 40 70 46 Q68 52 60 50" fill="${C.green}" opacity="0.5"/>
      <path d="M55 36 Q60 30 64 34 Q62 40 56 40" fill="${C.green}" opacity="0.4"/>
    `),
  },
]

// ── S3 + Prisma setup ─────────────────────────────────────────────────────────
const s3 = new S3Client({
  endpoint:         process.env.S3_ENDPOINT!,
  region:           process.env.S3_REGION ?? 'auto',
  forcePathStyle:   process.env.S3_FORCE_PATH_STYLE !== 'false',
  credentials: {
    accessKeyId:     process.env.S3_ACCESS_KEY!,
    secretAccessKey: process.env.S3_SECRET_KEY!,
  },
})

const prisma = new PrismaClient({
  datasources: { db: { url: process.env.DATABASE_URL! } },
})

const bucket    = process.env.S3_BUCKET!
const publicUrl = process.env.S3_PUBLIC_URL ?? `${process.env.S3_ENDPOINT}/${bucket}`

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const missing = ['S3_ENDPOINT','S3_BUCKET','S3_ACCESS_KEY','S3_SECRET_KEY','DATABASE_URL']
    .filter(k => !process.env[k])
  if (missing.length) {
    console.error('Missing env vars:', missing.join(', '))
    process.exit(1)
  }

  // Use raw SQL — the generated Prisma client is stale and lacks presetAvatar
  const existing = await prisma.$queryRawUnsafe<Array<{ labelNo: string }>>(
    `SELECT "labelNo" FROM "PresetAvatar"`
  )
  const existingLabels = new Set(existing.map(r => r.labelNo))

  const lastRow = await prisma.$queryRawUnsafe<Array<{ sortOrder: number }>>(
    `SELECT "sortOrder" FROM "PresetAvatar" ORDER BY "sortOrder" DESC LIMIT 1`
  )
  let sortOrder = (lastRow[0]?.sortOrder ?? -1) + 1

  for (const av of avatars) {
    if (existingLabels.has(av.labelNo)) {
      console.log(`  skip  ${av.labelNo} (already exists)`)
      continue
    }

    const svgBuf = Buffer.from(av.svgBody(), 'utf-8')
    const key    = `preset-avatars/${randomUUID()}.svg`
    const url    = `${publicUrl}/${key}`

    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: svgBuf,
      ContentType: 'image/svg+xml',
    }))

    await prisma.$executeRawUnsafe(
      `INSERT INTO "PresetAvatar" (id, url, "labelNo", "labelEn", "isActive", "sortOrder", "createdAt", "updatedAt")
       VALUES ($1, $2, $3, $4, true, $5, NOW(), NOW())`,
      randomUUID(), url, av.labelNo, av.labelEn, sortOrder
    )

    sortOrder++
    console.log(`  added ${av.labelNo} / ${av.labelEn} → ${key}`)
  }

  console.log('\nDone.')
}

main().catch(e => { console.error(e); process.exit(1) }).finally(() => prisma.$disconnect())
