# Design Document
## MindDuel – Sosialt hjernetrim for iPhone

**Versjon:** 1.0
**Dato:** 2026-04-29
**Status:** Klar for utvikling
**Basert på PRD:** v0.1

---

## 1. Designprinsipper

MindDuels visuelle design bygger på fem kjerneverdier:

- **Minimalistisk og mørkt** – Mørk lilla bakgrunn som primærflate, inspirert av Apples spilldesign. Ren komposisjon uten visuell støy.
- **Ikonbasert** – Egendefinerte SVG-ikoner i konsistent linjær stil (2px stroke). Emojis brukes ikke i UI-elementer.
- **Fokus** – Aldri mer enn én primærhandling synlig om gangen under spilling.
- **Transparent tilstand** – Liv og hopp alltid synlig som piller; treningsrunder alltid tydelig merket.
- **Universelt vennlig** – Lesbart og forståelig for både barn og voksne. Minimum tekststørrelse 9 pt, viktig informasjon ≥ 11 pt.

---

## 2. Visuelt designsystem

### 2.1 Fargepalett

Mørk modus er primærtilstanden. Lys modus støttes via systeminnstilling, men dokumenteres separat ved behov.

#### Bakgrunner og overflater

| Token | Verdi | Bruk |
|---|---|---|
| `bg` | `#0D0B18` | Sidebakgrunn |
| `bg-deep` | `#080612` | Notch, segmentert kontroll-bakgrunn |
| `surface` | `#161230` | Primærkort, fremhevede beholdere |
| `surface-2` | `#1C1836` | Sekundærkort, listeelementer, ikon-bokser |
| `border` | `#2A2050` | Telefonramme |
| `border-2` | `#2E2860` | Kort- og divider-kant |

#### Tekst

| Token | Verdi | Bruk |
|---|---|---|
| `text` | `#FFFFFF` | Overskrifter, primærtekst |
| `text-2` | `#B8B0E0` | Sekundærtekst, knapper på mørk bakgrunn |
| `text-3` | `#6B6294` | Metadata, labels, "siden"-stempel |
| `text-4` | `#3F3870` | Tertiærtekst, statusbar |

#### Aksent og semantiske farger

| Token | Verdi | Bruk |
|---|---|---|
| `accent` | `#6366F1` | Primærfarge (indigo), lenker, Pi-modus identitet |
| `accent-deep` | `#4F46E5` | Primærknapper, ikon-bakgrunn, brukerens avatar |
| `accent-soft` | `#2D2A6E` | Fremhevede rader (du i scoreboard), pille-bakgrunn |
| `pink` | `#EC4899` | Regning-modus identitet |
| `pink-deep` | `#BE185D` | Regning ikon-bakgrunn |
| `pink-soft` | `#4A1D3F` | Regning pille-bakgrunn |
| `green` | `#10B981` | Riktig svar, "Klar"-status, online-prikk |
| `green-soft` | `#064E3B` | Riktig-svar-bakgrunn |
| `amber` | `#F59E0B` | Førsteplass, trofé, score-fremheving |
| `amber-soft` | `#451A03` | Førsteplass-rad-bakgrunn |
| `red` | `#EF4444` | Liv (hjerte), feil svar, fareindikator |
| `red-soft` | `#3A1A1A` | Feil-svar-bakgrunn, destruktive knapper |

> **Kontrastmål:** Alle tekst/bakgrunn-kombinasjoner oppfyller WCAG AA (≥ 4.5:1 for liten tekst, ≥ 3:1 for stor tekst).

### 2.2 Typografi

San Francisco (SF Pro) brukes for alle tekstlag.

| Stil | Størrelse | Vekt | Bruk |
|---|---|---|---|
| Display | 30 pt | 800 (Heavy) | Score på rundeslutt, store tall |
| Title | 20 pt | 800 | Hjemskjerm-velkomst |
| Heading | 17 pt | 800 | Skjermoverskrifter, modale titler |
| Title-2 | 15 pt | 800 | Profilnavn, kortoverskrifter |
| Subtitle | 14 pt | 700 | Topbar-titler |
| Body | 13 pt | 700 | Modusnavn, viktige stats |
| Body-md | 12 pt | 700 | Knapper, scoreboard-rader |
| Body-sm | 11 pt | 600 | Listeelementer, statistikk |
| Caption | 10 pt | 600 | Metadata, undertekster, "Hopp over" |
| Caption-sm | 9 pt | 700 | Section labels (med letter-spacing 0.1em) |

