# Product Requirements Document
## MindDuel – Sosialt hjernetrim for iPhone

**Versjon:** 0.2
**Dato:** 2026-05-06
**Status:** Oppdatert – reflekterer implementert M1–M5

---

## 1. Produktoversikt

MindDuel er en sosial iOS-app der spillere konkurrerer om å løse mentale utfordringer så raskt og nøyaktig som mulig. Appen tilbyr ti spillmodi – Pi, Regning, Kjemi, Geografi, Hjernetrim, Naturvitenskap, Historie, Fysikk, Sport og Grammatikk – og støtter både solo-spill og sanntids flerspillermodus. Poengsum beregnes ut fra en kombinasjon av nøyaktighet og hastighet.

---

## 2. Mål og suksesskriterier

| Mål | Suksesskriterium |
|-----|------------------|
| Engasjerende daglig bruk | ≥ 3 spilløkter per aktiv bruker per uke |
| Sosial vekst | ≥ 40 % av nye brukere inviterer minst én venn innen 7 dager |
| Konvertering til betalt | ≥ 5 % av månedlige aktive brukere har abonnement eller engangskjøp |
| Retensjon | 30-dagers retensjon ≥ 35 % |

---

## 3. Brukergrupper

- **Primær:** Norske iPhone-brukere 10–40 år med interesse for hjernetrim og sosial konkurranse
- **Sekundær:** Lærere/foreldre som ønsker pedagogisk spill for barn (vanskelighetsgrad tilpasses alder automatisk)

---

## 4. Autentisering og brukerprofil

### 4.1 Sign in with Apple
- Eneste innloggingsmetode
- Brukerens fødselsdato hentes fra Apple-profilen og lagres kryptert
- Brukerens alder beregnes ved registrering og oppdateres automatisk på fødselsdagen

### 4.2 Brukernavn
- Velges av brukeren ved første innlogging
- Unikt i systemet, 3–20 tegn, kun bokstaver/tall/understrek
- Vises for alle spillere i scoreboard og flerspiller

### 4.3 Aldersbasert vanskelighetsgrad (Regnestykker)
| Aldersgruppe | Vanskelighetsintervall |
|---|---|
| Under 10 år | Kun addisjon og subtraksjon, enkle tall |
| 10–13 år | +, −, ×, ÷ med enkle tall |
| 14–17 år | Alle 4 operasjoner, parenteser, negative tall |
| 18–29 år | Brøk, prosent, potenser, enkle ligninger |
| 30+ år | Full bredde inkl. kvadratrøtter, enkle logaritmer |

Alderen vises for andre spillere på profilkortet.

---

## 5. Spillmodi

### 5.1 Pi-modus
Spilleren skal gjette neste siffer i rekken av desimaler i π (3,14159265…).

**Mekanikk:**
- Hittil korrekte desimaler vises øverst
- Spilleren velger ett siffer (0–9) fra 10 knapper
- Ved korrekt svar: neste desimal vises, timeren nullstilles per desimal
- Tid per desimal loggføres

**Kontinuerlig progresjon:**
Hver bruker har én personlig posisjon i Pi-sekvensen som vedvarer på tvers av alle runder og økter. En ny runde starter alltid fra brukerens nåværende posisjon. Posisjonen beveger seg fremover ved vellykkede runder.

Ved tap i solorunde rulles posisjonen tilbake med X % av antall desimaler gjett i den tapte runden (X fastsettes under playtesting). Posisjonen kan aldri rulles tilbake forbi brukerens all-time startposisjon.

Ved tap i gruppespill rulles posisjonen tilbake med X % fra det punktet runden ble avsluttet (der en spiller vant), ikke fra brukerens opprinnelige startposisjon ved rundestart.

Brukeren kan manuelt velge startpunkt for treningsrunder fra et hvilket som helst tidligere siffer uten at progresjonen påvirkes (se seksjon 5.3).

**Poengsum per runde:**

```
Score = Antall_korrekte_desimaler × (K / Snitt_tid_per_desimal_i_sekunder)
```

Der K er en kalibreringskonstant fastsatt ved playtesting. K kan justeres i backend uten app-oppdatering.

Oppgaver som ble hoppet over ekskluderes fra tidsberegningen.

