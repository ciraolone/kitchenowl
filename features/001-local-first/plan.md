<!-- Piano tecnico della feature 001 (lista della spesa local first): come sono fatti oggi la cache e la coda offline dell'app Flutter, cosa si cambia nell'app e nel backend, la regola delle sovrapposizioni e come si compila e firma l'APK. Le decisioni qui sono concordate con Andrea il 2026-10-09; il comportamento atteso sta in spec.md. -->

# Piano tecnico

## Com'è oggi

L'app Flutter (`kitchenowl/lib`) ha già i pezzi di una modalità offline, ma li usa solo come ripiego quando il server non risponde.

- `TransactionHandler.runTransaction` (`services/transaction_handler.dart`) prova sempre prima `runOnline()` e solo se fallisce usa `runLocal()`, accodando la transazione in `TransactionStorage` (`transactions.json` sul telefono). La coda viene svuotata da `runOpenTransactions` al ritorno della connessione.
- `MemStorage` tiene in memoria liste, categorie, ricette ecc. e le salva su file tramite `TempStorage`, quindi una copia persistente esiste già.
- `ShoppinglistCubit._refresh` riscarica in sequenza tutte le liste, poi categorie e ricerca, e viene chiamato a ogni lettera della ricerca (`search` → `refresh(query)`) e dopo ogni `add`.
- La ricerca locale (`TransactionShoppingListSearchItem.runLocal`) guarda solo gli articoli in lista e i recenti, non il catalogo completo. Il backend espone già il catalogo intero su `GET /api/household/<id>/item`.
- Gli aggiornamenti in tempo reale arrivano via socket.io (`shoppinglist_item:add` / `shoppinglist_item:remove`, `services/api/shoppinglist.dart`).
- Il backend accetta già `removed_at` (millisecondi) sulla rimozione e lo usa come data della spunta nella cronologia; aggiunta e modifica della descrizione non hanno un equivalente.

## Cosa cambia nell'app

1. **Lettura sempre locale.** Le letture della lista della spesa (liste, categorie, catalogo articoli, ricerca) rispondono dalla copia locale. L'aggiornamento dal server parte in sottofondo all'apertura, al ritorno in primo piano, alla riconnessione del socket e a ogni evento socket; quando arriva, aggiorna la copia locale e lo schermo.
2. **Catalogo articoli locale.** Si aggiunge al salvataggio persistente il catalogo completo degli articoli della casa (`GET /api/household/<id>/item`), aggiornato in sottofondo e tenuto allineato dagli eventi socket. La ricerca filtra questo catalogo in memoria: niente rete mentre si scrive.
3. **Scrittura sempre locale e coda sempre attiva.** Aggiunta, spunta e descrizione si applicano subito alla copia locale e finiscono **sempre** nella coda persistente, che un unico "postino" svuota in sottofondo in ordine di creazione. Si toglie la distinzione online/offline al momento del gesto: è il postino a decidere quando c'è rete.
4. **Ogni azione porta il suo momento.** Ogni transazione della lista viene inviata con il momento in cui Andrea l'ha fatta (`changed_at`, millisecondi), non quello d'invio.
5. **Niente ricaricamenti dopo i gesti.** `add` e `remove` non chiamano più `refresh`: la copia locale è già giusta e la conferma del server arriva via socket.
6. **Avviso sulle sovrapposizioni.** Quando il server risponde che un'azione è stata superata, il postino la toglie dalla coda, riallinea quell'articolo dalla copia del server e mostra un avviso breve con il nome dell'articolo.

## Cosa cambia nel backend

- Aggiunta (`add-item-by-name`, `PUT /shoppinglist/<id>/item/<item>`) e rimozione (`DELETE /shoppinglist/<id>/item` e `/items`) accettano un `changed_at` opzionale. Per la rimozione `removed_at` esistente resta valido e vale come `changed_at`.
- Prima di applicare un'azione con `changed_at`, il server calcola l'ultimo momento noto in cui l'articolo è cambiato in quella lista: il più recente fra `shoppinglist_items.updated_at` (articolo in lista) e la voce più recente della cronologia per quell'articolo e quella lista (aggiunte e spunte). Se è successivo a `changed_at`, l'azione **non** si applica e la risposta dice `{"applied": false}` con lo stato attuale dell'articolo; altrimenti si applica e risponde `{"applied": true}`.
- La cronologia registra come data dell'aggiunta e della spunta il `changed_at` ricevuto, così l'ordinamento per ordine d'acquisto impara anche dalle spese fatte senza campo.
- Le chiamate senza `changed_at` (versione web, automazioni, app ufficiale) si comportano come oggi: si applicano sempre, con la data del server.

## Regola delle sovrapposizioni

Vince, per singolo articolo di una lista, l'azione con il momento più recente. Il confronto è sugli orologi del telefono e del server, entrambi sincronizzati in rete: uno scarto di qualche secondo è irrilevante per l'uso reale, perché una sovrapposizione richiede due modifiche allo stesso articolo nella stessa finestra in cui il telefono era scollegato. Si è scelta questa regola, invece di fusioni più elaborate, perché le azioni sulla lista sono quasi tutte "c'è / non c'è" e l'unico utente è Andrea.

La vecchia scadenza di tre giorni delle transazioni in coda (`runOpenTransactions`) non si applica alla lista della spesa: con la regola del momento più recente un'azione vecchia viene già scartata dal server se superata, quindi buttarla senza dirlo sarebbe solo una perdita silenziosa.

## Compilazione, firma, distribuzione

- L'APK si compila in un container Docker (Flutter + Android SDK), come per FairSpeed: niente SDK installati sul server.
- L'`applicationId` resta `com.tombursch.kitchenowl`: l'app nuova sostituisce quella dello store (che va disinstallata prima, perché la firma è diversa).
- La chiave di firma vive in `~/services/kitchenowl/firma-android/`, fuori dal repo e dentro il backup restic della home. Perderla vorrebbe dire non poter più aggiornare l'app installata senza disinstallarla.
- Il numero di versione segue quello di KitchenOwl con un suffisso nostro, in modo che si veda dalla schermata "Informazioni".
- L'APK arriva ad Andrea in chat con `ai-bridge-send`.

## Ramo git

Il lavoro del fork vive sul ramo `feature/item-photos`, che è già quello da cui si compila l'immagine Docker del server: le modifiche di questa feature vanno sullo stesso ramo, per avere un'unica linea del fork.
