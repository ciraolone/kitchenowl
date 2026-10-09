<!-- Come è fatta la scorciatoia "Aggiungi articolo" (feature 002): scelte tecniche e vincoli. Il cosa sta in spec.md. -->

# Piano

## Scorciatoia statica di Android, nessun plugin

La voce è una scorciatoia statica dichiarata in `android/app/src/main/res/xml/shortcuts.xml` e agganciata all'attività principale nel manifest. Il testo viene da `strings.xml` (inglese in `values/`, italiano in `values-it/`), l'icona è un vettoriale "+" in `drawable/ic_shortcut_add_item.xml`.

Scartato il plugin `quick_actions`: le scorciatoie le crea dal codice Dart a ogni avvio (non ci sono finché l'app non è stata aperta una volta) e aggiunge una dipendenza per una cosa che Android fa da solo.

## Il percorso passa dai link interni già esistenti

La scorciatoia apre il link `kitchenowl://app/add-item`. L'app accetta già lo schema `kitchenowl://` e ha il deep linking di Flutter attivo, che consegna il percorso `/add-item` al router sia ad app chiusa sia ad app aperta (l'attività è `singleTask`, quindi il link arriva alla stessa istanza).

Nel router, `/add-item` è una rotta di solo reindirizzamento: legge `lastHouseholdId` e porta a `/household/<id>/items?add=<istante>`, oppure a `/household` se non c'è una casa. Il parametro `add` porta l'istante in millisecondi perché ogni tocco produca un indirizzo diverso: se la lista è già aperta su un indirizzo identico il router non ricostruirebbe nulla e il campo non riprenderebbe il fuoco.

## Il fuoco sul campo di ricerca

Il mixin `AddItemShortcutFocus` (`lib/pages/household_page/add_item_shortcut_focus.dart`), usato da `ShoppinglistPage`, legge `add` dallo stato del router in `didChangeDependencies` e, quando cambia rispetto all'ultimo gestito, dà il fuoco al campo di ricerca dopo il primo disegno. Per farlo `SearchTextField` accetta un `focusNode` dall'esterno (se non arriva, ne crea uno suo come prima).

Due trappole viste sull'emulatore. Ad app in sottofondo il link arriva prima che Android ridia la finestra all'app, e un fuoco dato in quel momento resta senza tastiera (una volta su due): si aspetta lo stato `resumed`, che su Android arriva con la finestra attiva. Se il campo ha ancora il fuoco ma la tastiera è stata chiusa col tasto indietro, `requestFocus` non fa nulla: la tastiera si riapre con `TextInput.show`.