---

### 5.2 Regnestykke-modus
Spilleren får opp et regnestykke og skal velge riktig svar blant 4 alternativer så raskt som mulig.

**Mekanikk:**
- 4 svaralternativer vises, kun ett er korrekt
- Tid per oppgave loggføres

**Kontinuerlig progresjon:**
Hver bruker har ett personlig vanskelighetsgrad-nivå som vedvarer på tvers av alle runder og økter. Nye regnestykker genereres alltid dynamisk, men vanskelighetsgraden er personlig og persistent. Nivået øker etter hvert 5. korrekte svar innenfor gjeldende nivå.

Ved tap i solorunde rulles nivået tilbake med X % av fremgangen gjort i den tapte runden (X fastsettes under playtesting).

Ved tap i gruppespill rulles nivået tilbake med X % fra det punktet runden ble avsluttet (der en spiller vant), ikke fra brukerens opprinnelige nivå ved rundestart.

Brukeren kan manuelt velge å starte treningsrunder fra et lavere nivå uten at progresjonen påvirkes (se seksjon 5.3).

**Poengsum per runde:**

```
Score = Σ (Vanskelighetspoeng_per_oppgave) × (K / Snitt_tid_per_oppgave_i_sekunder)
```

Vanskelighetspoeng: Nivå 1 = 1p, Nivå 2 = 2p, … (lineær skala, maks Nivå 10 = 10p). K er samme kalibreringskonstant som i Pi-modus.

Oppgaver som ble hoppet over ekskluderes fra tidsberegningen.

### 5.3 Trenings-/læringsmodus

Tilgjengelig i begge modi. Treningsrunder påvirker ikke brukerens progresjon, score eller dagkvote.

**Pi-modus – treningsfunksjoner:**
- Brukeren kan velge å starte fra et hvilket som helst siffer i sin allerede oppnådde sekvens
- Ved feil vises korrekt svar automatisk før neste siffer presenteres
- Ingen tidspress – timer vises men teller ikke mot score

**Regnestykke-modus – treningsfunksjoner:**
- Brukeren kan velge å spille på et lavere vanskelighetsgrad-nivå enn sitt nåværende
- Ved feil vises korrekt svar og utregning automatisk
- Ingen tidspress – timer vises men teller ikke mot score

Treningsrunder er tydelig merket i UI-et (f.eks. «Treningsrunde» i stedet for «Spill») slik at brukeren alltid vet at progresjonen ikke påvirkes.

---

### 5.4 Gruppespill – progresjon og invitasjon

**Startnivå:**
Den som oppretter rommet velger startnivå for runden. To alternativer tilbys:
- **Fra start (standard):** Runden begynner fra siffer 1 i Pi / nivå 1 i Regnestykker
- **Egendefinert nivå:** Romoppretter velger et spesifikt siffer/nivå manuelt

Inviterte spillere informeres om valgt startnivå, modus og hvilke andre spillere som er med i invitasjonen, før de aksepterer. Dette lar spillere ta en informert beslutning om de vil delta.

Alle spillere i runden starter fra samme valgte nivå/posisjon, uavhengig av individuell progresjon. Etter runden oppdateres hver spillers individuelle progresjon basert på utfallet: vinneren går fremover fra rundeavslutningstidspunktet, taperne rulles X % tilbake fra samme punkt.

Gjelder begge modi:

| Ressurs | Antall ved start | Effekt ved bruk |
|---|---|---|
| ❤️ Liv | 5 | Brukes ved feil svar. Ved 0 liv: spillet avsluttes |
| ⏭ Hopp | 5 | Lar spilleren hoppe over én oppgave uten straff. Ved 0 hopp: kan ikke lenger hoppe |

Runden avsluttes når enten liv eller hopp er brukt opp, eller spilleren velger å avslutte.

### 5.5 Kunnskapsbaserte modi

Åtte modi bruker samme mekanikk som Regning (4 svaralternativer, live/hopp, timeout), men med fagbaserte spørsmål i stedet for genererte regnestykker. Spørsmålsbanker lagres i backend og versjonshåndteres; appen sjekker jevnlig om det finnes en nyere versjon og cacher pakken lokalt. Spørsmål bundlet i appen brukes som fallback ved første oppstart uten nett.

