# Vokabeltrainer – Green Line Bayern (Klasse 5–10)

Offline-Vokabeltrainer für das Englischbuch **Green Line, Ausgabe Bayern
ab 2017** am bayerischen Gymnasium. Reine Web-App, die per
[apk-builder](../apk-builder) zur signierten Android-APK wird – kein
Framework, keine externen Abhängigkeiten, kein Netzwerkzugriff zur Laufzeit.

Zwei Abfragearten: **Multiple Choice** und **Selbsteingabe** mit toleranter
Prüfung. Dazu ein Leitner-Boxensystem, ein automatisches Deck „Schwierige
Wörter" und ein Editor für eigene Listen.

## Woher die Vokabeln kommen

Der Ernst Klett Verlag stellt den Lernwortschatz aller sechs Bände als
kostenlose PDFs bereit – ursprünglich als Hilfe für ukrainische Geflüchtete,
mit den Spalten *Lektion | Englisch | Phonetik | Deutsch | Ukrainisch*:

<https://www.klett.de/inhalt/vokabellisten/green-line-bayern-(ausgabe-2017)/278509>

Die App enthält damit exakt den Wortschatz, der im Unterricht abgefragt wird –
nichts davon ist erfunden oder nachempfunden.

```powershell
.\tools\fetch-vocab.ps1      # laedt die 6 PDFs nach source-pdfs\
.\tools\build-vocab.ps1      # erzeugt web\data\vocab.gl1..6.js
```

**Die PDFs tragen „© Ernst Klett Verlag … Alle Rechte vorbehalten".** Privat
damit zu lernen ist unproblematisch, die Liste weiterzuverbreiten nicht –
deshalb stehen `source-pdfs/` und `web/data/vocab.gl*.js` in `.gitignore`.
Im Repo liegen nur Code, die beiden Skripte und eine eigene Demo-Liste. Wer
klont, erzeugt die Daten mit den zwei Befehlen oben selbst.

Der Vollständigkeit halber: eine fertig gebaute **APK unter Releases enthält
den Wortschatz mit** – dort greift der `.gitignore` naturgemäß nicht.

### Wie die Extraktion funktioniert

`build-vocab.ps1` ruft `pdftotext -table` auf (liegt bei Git für Windows
unter `mingw64\bin` bei – kein zusätzlicher Download) und zerlegt die Tabelle
**positionsbasiert**:

```
U1   S1   family tree   !*fxmli +tri:?   Stammbaum   <kyrillisch>
^0   ^sec ^enStart      ^phonStart       ^deStart    ^erstes kyrillisches Zeichen
```

Zwei Stolpersteine, die den naheliegenden Weg versperren:

- **Die Spaltenoffsets ändern sich von Seite zu Seite** und stimmen auch
  nicht mit der Kopfzeile überein (Überschriften sind zentriert, Daten
  linksbündig). Sie werden deshalb je Seite aus den Datenzeilen selbst
  ermittelt: das `!` der Phonetik als Anker, davor die letzte häufige
  Spaltenposition als Englisch-Spalte, dahinter der erste Text nach dem `?`
  als Deutsch-Spalte.
- **Lange Zellen brechen um.** Zeilen ohne Lektionscode sind Fortsetzungen
  und werden spaltenweise an den vorherigen Datensatz angehängt.

Verworfen werden die Phonetik-Spalte (Kletts eigene ASCII-Notation, kein IPA)
und die ukrainische Spalte.

**Ergebnis (geprüft):** 4.834 Vokabeln, 0 verworfen.

| Band | Klasse | Vokabeln | Lektionen |
| --- | --- | --- | --- |
| Green Line 1 | 5 | 1.099 | PUA, PUB, U1–U6, AC1–AC3, F1–F3 |
| Green Line 2 | 6 | 964 | U1–U6, AC1–AC3, F1–F3 |
| Green Line 3 | 7 | 660 | U1–U4, AC1–AC3, F1–F2, TS1–TS2 |
| Green Line 4 | 8 | 669 | U1–U4, AC1–AC3, F1–F3, TS1–TS2 |
| Green Line 5 | 9 | 682 | U1–U3, AC1–AC3, F1–F2, TS1–TS2 |
| Green Line 6 | 10 | 760 | U1–U3, AC1–AC4, F1–F5, TS |