Dynamic Type støttes for tilgjengelighet. Minimum tap-target: 44×44 pt (Apple HIG).

### 2.3 Ikoner

Egendefinert SVG-ikonsett i lineær stil. Alle ikoner har 2px stroke og runde linjeender for et vennlig uttrykk. Ikoner brukt:

- `back` – tilbake-pil
- `cog` – innstillinger
- `heart` – liv (fylt rød)
- `skip` – hopp (dobbel-pil høyre)
- `clock` – timer
- `bell`, `moon`, `globe` – innstillinger
- `doc`, `trash` – personvern
- `trophy` – rundeslutt, posisjon
- `swords` – flerspiller/gruppespill
- `users`, `user`, `plus` – sosial
- `flag` – flagging av suspisøs aktivitet
- `check` – validering, riktig svar, klar-status
- `warn` – advarselsmodal
- `chevron` – navigasjonspil

### 2.4 Spacing

8 pt grid med følgende tokens:

| Token | Verdi |
|---|---|
| `xs` | 4 pt |
| `sm` | 8 pt |
| `md` | 14 pt |
| `lg` | 18 pt |
| `xl` | 24 pt |

Standard horisontal padding på skjerm: 14 pt.

### 2.5 Corner radius

| Komponent | Radius |
|---|---|
| Telefonramme | 38 pt |
| Primærkort | 16 pt |
| Sekundærkort | 14 pt |
| Innstillings-ikonboks | 7 pt |
| Knapper | 100 pt (full pill) |
| Sifferknapper (Pi) | 50% (sirkel) |
| Svarknapper (Regning) | 14 pt |
| Pille-tags | 100 pt |

### 2.6 Skygger

Bruker ikke skygger i mørk modus. Bruker i stedet `border-2` (0.5 pt) for å definere kortgrenser og dybde.

---

## 3. Komponentbibliotek

### 3.1 Topbar

Fast struktur på tvers av alle skjermer:

```
[venstre 28×28] [sentrert tittel] [høyre 28×28]
```

- Venstre: tilbake-knapp (`back`-ikon i sirkel) eller tom 28 pt spacer
- Sentrert: skjermtittel i Subtitle-stil
- Høyre: handlingsknapp (avatar / cog / pille / etc.) eller tom 28 pt spacer

Tomme spacers brukes for å sikre at tittelen alltid er sentrert. Ingen skjerm har skjev topbar.

### 3.2 Knapper

| Type | Bakgrunn | Tekst | Bruk |
|---|---|---|---|
| Primary | `accent-deep` | hvit | Hovedhandling |
| Ghost | `surface-2` med kant | `text-2` | Sekundærhandling |
| Danger | `red-soft` med rød kant | `red` | Destruktive handlinger (logg ut, forlat spill) |
| Disabled | `surface-2` | `text-4` | Inaktiv tilstand |

Alle knapper har radius 100 pt (full pill), padding 11 pt vertikalt, font 12 pt 700.

### 3.3 Kort

To nivåer av kort:

- **Primærkort (`surface`):** Hovedinnhold som spilldisplay, moduskort, gruppespill-kort. Radius 16, kant 0.5 pt `border-2`.
- **Sekundærkort (`surface-2`):** Statistikk, innstillingsrader, små stat-bokser. Radius 14, kant 0.5 pt `border-2`.

### 3.4 Avataravatarer

Tre størrelser brukt konsistent:

| Klasse | Størrelse | Font | Bruk |
|---|---|---|---|
| `av-sm` | 26×26 pt | 9 pt 700 | Listerader, scoreboard, aktivitetsfeed |
| `av-md` | 32×32 pt | 11 pt 700 | Spillerrekkefølge i gruppespill |
| `av-lg` | 56×56 pt | 22 pt 700 | Profilskjermer |

