# Milepæler – MindDuel
## Utviklingsplan for iOS-app

**Versjon:** 1.1
**Dato:** 2026-05-06
**Basert på:** PRD v0.1 + Design Document v1.0

---

## Oversikt

| # | Milepæl | Leveranse | Estimert varighet |
|---|---|---|---|
| M1 | Fundament | Prosjektoppsett, autentisering, designsystem | 2 uker |
| M2 | Spillbar prototype | Core loop for begge modi, solo | 3 uker |
| M3 | Progresjon og score | Kontinuerlig progresjon, scorelogikk, dagkvote | 2 uker |
| M4 | Sosialt lag | Venner, scoreboard, profiler | 2 uker |
| M5 | Flerspiller | Sanntids gruppespill, invitasjoner, turlogikk | 3 uker |
| M6 | Cloud Backend | Sentral datalagring, admin-grensesnitt, telemetri, spørsmålsbank, bildehosting | 5 uker |
| M7 | Betaling og abonnement | StoreKit 2, gratis/betalt-modell | 1 uke |
| M8 | Polering | Animasjoner, haptics, onboarding, treningsrunde | 2 uker |
| M9 | App Store-klargjøring | Metadata, skjermbilder, testflight, innlevering | 1 uke |

**Total estimert tid:** ~21 uker

---

## M1 – Fundament
**Mål:** Alt teknisk og visuelt grunnarbeid er på plass. Ingen spillfunksjonalitet ennå.

### Teknisk
- Xcode-prosjekt opprettet med SwiftUI og Swift Package Manager
- Sign in with Apple implementert (AuthenticationServices)
- Brukernavn-valg ved første innlogging
- Backend-prosjekt opprettet (API + database i EU-region)
- Lokalisering satt opp fra dag én (String Catalogs, norsk + engelsk)
- Mørk modus via systeminnstilling (Color Assets med light/dark-varianter)

### Design
- Fargepalett implementert som Color Assets (`bg`, `surface`, `accent`, `pink`, `green`, `red`, m.fl.)
- Typografiskala implementert som ViewModifiers (Display, Title, Heading, Body, Caption, m.fl.)
- 8 pt spacing-tokens definert
- SVG-ikonsett importert og tilpasset SwiftUI
- Topbar-komponent bygget (tre-felt-struktur)
- Knapp-komponenter (Primary, Ghost, Danger, Disabled)
- Kort-komponenter (Primær- og sekundærkort)
- Avatar-komponent (sm/md/lg)
- Pill-tag-komponent

### Leveransekrav
- [ ] Bruker kan logge inn med Apple-konto og velge brukernavn
- [ ] Hjemskjerm vises med korrekt designsystem
- [ ] Appen kjører på fysisk enhet (mørk modus)
- [ ] Lokalisering fungerer for norsk og engelsk

---

## M2 – Spillbar prototype
**Mål:** Begge spillmodi er spillbare i solo. Ingen persistens, ingen score – bare kjerneopplevelsen.

### Pi-modus
- Pi-sekvens tilgjengelig i backend (minst 10 000 desimaler)
- Sifferknapper (5×2 sirkulær grid) implementert
- Riktig/feil-svar vises visuelt (grønn/rød feedback)
- Liv og hopp-piller øverst på skjermen fungerer
- 10-sekunders timeout → automatisk hopp
- Appen venter på brukerinteraksjon etter timeout før neste oppgave vises
- Runden avsluttes ved 0 liv eller 0 hopp

### Regning-modus
- Oppgavegenerator bygget for alle aldersgrupper (seksjon 4.3 i PRD)
- 4 svaralternativer vises (én korrekt, tre plausible feil)
- Riktig/feil-svar vises visuelt
- Liv, hopp og timeout fungerer likt som Pi-modus

