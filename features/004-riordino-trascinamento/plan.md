<!-- Come è fatta la feature 004 (riordino con trascinamento): il percorso nel negozio come unica fonte dell'ordine, la regola di spostamento uguale su telefono e server, il ricordo dei trascinamenti per l'analisi notturna e i pezzi dell'interfaccia. Il cosa sta in spec.md. -->

# Piano

## Un solo ordine: il percorso

L'ordine "mio" è il campo `ordering` degli articoli (della casa, non della lista), lo stesso che l'analisi notturna calcola dalle spese. Zero vuol dire "mai piazzato" e va in fondo. A parità di numero (tipicamente fra gli zeri) si ordina per nome in minuscolo, sia sul telefono sia sul server, così i due vedono lo stesso ordine e lo spostamento dà lo stesso risultato. Il confronto sta in `compareByRoute` (`lib/services/local_first/item_route.dart`), usato sia dall'ordinamento automatico sia da quello per reparti; l'alfabetico non cambia.

## Regola di spostamento

Si mette l'articolo spostato subito dopo (o subito prima) dell'articolo su cui è stato lasciato, poi si rinumera: ricevono un numero tutti gli articoli fino a quello spostato compreso, e quelli dopo solo se ne avevano già uno. Così uno zero lasciato fra due zeri prende posto senza trascinarsi dietro gli altri, e uno zero che finisce prima dello spostato ne riceve uno per non scivolare in fondo.

La stessa regola esiste in Dart (`placeInRoute`, sugli articoli della lista) e in Python (`backend/app/service/item_route.py`, su tutti gli articoli della casa): la si applica sul telefono per vederla subito anche senza rete, e sul server perché è lui la fonte vera. Gli articoli della lista restano nello stesso ordine relativo in entrambi i casi; i numeri possono essere diversi, e al primo aggiornamento il telefono prende quelli del server.

## Azione in coda

`TransactionShoppingListArrangeItem` (`lib/services/transactions/shoppinglist_arrange.dart`) è un'azione local first come quelle della feature 001: si applica subito alla copia locale, va in coda, si consegna in ordine, e si riapplica sopra ogni copia fresca finché non è consegnata (è idempotente). Porta l'articolo spostato, l'articolo dopo cui o prima di cui va, l'eventuale reparto nuovo e l'ordine del gruppo dopo lo spostamento (tutta la lista nell'automatico, il reparto in quello per reparti). Gli articoli aggiunti senza rete non hanno ancora un id: lo si ricava dal catalogo locale al momento della consegna, come per le altre azioni.

Il server la riceve su `POST /api/household/<id>/item/arrange` con `item_id`, `after_item_id` o `before_item_id`, `category` (solo se cambia, `null` per togliere il reparto), `route` (id del gruppo in ordine) e `changed_at`. Risponde sempre 200 se gli articoli sono della casa: qui non c'è la regola delle sovrapposizioni della feature 001, perché uno spostamento non è un "c'è / non c'è" e vince semplicemente l'ultimo arrivato.

## Ricordo per l'analisi notturna

Ogni spostamento dentro la lista salva l'ordine del gruppo nella tabella `item_route_hint` (casa, lista di id, `created_at` = momento del gesto). L'analisi notturna (`jobs.daily`) mette insieme le spese riconosciute dalle spunte e questi ricordi, in ordine di tempo, e li passa tutti al calcolo dell'ordine: un ricordo pesa come una spesa fatta in quel momento. I suggerimenti di articoli continuano a usare solo le spese vere, perché un riordino non dice nulla su cosa si compra insieme. I ricordi non si cancellano: il calcolo già fa pesare sempre meno quelli vecchi, e il loro numero cresce di uno per trascinamento.

La finestra che tiene insieme le spunte di una spesa (`eps` del raggruppamento DBSCAN in `cluster_shoppings.py`) passa da 600 a 7200 secondi; resta il minimo di 5 spunte.

## Interfaccia

- `ArrangeableItem` (`lib/widgets/shopping_list/arrangeable_item.dart`) avvolge una casella: `LongPressDraggable` per trascinare e `DragTarget` per ricevere. La pressione lunga della casella stessa viene spenta, altrimenti i due gesti si contendono il dito: se il dito si lascia senza essersi spostato di almeno 16 punti, è `ArrangeableItem` ad aprire la scheda. Fa scorrere la lista ai bordi con `EdgeDraggingAutoScroller` di Flutter, e resta viva (keep alive) mentre è trascinata, altrimenti scorrendo lontano la griglia la smonterebbe e smetterebbe di ricevere i movimenti del dito.
- Il "tac" della pressione lunga è `HapticFeedback.heavyImpact` (su Android un `CONTEXT_CLICK`) in `_onDragStarted`, con `hapticFeedbackOnStart` spento: quello di serie di `LongPressDraggable` è un `selectionClick` (`CLOCK_TICK`), che su molti telefoni non si sente.
- `SliverItemGridList` riceve un `ItemArrangement` facoltativo (chi è trascinato, cosa fare all'inizio, alla fine e al rilascio) e, se c'è, avvolge ogni casella in `ArrangeableItem`.
- `SliverShopinglistItemView` diventa con stato e ricorda quale articolo si sta trascinando. Nell'ordinamento per reparti, durante il trascinamento, disegna il reparto d'origine com'è e tutti gli altri (anche vuoti) come `CategoryDropHeader`. Ogni reparto ha una chiave fissa, così quello d'origine non viene ricostruito e la casella trascinata non si smonta.
- Quando i reparti si chiudono, la lista sopra si accorcia: `ArrangeableItem` misura la sua posizione prima e dopo e corregge lo scorrimento, così l'articolo resta sotto il dito.
- La pagina passa al riquadro della lista (non a quello della ricerca) le due azioni del cubit, `arrangeItem` e `moveItemToCategory`; è il riquadro a non attivare il trascinamento nell'ordinamento alfabetico.
- Sull'emulatore `adb shell input draganddrop` non basta per provarlo: comincia a muovere dopo 400 ms, prima dei 500 della pressione lunga di Flutter, e diventa uno scorrimento. Serve `input motionevent DOWN`, un secondo di attesa, poi `MOVE` e `UP`.
