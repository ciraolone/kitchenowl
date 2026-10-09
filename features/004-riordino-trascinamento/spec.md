<!-- Cosa fa e perché il riordino a trascinamento della lista della spesa (feature 004 del fork di Andrea): in quali ordinamenti c'è, cosa succede nell'ordinamento per reparti, come convive con la scheda dell'articolo e con l'ordine imparato dalle spese. Il come sta in plan.md. -->

# Riordino con trascinamento

## Perché

L'ordine automatico (per ordine d'acquisto) si impara solo dalle spese e si aggiorna la notte, e il reparto di un articolo si cambia solo dalla sua scheda. Andrea vuole sistemare entrambe le cose a mano, direttamente dalla lista, spostando gli articoli col dito.

## Comportamento

- Il trascinamento c'è negli ordinamenti **automatico** e **per reparti**. Nell'ordinamento **alfabetico** non c'è: lì tutto resta com'è.
- Tenendo premuto un articolo e muovendo il dito lo si trascina. Tenendolo premuto e lasciandolo senza muoverlo si apre la sua scheda, come prima. Non c'è una zona apposta per aprire la scheda. Quando la pressione lunga scatta, il telefono dà un "tac" netto.
- Lasciando l'articolo sopra un altro articolo, prende il suo posto: se scendeva finisce subito dopo, se saliva subito prima. Lo spostamento si vede subito e funziona anche senza rete.
- Ordinamento automatico: l'ordine è quello di tutta la lista.
- Ordinamento per reparti: dentro ogni reparto gli articoli seguono l'ordine automatico (il percorso nel negozio) e non più l'alfabeto, così lo spostamento dentro un reparto resta visibile.
- Ordinamento per reparti, appena il dito si muove: il reparto da cui parte l'articolo resta aperto, tutti gli altri si riducono a una riga col nome, compresi quelli che non hanno articoli in lista. Lasciando l'articolo su una di queste righe lo si sposta in quel reparto (c'è anche "Uncategorized"), e il cambio è permanente: la volta dopo l'articolo comparirà in quel reparto. Lasciato il dito, i reparti tornano come prima.
- Avvicinando l'articolo al bordo alto o basso della lista, la lista scorre da sola.
- Ogni trascinamento dentro la lista conta per l'ordine automatico come una spesa recente fatta in quell'ordine: l'analisi notturna ne tiene conto invece di cancellarlo. Se poi le spunte durante le spese raccontano un ordine diverso, col tempo vincono le spunte. Lo spostamento in un altro reparto non conta come spesa.
- Una spesa si riconosce quando almeno 5 spunte cadono entro **2 ore** prima o dopo una stessa spunta (prima erano 10 minuti); le spunte a meno di 2 ore da queste si aggiungono alla stessa spesa.

## Fuori scope

- Riordinare i reparti fra loro (resta nelle impostazioni della casa).
- Trascinare dai risultati della ricerca o dagli articoli recenti.
