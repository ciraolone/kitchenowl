<!-- Ordine dei lavori della feature 001 (lista della spesa local first). Si spunta man mano; il cosa sta in spec.md, il come in plan.md. -->

# Compiti

## Backend

- [x] `changed_at` opzionale su aggiunta, modifica descrizione e rimozione (singola e multipla), con `removed_at` ancora accettato
- [x] Regola "vince il più recente" per articolo, risposta `409` con lo stato del server
- [x] Cronologia datata con `changed_at`
- [x] Test API: azione superata scartata, azione più recente applicata, chiamate senza `changed_at` invariate, data della spunta presa da `changed_at`
- [x] Ricompilare l'immagine del server e riavviare il container

## Compilazione Android

- [x] Compilazione in container Flutter + Android SDK (`build-android.sh`, immagine cirruslabs già pronta)
- [x] Chiave di firma in `~/services/kitchenowl/firma-android/` e configurazione di firma nel progetto Android
- [x] Prima compilazione dell'APK invariato, per verificare che la catena funzioni prima di toccare l'app

## App

- [x] Catalogo articoli nella copia persistente, aggiornato in sottofondo e dagli eventi socket
- [x] Ricerca dal catalogo locale, senza rete
- [x] Letture della lista sempre dalla copia locale, aggiornamento in sottofondo (apertura, ritorno in primo piano, riconnessione, eventi socket)
- [x] Coda persistente sempre attiva con un unico postino; scrittura locale immediata
- [x] `changed_at` su ogni transazione della lista
- [x] Niente `refresh` dopo `add` e `remove`
- [x] Gestione della risposta `409`: riallineo dell'articolo e avviso con il nome
- [x] Niente scadenza dei tre giorni per le transazioni della lista
- [x] Test unitari su ricerca locale ed esito delle consegne (la coda e il riallineo dipendono da file e rete del telefono: si verificano nella prova sul campo)

## Consegna

- [x] APK firmato mandato ad Andrea in chat, con le istruzioni di installazione (disinstallare prima l'app dello store)
- [ ] Prova sul campo: ricerca, aggiunta e spunta in modalità aereo, ritorno della rete, sovrapposizione provocata apposta