### Felles
- Resource-pill (liv/hopp) implementert (seksjon 3.7 i Design)
- Skip-knapp med timer implementert (seksjon 3.8 i Design)
- Enkel rundeslutt-skjerm (ikke ferdig designet ennå – placeholder)
- Forlat spill-knapp med bekreftelsesmodal

### Leveransekrav
- [ ] Begge modi er spillbare fra start til slutt
- [ ] Liv og hopp trekkes korrekt
- [ ] Timeout bruker hopp og venter på interaksjon
- [ ] Runden avsluttes og returnerer til hjemskjerm

---

## M3 – Progresjon og score
**Mål:** Scorelogikk og kontinuerlig progresjon er implementert og persistent.

### Scorelogikk
- Tid per oppgave loggføres på server (ikke klient)
- Session-tokens generert per runde (anti-juks)
- Serverside fasit-validering implementert
- Tidsvalidering: svar under 200 ms avvises
- Scoreformel implementert for begge modi (K-konstant, snittid, vanskelighetspoeng)
- Treningsrunder teller ikke mot score eller progresjon

### Kontinuerlig progresjon
- Personlig posisjonsverdi lagret per bruker per modus i database
- Posisjon oppdateres etter hver runde (fremover ved suksess, X % tilbake ved tap)
- X % fastsettes med standardverdi frem til playtesting justerer den (forslag: 15 %)
- Progresjon kan ikke rulle tilbake forbi brukerens all-time startposisjon (solo)
- Treningsrunde: bruker velger startpunkt fritt uten at progresjon påvirkes

### Dagkvote
- 10 oppgaver per dag for gratisbrukere (treningsrunder ekskludert)
- Kvote nullstilles ved midnatt lokal tid
- Banner vises ved 8/10 brukte oppgaver
- Kvote-sjekk skjer serverside

### Rundeslutt-skjerm
- Ferdig implementert etter design (seksjon 5.8): score telles opp, statistikk, knapper
- Personlig rekord-indikator

### Leveransekrav
- [ ] Score beregnes korrekt og lagres i database
- [ ] Progresjon vedvarer mellom økter
- [ ] Tilbakerulling fungerer ved tap
- [ ] Dagkvote stopper spill ved 10 oppgaver (gratisbrukere)
- [ ] Rundeslutt-skjerm viser korrekt data

---

## M4 – Sosialt lag
**Mål:** Venner, profiler og scoreboard er fullt funksjonelle.

### Profiler
- Min profil-skjerm (seksjon 5.10 i Design): avatar, stats, fremgang, venner
- Annens profil-skjerm (seksjon 5.11): "Utfordre" og "+ Venn"-knapper
- Moduskort med progress bar og nivå (seksjon 3.6 i Design)

### Venner
- Søk etter brukernavn
- Send/godta/avslå venneforespørsler
- Venneforespørsler vises som notifikasjonsbadge

### Scoreboard
- Tre-fane-visning: Venner / Lokalt / Globalt (seksjon 5.9 i Design)
- Lokalt scoreboard bruker CoreLocation for radius-søk (posisjon lagres ikke på server)
- Brukeren er fremhevet med indigo-bakgrunn
- Førsteplass fremhevet med gull-bakgrunn
- Flaggede brukere vises med flagg-ikon

### Anti-juks
- Avviksdeteksjon implementert (snittid under 400 ms over mange runder → flagg)
- Flagg-ikon vises på brukerens profil og i scoreboard
- Bruker kan trykke på flagg for å lese forklaring
- Manuell gjennomgang-prosess dokumentert for administrator

### Push-notifikasjoner (APNs)
- Venneforespørsel mottatt
- Invitasjon til gruppespill mottatt

### Leveransekrav
- [ ] Venner kan legges til og vises
- [ ] Alle tre scoreboard-visninger fungerer
- [ ] Profiler viser korrekt data
- [ ] Push-notifikasjoner leveres for venneforespørsler og invitasjoner

---

## M5 – Flerspiller
**Mål:** Sanntids gruppespill fungerer fullt ut.

