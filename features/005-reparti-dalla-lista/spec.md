<!-- Cosa fa e perché la gestione dei reparti dalla lista della spesa (feature 005 del fork di Andrea): riordinarli col dito nell'ordinamento per reparti e crearne uno nuovo dal pannello del pulsante casa. Il come sta in plan.md. -->

# Reparti dalla lista

## Perché

Con la feature 004 Andrea sposta gli articoli col dito, ma l'ordine dei reparti si cambia solo dalle impostazioni della casa, e un reparto nuovo si crea solo da lì. Vuole fare entrambe le cose dalla lista, con lo stesso gesto degli articoli.

## Comportamento

- Nell'ordinamento **per reparti**, tenendo premuto il nome di un reparto e muovendo il dito lo si trascina. Quando la pressione lunga scatta il telefono dà lo stesso "tac" degli articoli. Tenere premuto e lasciare senza muovere non fa nulla; il tocco sul nome continua ad aprire e chiudere il reparto.
- Appena il dito si muove, tutti i reparti si riducono a una riga col nome, compresi quelli che non hanno articoli in lista. Il reparto trascinato resta visibile, sbiadito. "Uncategorized" non compare: sta sempre in fondo e non si sposta.
- Lasciando il reparto sopra un altro, prende il suo posto: se scendeva finisce subito dopo, se saliva subito prima. Lasciato il dito, i reparti tornano come prima, nel nuovo ordine.
- Avvicinando il reparto al bordo alto o basso, la lista scorre da sola.
- L'ordine nuovo è quello dei reparti della casa, lo stesso delle impostazioni: vale per sempre e per tutti. Si vede subito e funziona anche senza rete.
- Nel pannello del pulsante casa c'è la voce **Add category**: chiede il nome e crea il reparto. Il reparto nuovo va in fondo, prima di "Uncategorized". Anche questo funziona senza rete. Se esiste già un reparto con lo stesso nome (maiuscole comprese o no) non se ne crea un secondo.
- Un reparto nuovo è vuoto, quindi nella lista non si vede finché non ci si sposta dentro un articolo: compare fra le righe quando si trascina un articolo o un reparto.

## Fuori scope

- Rinominare, unire o cancellare reparti: resta nelle impostazioni della casa.
- Trascinare i reparti negli ordinamenti alfabetico e automatico, dove i reparti non si vedono.