Brukerens egen avatar er alltid `accent-deep` med `accent`-kant. Andre brukere får tilfeldig farge (indigo/lilla/grønn/rød) basert på initial.

### 3.5 Pill-tags

Status-piller med konsistent padding (3 pt vertikalt, 9 pt horisontalt), font 9 pt 700:

- `pill-green` – Klar, fullført
- `pill-amber` – Venter, midlertidig status
- `pill-red` – Fare, suspendert
- `pill-accent` – Nøytral indigo

### 3.6 Moduskort (ikon-fokusert)

Moduskortet er det visuelle ankerelementet for de to spillmodusene (Pi og Regning). Det brukes på hjemskjerm og profilskjermer.

**Layout:** Sentrert vertikal stabling for å fungere likt for korte og lange modusnavn, og for å gi et ikon-fokusert, leketøyaktig uttrykk som passer for både barn og voksne.

```
┌──────────────────────┐
│         ┌──┐         │  ← 44pt sirkulært ikon
│         │π │         │     med modusens identitetsfarge
│         └──┘         │
│      Pi-modus        │  ← 12pt 800
│      2 847p          │  ← 14pt 800, modusfarge
│  [██████░░░]  12     │  ← Progress bar + nivå-tall
│   Nivå 12 av 20      │  ← 9pt, text-3
└──────────────────────┘
```

**Spesifikasjoner:**

| Element | Verdi |
|---|---|
| Padding | 14 pt vertikal × 11 pt horisontal |
| Gap mellom elementer | 7 pt |
| Ikon | 44×44 pt sirkel, font 22 pt 800, hvit farge |
| Ikon-bakgrunn | `accent-deep` (Pi) eller `pink-deep` (Regning) |
| Modusnavn | 12 pt 800, hvit |
| Score | 14 pt 800, modusfarge (`accent` eller `pink`) |
| Progress bar | 4 pt høy, full pill-radius, fyll matcher modusfarge |
| Nivå-tall | 10 pt 700, modusfarge |
| Undertekst | 9 pt regular, `text-3` |

**Kompakt variant (profilskjermer):** Samme layout med litt mindre ikon (38×38) og 11 pt padding. Brukes når moduskortet er sekundært til andre profilelementer.

> **Designvalg:** Vi prøvde først en horisontal layout med navn øverst og tall til høyre, men "Regning" var for langt og brakk kortbalansen. Den vertikale ikon-fokuserte layouten gjør plass til alle navn uten linjebryting og gir et hyggeligere, mer leketøyaktig uttrykk.

### 3.7 Resource-pill (Liv og hopp)

Fast plassering øverst på spillskjerm. Hjerte (rødt) til venstre, hopp (indigo) til høyre. Hver pille viser ikon + antall i tekst. Bakgrunn `surface-2`, radius 100 pt, padding 6 pt vertikalt × 12 pt horisontalt, font 13 pt 700.

### 3.8 Skip-button

Stor sirkulær knapp, 44×44 pt, plassert sentrert nederst på spillskjerm. `surface-2` bakgrunn, 1.5 pt indigo kant. Skip-ikon i `text-2` farge, 16×16 pt. Timer (med klokke-ikon) er stablet under knappen, 11 pt 600.

### 3.9 Sifferknapp og svarknapp

- **Pi-modus:** 5×2 grid med sirkulære sifferknapper (aspect-ratio 1:1, radius 50%). Tall 0–9 i font 14 pt 700.
- **Regning:** 2×2 grid med rektangulære knapper (radius 14 pt). Tall i font 15 pt 700.

Tilstander:
- Standard: `surface-2` bakgrunn, `border-2` kant, hvit tekst
- Riktig (kort animasjon): grønn fyll, grønn kant, grønn tekst
- Feil (kort animasjon): rød fyll, rød kant, rød tekst

### 3.10 Innstillings-rad

Standard listerad i innstillinger:

```
[ikon-boks 24×24 (avrundet 7pt)] [label] [verdi/toggle/chevron]
```

Ikon-boksen har `accent-soft` bakgrunn med `accent`-fargede ikoner. Destruktive handlinger bruker `red-soft` med `red`-ikon.