### Lobbyfunksjonalitet
- Flerspillerlobby-skjerm implementert (seksjon 5.12 i Design)
- Opprett rom: velg modus og startnivå (Fra start / Egendefinert)
- Inviter via brukernavn eller delingslenke
- Inviterte spillere ser modus, startnivå og deltakere i push-notifikasjon før de aksepterer
- Romkode vises i topbar
- Maks 8 spillere per rom
- Spillerrekkefølge vises med Klar/Venter-status

### Sanntids turlogikk (WebSocket)
- Runde-robin turrekkefølge
- Aktiv spiller fremhevet med "DIN TUR"-label og accent-ramme
- LIVE-indikator i topbar
- Timeout (10 sek) → automatisk hopp, venter på interaksjon
- Spiller ute ved 0 liv eller 0 hopp
- Siste gjenværende spiller vinner

### Scorelogikk for gruppespill
- Ventetid (tur startet → oppgave vist) og svartid (oppgave vist → svar sendt) loggføres
- Trekk-score = Vanskelighetspoeng × (K / (Svartid + W × Ventetid))
- W fastsettes under playtesting (forslag: 0,2)
- Vinnerbonus: +20 % på total rundepoeng

### Progresjon i gruppespill
- Alle starter fra romvertens valgte nivå/posisjon
- Etter runden: vinner går fremover, tapere rulles X % tilbake fra avslutningstidspunkt

### Tilkoblingshåndtering
- Frakobling under 15 sek: spillet venter, andre spillere ser "Venter på @brukernavn…"
- Frakobling over 15 sek: behandles som frivillig exit
- Runde teller ikke mot score ved tilkoblingsproblemer

### Push-notifikasjoner
- Din tur i gruppespill
- Runden er over

### Leveransekrav
- [ ] Gruppespill med 2–8 spillere fungerer end-to-end
- [ ] Turlogikk og live-visning fungerer i sanntid
- [ ] Scorelogikk med ventetid/svartid beregnes korrekt
- [ ] Progresjon oppdateres riktig for alle spillere etter runden
- [ ] Frakobling håndteres uten at appen krasjer

---

## M6 – Cloud Backend
**Mål:** Fullstendig sky-backend etablert med sikker kommunikasjon, sentralisert datalagring, admin-grensesnitt og alle støttefunksjoner som kreves for produksjonssetting.

### Infrastruktur og sikkerhet
- Produksjonsmiljø satt opp (EU-region, GDPR-compliant) med staging-miljø for testing
- HTTPS/TLS (REST) og WSS (WebSocket) for all kommunikasjon mellom app og backend
- JWT-basert autentisering for alle API-kall fra appen; tokens roteres jevnlig
- Admin-grensesnitt med separat autentisering og rollebasert tilgangskontroll (f.eks. admin / moderator)
- Kryptert lagring av sensitiv brukerdata (fødselsdato, Apple-bruker-ID hashed)
- API rate limiting og throttling på servernivå
- Logging, error tracking og uptime monitoring

### Brukerdata og spilløkter
- All brukerprofil-data, progresjon og scores lagres sentralt – støtter flere enheter per bruker
- Spilløkter og solo-sessions synkroniseres med backend; offline-spill bufres lokalt og synkroniseres ved reconnect
- Session-tokens og serverside fasit-validering flyttes fra klient til backend (fullføring av M3/M5-plan)
- Anti-juks-flagging flyttes serverside der timing-data valideres uavhengig av klienten

### Spørsmålsbank
- Spørsmål for alle kunnskapsbaserte modi lagres i backend-database (erstatter statiske bundlete spørsmålslister)
- Versjonssystem: appen sjekker ved oppstart og jevnlig (f.eks. daglig i bakgrunnen) om det finnes en nyere versjon av spørsmålspakken for de aktive modiene
- Appen laster ned og cacher oppdatert spørsmålspakke ved versjonsbump; gammel pakke beholdes til ny er fullstendig lastet ned
- Spørsmål bundlet i appen beholdes som fallback ved første oppstart uten nettverkstilgang
- Admin-grensesnitt for CRUD av spørsmål med støtte for modus, nivå og vanskelighetsgrad-tagging