| Modus | Fagområde | Vanskelighetsgrad |
|---|---|---|
| Kjemi | Grunnstoff, reaksjoner, periodesystem | Nivå 1–20 |
| Geografi | Land, flagg, hovedsteder, LK20-pensum | Nivå 1–20 |
| Hjernetrim | Tallmønstre, aritmetiske snarveier, arbeidsminne | Nivå 1–20 |
| Naturvitenskap | Biologi, fysikk, astronomi, geologi | Nivå 1–20 |
| Historie | Norgeshistorie og verdenshistorie, forhistorie til nåtid | Nivå 1–20 |
| Fysikk | Mekanikk, elektrisitet, termodynamikk | Nivå 1–20 |
| Sport | Populære idretter, regler, utøvere, OL | Nivå 1–20 |
| Grammatikk | Norsk grammatikk (nynorsk/bokmål) | Nivå 1–20 |

Progresjon, scorelogikk og dagkvote er identisk med Regning-modus (se §5.2). Nivåoppgang styres av adaptiv terskel basert på svartid og antall feil innenfor gjeldende nivå.

---

## 7. Flerspiller – Sanntidsmodus

To eller flere spillere konkurrerer i sanntid i en felles runde.

**Spillflyt:**
1. En spiller oppretter rom og inviterer venner via brukernavn eller delingslenke
2. Spillere kobler seg til rommet (maks 8 spillere per rom)
3. Spillerne svarer på oppgaver etter tur i en fast rekkefølge (runde-robin)
4. Hver spiller har sine egne liv og hopp
5. Spillere som bruker opp liv eller hopp er ute av runden
6. Siste gjenværende spiller som svarer riktig vinner

**Poeng i flerspiller:**

Poeng per trekk beregnes basert på to tidskomponenter:

- **Ventetid:** Tid fra det blir spillerens tur til oppgaven vises (spilleren åpner appen)
- **Svartid:** Tid fra oppgaven vises til svar sendes

```
Trekk-score = Vanskelighetspoeng × (K / (Svartid + W × Ventetid))
```

W er en vektingsfaktor < 1 som sikrer at ventetid påvirker poengene, men ikke dominerer over selve svartiden. Både K og W fastsettes under playtesting (tentativt W = 0,1–0,3).

Eksempel med W = 0,2:
- Spiller A venter 600 sek, svarer på 4 sek → nevner = 4 + 120 = 124
- Spiller B venter 120 sek, svarer på 4 sek → nevner = 4 + 24 = 28

Spiller B får betydelig høyere poeng selv med identisk svartid, fordi de reagerte raskere på at det var deres tur.

Vinnerbonus: +20 % på total rundepoeng.

---

## 8. Scoreboard og sosiale funksjoner

### 8.1 Venner
- Søk etter og legg til andre spillere via brukernavn
- Se venners profilkort: brukernavn, alder, snittpoeng per modus, siste aktivitet

### 8.2 Scoreboard-visninger
| Visning | Beskrivelse |
|---|---|
| Venner | Rangering blant egne venner, alle tider |
| Lokalt | Rangering blant spillere innenfor valgt radius (1 km / 5 km / 25 km / 50 km) |
| Globalt | Topp 100 globalt |

Scoreboard viser: Rang, brukernavn, alder, snittpoeng siste 30 dager.

### 8.3 Profilkort
- Vises ved å trykke på et brukernavn i scoreboard eller venneliste
- Innhold: brukernavn, alder, snittpoeng Pi-modus, snittpoeng Regnestykkemodus, antall runder spilt, member since

---

## 9. Gratis vs. betalt

| Funksjon | Gratis | Betalt |
|---|---|---|
| Oppgaver per dag | 20 | Ubegrenset |
| Begge spillmodi | ✅ | ✅ |
| Flerspiller | ✅ | ✅ |
| Scoreboard | ✅ | ✅ |
| Venneliste | ✅ | ✅ |

### 9.1 Betalingsalternativer
- **Månedlig abonnement:** 19 kr/mnd (månedlig fornyelse, kan avsluttes når som helst)
- **Årlig abonnement:** 99 kr/år (årlig fornyelse, kan avsluttes når som helst)
- **Engangskjøp:** 199 kr (livsvarig tilgang, ingen gjentakende belastning)