---

## 4. Skjermflyt og navigasjon

```
Innlogging
    └── Velg brukernavn
        └── Onboarding (4 skjermbilder, kan hoppes over)
            └── Hjemskjerm ──────────────────────────────┐
                ├── Pi-modus                             │
                │   └── Spillskjerm                      │
                │       └── Rundeslutt                   │
                ├── Regning                          │
                │   └── Spillskjerm                      │
                │       └── Rundeslutt                   │
                ├── Gruppespill                          │
                │   ├── Lobby                            │
                │   └── Live spill (med spillerrekkefølge)
                │       └── Rundeslutt                   │
                ├── Min profil ──────────────────────────┤
                │   └── Innstillinger                    │
                │       └── Logg ut                      │
                ├── Annens profil (fra scoreboard)       │
                └── Scoreboard ──────────────────────────┘
```

Modaler:
- Forlat spill (overlegg på spillskjerm)
- Logg ut (overlegg på innstillinger)
- Profilkort (sheet fra scoreboard)

---

## 5. Skjermspesifikasjoner

### 5.1 Innlogging

Sentrert komposisjon med stor logo (62×62 indigo blokk med "M"), apptittel og tagline, fulgt av "Sign in with Apple"-knapp i hvit pille. Vilkår-tekst i bunn.

### 5.2 Velg brukernavn

Tittel "MindDuel" med innstillings-ikon i topbar. Sentral tom avatar-illustrasjon, deretter "Velg ditt tag"-overskrift med undertekst. Inputfelt med @-prefiks og live-validering (grønn ramme + check-ikon når gyldig). Tre valideringsregler vises som grønne check-rader. Primærknapp "Fortsett" deaktiveres til alle regler er oppfylt og brukernavnet er tilgjengelig.

### 5.3 Onboarding

4 skjermbilder med hopp-over-lenke øverst til høyre, sentrert ikon-illustrasjon, overskrift, beskrivelse, fremdriftsindikator (utvidet aktiv prikk + tre runde inaktive) og "Neste"-primærknapp.

### 5.4 Hjemskjerm

```
[God dag, @petter]                            [P]
 Klar for en ny utfordring?

┌──────────────────┐  ┌──────────────────┐
│       [π]        │  │       [∑]        │
│    Pi-modus      │  │   Regning   │
│     2 847p       │  │     1 340p       │
│  [████░] 12      │  │  [██░░░] 4       │
│  Nivå 12 av 20   │  │  Nivå 4 av 10    │
└──────────────────┘  └──────────────────┘

┌─────────────────────────────────────────┐
│ [⚔ 2]  Gruppespill                      │
│        Utfordre venner i sanntid        │
│ [Bli med]    [Opprett]                  │
└─────────────────────────────────────────┘

Siste aktivitet                  Se alle
┌─────────────────────────────────────────┐
│ [MK•] Du vant mot @magnus         2t   │
│       Pi-modus · +45 poeng              │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ [SR]  Ny personlig rekord!         5t   │
│       Regning · 1 340p             │
└─────────────────────────────────────────┘
```

**Nøkkelpunkter:**
- Moduskortene bruker ikon-fokusert layout (se 3.6) – sentrert vertikalt med 44pt ikon øverst
- Hver modus viser sin egen identitetsfarge gjennom ikon, score-tall og progress bar
- Begge kort har garantert lik størrelse uavhengig av modusnavnets lengde
- Gruppespill-ikon har rød badge med antall ventende invitasjoner
- "Bli med" er primær (fylt indigo), "Opprett" er sekundær (transparent med indigo kant)
- Aktivitetsfeed er individuelle kort, ikke en sammenhengende liste
- Online-prikk vises på avatar når relevant (grønn på `surface`-kant)

### 5.5 Spillskjerm – Pi-modus

```
[‹]   Pi-modus   [P]

[♥ 3]                         [» 2]

┌─────────────────────────────────┐
│        12 desimaler gjettet     │
│         3.14159…                │
└─────────────────────────────────┘

[1] [2] [2✓] [4] [5]
[6] [7] [8]  [9] [0]

           [»]
         ⏱ 0,0 sek
```