### Bildehosting
- Bilder appen bruker (foreløpig flagg for geografi-modus) hostes sentralt (CDN eller object storage i EU)
- Appen sjekker versjon/hash og laster ned oppdaterte bilder ved endring
- Bilder caches lokalt på enheten; bilder bundlet i appen brukes som fallback ved offline

### Spillmodus-styring
- Admin kan aktivere, skjule og fjerne spillmodi uten app-oppdatering
- Støtte for midlertidige/sesongbaserte modi (påske, VM, OL, jul osv.) med planlagte start- og sluttidspunkter
- Appen henter aktiv moduskonfigurasjon ved oppstart med lokal fallback ved offline

### Bruksstatistikk og telemetri
- Appen sender anonym telemetri: skjermvisninger, funksjonsklikk, sesjonslengde, feilhendelser
- Telemetri sendes i batches for å spare batteri og data; ingen PII inkluderes
- Admin-dashboard viser nøkkelmetrikker: DAU/MAU, populære modi, gjennomsnittlig sesjonslengde, dagkvote-utnyttelse
- Crash reporting integrert

### Tilbakemeldingssystem
- Brukere sender tilbakemelding via innstillingsskjermen i appen
- Backend mottar og lagrer tilbakemeldinger (ticket-system med status: åpen / under behandling / lukket)
- Admin kan se, kategorisere og svare på tilbakemeldinger i admin-grensesnittet
- Svar pushes til brukeren via APNs-notifikasjon og/eller in-app melding

### Admin-grensesnitt (web)
- Brukeradministrasjon: søk, vis profil, fjern flagg, suspender konto
- Spørsmålsadministrasjon: CRUD for alle spørsmål, versjonspublisering
- Bildeadministrasjon: last opp, oppdater og arkiver bilder brukt i appen
- Spillmodus-konfigurasjon: aktiver/skjul/sesongsett modi
- Tilbakemeldingshåndtering: vis, svar og lukk tickets
- Statistikk-dashboard med nøkkelmetrikker

### iOS-app-endringer
M6 krever betydelige endringer i appen for å gå fra lokal/mock-tilstand (M1–M5) til ekte backend-integrasjon.

**Nettverkslag**
- Robust API-klient bygget (URLSession + async/await); håndterer JWT-autentisering, token-rotasjon og automatisk retry ved kortvarige nettverksfeil
- Offline-buffer: data som genereres uten nett (solo-scores, progresjon) køes lokalt og synkroniseres automatisk ved reconnect
- Feilhåndtering og bruker-synlig nett-status der relevant (f.eks. flerspiller krever nett)

**Spørsmålsbank**
- Bundlet JSON for alle 8 kunnskapsbaserte modi erstattes med versjonert nedlasting + lokal disk-cache
- Versjonsjekk kjøres ved appstart og jevnlig i bakgrunnen; ny pakke lastes ned og byttes ut atomisk
- Bundlet innhold beholdes kun som fallback ved første oppstart uten nett

**Bildenedlasting**
- Bundlete flagg-bilder (og fremtidige bilder) erstattes med CDN-nedlasting og lokal disk-cache
- Hash-basert sjekk avgjør om et bilde trenger oppdatering

**Spillmodus-konfigurasjon**
- Hardkodet moduskonfigurasjon erstattes med henting fra backend
- Appen viser kun moduser som er aktive ifølge backend; skjuler/viser midlertidige modi automatisk
- Siste kjente konfigurasjon caches lokalt for offline-fallback

