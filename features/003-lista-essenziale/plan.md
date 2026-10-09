<!-- Come è fatta la feature 003 (lista essenziale): scelte tecniche. Il cosa sta in spec.md. -->

# Piano

## Lingua

`MaterialApp` riceve `locale: Locale('en')` in `lib/app.dart`, e `main.dart` imposta `Intl.defaultLocale = 'en'` dopo `findSystemLocale`, così anche date e numeri formattati con `intl` seguono l'inglese invece della lingua del telefono. Le traduzioni restano nel progetto (servono a non divergere dall'originale nei merge); semplicemente non vengono scelte. La stringa nativa della scorciatoia perde la versione italiana (`values-it/strings.xml` rimosso), altrimenti su un telefono italiano il launcher mostrerebbe "Aggiungi articolo" in un'app inglese.

Scartata l'impostazione "lingua dell'app" di Android 13+: andava fatta a mano sul telefono e non avrebbe toccato la versione web.

## Barra in basso e pulsanti in linea

In `HouseholdPage` la `NavigationBar` sparisce sui telefoni; la barra laterale di tablet e computer resta. Il pannello del pulsante casa si apre da un'unica funzione, `MorePage.show`, usata sia dalla barra laterale (tramite `_onItemTapped`) sia dal nuovo pulsante della lista.

In `ShoppinglistPage` la riga del campo di ricerca diventa campo + pulsante ordinamento + pulsante casa; l'intestazione sotto tiene solo la scelta della lista quando ce n'è più d'una. Le icone dell'ordinamento stanno in `ShoppinglistSorting.toIcon`.

## Tocco e pressione lunga

In `ShoppinglistPage` l'azione della lista torna su `onPressed`/`onRecentPressed`, come nell'originale. Lasciando vuoti `onLongPressed`/`onRecentLongPressed`, `SliverItemGridList` usa da sé `openMenu`, cioè la scheda dell'articolo: nessun codice nuovo per la pressione lunga.
