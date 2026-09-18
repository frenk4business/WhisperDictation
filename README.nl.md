# WhisperDictation — Nederlands, Engels en Automatisch

Ontwikkelfork van [sam-pop/WhisperDictation](https://github.com/sam-pop/WhisperDictation),
met behoud van de oorspronkelijke MIT-licentie en copyrightvermelding.
De Nederlandse uitbreiding is **nog niet stabiel vrijgegeven of met echte dictatie gevalideerd**.
De universele macOS-build, 149 Swift-tests en 7 toolingtests zijn geslaagd.
Een DMG voor praktijktests wordt bij elke CI-build gemaakt: zie [testinstructies](TESTEN.nl.md).
Zie [DEVELOPMENT.md](DEVELOPMENT.md) en [concept-PR #1](https://github.com/frenk4business/WhisperDictation/pull/1).

## Wat is toegevoegd?

- Nederlands (`nl`), Engels (`en`) en automatische taaldetectie (`auto`).
- Meertalige `base-q5_1`, `small-q5_1` en `medium-q5_0`, met SHA-256-controle.
- Nederlands als standaard voor een nieuwe installatie; bestaande instellingen
  blijven Engels. Engels behoudt de bestaande corrector en regressietests.
- Nederlandse en Engelse interface, afzonderlijk instelbaar van de gesproken taal.
- Nederlandse getalwoorden (zoals `tweeënveertig`), decimale komma, hoofdletters,
  leestekenspatiëring, productnamen en persoonlijke termen.
- Optionele gesproken commando's: punt, komma, vraagteken, uitroepteken,
  dubbele punt, nieuwe regel, nieuwe alinea. Standaard uit.

## Instellen op een Mac

Na een geslaagde build: open Instellingen → Algemeen → Gesproken taal.
Kies **Nederlands** en download **Small Q5 (meertalig)** bij Model. De interface
kan onafhankelijk op Nederlands of Engels staan. Geef zelf microfoon- en
toegankelijkheidstoegang in macOS. Audio wordt lokaal verwerkt; alleen het
downloaden van modellen vereist internet.

Nederlands en Automatisch accepteren geen `.en`-model. Bij een taalwissel wordt
een incompatibele selectie vervangen door `small-q5_1`; er start geen automatische
grote download. Download het model eerst en activeer het. Bestaande modellen
worden niet verwijderd. De prompt/woordenlijst wordt per gesproken taal bewaard;
persoonlijke termen zijn gedeeld.

## Zelf bouwen

Benodigd: macOS 14+, Xcode Command Line Tools, CMake en Python 3. Voor XCTest:
volledige Xcode en XcodeGen. Gebruik deze fork, niet de upstream-download.

```sh
git clone --recurse-submodules https://github.com/frenk4business/WhisperDictation.git
cd WhisperDictation
git switch feature/dutch-language-support
make whisper
make app
make model
open build/WhisperDictation.app
```

Tests: `xcodegen generate`, daarna
`xcodebuild test -project WhisperDictation.xcodeproj -scheme WhisperDictation -destination 'platform=macOS'`.
De directe Make-build compileert dezelfde vertaalcatalogus als Xcode. De app
heeft alleen ad-hoc-ondertekening; Apple-notarisatie is niet ingericht.

De fork behoudt momenteel de oorspronkelijke bundle-ID en modellenmap voor
migratie. Installeer/draai de originele en aangepaste app niet tegelijk.

## Grenzen van deze eerste implementatie

- De corrector herschrijft geen grammatica of betekenis. `een` blijft een lidwoord;
  `één` kan een cijfer worden. Datums, tijden, losse telreeksen, telefoonnummers en
  alle mogelijke losse getalwoordcombinaties worden niet intelligent geïnterpreteerd.
- Samengestelde gehele getallen worden herkend tot 999.999. De decimale regel
  ondersteunt één getal na ‘komma’; spreek bijvoorbeeld ‘drie komma vijf’.
- Technische termen helpen de herkenning, maar garanderen geen foutloze vaktaal.
- Automatisch bepaalt de taal per opname/live-fragment, niet per woord.
  Voor overwegend Nederlandse technische zinnen is Nederlands het uitgangspunt.
- Gewone NL/Auto-dictatie typt na de volledige decode. Live dicteren typt per
  VAD-fragment. Spreek getallen en commando's zonder lange tussentijdse pauze:
  correctie over twee afzonderlijke live-fragmenten is nog niet geïmplementeerd.
- Regeleinden zijn Unicode-tekst, geen verzendsneltoets. Het gedrag verschilt per
  app: test eerst in concepten, vooral in chatapps en terminals.

## Testen en vrijgeven

Er zijn [55 voorleeszinnen en een testprotocol](evaluation/nl/README.md), maar
nog geen opnamen, WER-scores of snelheidsmetingen. Publiceer geen privéopnamen
in deze openbare repository. De releaseworkflow maakt alleen een **concept-prerelease**.
Er is geen tag of release gepubliceerd. CI levert wel een DMG-testpakket met
checksum. Echte dicteer- en invoegtests zijn nodig vóór vrijgave.
