<!-- Scelte tecniche della feature 005 (reparti dalla lista). Il cosa sta in spec.md. -->

# Piano

## Azioni in coda

Riordino e creazione sono azioni local first come quelle della lista (feature 001): `TransactionCategoryArrange` e `TransactionCategoryAdd` in `services/transactions/category.dart`, applicate subito alla copia dei reparti in `MemStorage`, accodate e consegnate dal postino.

- Il riordino porta il reparto spostato e la **posizione** d'arrivo fra i reparti veri (Uncategorized escluso). È la stessa misura che il server già accetta (`ordering` su `POST /api/category/<id>`, che rinumera tutti i reparti) e che usa la pagina delle impostazioni. Riapplicata sopra la copia fresca del server è innocua: se il server ha già lo spostamento, il reparto è già lì.
- La creazione aggiunge in coda il reparto senza id. Alla consegna il server risponde col reparto creato e la copia locale prende il suo id. Le azioni successive in coda che nominano un reparto senza id (riordino, spostamento di un articolo nel reparto nuovo) lo ricavano per nome dalla copia locale, come già fanno gli articoli col catalogo.
- `ShoppinglistCubit._refresh` riapplica le azioni in coda anche sopra i reparti freschi del server: aspetta che arrivino prima di `replayPending` e poi li rilegge dalla copia locale.

## Server

Un reparto nuovo prende come `ordering` il numero dei reparti già presenti, così va in fondo. Prima prendeva 0 e finiva in cima mescolato per nome col primo. Vale anche per le impostazioni e la versione web.

## Confronto fra reparti

`Category` è uguale a un'altra solo se coincidono id, nome **e** `ordering`. Dopo un riordino locale i reparti della lista hanno l'ordering nuovo mentre gli articoli si portano dietro quello vecchio fino al prossimo aggiornamento dal server, e con l'uguaglianza piena gli articoli sparirebbero dai loro reparti. La lista confronta quindi i reparti con `isSameCategory` (`models/category.dart`): per id quando entrambi lo hanno, altrimenti per nome. Non si cambia l'uguaglianza di `Category`, perché gli stati dei cubit la usano per accorgersi di un nome cambiato.

## Trascinamento

Nell'ordinamento per reparti gli articoli in lista li mostra `SliverShoppinglistCategories`, che tiene lo stato di entrambi i trascinamenti (articolo e reparto); `SliverShopinglistItemView` resta senza stato e negli altri ordinamenti mostra la griglia unica.

- `ArrangeableCategoryTitle` avvolge il nome del reparto in `SliverCategoryItemGridList` con un `LongPressDraggable<Category>`. Come per gli articoli il "tac" è `strongHapticClick` e il riordino vero parte solo oltre 16 px, così una pressione senza movimento non chiude i reparti.
- Appena parte, la vista sostituisce tutti i reparti con righe `SliverCategoryDropHeader`, ora generica sul tipo trascinato (articolo o reparto). La riga d'origine smonta il nome da cui è partito il trascinamento: Flutter chiama comunque la fine del trascinamento, ma non più gli spostamenti del dito. Per questo lo scorrimento ai bordi lo guidano le righe, che ricevono gli spostamenti del reparto che passa sopra (`onMove`), e non il nome trascinato.
- Dopo che i reparti si sono chiusi, la riga del reparto trascinato viene portata sotto il dito con uno scorrimento.
- La posizione d'arrivo segue la regola degli articoli: il reparto prende l'indice di quello su cui è lasciato.

## Pulsante

`MorePage.show` riceve anche `ShoppinglistCubit`, perché la voce **Add category** crea il reparto da lì. Il dialogo è lo stesso `TextDialog` delle impostazioni.