Die Zahlen je Lektion wurden gegen eine rohe Zählung im PDF
(`pdftotext -table gl1.pdf - | grep -cE '^U1 '`) abgeglichen und stimmen auf
den Eintrag genau.

## Datenmodell

`web/data/index.js` (eingecheckt) hält Band-Metadaten und Unit-Titel,
`web/data/vocab.gl<N>.js` (generiert) die Vokabeln:

```js
window.VOCAB_GL1 = {
  band: 'gl1', version: 1,
  units: [{ code: 'U1', words: [
    { en: 'family tree', de: ['Stammbaum'], kind: 'w', sec: 'S1' },
    { en: "What's your name?", de: ['Wie heißt du?', 'Wie heißen Sie?'], kind: 'p' }
  ]}]
};
```

- `de` ist immer eine **Liste** – Kletts Semikolon trennt gleichwertige
  Übersetzungen, und genau die zählen bei der Selbsteingabe alle als richtig.
- `kind`: `w` = Einzelwort/kurze Wendung, `p` = ganzer Satz (Satzzeichen am
  Ende oder mehr als drei Wörter). Der Schalter „Nur Einzelwörter" filtert
  darüber, und in der gemischten Abfrage bekommen Sätze immer Multiple
  Choice statt Eintippen.
- `sec` ist der Abschnitt innerhalb der Unit (`CI`, `S1`–`S3`, `SK2`, `ST`,
  `UT`, `CO`). Die Klartext-Namen dafür stehen in `index.js` unter
  `secLabels` und sind eine **Auslegung der Kürzel** – wenn im Buch etwas
  anderes steht, dort korrigieren.

Bänder werden einzeln über ein eingefügtes `<script>`-Tag nachgeladen (nicht
per `fetch`, das unter `file://` scheitert), damit beim Start nicht alle
4.834 Vokabeln geparst werden.

## Lernlogik

**Leitner-Boxen 1–5 pro Vokabel.** Richtig → eine Box hoch (max. 5), falsch →
zurück auf Box 1, „fast richtig" (Tippfehler) → Box bleibt stehen. Ab Box 4
gilt eine Vokabel als „sitzt" und zählt in den Fortschrittsring.

**Portionsauswahl:** sortiert nach (Box aufsteigend, längster Abstand seit der
letzten Abfrage, Zufall), davon die ersten 10/15/20 – dann gemischt. Wer eine
Unit mehrfach übt, bekommt also zuerst das, was noch nicht sitzt.

### Ablenker bei Multiple Choice

Ablenker, die offensichtlich unmöglich sind, machen die Frage wertlos – man
rät die richtige Antwort weg, ohne die Vokabel zu kennen. Die App zieht
deshalb gezielt **zwei (manchmal drei) nahe** Ablenker und **einen deutlich
verschiedenen**. „Nah" wird ohne Wörterbuch aus vier Signalen gebildet:

| Signal | Punkte | warum |
| --- | --- | --- |
| Gleicher Abschnitt im Buch (`sec`) | +4 | gleicher Abschnitt = fast immer gleiches Thema |
| Nachbarschaft in der Buchreihenfolge (±15) | +3 | Ersatzsignal, wo es keine Abschnittscodes gibt (Pick-up A/B) |
| Gleiche grobe Wortart | +3 | `to …` = Verb, Großschreibung = Nomen, sonst klein |
| Gleiche Art (Wort/Satz) | +2 | kein Einzelwort gegen einen ganzen Satz |
| Schreib-Ähnlichkeit | 0–10 | Anfangsbuchstabe, Wortanfang, Wortende, Länge, Wortzahl |