### 5.6 Spillskjerm – Regning

```
[‹]   Regning   [P]

[♥ 5]                         [» 5]

┌─────────────────────────────────┐
│        Nivå 4 · Oppgave 3       │
│           17 × 8 = ?            │
└─────────────────────────────────┘

[126]      [136 ✓]
[146 ✗]    [156]

           [»]
         ⏱ 1,8 sek
```

### 5.7 Spillskjerm – Gruppespill

Samme som solo, med tillegg av:
- Rom-ID i topbar i stedet for modus-tittel ("● Gruppespill")
- Spillerrekkefølge-rad: aktiv spiller fremhevet med `accent-deep` ramme og "DIN TUR"-label, neste spillere dempet (40% opacity)
- "● LIVE"-indikator i topbar (grønn prikk + tekst)

### 5.8 Rundeslutt

```
        [🏆 trofé]
     RUNDE FERDIG
       2 847p
   ✓ Personlig rekord

[Korrekte: 12]   [Snitt tid: 1,4s]

VENNER
[1 @magnus     3 200p]   ← gull-bakgrunn
[2 Du          2 847p]   ← indigo-bakgrunn

[Spill igjen]            ← primærknapp
[Tilbake til hjem]       ← ghost-knapp
```

**Layout-regler:**
- Topp-til-bunn flyt med flex-spacer for å sikre at knappene alltid er synlige
- Padding 14 pt på alle sider, og 16 pt nederst for å gi knappene pust
- Kun topp 2-3 venner vises – ikke en lang liste

### 5.9 Scoreboard

Topbar med tilbake-knapp og "Scoreboard"-tittel. Tre-fane segmentert kontroll: Venner / Lokalt / Globalt. Liste med rader som viser rang, avatar, brukernavn, alder, og snittpoeng. Førsteplass har gull-bakgrunn, brukeren har indigo-bakgrunn. Flaggede brukere viser flagg-ikon ved navnet.

### 5.10 Min profil

```
[Min profil]                          [⚙]

       [P]  ← stor avatar
     @petter
  Medlem siden januar 2025

FREMGANG
[Pi: 2 847p, Nivå 12/20]  [∑: 1 340p, Nivå 4/10]
                          (begge med progress bars)

STATISTIKK
Runder spilt   ·  147
Venner         ·  8
Alder          ·  34 år

VENNER
[MK] [SR] [AL] [+]
```

### 5.11 Annens profil

Samme struktur som Min profil, men:
- Tilbake-knapp i topbar i stedet for spacer
- Innstillings-ikon erstattes av tom spacer
- Stats-seksjonen viser "Sist aktiv" i stedet for "Venner"-tall
- To handlingsknapper nederst: "Utfordre" (ghost) + "+ Venn" (primær)

### 5.12 Flerspillerlobby

```
[‹]   Flerspiller            [#4F2A]

MODUS
[π Pi-modus]    [∑ Regning]
 (aktiv)         (dempet 50%)

STARTNIVÅ
[Fra start (#1)              ›]

SPILLERE (3/8)
[P @petter (Romvert)    ✓ Klar]
[MK @magnus             ✓ Klar]
[SR @sara               ⏳ Venter]
[+  Inviter spiller]

[Venter på @sara…]              ← deaktivert
```

### 5.13 Innstillinger

Tre seksjoner med mellomtitler:

**KONTO:** Varsler (toggle), Mørk modus (System), Språk (Norsk)

**ABONNEMENT:** Plan-status med "Oppgrader"-knapp

**PERSONVERN:** Vilkår og personvern, Slett konto og data (rød)

Nederst: "Logg ut"-danger-knapp.

Hver innstillingsrad har et avrundet-firkantet ikon i `accent-soft`-fargen til venstre.

### 5.14 Modaler

**Forlat spill:** Bakgrunnsspill dempes til 20% opacity. Modal med advarsel-ikon (oransje), tittel "Forlate spillet?", forklaring, og to knapper: "Forlat spillet" (danger) + "Fortsett å spille" (ghost).

**Logg ut:** Lignende struktur, men på innstillingsbakgrunn. Wave-ikon, "Logg ut?"-tittel, primær + ghost knapper.

