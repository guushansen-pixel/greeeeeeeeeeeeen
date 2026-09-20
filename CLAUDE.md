# Vokabeltrainer

Offline-Vokabeltrainer zu Green Line, Ausgabe Bayern ab 2017 (Klasse 5-10),
reine Web-App in einer Datei, die per [apk-builder](../apk-builder) zur APK
wird. Datenherkunft, Extraktions-Pipeline, Datenmodell, Leitner-Logik und die
tolerante Antwortprüfung stehen in [README.md](README.md) - dort nachlesen
statt hier duplizieren.

## Vokabeldaten

`web/data/vocab.gl*.js` und `source-pdfs/` sind **gitignored** und in einem
frischen Klon nicht vorhanden. Sie stammen aus den kostenlosen
Klett-Vokabellisten ("(c) Ernst Klett Verlag ... Alle Rechte vorbehalten") -
privat lernen ist ok, weiterverbreiten nicht. Neu erzeugen:

```powershell
.\tools\fetch-vocab.ps1      # laedt die 6 PDFs (braucht Netz)
.\tools\build-vocab.ps1      # pdftotext -> web\data\vocab.gl1..6.js
```

Der Konverter braucht `pdftotext` - kommt mit Git fuer Windows mit
(`mingw64\bin\pdftotext.exe`), wird notfalls dort direkt gesucht.

## Build & Test

Kein Bundler, kein Build-Step fuer die Web-App selbst. Zum Testen **immer
ueber http**, nie per `file://` - dort ist localStorage still abgeschaltet und
jeder Lernfortschritt verschwindet beim Neuladen, ohne Fehlermeldung:

```powershell
.\tools\serve.ps1            # http://localhost:8099
```

Mit `?test=1` an der URL liegen `normalize`, `fold`, `lev`, `checkAnswer`,
`parseImport`, `buildOptions`, `similarity`, `makeItem` und `wordsOfUnit`
unter `window.__vt` - Antwortpruefung und Ablenkerqualitaet lassen sich damit
aus der Konsole ueber hunderte Faelle messen, statt sie durchzuklicken.

APK bauen - **nicht** direkt `apk-builder\new-app.ps1`/`build-apk.ps1`
aufrufen, sondern immer ueber den eigenen Wrapper, der Portrait-Lock,
Keep-Screen-On und den Predictive-Back-Handler nachpatcht (apk-builder
unterstuetzt nichts davon nativ, und `apps\Vokabeltrainer` wird bei jedem
`-Force`-Lauf komplett neu generiert):

```powershell
.\build.ps1                              # Debug-APK
.\build.ps1 -Release                     # signierte Release-APK
.\build.ps1 -Release -Install            # + adb install auf verbundenes Geraet
.\build.ps1 -VersionName "1.1" -VersionCode 2 -Release   # bei jedem Release hochzaehlen
```

Was sich nur auf dem echten Geraet (Pixel 11 Pro) verifizieren laesst:
Zurueck-Wischgeste waehrend einer Uebung, ob die Bildschirmtastatur das
Eingabefeld verdeckt, Portrait-Lock, Keep-Screen-On, WebView-Force-Dark.

## Konventionen

- Alles in `web/index.html` (HTML+CSS+JS inline), kein Framework, keine
  externen Abhaengigkeiten - muss offline funktionieren. `new-app.ps1` wird
  ohne `-Online` aufgerufen.
- `icon.xml` liegt bewusst **neben** `web/`, nicht darin.
- Vokabelpakete werden per eingefuegtem `<script>`-Tag nachgeladen, nie per
  `fetch` - `fetch` scheitert unter `file://`.
- localStorage-Keys sind versioniert und namespaced
  (`vokabeltrainer.settings.v1`, `vokabeltrainer.progress.v1`, ...) - bei
  einer Schemaaenderung neue Versionsnummer statt stiller Migration.
- Unit-Titel und die Klartextnamen der Abschnittskuerzel (CI, S1, ST, UT, CO)
  stehen **nur** in `web/data/index.js` - Aenderungen dort, nicht im
  Generat und nicht im App-Code.
- Neue Lektionsart: `lessonLabel()` und `lessonEmoji()` in `index.html` sind
  die einzigen Stellen mit Codewissen; der Konverter kennt die Codes nur ueber
  `$reCode`.
- Beim Erweitern der Antwortpruefung immer erst die Fallliste in der Konsole
  (`?test=1`) erweitern, dann den Code - die Pruefung ist das Stueck, an dem
  die App steht oder faellt.
- `buildOptions()` mischt bewusst nahe und weite Ablenker (Details in
  README). Wer dort an den Gewichten dreht, misst die Wirkung ueber
  `?test=1` an mehreren hundert gezogenen Fragen nach, nicht an drei
  Beispielen - einzelne Ziehungen sagen bei zufaelliger Auswahl nichts.
- `word.idx` (Platz in der Buchreihenfolge) ist kein Deko-Feld, sondern das
  Themensignal fuer Decks ohne Abschnittscodes - beim Bauen neuer
  Wortlisten mitsetzen.
- Waehrend der Uebung haengen zwei Tastatur-Handler am selben Enter: einer
  am Eingabefeld (prueft, `stopPropagation`) und einer am `document`
  (schaltet weiter). `nextQuestion()` schaltet ausserdem nur weiter, wenn
  `quiz.answered` gesetzt ist, und loescht das Flag sofort - das faengt die
  Doppelauslösung mit dem nativen Klick des fokussierten Weiter-Knopfes ab.
  Wer daran etwas aendert, prueft beide Wege (Tastatur und Maus) und den
  Mehrfachklick nach.
- Kein Audio/TTS bisher (bewusst zurueckgestellt, siehe README) - kein WebGL
  (siehe [hopper](../hopper): auf echtem Geraet stark geruckelt trotz sauberem
  Desktop-Test).

## Aktueller Stand

Siehe "Geprueft" in [README.md](README.md).