Betaling håndteres via Apple In-App Purchase (StoreKit 2).

Daglig kvote nullstilles ved midnatt (lokal tid). Spillere varsles med et banner når de nærmer seg grensen (16/20 oppgaver brukt).

---

## 10. Brukergrensesnitt – designprinsipper

- **Minimalistisk:** Hvit/lys bakgrunn, én primærfarge, tydelige fonter med stor kontrast
- **Én handling per skjerm:** Aldri mer enn én primærknapp synlig om gangen under spilling
- **Tilstandsindikator:** Liv og hopp alltid synlig øverst under spilling
- **Ingen distraksjoner:** Ingen bannere eller reklame av noe slag

### 10.1 Skjermoversikt

1. **Velkomstskjerm** – Sign in with Apple-knapp
2. **Brukernavnvalg** – Enkel tekstinnskriving med live-validering
3. **Onboarding** – 4 skjermbilder, kan hoppes over
4. **Hjemskjerm** – Moduskort (Pi / Regning), snarvei til alle 10 modi, Flerspiller-seksjon, aktivitetsfeed
5. **Se alle modi** – Sheet med alle 10 spillmodi
6. **Spillskjerm** – Oppgave sentrert, liv/hopp øverst, svar-knapper nederst (felles layout, all-modi)
7. **Rundeslutt** – Poengoppsummering, sammenligning med venner, "Spill igjen"-knapp
8. **Scoreboard** – Tab: Venner / Lokalt / Globalt
9. **Min profil** – Egne stats, fremgang per modus, venner, avatar-velger
10. **Annens profil** – Stats + "Utfordre" og "+ Venn"-knapper
11. **Innstillinger** – Konto, abonnement, personvern, tilbakemelding, logg ut
12. **Flerspillerlobby** – Opprett rom / bli med i rom, spillerstatus
13. **Flerspiller-spill** – Live turbasert spill med LIVE-indikator og spillerrekkefølge
14. **Flerspiller-invitasjoner** – Liste over ventende invitasjoner
15. **Flerspiller ferdig** – Vinner + resultater
16. **Aktive spill** – Liste over pågående background-rooms (solo og flerspiller)

---

## 11. Tekniske krav

| Krav | Spesifikasjon |
|---|---|
| Plattform | iOS 16+ |
| Språk | Swift / SwiftUI |
| Backend | REST API (HTTPS) + WebSocket (WSS) for sanntids flerspiller; implementeres i M6 |
| Lokal utvikling | Docker Compose: API + PostgreSQL + Redis + MinIO (S3-kompatibel lokal lagring) |
| Produksjonshosting | Railway (EU/Frankfurt): API-server + Admin-webapp + Managed PostgreSQL + Managed Redis |
| Objektlagring (prod) | Cloudflare R2 (EU, ingen egress-kostnader, erstatter MinIO fra lokal utvikling) |
| CI/CD | GitHub Actions: automatisk bygg + test ved push; automatisk deploy til staging, manuell godkjenning til produksjon |
| Autentisering | Sign in with Apple (AuthenticationServices) |
| Betaling | StoreKit 2 |
| Databaser | Brukerdata GDPR-compliant, lagret i EU-region |
| Lokasjon | CoreLocation kun for scoreboard-radius, ikke lagret på server |
| Offline | Enkeltspiller kan spilles offline; data bufres lokalt og synkroniseres ved reconnect. Flerspiller krever aktiv internettilkobling. |
| Lokalisering | All tekst i appen, onboarding-illustrasjoner og App Store-materiell leveres på norsk og engelsk. Språk følger iPhone-systemspråket automatisk (NSLocalizedString / String Catalogs). |

---

## 12. Personvern og GDPR

- Fødselsdato brukes kun til aldersberegning og lagres kryptert
- Nøyaktig GPS-posisjon lagres aldri; kun radius-søk utføres i øyeblikket
- Brukere kan slette konto og all tilknyttet data fra profilsiden
- Apple-bruker-ID anonymiseres i backend (hashed)

---

## 13. Scope – MVP vs. fremtidige versjoner

