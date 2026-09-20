/*
 * Eigene kleine Demo-Liste - selbst zusammengestellter Grundwortschatz,
 * kein Auszug aus einem Lehrwerk. Sie ist eingecheckt, damit die App auch
 * in einem frischen Klon etwas anzeigt, bevor tools\build-vocab.ps1 die
 * echten Banddaten erzeugt hat.
 */
window.VOCAB_DEMO = {
  band: 'demo', version: 1,
  source: 'Eigene Demo-Liste (kein Lehrwerksauszug)',
  units: [
    {
      code: 'D1',
      words: [
        { en: 'school', de: ['Schule'], kind: 'w' },
        { en: 'teacher', de: ['Lehrer', 'Lehrerin'], kind: 'w' },
        { en: 'pupil', de: ['Schueler', 'Schuelerin'], kind: 'w' },
        { en: 'classroom', de: ['Klassenzimmer'], kind: 'w' },
        { en: 'homework', de: ['Hausaufgabe', 'Hausaufgaben'], kind: 'w' },
        { en: 'pencil', de: ['Bleistift'], kind: 'w' },
        { en: 'book', de: ['Buch'], kind: 'w' },
        { en: 'friend', de: ['Freund', 'Freundin'], kind: 'w' },
        { en: 'family', de: ['Familie'], kind: 'w' },
        { en: 'brother', de: ['Bruder'], kind: 'w' },
        { en: 'sister', de: ['Schwester'], kind: 'w' },
        { en: 'kitchen', de: ['Kueche'], kind: 'w' },
        { en: 'garden', de: ['Garten'], kind: 'w' },
        { en: 'breakfast', de: ['Fruehstueck'], kind: 'w' },
        { en: 'to play', de: ['spielen'], kind: 'w' },
        { en: 'to read', de: ['lesen'], kind: 'w' },
        { en: 'to write', de: ['schreiben'], kind: 'w' },
        { en: 'to run', de: ['rennen', 'laufen'], kind: 'w' },
        { en: 'happy', de: ['gluecklich', 'froh'], kind: 'w' },
        { en: 'tired', de: ['muede'], kind: 'w' },
        { en: 'always', de: ['immer'], kind: 'w' },
        { en: 'never', de: ['nie', 'niemals'], kind: 'w' },
        { en: 'What is your name?', de: ['Wie heisst du?'], kind: 'p' },
        { en: 'How old are you?', de: ['Wie alt bist du?'], kind: 'p' }
      ]
    }
  ]
};