**Flerspiller**
- Mock WebSocket-implementasjon (M5) erstattes med ekte WebSocket-tilkobling (WSS)
- All turlogikk, session-tokens og fasit-validering håndteres serverside

**Progresjon, scores og dagkvote**
- `UserDefaults`-basert progresjon og scorelagring erstattes med serverside persistens
- Dagkvote-sjekk flyttes fra lokal til serverside; lokal kopi brukes kun som optimistisk UI-indikator
- Session-tokens for hvert spill mottas fra server ved rundestart og sendes med alle svar

**Anti-juks**
- Klientbasert flagg-logikk fjernes fra `UserDefaults`; flagg-status hentes fra backend ved innlogging og oppdateres i sanntid

**Telemetri**
- Event-tracking implementert for skjermvisninger, funksjonsklikk og sesjonslengde
- Events batches og sendes i bakgrunnen uten å påvirke appytelse

**Tilbakemeldingsskjema**
- Tilbakemeldingsskjerm i innstillinger kobles til backend ticket-API
- In-app-visning av svar på tilbakemeldinger

**Push-notifikasjoner**
- APNs device token registreres med backend ved innlogging
- Mottak og visning av notifikasjoner: din tur, runden er over, invitasjon, svar på tilbakemelding

### Leveransekrav
**Backend**
- [ ] Produksjonsmiljø live i EU-region med staging-miljø
- [ ] All kommunikasjon mellom app og backend er kryptert (HTTPS/WSS)
- [ ] Admin-grensesnitt live med rollebasert autentisering
- [ ] Spørsmålsbanker versjonshåndteres og kan oppdateres uten app-release
- [ ] Bilder hostes sentralt (CDN/object storage)
- [ ] Admin kan aktivere/skjule/sesongsette spillmodi uten app-oppdatering
- [ ] Tilbakemeldingssystem fungerer end-to-end (mottak, svar og lukking)
- [ ] Anti-juks-flagging kjøres serverside

**iOS-app**
- [ ] All brukerprofil-data, progresjon og scores lagres sentralt og synkroniseres på tvers av enheter
- [ ] Solo-spill fungerer offline; data synkroniseres ved reconnect
- [ ] Appen laster ned og cacher spørsmålspakker og bilder; versjonsjekk kjøres ved oppstart
- [ ] Flerspiller bruker ekte WebSocket-tilkobling (ikke mock)
- [ ] Scoreboard (venner/lokalt/globalt) henter data fra reelle API-endepunkter
- [ ] Dagkvote-sjekk er serverside
- [ ] Session-tokens brukes for alle spillrunder
- [ ] Anonym telemetri sendes fra appen og vises i admin-dashboard
- [ ] Push-notifikasjoner (APNs) fungerer for tur, runde ferdig, invitasjon og tilbakemeldingssvar

---

## M7 – Betaling og abonnement
**Mål:** Betalingsmodell er live og fungerer via Apple In-App Purchase.

### StoreKit 2
- Månedlig abonnement: 19 kr/mnd konfigurert i App Store Connect
- Engangskjøp: 199 kr konfigurert i App Store Connect
- Kjøpsflyten implementert fra innstillinger og fra kvote-banner
- Receipt-validering serverside
- Gjenopprettelse av kjøp implementert ("Gjenopprett kjøp"-knapp)

### Brukeropplevelse
- Abonnementsstatus vises på innstillingsskjermen (seksjon 5.13 i Design)
- Banner vises ved 8/10 daglige oppgaver med "Oppgrader"-knapp
- Betalte brukere ser ingen kvote-begrensning

### Leveransekrav
- [ ] Kjøp av abonnement og engangskjøp fungerer i Sandbox
- [ ] Kvoten oppheves umiddelbart etter kjøp
- [ ] Gjenopprettelse av kjøp fungerer

---

## M8 – Polering
**Mål:** Appen føles ferdig. Animasjoner, overganger, onboarding og treningsrunde er på plass.

