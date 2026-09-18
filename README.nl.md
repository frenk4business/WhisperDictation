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

- De Nederlandse herkenningskwaliteit en snelheid zijn nog niet gemeten met echte
  opnamen. De geautomatiseerde tests controleren codegedrag, niet accenten,
  achtergrondgeluid, microfoonkwaliteit of Whisper-fouten.
- Gewone NL/Auto-dictatie typt pas na de volledige decode. Als de focus of cursor
  intussen verandert, kan tekst op de verkeerde plek terechtkomen. Live dicteren
  verlaagt die wachttijd, maar werkt per VAD-fragment.
- Automatisch bepaalt één taal per opname of live-fragment, niet per woord. Een zin
  met veel Nederlands én Engels kan daardoor de verkeerde correctielaag krijgen;
  korte fragmenten zijn extra lastig te detecteren.
- De corrector herschrijft geen grammatica, spelling of betekenis. Hij verzorgt
  hoofdletters, spaties, enkele vaste termen en beperkte getalconversie.
- Getalconversie herkent vooral aaneengeschreven vormen tot 999.999 en eenvoudige
  decimalen zoals ‘drie komma vijf’. `een` blijft conservatief een lidwoord. Datums,
  tijden, valuta, percentages, telefoonnummers, reeksen en vrije combinaties van
  losse getalwoorden hebben geen semantische parser.
- Gesproken commando's zijn contextongevoelig en daarom standaard uit. Met de optie
  aan wordt bijvoorbeeld elk los woord ‘punt’ een leesteken. Een commando of getal
  dat door een live-VAD-pauze over twee fragmenten valt, wordt niet samengevoegd.
- Technische termen en de eigen woordenlijst sturen Whisper en herstellen casing,
  maar garanderen geen juiste herkenning van productnamen of gemengde vaktaal.
- Tekstinvoer gebruikt macOS Accessibility en Unicode-toetsaanslagen. Regeleinden
  zijn geen verzendsneltoets; beveiligde velden en sommige apps kunnen invoer
  blokkeren of anders verwerken. Test vooral chatapps en terminals eerst in concepten.
- De testbuild is ad-hoc ondertekend en niet door Apple genotariseerd. De fork deelt
  momenteel bundle-ID, instellingen en modellenmap met de originele app; installeer
  of draai beide varianten niet tegelijk.

## Testen en vrijgeven

Er zijn [55 voorleeszinnen en een testprotocol](evaluation/nl/README.md), maar
nog geen opnamen, WER-scores of snelheidsmetingen. Publiceer geen privéopnamen
in deze openbare repository. De releaseworkflow maakt alleen een **concept-prerelease**.
Er is geen tag of release gepubliceerd. CI levert wel een DMG-testpakket met
checksum. Echte dicteer- en invoegtests zijn nodig vóór vrijgave.
