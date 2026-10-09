<!-- Ordine dei lavori della feature 001 (lista della spesa local first). Si spunta man mano; il cosa sta in spec.md, il come in plan.md. -->

# Compiti

## Backend

- [ ] `changed_at` opzionale su aggiunta, modifica descrizione e rimozione (singola e multipla), con `removed_at` ancora accettato
- [ ] Regola "vince il più recente" per articolo e risposta `applied: true/false` con lo stato attuale
- [ ] Cronologia datata con `changed_at`
- [ ] Test API: azione superata scartata, azione più recente applicata, chiamate senza `changed_at` invariate, data della spunta presa da `changed_at`
- [ ] Ricompilare l'immagine del server e riavviare il container

## Compilazione Android

- [ ] Immagine Docker di compilazione (Flutter + Android SDK)
- [ ] Chiave di firma in `~/services/kitchenowl/firma-android/` e configurazione di firma nel progetto Android
- [ ] Prima compilazione dell'APK invariato, per verificare che la catena funzioni prima di toccare l'app

## App

- [ ] Catalogo articoli nella copia persistente, aggiornato in sottofondo e dagli eventi socket
- [ ] Ricerca dal catalogo locale, senza rete
- [ ] Letture della lista sempre dalla copia locale, aggiornamento in sottofondo (apertura, ritorno in primo piano, riconnessione, eventi socket)
- [ ] Coda persistente sempre attiva con un unico postino; scrittura locale immediata
- [ ] `changed_at` su ogni transazione della lista
- [ ] Niente `refresh` dopo `add` e `remove`
- [ ] Gestione `applied: false`: riallineo dell'articolo e avviso con il nome
- [ ] Niente scadenza dei tre giorni per le transazioni della lista
- [ ] Test unitari su coda, regola di riallineo e ricerca locale

## Consegna

- [ ] APK firmato mandato ad Andrea in chat, con le istruzioni di installazione (disinstallare prima l'app dello store)
- [ ] Prova sul campo: ricerca, aggiunta e spunta in modalità aereo, ritorno della rete, sovrapposizione provocata apposta