Gezogen wird gewichtet aus dem oberen Feld statt stur von oben – dieselbe
Vokabel sieht bei der nächsten Runde also nicht genau gleich aus. Der
bewusst verschiedene Ablenker darf inhaltlich weit weg sein, aber nicht durch
seine Länge auffallen, sonst sticht die richtige Antwort wieder heraus.

In der Praxis sieht das so aus:

```
red    ->  violett | rot | blau | schwarz
three  ->  zwei | drei | ja | elf
blau   ->  blue | pink | red | people (pl)
wardrobe -> mehr | Keks | Küchenschrank | Kleiderschrank
```

**Nie als Ablenker** erscheint etwas, das für dieselbe Vokabel richtig wäre:
weder eine andere Übersetzung desselben Eintrags, noch ein Wort, das sich
eine Übersetzung mit dem gefragten teilt. Ohne diese Sperre wäre „friendly"
bei der Frage „nice" (*nett; schön; lieb*) als falsch gewertet worden,
obwohl es passt.

### Tolerante Prüfung bei Selbsteingabe

Das ist das Stück, an dem die App steht oder fällt – ein Trainer, der
„stammbaum" als falsch wertet, wird nicht benutzt.

1. **Normalisieren:** Kleinschreibung, Klammerzusätze (`(pl)`, `(Sg.)`) weg,
   Satzzeichen weg, Anführungszeichen weg, Mehrfach-Leerzeichen weg,
   führendes `to` / `the` / `a` / `an` bzw. `der` / `die` / `das` / `ein` weg.
2. **Umlaute falten:** `ä/ae → a`, `ö/oe → o`, `ü/ue → u`, `ß/ss → s`.
   Damit gelten „Mäuse", „Maeuse" und „Mause" alle als richtig.
3. **Alle Varianten prüfen:** jede Übersetzung aus `de`, und bei
   Einzelwörtern zusätzlich jeder Teil einer Aufzählung – „Maus (Sg.), Mäuse
   (Pl.)" akzeptiert „Maus" genauso wie „Mäuse".
4. **Tippfehler:** Levenshtein-Distanz ≤ 1 (ab 5 Zeichen) bzw. ≤ 2 (ab 9
   Zeichen) → „Fast! Achte auf die Schreibweise" mit der richtigen Lösung.
   Zählt als richtig, befördert die Vokabel aber **nicht** in die nächste Box.
   Unter 5 Zeichen wird nicht toleriert – bei „Idee"/„Idea" oder „nie"/„sie"
   wäre ein Zeichen Unterschied schon ein anderes Wort.

