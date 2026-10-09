<!-- Specifica della trasformazione "local first" dell'app Android di KitchenOwl nel fork di Andrea: cosa deve vedere e poter fare Andrea, cosa resta fuori, come si comporta l'app quando telefono e server non sono d'accordo. Il come tecnico sta in plan.md, l'ordine dei lavori in tasks.md. -->

# Lista della spesa local first

## Perché

L'app Android ufficiale è lenta: ogni lettera scritta nella ricerca e ogni articolo aggiunto aspettano il server, che sta a casa dietro Cloudflare e una linea 5G. Una singola domanda costa 150-400 millisecondi e l'app ne fa tre in fila per ogni gesto, quindi si arriva a quasi un secondo per tasto. Al supermercato, con poco campo, peggiora.

L'intero archivio è piccolo (11 MB, circa 750 articoli, un solo utente) e sta tutto comodamente sul telefono. L'idea è ribaltare la priorità: il telefono è la fonte da cui l'app legge e su cui scrive, il server resta la copia di riferimento per il backup, le automazioni e gli altri dispositivi (la versione web dal PC).

## Cosa deve succedere

### Aprire l'app

- La lista compare subito con l'ultimo stato noto, senza schermata di caricamento, anche senza rete.
- Se la rete c'è, l'app si aggiorna da sola in sottofondo e i cambiamenti arrivati nel frattempo compaiono senza che Andrea faccia nulla.

### Cercare un articolo

- I risultati compaiono a ogni lettera, istantanei, cercando fra **tutti** gli articoli mai usati (non solo quelli in lista o recenti), anche senza rete.
- Scrivere nella ricerca non genera traffico verso il server.

### Aggiungere, spuntare, modificare

- Aggiungere un articolo, spuntarlo o cambiarne la descrizione ha effetto immediato sullo schermo, sempre, con o senza rete.
- La modifica parte verso il server in sottofondo. Se la rete manca resta in coda sul telefono e parte da sola appena la rete torna, anche dopo giorni e anche se l'app è stata chiusa nel frattempo.
- Nessuna modifica fatta sul telefono va persa in silenzio.
- Il momento registrato di ogni spunta è quello in cui Andrea l'ha fatta, non quello in cui è arrivata al server: l'ordinamento automatico per ordine d'acquisto deve imparare bene anche dalle spese fatte senza campo.

### Modifiche che arrivano da fuori

- Se la lista cambia sul server (automazioni, versione web) mentre il telefono è in rete, il cambiamento compare sul telefono entro pochi secondi.
- Se il telefono era senza rete, i cambiamenti arrivano al primo collegamento utile.

### Sovrapposizioni

Una sovrapposizione è lo stesso articolo modificato in due posti mentre il telefono era senza rete: per esempio spuntato al supermercato senza campo e, nel frattempo, riaggiunto da un'automazione.

- Per ogni articolo vince la modifica **fatta per ultima**, contando il momento in cui è stata fatta e non quello in cui è arrivata al server.
- Le modifiche su articoli diversi non si pestano mai i piedi: si applicano tutte.
- Quando una modifica fatta sul telefono viene scartata perché sul server ce n'è una più recente, l'app lo dice con un avviso discreto che nomina l'articolo (es. "Latte: sul server c'è una modifica più recente, tenuta quella").
- Dopo la riconciliazione telefono e server mostrano la stessa lista.

### Installazione e aggiornamenti

- L'app è una versione compilata da noi: sostituisce quella dello store, va installata a mano e richiede un nuovo accesso. I dati stanno sul server e non si perdono.
- Gli aggiornamenti arrivano come file da installare mandato in chat, non più dallo store.

## Fuori da questo lavoro

- Ricette, pianificatore dei pasti e spese restano come sono oggi (chiedono al server). Oggi non sono usati; si riprenderanno se servirà.
- Più persone che modificano la stessa lista contemporaneamente: la regola "vince l'ultima" vale anche per loro, ma non si costruisce niente di più sofisticato (fusioni, storico delle versioni).
- La versione web e l'app per iPhone non cambiano comportamento.