### Implementert per M5
- 10 spillmodi (solo og flerspiller)
- Sign in with Apple + brukernavn
- Kontinuerlig progresjon med adaptiv vanskelighetsgrad
- Venneliste og scoreboard (venner + lokalt + globalt)
- Sanntids flerspiller (opptil 8 spillere, alle 10 modi)
- Dagkvote (20 oppgaver for gratisbrukere) – lokal, backend ikke implementert
- Avatar-velger og tilbakemeldingsfunksjon
- Solo-økt-persistens ("background rooms")

### Fremtidige versjoner
- Push-varslinger ("Venn utfordrer deg")
- Sesongbaserte rangeringer med premier
- Android-versjon
- Daglige utfordringer med felles scoreboard
- Achievements/merker

---

## 14. Notifikasjoner

Push-notifikasjoner skal være sparsomt brukt og kun sendes ved hendelser som krever brukerens oppmerksomhet. Notifikasjoner håndteres via APNs (Apple Push Notification service).

| Hendelse | Notifikasjonstekst (eksempel) |
|---|---|
| Din tur i flerspillerrunde | "Det er din tur i runden med @brukernavn!" |
| Spillrunde er over | "Runden er ferdig – se resultatet!" |
| Invitasjon til spill | "@brukernavn inviterer deg til en runde" |

Ingen markedsføringsnotifikasjoner eller påminnelser om daglig kvote sendes.

---

## 15. Onboarding

Vises én gang etter at brukeren har registrert seg og valgt brukernavn. Består av 3–4 enkle skjermbilder med illustrasjoner og korte tekster.

| Skjerm | Innhold |
|---|---|
| 1 | Velkommen – kort intro til de to spillmodiene med et eksempelbilde av spillskjermen |
| 2 | Liv og hopp – animert illustrasjon som viser hva som skjer ved feil svar og ved hopp |
| 3 | Score – enkel visuell forklaring av hvordan nøyaktighet og hastighet teller |
| 4 | Venner og scoreboard – vis hvordan en finner venner og ser rangeringer |

Brukeren kan hoppe over onboarding og få den opp igjen fra profilsiden.

Alle onboarding-skjermbilder, illustrasjoner og tekster leveres på norsk og engelsk, og vises i henhold til iPhone-systemspråket.

---

## 16. Feilhåndtering og spillregler

### 16.1 Timeout
Om brukeren ikke svarer innen **10 sekunder** brukes ett hopp automatisk. Neste oppgave presenteres først når brukeren aktivt interagerer med appen (f.eks. trykker på skjermen). Dette sikrer at spillet ikke rykker videre uten at brukeren er til stede.

### 16.2 Forlate en spillrunde
- Inne i spillrunden vises en diskret "Forlat spill"-knapp, kun synlig når det er brukerens tur
- Ved trykk vises en bekreftelsesdialog: "Er du sikker på at du vil forlate spillet?"
- Ved bekreftelse: brukeren trekker seg ut, behandles som om liv er brukt opp (ute av runden)
- Brukeren kan umiddelbart starte eller bli med i en ny runde (solo eller flerspiller)

### 16.3 Tilkoblingsproblemer i flerspiller
- Ved kortvarig frakoblings (under 15 sek): spillet venter, de andre spillerne ser "Venter på @brukernavn…"
- Ved lengre frakobling: spilleren behandles som om de har forlatt spillet frivillig (se 16.2)
- Ingen straff på scoreboard for tilkoblingsproblemer (runden teller ikke)

---

## 17. Anti-juks og dataintegritet

### 17.1 Serverside fasit
Korrekte svar genereres og valideres utelukkende på server. Klienten sender kun brukerens valg – aldri fasiten eller valideringen.

### 17.2 Tidsvalidering
Serveren avviser svar der oppgitt responstid er fysisk umulig (under 200 ms). Svar med ugyldig tid logges og ignoreres.

### 17.3 Session-tokens
Hver spillrunde tildeles et unikt server-generert token ved oppstart. Svar uten gyldig, aktivt token avvises.

### 17.4 API rate limiting
Maks antall API-kall per bruker per sekund begrenses på servernivå. Automatiserte scripts som sender svar i bulk blokkeres.