Mit `?test=1` an der URL liegen `normalize`, `fold`, `lev`, `checkAnswer` und
`parseImport` unter `window.__vt` zum Prüfen in der Konsole. 27 Fälle sind so
abgedeckt (siehe „Geprüft").

## Wortschatz eingrenzen (Hausaufgabe)

Eine Lektion hat 84 bis 157 Vokabeln – niemand lernt die an einem Tag. Jedes
Deck lässt sich deshalb über **Vokabeln auswählen** auf den Teil eingrenzen,
der heute dran ist. Die Liste steht in Buchreihenfolge und ist durchnummeriert,
damit „Nr. 1 bis 20" dem entspricht, was im Hausaufgabenheft steht.

- **Bereich**: „Nur Nr. \_\_ bis \_\_" setzt die Auswahl auf genau diesen Block
- **Schnellwahl**: *Alle*, *Keine*, *Noch offen* (alles, was noch nicht in
  Box 4 oder 5 sitzt) und ein Knopf je Abschnitt (*Check-in*, *Station 1*, …)
- **Einzeln antippen** für Korrekturen
- Jede Zeile zeigt Englisch, Deutsch, einen Punkt für den Lernstand (grau →
  gelb → grün) und die Markierung **Satz** bei ganzen Sätzen

Die Auswahl wird je Deck und Band gespeichert und bleibt bis zur nächsten
Änderung – am nächsten Tag also einfach weiterüben oder den Bereich
verschieben. Auf der Startseite steht dann „· 19 ausgewählt" an der Karte.
Sind alle Vokabeln ausgewählt, wird nichts gespeichert (das ist der
Normalzustand „alles").

Der frühere Filter **Abschnitt** auf dem Einstellungs-Bildschirm ist dabei
entfallen – die Abschnitts-Knöpfe in der Auswahl können dasselbe, lassen sich
aber kombinieren und nachbearbeiten.

Zusammen mit dem Schalter *Nur Einzelwörter* kann eine Auswahl kleiner
ausfallen als gedacht (Pick-up A besteht größtenteils aus ganzen Sätzen).
Der Einstellungs-Bildschirm sagt das dann ausdrücklich, statt es still zu tun:
„16 ausgewählte Vokabeln sind ganze Sätze und bleiben wegen *Nur
Einzelwörter* außen vor."

## Eigene Listen

Import per Einfügen, eine Vokabel pro Zeile. Als Trennzeichen zwischen
Englisch und Deutsch gehen `=`, ein Tabulator, ` - ` und ` – `; mehrere
gültige Übersetzungen mit `;`:

```
apple = Apfel
to run = rennen; laufen
grandmother - Oma
school	Schule
```

Zeilen ohne Trennzeichen werden übersprungen und gezählt. Eine gespeicherte
Liste lässt sich jederzeit wieder als Text öffnen und bearbeiten.

## Speicher (localStorage)

| Key | Inhalt |
| --- | --- |
| `vokabeltrainer.settings.v1` | Theme, Band, Richtung, Modus, Portionsgröße, Filter |
| `vokabeltrainer.progress.v1` | `{ "gl1\|U1\|family tree": {box, right, wrong, last} }` |
| `vokabeltrainer.stats.v1` | Lerntage (für die Serie), Übungen, Antworten |
| `vokabeltrainer.decks.v1` | eigene Listen |
| `vokabeltrainer.selection.v1` | eingegrenzter Wortschatz je Deck: `{ "gl1\|unit:U1": ["gl1\|U1\|at home", …] }` |

Keys sind versioniert und namespaced – bei einer Schemaänderung neue
Versionsnummer statt stiller Migration.

## Projektstruktur

```
build.ps1            apk-builder-Wrapper (Portrait-Lock, Keep-Screen-On, Predictive Back)
icon.xml             Launcher-Icon (Stapel Vokabelkarten mit Haken)
tools/
  fetch-vocab.ps1    laedt die 6 Klett-PDFs
  build-vocab.ps1    PDF -> web/data/vocab.gl<N>.js
  serve.ps1          lokaler Testserver auf http://localhost:8099
web/
  index.html         die komplette App (HTML+CSS+JS inline)
  data/index.js      Band-Metadaten, Unit-Titel, Abschnittsnamen (eingecheckt)
  data/demo.js       eigene Demo-Liste als Fallback (eingecheckt)
  data/vocab.gl*.js  generiert, gitignored
source-pdfs/         gitignored
```

## Bauen und Testen

```powershell
.\tools\serve.ps1                                      # http://localhost:8099
.\build.ps1                                            # Debug-APK
.\build.ps1 -Release                                   # signierte Release-APK
.\build.ps1 -Release -Install                          # + adb install
.\build.ps1 -VersionName "1.1" -VersionCode 2 -Release # bei jedem Release hochzaehlen
```

**Im Browser immer über `serve.ps1` testen, nicht per `file://`** – dort
schalten Browser localStorage still ab, und der Lernfortschritt verschwindet
beim Neuladen, ohne dass ein Fehler erscheint.

## Geprüft

Im Browser über `http://localhost:8099` (Chromium, Viewport 375 px):

- Konverter: Anzahl je Lektion stimmt für alle sechs Bände mit der Rohzählung
  im PDF überein, 0 Einträge verworfen; Umbruchzellen korrekt zusammengefügt
  („Hunde sind meine Freunde, aber Katzen nicht."), Umlaute intakt,
  Semikolon-Varianten getrennt (395 Einträge in Band 1 haben mehrere)
- Prüflogik: 27 Fälle über `?test=1`, alle grün – Groß/Klein, Leerraum,
  Umlaut-Umschreibungen, `ß`/`ss`, Artikel- und `to`-Präfix, Aufzählungen,
  Tippfehler-Toleranz und ihre Untergrenze
- Ablenker: über je 300–400 gezogene Fragen in Pick-up A/B, Unit 1, 3, 5 und 6
  in beiden Richtungen haben **96–100 %** der Fragen mindestens zwei Ablenker,
  die in Schreibweise oder Thema nahe an der richtigen Antwort liegen; bei
  38–62 % sind es alle drei. Immer vier Optionen, keine Dubletten, und in
  2–12 % sticht die richtige Antwort durch ihre Länge heraus
- Import-Parser: alle vier Trennzeichen, Mehrfach-Übersetzungen, kaputte
  Zeilen werden gezählt statt zu stören
- Kompletter Durchlauf Multiple Choice über 10 Vokabeln bis zur Auswertung,
  ebenso im gemischten Modus (Auswahl und Eintippen gemischt)
- Tastatur-Ablauf mit echten Tastendrücken: der erste Enter prüft und zeigt
  die Rückmeldung, der zweite schaltet weiter – genau eine Vokabel pro
  Zyklus. Ein Dreifachklick auf „Weiter" springt trotzdem nur eine Vokabel
  vor, „Weiter" ohne Antwort tut nichts
- Fortschritt und Serie überstehen einen Reload (localStorage geprüft)
- „Schwierige Wörter" füllt sich nach falschen Antworten
- Wortschatz eingrenzen: Bereich „Nr. 5 bis 24" wählt genau diese 20, einzelnes
  Antippen korrigiert, Abschnitts-Knopf *Check-in* wählt genau dessen 29
  Vokabeln; die Auswahl übersteht einen Reload, steht auf der Startkarte und
  die Übung fragt exakt die ausgewählten ab (Bereich 1–12 → 12 Vokabeln)
- Der Hinweis zu weggefilterten Sätzen erscheint und verschwindet passend zum
  Schalter *Nur Einzelwörter*
- Zurück aus der Auswahl führt zur Übungseinstellung und von dort zum Start –
  über den Knopf **und** über die Zurück-Geste (`history.back()`) gleich
- Die längste Liste („Alles gemischt", 1.099 Zeilen) baut sich in 64 ms auf
- Kein horizontales Scrollen auf 375 px auf allen Bildschirmen
- Helles und dunkles Theme

**Noch offen – nur am Gerät (Pixel 11 Pro) prüfbar:**

- Zurück-Wischgeste bricht die Übung nicht hart ab, sondern führt zum Start
- Bildschirmtastatur verdeckt das Eingabefeld nicht
- Portrait-Lock, Keep-Screen-On, WebView-Force-Dark-Verhalten

## Bewusst nicht drin

Aussprache/Text-to-Speech, die Phonetik-Spalte (Kletts ASCII-Notation bräuchte
eine Mapping-Tabelle), die ukrainische/arabische Spalte als
Herkunftssprachen-Modus, Lernstatistiken über die Zeit, Erinnerungen, und die
Reihe „Green Line New Bayern" (andere Ausgabe – wäre ein Konverter-Lauf plus
neue Unit-Titel).

---

Vokabeln aus den kostenlosen Vokabellisten des Ernst Klett Verlags
(© Ernst Klett Verlag GmbH, Stuttgart) zu Green Line, Ausgabe Bayern ab 2017.
Nur für den privaten Gebrauch.
