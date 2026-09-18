# Nederlandse testversie proberen

Voor macOS 14 (Sonoma) of nieuwer, op Apple Silicon of Intel.
Dit is een ontwikkelversie voor lokale praktijktests, geen stabiele release.

## Downloaden en openen

1. Log in op GitHub en open de geslaagde CI-run van de branch
   `feature/dutch-language-support` in `frenk4business/WhisperDictation`.
2. Download onder **Artifacts** het pakket **WhisperDictation-Dutch-test-macOS**.
3. Pak de ZIP uit en open **WhisperDictation.dmg**. Sleep **WhisperDictation** naar
   **Applications/Programma's**. Sluit eerst een eventueel draaiende oude versie.
4. Open WhisperDictation vanuit Programma's. De app verschijnt in de menubalk;
   er hoeft geen normaal appvenster of Dock-pictogram te verschijnen.

Deze build is ad-hoc ondertekend, maar niet door Apple genotariseerd. macOS kan
bij de eerste start een melding over een onbekende ontwikkelaar geven. Volg
alleen voor deze zelfgekozen testdownload Apple's uitleg over het openen van
een app van een onbekende ontwikkelaar:
https://support.apple.com/nl-nl/guide/mac-help/mh40616/mac

Je hoeft geen algemene beveiligingsinstellingen uit te schakelen. Krijg je een
andere melding, bijvoorbeeld dat het bestand beschadigd is? Bewaar de exacte
melding of een screenshot zodat we die kunnen onderzoeken.

De originele app en deze fork gebruiken dezelfde instellingen en modellenmap.
Draai ze niet tegelijkertijd. Wil je een oude versie bewaren, verplaats die
eerst naar een andere map voordat je de testversie installeert.

## Nederlands instellen

1. Verleen **Microfoon**- en **Toegankelijkheid**-toegang als de app daarom vraagt.
   Toegankelijkheid is nodig voor de sneltoets en het invoegen van tekst.
2. Open via het menubalkpictogram **Instellingen → Algemeen**.
3. Kies bij **Gesproken taal**: **Nederlands**. Kies eventueel ook Nederlands als
   interfacetaal. Een bestaande Engelse installatie wordt niet automatisch omgezet.
4. Download bij **Model**: **Small Q5 (meertalig)**, ongeveer 190 MB. Kies zo nodig
   **Activeren** en wacht tot de app **Gereed** meldt. Gebruik geen model met `.en`.
5. Laat **Live dicteren** en **Gesproken Nederlandse leestekens** bij de eerste
   test uit. Controleer de gekozen sneltoets; standaard is dit de rechter Option/⌥.

## Eerste test van vijf minuten

Open een leeg document in **TextEdit** en zet de cursor in het document. Houd de
sneltoets ingedrukt, spreek, laat los en wacht tot de tekst verschijnt.

Probeer achtereenvolgens:

- “Goedemorgen, ik wil vandaag mijn planning bespreken.”
- “Kun je het Grafana dashboard aanpassen en een bericht in Slack sturen?”
- “Er zijn tweeënveertig nieuwe berichten.”
- “De temperatuur is drie komma vijf graden.”
- “Het budget is vijfduizend euro.”

Met getalconversie aan verwacht je onder meer **42**, **3,5** en **5000** (of
**5.000** bij gegroepeerde getalnotatie). Controleer of woorden ontbreken of
verdubbelen en of GitHub, API, JSON, OpenAI en ChatGPT goed gespeld worden.

Test daarna pas in een leeg concept in Slack, ChatGPT, Mail of je editor.
Gesproken leestekens kun je afzonderlijk aanzetten en proberen met:
“Hallo punt nieuwe regel dit is een test.” Test regeleinden eerst in TextEdit.
Commando's die je over twee afzonderlijke live-pauzes verdeelt, worden nog niet
samengevoegd. Live dicteren vereist daarnaast het Silero VAD-model.

## Feedback

Geef door: Mac/macOS-versie, gekozen model, live aan/uit, wat je zei, welke tekst
verscheen en ongeveer hoe lang het duurde. Een screenshot van een foutmelding
helpt. Gebruik testzinnen zonder privé- of klantgegevens; audio blijft lokaal.

Voor een uitgebreidere proef: `evaluation/nl/prompts.json` bevat 55 zinnen.
De SHA-256-checksum van de DMG staat naast de download. Optioneel controleren:

```sh
shasum -a 256 -c WhisperDictation.dmg.sha256
```