---

## 6. Animasjoner og overganger

| Hendelse | Animasjon | Varighet |
|---|---|---|
| Riktig svar | Knapp lyser grønt + lett pulse | 250 ms |
| Feil svar | Knapp lyser rødt + shake | 300 ms |
| Hopp brukt | Knapp dusker ned, ny oppgave glir inn | 200 ms |
| Skjermovergang | Slide fra høyre (push), slide tilbake (pop) | 350 ms |
| Rundeslutt | Score telles opp fra 0 med ease-out | 600 ms |
| Liv mister | Hjerte-pille krymper kort, tall oppdateres | 300 ms |
| Modal-overlegg | Fade + scale-in fra 95% | 200 ms |

Alle animasjoner respekterer `preferredReducedMotion`.

---

## 7. Haptisk tilbakemelding

| Hendelse | Type | iOS API |
|---|---|---|
| Riktig svar | Success | `UINotificationFeedbackGenerator.success` |
| Feil svar | Error | `UINotificationFeedbackGenerator.error` |
| Hopp brukt | Light impact | `UIImpactFeedbackGenerator.light` |
| Modal åpnes | Medium impact | `UIImpactFeedbackGenerator.medium` |

---

## 8. Tilgjengelighet

| Område | Krav |
|---|---|
| Minste tekststørrelse | 9 pt (kun for tertiær metadata) |
| Kontrast | WCAG AA (4.5:1 tekst, 3:1 store elementer) |
| Tap target | Minimum 44×44 pt |
| Dynamic Type | Tekst skalerer med systeminnstilling |
| Reduced Motion | Animasjoner erstattes med fade |
| VoiceOver | Planlagt (v2) |

---

## 9. Lokalisering

All tekst på **norsk** og **engelsk**, automatisk valgt etter systemspråk. Onboarding-illustrasjoner leveres i to språkvarianter.

---

## 10. Beslutningslogg fra designprosessen

Følgende valg er tatt eksplisitt basert på iterasjon med stakeholder:

1. **Mørk lilla bakgrunn** valgt over lysere alternativer (inspirert av Apple Games)
2. **Ikonbasert UI** med egendefinerte SVG-ikoner – emojis er ikke tillatt i UI
3. **Sirkulære sifferknapper** for Pi-modus i 5×2 grid
4. **Hopp-knapp + timer stablet vertikalt** sentrert under svarområdet (ikke side ved side)
5. **Konsistent topbar** med tre-felt-struktur på alle skjermer
6. **Progress bar + nivå-tall** for nivåvisning – ingen kryptiske "L12"-badger
7. **Like store moduskort** via identisk strukturmal og CSS Grid
8. **Ikon-fokusert vertikal moduskort-layout** – løser problemet med varierende navnelengder og gir et leketøyaktig uttrykk for både barn og voksne
9. **Modus omdøpt fra "Regnestykker" til "Regning"** – gir symmetriske moduskort med titler som passer på én linje, og fungerer like godt for målgruppen (kort, barnvennlig, beskrivende)
10. **Aktivitetsfeed med individuelle kort** i stedet for ren liste
11. **Ingen tab-bar** – navigasjon skjer via tilbake-knapper og direkte fra hjemskjerm
12. **Røde notifikasjons-badges** kun med tall (uten "invitasjoner"-tekst som brytes)

---

## 11. Åpne spørsmål

| # | Spørsmål | Status | Beslutning |
|---|---|---|---|
| 1 | Skal lys modus støttes i v1, eller kun mørk? | ✅ Avklart | Kun mørk modus i v1. Lys modus er backlog for v2. |
| 2 | Endelig logo og ordmerke – skal det lages? | ✅ Avklart | Ja. Minimalistisk SVG-stil, konsistent med designsystemet. Ferdig til M8. |
| 3 | Lyddesign for riktig/feil-svar | Backlog (v2) | – |
| 4 | Onboarding-illustrasjonsstil | ✅ Avklart | Minimalistisk SVG – konsistent med resten av designsystemet. |
| 5 | VoiceOver-implementasjon | Backlog (v2) | – |
