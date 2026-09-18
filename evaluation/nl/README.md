# Nederlandse praktijktest — nog niet uitgevoerd

`prompts.json` bevat 55 leeszinnen, **geen audio-opnamen of gemeten resultaten**.
Gebruik alleen eigen/toegestane stemmen en geen echte klantgegevens. Publiceer
geen opnamen of transcripties zonder toestemming van de spreker.

## Protocol

1. Noteer commit, macOS, CPU, microfoon, model/checksum, taal, alle correctieopties
   en of live dicteren aanstaat. Begin met `nl` + `small-q5_1`, commando's uit.
2. Lees alle niet-commandozinnen in normaal tempo. Bewaar vrijwillig opgenomen
   WAV-bestanden lokaal (16 kHz mono voor whisper-cli). Herhaal korte fragmenten,
   bedragen en gemengde zinnen met natuurlijke pauzes en met achtergrondgeluid.
3. Test de vijf commandozinnen apart met commando's aan. Test diezelfde woorden
   ook als gewone inhoud met commando's uit. Probeer pauzes midden in een commando.
4. Vergelijk English + bestaand `.en`-model en Automatic + meertalig model.
   Automatische detectie is per opname/live-fragment, niet per woord.
5. Registreer ontbrekende/extra woorden, productnamen, getallen, regeleinden,
   annuleren, modelwissel, tijd tot eerste tekst en totale verwerkingstijd.
   Meet zowel koude als warme start. Vul geen geschatte cijfers in.
6. Test invoegen in concepten in Slack, Chrome, ChatGPT, PyCharm, Mail en TextEdit.
   Controleer Unicode, bestaande tekst/selecties en regeleinden. Verstuur niets.
7. Stop/start snel, annuleer tijdens verwerking, trek de microfoon los en probeer
   instellingen te wijzigen tijdens opname. Controleer dat audio nooit wordt
   doorgestuurd en dat een Engels model niet voor Nederlands wordt gebruikt.

## Scoren

Maak lokaal een JSONL-bestand met per opname `id`, `reference`, `hypothesis`.
Gebruik de werkelijk uitgesproken woorden als referentie voor **ruwe ASR**.
Beoordeel gecorrigeerde UI-tekst afzonderlijk met een bijpassende referentie;
getalwoorden en cijfers zijn bewust niet automatisch gelijkgesteld.

```sh
python3 scripts/evaluate-transcripts.py /path/to/local-transcripts.jsonl
```

Het script berekent woordfoutpercentage (WER) zonder hoofdletters/interpunctie.
Controleer leestekens, cijfers, namen en opmaak daarnaast handmatig: WER alleen
bewijst niet dat dicteren bruikbaar is. Sla lokale opnamen en beoordelingen niet
in deze openbare repository op.

## Vrijgavepoort

Nog nodig: geslaagde macOS-build en XCTest, bovenstaande opnamen, resultaten
per app, inspectie van NL-layout en toegankelijkheid, installatieproef DMG,
expliciete beoordeling door de gebruiker. Pas daarna een prerelease; geen
stabiele release op basis van alleen unit tests.