### Animasjoner og overganger (seksjon 6 i Design)
- Riktig svar: grønn pulse (250 ms)
- Feil svar: rød shake (300 ms)
- Hopp: ny oppgave glir inn (200 ms)
- Skjermoverganger: slide push/pop (350 ms)
- Rundeslutt: score telles opp med ease-out (600 ms)
- Liv mister: hjertepille krymper kort (300 ms)
- Modal: fade + scale-in fra 95 % (200 ms)
- Alle animasjoner respekterer `preferredReducedMotion`

### Haptics (seksjon 7 i Design)
- Riktig svar: UINotificationFeedbackGenerator.success
- Feil svar: UINotificationFeedbackGenerator.error
- Hopp brukt: UIImpactFeedbackGenerator.light
- Modal åpnes: UIImpactFeedbackGenerator.medium

### Onboarding (seksjon 15 i PRD)
- 3–4 skjermbilder med illustrasjoner implementert (norsk + engelsk)
- Vises etter registrering
- Kan hoppes over og gjenåpnes fra profilsiden
- Illustrasjonsstil avklart (se åpne spørsmål i Design.md)

### Treningsrunde
- Tydelig "Treningsrunde"-merking i UI
- Fasit vises ved feil
- Timer vises men teller ikke mot score
- Teller ikke mot dagkvote

### Lys modus
Kun mørk modus støttes i v1. Color Assets implementeres uten light-variant. Lys modus er backlog for v2.

### Generell QA
- Gjennomgang av alle skjermbilder mot designdokumentet
- Edge cases: langt brukernavn, offline-modus, 0 venner, høyt progresjonsnivå

### Leveransekrav
- [ ] Alle animasjoner fra Design.md er implementert
- [ ] Haptics fungerer og respekterer systeminnstilling
- [ ] Onboarding vises ved første innlogging
- [ ] Treningsrunde fungerer uten å påvirke progresjon eller kvote

---

## M9 – App Store-klargjøring
**Mål:** Appen er klar for innlevering til App Store Review.

### TestFlight
- Intern TestFlight-distribusjon til testbrukere
- Minimum 2 ukers testperiode anbefales før innlevering
- Kritiske bugs fra testing lukkes

### App Store Connect
- Appnavn: MindDuel
- Undertittel og beskrivelse på norsk og engelsk (PRD seksjon 18)
- Nøkkelord på begge språk
- Skjermbilder (6,7" og 5,5") på norsk og engelsk – alle med lokalisert tekst
- App-ikon (1024×1024 pt) ferdigstilt
- Aldersgrense satt til 9+
- Personvernerklæring publisert og lenket
- In-App Purchase-produkter godkjent

### Teknisk sjekkliste
- [ ] Ingen private API-kall
- [ ] App Tracking Transparency ikke nødvendig (ingen sporing av tredjepart)
- [ ] CoreLocation kun brukt til radius-søk (ingen bakgrunnslokasjon)
- [ ] GDPR-sletting fra profilsiden fungerer end-to-end
- [ ] Appen er testet på iPhone SE (minste skjerm) og iPhone Pro Max (største)

### Leveransekrav
- [ ] Appen er godkjent av App Store Review
- [ ] Begge kjøpsprodukter er live i App Store
- [ ] Appen er tilgjengelig for nedlasting

---

## Åpne designspørsmål som må avklares før M8

Disse er hentet fra Design.md seksjon 11 og påvirker M7 direkte:

| # | Spørsmål | Beslutning |
|---|---|---|
| 1 | Skal lys modus støttes i v1, eller kun mørk? | **Kun mørk modus i v1.** Color Assets trenger ikke light-varianter. |
| 2 | Endelig logo og ordmerke – skal det lages? | **Ja.** Må være ferdig til M8 (App-ikon 1024×1024 pt). |
| 4 | Onboarding-illustrasjonsstil | **Minimalistisk SVG** – konsistent med resten av designsystemet. |