### 17.5 Avviksdeteksjon og flagging
- Brukere med konsekvent responstid under 400 ms over 5 eller flere runder flagges automatisk
- **Flagget bruker** får et synlig varslingsikon i appen (🚩 ved brukernavnet)
- Brukeren kan trykke på ikonet for å lese en forklaring: "Kontoen din er flagget for gjennomgang av mulig uvanlig aktivitet. Dette påvirker ikke spilling, men scoren din er midlertidig skjult fra globalt scoreboard."
- Flagget vises også for andre spillere på profilkortet og i scoreboard
- Ingen automatisk utestengelse – kun manuell gjennomgang av administrator
- Ved gjennomgang: flagg fjernes (uskyldig) eller konto suspenderes manuelt

**Implementasjonsstatus:** Flagging er per M5 klientbasert (lagret i `UserDefaults`). I M6 flyttes flagging serverside der timing-data valideres uavhengig av klienten.

**Administrativ gjennomgang (M6+):**

| Steg | Handling |
|---|---|
| Hent rundehistorikk | `SELECT * FROM rounds WHERE user_id = ? ORDER BY created_at DESC LIMIT 50` |
| Sjekk snittid | `AVG(answer_time_ms)` – under 400 ms konsekvent er mistenkelig |
| Sjekk streak | Ubrutt riktig-rekke over 20+ spørsmål på høy vanskelighetsgrad |
| Krysskjekk enhet | Flere kontoer fra samme enhet-fingeravtrykk |

| Utfall | Handling |
|---|---|
| Falsk positiv | Fjern flagg: `PATCH /admin/users/:id { "flagged": false }` |
| Bekreftet juks | Suspender: `PATCH /admin/users/:id { "suspended": true }` |
| Uklart | La flagg stå, overvåk 7 dager til |

---

## 18. App Store-metadata

| Felt | Innhold |
|---|---|
| **Appnavn** | MindDuel |
| **Undertittel** | Hjernetrim mot venner |
| **Kategori** | Games → Trivia / Education |
| **Aldersgrense** | 9+ (anbefalt, pga. konkurranseelement og tall) |
| **Støttede språk (MVP)** | Norsk, Engelsk |
| **Beskrivelse (kort) – NO** | Konkurrér mot venner i Pi-gjetting og regnestykker – jo raskere og mer nøyaktig, jo bedre score. |
| **Beskrivelse (kort) – EN** | Compete with friends in Pi-guessing and math challenges – the faster and more accurate, the higher your score. |
| **Nøkkelord – NO** | hjernetrim, matte, pi, venner, konkurranse, regnestykke, quiz, læring, tall |
| **Nøkkelord – EN** | brain training, math, pi, friends, compete, quiz, mental math, learning, numbers |

**Lang beskrivelse – Norsk (App Store):**
> MindDuel er hjernetrening som faktisk er gøy – og enda gøyere når du konkurrerer mot venner.
>
> Velg mellom to utfordringer: gjett neste siffer i Pi-rekken, eller løs regnestykker i stadig økende vanskelighetsgrad. Du har fem liv og fem hopp – bruk dem klokt. Scoren din avgjøres av både hvor mange oppgaver du klarer og hvor raskt du svarer.
>
> Spill alene, sett rekord på scoreboard, eller inviter venner til en felles runde der dere veksler på å svare – siste mann stående vinner.
>
> • Enkelt, rent brukergrensesnitt uten forstyrrelser
> • Vanskelighetsgrad tilpasset din alder automatisk
> • Se hvordan du rangerer blant venner og spillere i nærheten
> • Gratis å spille – 10 oppgaver daglig inkludert

**Lang beskrivelse – English (App Store):**
> MindDuel is brain training that's actually fun – and even more fun when you're competing against friends.
>
> Choose between two challenges: guess the next digit in the Pi sequence, or solve math problems at increasing difficulty. You have five lives and five skips – use them wisely. Your score depends on both how many problems you solve and how fast you answer.
>
> Play solo, set records on the scoreboard, or invite friends to a shared round where you take turns answering – last one standing wins.
>
> • Clean, distraction-free interface
> • Difficulty automatically adjusted to your age
> • See how you rank among friends and nearby players
> • Free to play – 10 problems included daily

