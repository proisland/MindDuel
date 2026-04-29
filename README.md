# MindDuel

Sosialt hjernetrim for iPhone – to spillmodi (Pi-gjetting og Regnestykker), solo og sanntids flerspiller, med kontinuerlig progresjon og scoreboard.

## Dokumentasjon

All produkt- og designdokumentasjon ligger i [`docs/`](docs/):

- [`docs/prd.md`](docs/prd.md) – Product Requirements Document (v0.1)
- [`docs/Design.md`](docs/Design.md) – Designsystem og skjermspesifikasjon (v1.0)
- [`docs/milestones.md`](docs/milestones.md) – Utviklingsplan, M1–M8

Disse er kilden til sannhet. README og [`CLAUDE.md`](CLAUDE.md) skal ikke duplisere innhold derfra – lenk i stedet.

## Teknisk stack

Definert i `docs/prd.md` §11:

| Område | Valg |
|---|---|
| Plattform | iOS 16+ |
| Språk / UI | Swift, SwiftUI |
| Avhengigheter | Swift Package Manager |
| Auth | Sign in with Apple (AuthenticationServices) |
| Betaling | StoreKit 2 |
| Backend | REST API + WebSocket (sanntids flerspiller), EU-region |
| Lokalisering | String Catalogs, norsk + engelsk fra dag én |

iOS-klient og backend ligger i samme repo. Konkret prosjektstruktur etableres i M1.

## Utvikling per milepæl

Vi jobber milepæl for milepæl etter `docs/milestones.md`. Hver milepæl er en sammenhengende leveranse med egne leveransekrav (avkrysningsbokser nederst i hvert M-avsnitt).

### Anbefalt branch-strategi

**Ja, én branch per milepæl.** Det gir en tydelig PR per leveranse, gjør review håndterbar, og lar `main` alltid reflektere siste fullførte milepæl.

Navngivning: `milestone/m<nr>-<kortnavn>` (kebab-case, ASCII, basert på milepælnavnet i `milestones.md`):

| Milepæl | Branch |
|---|---|
| M1 – Fundament | `milestone/m1-fundament` |
| M2 – Spillbar prototype | `milestone/m2-prototype` |
| M3 – Progresjon og score | `milestone/m3-progresjon` |
| M4 – Sosialt lag | `milestone/m4-sosialt` |
| M5 – Flerspiller | `milestone/m5-flerspiller` |
| M6 – Betaling og abonnement | `milestone/m6-betaling` |
| M7 – Polering | `milestone/m7-polering` |
| M8 – App Store-klargjøring | `milestone/m8-appstore` |

Større delleveranser innenfor én milepæl kan få egne `feature/m<nr>-<tema>`-brancher som merges inn i milepælsbranchen før den selv merges til `main`.

### Arbeidsflyt

1. Branch ut fra siste `main`: `git switch -c milestone/m1-fundament origin/main`
2. Implementer mot leveransekravene i milepælens seksjon i `docs/milestones.md`.
3. Hak av `[ ]` → `[x]` etter hvert som krav er oppfylt (samme PR).
4. Åpne PR mot `main` så snart noe er review-klart (gjerne som draft tidlig).
5. Når alle leveransekrav er huket av og PR er godkjent: squash/merge til `main`, tag som `m1`, `m2`, …

### Definition of Done per milepæl

- Alle leveransekrav i milepælen er huket av i `docs/milestones.md`.
- Appen bygger og kjører på fysisk enhet (fra og med M1).
- Ingen åpne `// TODO`/placeholder for funksjonalitet i milepælens scope.
- Endringer som påvirker arkitektur, tooling eller kommandoer er reflektert i `CLAUDE.md`.

## Kom i gang

iOS-prosjektet er ikke opprettet ennå – det skjer som første steg i **M1 – Fundament** (`docs/milestones.md`). Når Xcode-prosjektet er på plass, oppdateres denne seksjonen med konkrete kommandoer for bygg, test og kjøring.
