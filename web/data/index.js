/*
 * Band- und Lektions-Metadaten zu Green Line, Ausgabe Bayern ab 2017.
 *
 * Diese Datei ist von Hand gepflegt und eingecheckt - anders als die
 * generierten vocab.gl<N>.js. Die Unit-Titel stammen von den
 * Klett-Produktseiten, die Codes aus den Vokabellisten selbst.
 *
 * Die Abschnitts-Bezeichnungen (secLabels) sind meine Auslegung der Kuerzel
 * aus der PDF-Spalte "Lektion" - wenn im Buch etwas anderes steht, hier
 * korrigieren, sonst nirgends.
 */
window.VOCAB_INDEX = {
  bands: [
    {
      id: 'gl1', n: 1, label: 'Green Line 1', grade: '5. Klasse',
      isbn: '978-3-12-803010-4',
      unitTitles: {
        U1: "It's fun at home",
        U2: "I'm new at TTS",
        U3: 'I like my busy days',
        U4: "Let's do something fun",
        U5: "Let's go shopping",
        U6: "It's my party"
      }
    },
    {
      id: 'gl2', n: 2, label: 'Green Line 2', grade: '6. Klasse',
      isbn: '978-3-12-803020-3',
      unitTitles: {
        U1: 'My friends and I',
        U2: 'The Sunshine State',
        U3: 'Off to the Rockies!',
        U4: 'Sport is good for you!',
        U5: 'Stay in touch',
        U6: 'Goodbye Greenwich'
      }
    },
    {
      id: 'gl3', n: 3, label: 'Green Line 3', grade: '7. Klasse',
      isbn: '978-3-12-803030-2',
      unitTitles: {
        U1: 'Find your place',
        U2: "Let's go to Wales!",
        U3: 'What was it like?',
        U4: 'In the Desert Southwest'
      }
    },
    {
      id: 'gl4', n: 4, label: 'Green Line 4', grade: '8. Klasse',
      isbn: '978-3-12-803040-1',
      unitTitles: {
        U1: 'Kids in America',
        U2: 'The Pacific Northwest',
        U3: 'Canada',
        U4: 'London - a world city'
      }
    },
    {
      id: 'gl5', n: 5, label: 'Green Line 5', grade: '9. Klasse',
      isbn: '978-3-12-803050-0',
      unitTitles: {
        U1: "G'day Australia!",
        U2: '(Never) enough!',
        U3: 'The good life?'
      }
    },
    {
      id: 'gl6', n: 6, label: 'Green Line 6', grade: '10. Klasse',
      isbn: '978-3-12-803060-9',
      unitTitles: {
        U1: 'Scotland',
        U2: 'Black in America',
        U3: 'Youth (and) culture'
      }
    }
  ],

  // Abschnitte innerhalb einer Unit (Spalte "Lektion", zweites Kuerzel).
  secLabels: {
    CI: 'Check-in',
    S1: 'Station 1', S2: 'Station 2', S3: 'Station 3',
    SK1: 'Skills 1', SK2: 'Skills 2', SK3: 'Skills 3',
    ST: 'Text smart',
    UT: 'Unit task',
    CO: 'Check-out'
  },

  // Kurze Erklaerung der Lektionsarten fuer die Startseite.
  kindNotes: {
    PU: 'Vorkurs aus der Grundschulzeit',
    AC: 'Across cultures - Landeskunde',
    F: 'Focus - Zusatzthema',
    TS: 'Text smart - Lese- und Schreibkurs'
  }
};
