<!-- Scelte tecniche della feature 007 (negozi): negozio = casa di KitchenOwl, impostazioni della lista salvate per casa sul telefono, fine dell'analisi notturna dell'ordine e ordine manuale dentro i reparti costruito sul trascinamento della feature 004. Il cosa sta in spec.md. -->

# Plan: Negozi

## Sintesi

Ogni negozio è una casa (household) di KitchenOwl, che già separa articoli, reparti e lista: lato dati non cambia nulla, si rinominano i testi, si aggiunge l'elenco dei negozi nel pannello e le impostazioni della lista passano da globali a per casa. L'analisi notturna smette di calcolare `Item.ordering`, che resta solo l'ordine dato col trascinamento della feature 004.

## File coinvolti

- `backend/app/jobs/jobs.py` — `daily()` non chiama più `findItemOrdering` né `route_instances`; restano `clusterShoppings` e `findItemSuggestions`.
- `backend/app/service/item_route.py` — restano `route_key` e `place_in_route`; vanno via `remember_route` e `route_instances`.
- `backend/app/models/item_route_hint.py`, `backend/app/models/__init__.py`, `backend/app/models/household.py` — via il modello `ItemRouteHint` e la relazione della casa.
- `backend/migrations/versions/<nuova>_.py` — cancella la tabella `item_route_hint` (vuota oggi), con `downgrade` che la ricrea come `a4c1e7d2b9f0`.
- `backend/app/controller/item/item_controller.py` — `arrangeItem`: niente più ricordo; se cambia il reparto `ordering = 0` e niente posto nel percorso.
- `backend/app/controller/item/schemas.py` — `ArrangeItem` perde `route` (resta `unknown = EXCLUDE`, così le azioni vecchie in coda passano lo stesso).
- `backend/tests/api/test_api_item_ordering.py`, `backend/tests/api/test_api_item_arrange.py` — via le prove dell'analisi notturna dell'ordine, che descrivono un comportamento che non c'è più.
- `kitchenowl/lib/enums/shoppinglist_sorting.dart` — via `algorithmic`; restano `alphabetical` e `category`.
- `kitchenowl/lib/cubits/shoppinglist_cubit.dart` — ordinamento letto e scritto per casa; `arrangeItem` lavora solo nel reparto; `moveItemToCategory` manda l'articolo in fondo.
- `kitchenowl/lib/services/local_first/item_route.dart` — `arrangeItems` azzera `ordering` quando cambia il reparto; testata aggiornata (non è più l'ordine automatico).
- `kitchenowl/lib/services/transactions/shoppinglist_arrange.dart` — via `route` dall'azione e dalla chiamata.
- `kitchenowl/lib/cubits/settings_cubit.dart` — impostazioni della lista per casa, `selectStore`, passaggio unico dei valori di oggi alla prima casa aperta.
- `kitchenowl/lib/cubits/household_add_update/household_settings_items_cubit.dart`, `kitchenowl/lib/pages/settings_household/household_settings_items_page.dart` — tolto il caso `algorithmic`.
- `kitchenowl/lib/pages/settings_page.dart` — la sezione della lista agisce sul negozio aperto e ne mostra il nome; nascosta se non c'è un negozio aperto.
- `kitchenowl/lib/pages/household_page/more.dart` — elenco dei negozi nel pannello.
- `kitchenowl/lib/pages/household_page/shoppinglist.dart` — icona del pulsante negozio.
- `kitchenowl/lib/widgets/settings_household/sliver_household_feature_settings.dart`, `kitchenowl/lib/cubits/household_add_update/household_add_cubit.dart` — via la scelta della lingua: un negozio nuovo nasce vuoto.
- `kitchenowl/lib/l10n/app_en.arb` — Household → Store nei valori (le chiavi restano).

## Decisioni di design

- **Negozio = casa.** Nessun concetto nuovo né modifica allo schema dei dati: le case isolano già articoli, reparti, liste, cronologia e foto, e il fork resta vicino all'originale per i merge.
- **Negozio nuovo vuoto.** Il server importa articoli e reparti di serie quando la casa ha una lingua (`importLanguage`, in creazione e alla prima impostazione della lingua). L'app non mostra più la scelta della lingua e non la propone in automatico (`HouseholdAddCubit` oggi la riempie con quella del telefono), quindi non la manda mai. Il server non si tocca: la versione web è la stessa app.
- **Rinomina solo nei testi.** Cambiano i valori in `app_en.arb` (l'unica lingua usata, feature 003); chiavi, classi, rotte (`/household/...`) e API restano, altrimenti ogni merge dall'originale diventa un conflitto.
- **Impostazioni per casa nel `SettingsCubit`.** Restano un unico cubit e un unico stato (`App.settings`), letti dagli stessi punti di oggi. Le impostazioni della lista (vista, dimensione griglia, stile elenco, icone nascoste, tocco, recenti e loro reparti, schermo acceso, ordinamento) si salvano in `PreferenceStorage` con chiave `<chiave>@<householdId>`; tema, colori e `restoreLastShoppingList` restano con la chiave globale di oggi. `selectStore(householdId)` carica quelle della casa (valori di serie se mai salvate) e i setter scrivono sulla casa selezionata. Più chiamate per la stessa casa condividono lo stesso caricamento.
- **L'ordinamento entra nel `SettingsCubit`.** Oggi lo legge e scrive `ShoppinglistCubit` sotto `itemSorting`; ora è un'impostazione per casa come le altre, salvata per nome (`alphabetical`/`category`) e non per indice, perché l'indice cambia togliendo `algorithmic`. `ShoppinglistCubit` resta l'unico che lo applica agli articoli: all'avvio chiama `App.settings.selectStore(household.id)` e, finito, imposta il suo `sorting`; `setSorting` scrive con `App.settings.setShoppingListSorting`. Il valore di serie per un negozio nuovo è `category`.
- **Chi seleziona il negozio.** Solo il costruttore di `ShoppinglistCubit`, che nasce con `HouseholdPage` per ogni casa aperta: è il primo punto che conosce la casa e quello che ha bisogno dell'ordinamento prima di mostrare la lista.
- **Passaggio unico dei valori di oggi.** Al primo `selectStore` dopo l'aggiornamento (segnalino `storeSettingsMigrated` assente), i valori salvati con le chiavi globali di oggi si copiano sulla casa aperta, `itemSorting` tradotto (0 → `alphabetical`, 1 e 2 → `category`), e le chiavi globali della lista si cancellano. Andrea ha una sola casa, quindi "Famiglia" tiene esattamente l'aspetto di oggi.
- **Impostazioni solo sul telefono.** Nessuna API nuova: le preferenze restano locali come oggi (spec).
- **Pannello del negozio.** `MorePage` mostra in cima l'elenco dei negozi da `HouseholdListCubit` (che legge dal server e ripiega sulla copia locale di `MemStorage`), con quello aperto segnato; un tocco fa `context.go('/household/<id>', extra: household)`, che aggiorna già `lastHouseholdId`. La voce che porta all'elenco completo resta, perché da lì si crea un negozio. Il pulsante accanto alla ricerca prende l'icona `storefront_rounded`.
- **Ultimo negozio e scorciatoia.** Già oggi passano da `lastHouseholdId`, scritto all'apertura di ogni casa (`router.dart`): nessuna modifica.
- **Senza rete.** Liste, reparti, catalogo e coda sono già per casa (`MemStorage`, `ItemCatalog`, azioni con la loro `household`): una casa aperta almeno una volta si riapre dalla copia locale. Da verificare a mano in fase di implementazione aprendo le case senza rete; si corregge solo ciò che non regge.
- **Ordine manuale = `Item.ordering` della feature 004 senza analisi notturna.** Il gesto, l'azione in coda e la regola di spostamento (`placeInRoute` / `place_in_route`) restano. Senza ordinamento automatico l'ordine conta solo dentro un reparto: `arrangeItem` calcola sempre il gruppo sul reparto dell'articolo bersaglio. Il server continua a rinumerare tutti gli articoli della casa, che conserva l'ordine relativo dentro ogni reparto.
- **In fondo al reparto = `ordering` 0.** Un articolo nuovo nasce già con 0; uno spostato in un altro reparto torna a 0 sia sul telefono (`arrangeItems`) sia sul server (`arrangeItem`). Fra gli zeri l'ordine è per nome: è il "mai ordinato a mano" della spec, ed evita un secondo tipo di numero da tenere allineato fra telefono e server.
- **Punto di partenza.** I numeri di `ordering` di oggi restano come sono (166 articoli numerati, 586 a zero): fermare l'analisi basta a congelarli.
- **Nomi nel codice.** `compareByRoute`, `placeInRoute`, `item_route.py` tengono il nome: rinominarli toccherebbe molti file senza cambiare nulla. Le testate dicono che il "percorso" ora è solo l'ordine manuale.

## Dipendenze esterne

Nessuna nuova.

## Invarianti

- `compareByRoute` (Dart) e `route_key` (Python) devono restare lo stesso confronto, e così `placeInRoute` e `place_in_route`: se divergono, telefono e server mostrano ordini diversi dopo lo stesso trascinamento (feature 004).
- Il cambio di reparto azzera `ordering` in entrambi i lati; se lo fa uno solo, l'articolo salta di posto al primo aggiornamento dal server.
- L'ordinamento si salva per nome: mai tornare all'indice dell'enum.
- `ShoppinglistCubit` deve leggere l'ordinamento solo dopo che `selectStore` della sua casa è finito, altrimenti prende quello del negozio aperto prima.
- La migrazione delle chiavi globali avviene una volta sola (segnalino), altrimenti un negozio nuovo erediterebbe le impostazioni di "Famiglia".

## Eccezioni alle rules

- **Codice morto (un solo modo / niente dead code)** — `backend/app/jobs/item_ordering.py` (`findItemOrdering`) resta nel repo senza chiamanti. Perché serve: è un file dell'originale, e cancellarlo crea un conflitto a ogni merge che lo tocca. Alternativa rifiutata: cancellarlo (il risparmio è un file mai letto, il costo sono conflitti ricorrenti con l'upstream). Lo stesso vale per i campi `orderby` delle API delle liste, che restano come nell'originale.

## Rischi noti

- Al primo disegno di un negozio la lista può mostrarsi per un istante con le impostazioni del negozio precedente, finché `selectStore` non ha letto le preferenze (letture locali, millisecondi).
- L'app manda ancora `orderby=<indice>` a `GET /shoppinglist`: con `category` ora a indice 1 il server ordina per `ordering` invece che per nome. È innocuo, perché l'app riordina comunque in locale.
- Un'azione di trascinamento rimasta in coda da una versione vecchia porta ancora `route`: il server la ignora (`EXCLUDE`).
- La versione web legge le preferenze dal browser: ogni browser ha le sue impostazioni per negozio, partendo da quelle di serie.
