# MindDuel

Sosialt hjernetrim for iPhone – 10 spillmodi (Pi, Regning, Kjemi, Geografi, Hjernetrim, Naturvitenskap, Historie, Fysikk, Sport og Grammatikk), solo og sanntids flerspiller, med kontinuerlig progresjon og scoreboard.

## Status

| Milepæl | Innhold | Status |
|---|---|---|
| M1 – Fundament | Prosjektoppsett, auth, designsystem | ✅ Ferdig |
| M2 – Spillbar prototype | Core game loop, begge modi | ✅ Ferdig |
| M3 – Progresjon og score | Scorelogikk, dagkvote, kontinuerlig progresjon | ✅ Ferdig |
| M4 – Sosialt lag | Venner, scoreboard, profiler | ✅ Ferdig |
| M5 – Flerspiller | Sanntids gruppespill, alle 10 modi | ✅ Ferdig |
| M6 – Cloud Backend | Sentral datalagring, admin-grensesnitt, telemetri, spørsmålsbank, bildehosting | 🔜 Neste |
| M7 – Betaling og abonnement | StoreKit 2, gratis/betalt-modell | ⏳ Planlagt |
| M8 – Polering | Animasjoner, haptics, onboarding, treningsrunde | ⏳ Planlagt |
| M9 – App Store-klargjøring | Metadata, skjermbilder, TestFlight, innlevering | ⏳ Planlagt |

## Dokumentasjon

All produkt- og designdokumentasjon ligger i [`docs/`](docs/):

- [`docs/prd.md`](docs/prd.md) – Product Requirements Document
- [`docs/Design.md`](docs/Design.md) – Designsystem og skjermspesifikasjon
- [`docs/milestones.md`](docs/milestones.md) – Utviklingsplan, M1–M9

Disse er kilden til sannhet. README og [`CLAUDE.md`](CLAUDE.md) skal ikke duplisere innhold derfra – lenk i stedet.

## Teknisk stack

Definert i `docs/prd.md` §11:

| Område | Valg |
|---|---|
| Plattform | iOS 16+ |
| Språk / UI | Swift, SwiftUI |
| Avhengigheter | Swift Package Manager |
| Auth | Sign in with Apple (AuthenticationServices) |
| Betaling | StoreKit 2 (M7) |
| Backend | REST API + WebSocket, EU-region (M6) |
| Lokalisering | String Catalogs, norsk + engelsk |

## Utvikling per milepæl

Vi jobber milepæl for milepæl etter `docs/milestones.md`. Hver milepæl er en sammenhengende leveranse med egne leveransekrav (avkrysningsbokser nederst i hvert M-avsnitt).

### Branch-strategi

Én branch per milepæl: `milestone/m<nr>-<kortnavn>`. Større delleveranser innenfor en milepæl kan få egne `feature/m<nr>-<tema>`-brancher som merges inn i milepælsbranchen.

### Arbeidsflyt

1. Branch ut fra siste `main`: `git switch -c milestone/m<nr>-<navn> origin/main`
2. Implementer mot leveransekravene i `docs/milestones.md`.
3. Hak av `[ ]` → `[x]` etter hvert som krav er oppfylt (samme PR).
4. Åpne PR mot `main` så snart noe er review-klart (gjerne som draft tidlig).
5. Squash/merge til `main`, tag som `m1`, `m2`, … når ferdig.

### Definition of Done per milepæl

- Alle leveransekrav i milepælen er huket av i `docs/milestones.md`.
- Appen bygger og kjører på fysisk enhet.
- Ingen åpne `// TODO`/placeholder for funksjonalitet i milepælens scope.
- Endringer som påvirker arkitektur, tooling eller kommandoer er reflektert i `CLAUDE.md`.

## Kom i gang

```bash
make setup    # brew install xcodegen && xcodegen generate (kjøres én gang)
make build    # Debug-bygg mot iPhone 16-simulator
make test     # Enhets- og UI-tester
```

Se `CLAUDE.md` for full kommandoreferanse og prosjektstruktur.