**App Store-bilder:**
Skjermbilder og grafikk leveres i to sett – ett per språk – der all synlig tekst i bildene er lokalisert. Dette gjelder:
- Skjermbilder av spillskjermen (oppgaver, liv/hopp-indikator, score)
- Onboarding-illustrasjoner
- Markedsføringsbanner (hvis aktuelt)

---

## 19. Visuelt design og UX

### 19.1 Mørk modus
Appen bruker utelukkende mørk modus, tvunget via `.preferredColorScheme(.dark)` uavhengig av systeminnstillingen. Det finnes ingen valg i appen. Color Assets har ikke light-varianter. Lys modus er backlog for v2.

### 19.2 Haptics
Subtil haptisk tilbakemelding ved:
- ✅ Riktig svar – lett "success"-vibrasjon (UINotificationFeedbackGenerator.success)
- ❌ Feil svar – kort "error"-vibrasjon (UINotificationFeedbackGenerator.error)
- ⏭ Hopp brukt – nøytral "impact"-vibrasjon (UIImpactFeedbackGenerator.light)

Haptics kan ikke skrus av i appen, men følger systeminnstillingen "Haptisk tilbakemelding" i iPhone-innstillingene.

---

## 20. Backend-arkitektur og admin (M6)

### 20.1 Sentral datalagring
All brukerdata, progresjon, scores og spilløkter lagres i backend-database (EU-region, GDPR-compliant). Dette muliggjør:
- Bruk av samme konto på flere enheter
- Sanntids flerspiller
- Serverside validering og anti-juks-kontroll

Solo-spill kan spilles uten internett; buffrede data synkroniseres ved reconnect. Flerspill krever aktiv tilkobling.

Dagkvoten håndheves på to nivåer: lokalt i appen (forhindrer spill over grensen ved offline-bruk) og serverside ved tilkobling (autoritativ kilde, overstyrer lokal teller og korrigerer eventuelle avvik ved reconnect). Dette sikrer at offline-spill ikke kan brukes til å omgå dagsgrensen.

### 20.2 Sikkerhet
- All kommunikasjon skjer over HTTPS (REST) og WSS (WebSocket)
- JWT-tokens autentiserer alle API-kall fra appen; tokens roteres jevnlig
- `id_token` fra Sign in with Apple verifiseres kryptografisk serverside mot Apples JWKS-endepunkt; backend aksepterer aldri et Apple-token uten uavhengig validering
- Alle API-endepunkter har `/v1/`-prefiks fra dag én; eldre klientversjoner støttes til en eksplisitt deprecation-dato
- Sensitiv brukerdata (fødselsdato, Apple-ID) lagres kryptert
- API rate limiting og throttling beskytter mot automatiserte angrep
- Admin-grensesnitt har eget autentiseringssystem med rollebasert tilgangskontroll

### 20.3 Spørsmålsbank og bildehosting
Spørsmål for alle kunnskapsbaserte modi og bilder appen bruker (f.eks. flagg) administreres sentralt:

| Ressurs | Versjonering | Lokal cache | Fallback |
|---|---|---|---|
| Spørsmålspakker | Versjonsnummer per modus | Ja, lagres til ny pakke er lastet | Bundlet i appen |
| Bilder | Hash-basert | Ja, etter første nedlasting | Bundlet i appen |

Appen sjekker ved oppstart og jevnlig i bakgrunnen om det finnes oppdatert innhold.

### 20.4 Spillmodus-konfigurasjon
Admin kan aktivere, skjule og fjerne spillmodi uten app-oppdatering. Støtter midlertidige/sesongbaserte modi (påske, VM, OL, jul osv.) med planlagte start- og sluttidspunkter. Appen henter aktiv moduskonfigurasjon ved oppstart med lokal fallback ved offline.

### 20.5 Bruksstatistikk og telemetri
Appen sender anonym, batch-basert telemetri (ingen PII): skjermvisninger, funksjonsklikk, sesjonslengde, feilhendelser. Admin-dashboard viser nøkkelmetrikker: DAU/MAU, populære modi, gjennomsnittlig sesjonslengde og dagkvote-utnyttelse.

### 20.6 Tilbakemeldingssystem
Brukere sender tilbakemelding via innstillingsskjermen. Backend lagrer tickets med status (åpen / under behandling / lukket). Admin kan svare direkte; svar leveres via APNs-notifikasjon eller in-app melding.

### 20.7 WebSocket-arkitektur
Redis brukes som pub/sub message broker mellom WebSocket-instanser slik at spillmeldinger rutes korrekt selv om klienter er koblet til ulike servere. Romtilstand (aktive spillere, tur, liv/hopp) lagres i Redis med TTL. Én Railway-instans dekker MVP-behovet, men arkitekturen er designet for horisontal skalering uten sticky sessions som krav. Serveren håndterer graceful shutdown ved deploy: pågående runder venter i maks 60 sekunder før prosessen stoppes.

### 20.8 Databasemigrering
Alle skjemaendringer gjøres via migrasjonsverktøy (Flyway, Liquibase eller Alembic) — ingen manuelle SQL-endringer direkte i produksjon. Migrasjonsstrategi er «additive first»: nye kolonner og tabeller legges til og backfylles før gamle fjernes, slik at eldre og nye app-versjoner kan kjøre mot samme database simultant (zero-downtime deploy). Ytelseskritiske spørringer (scoreboard, progresjon, rundehistorikk) har eksplisitte PostgreSQL-indekser definert i migrasjonsfiler.

### 20.9 Admin-grensesnitt
Web-basert grensesnitt med følgende moduler:

| Modul | Funksjonalitet |
|---|---|
| Brukeradministrasjon | Søk, vis profil, fjern flagg, suspender konto |
| Spørsmålsadministrasjon | CRUD, versjonspublisering, tagging (modus/nivå) |
| Bildeadministrasjon | Last opp, oppdater og arkiver bilder |
| Spillmodus-konfigurasjon | Aktiver/skjul/sesongsett modi |
| Tilbakemeldinger | Vis, kategoriser, svar og lukk tickets |
| Statistikk | DAU/MAU, populære modi, kvote-utnyttelse |

---

## 21. Backlog (fremtidige versjoner)

| Funksjon | Prioritet |
|---|---|
| Lyddesign (riktig/feil/timer-lyder, kan skrus av) | Middels |
| Tilgjengelighet – VoiceOver, dynamisk tekst, fargeblind-modus | Middels |
| Push-påminnelser om daglig streak (valgfritt, opt-in) | Lav |
| Mørk modus finjustering basert på brukertilbakemeldinger | Lav |
| Sesongbaserte rangeringer med premier | Lav |
| Daglige utfordringer med felles scoreboard | Lav |
| Android-versjon | Lav |
| Achievements/merker | Lav |

---

## 22. Avklarte designspørsmål

~~1. Skal hopp telles som "feil" i noen sammenheng, eller er de helt nøytrale?~~
**Avklart:** Hopp er helt nøytrale – ingen straff, påvirker ikke score.

~~2. Skal snitt-tidsberegningen ekskludere oppgaver som ble hoppet over?~~
**Avklart:** Ja – hoppede oppgaver ekskluderes fra tidsberegningen.

~~3. Skal flerspiller støtte ulike modi per rom?~~
**Avklart:** Alle spillere i et rom bruker alltid samme modus.

~~4. Nøyaktig vekting mellom tid og antall i scoreformelen~~
**Avklart:** Formelen bruker en kalibreringskonstant K (se §5). K fastsettes basert på data fra playtesting, og kan justeres i backend uten app-oppdatering.

~~5. Skal aldersbasert vanskelighetsgrad kunne overstyres manuelt av brukeren?~~
**Avklart:** Ja – brukeren kan manuelt velge et høyere eller lavere vanskelighetsintervall fra profilsiden. Alderen som vises for andre spillere forblir uendret (faktisk alder fra Apple-profil).

~~6. Daglig kvote – antall?~~
**Avklart:** 20 oppgaver per dag for gratisbrukere (`ProgressionStore.dailyQuota = 20`). Treningsrunder ekskluderes.

~~7. Lys modus i v1?~~
**Avklart:** Nei. Kun mørk modus, tvunget via `.preferredColorScheme(.dark)`. Lys modus er backlog for v2.
