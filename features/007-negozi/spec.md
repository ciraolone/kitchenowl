<!-- Cosa fa e perché la feature 007 del fork di Andrea: una lista separata per ogni negozio, ottenuta trasformando le "case" di KitchenOwl in negozi, ciascuno con articoli, reparti e impostazioni propri; insieme sparisce l'ordine del percorso imparato dalle spese, sostituito da un ordine manuale dentro i reparti. Il come sta in plan.md. -->

# Negozi

## Perché

Andrea compra in negozi diversi (supermercato, IKEA, ...) e vuole per ciascuno una lista a sé: con i suoi articoli, i suoi reparti e il suo modo di essere mostrata. L'ordine del percorso imparato dalle spese non lo usa: bastano i reparti, con un ordine deciso a mano.

In KitchenOwl ogni "casa" ha già articoli, reparti e lista propri, separati dalle altre. Ogni negozio è quindi una casa, e nell'app la parola "casa" diventa "negozio".

## Comportamento

### Negozi

- Ovunque nell'app (telefono e versione web) la casa si chiama **Store** al posto di **Household**: pulsante, pannello, elenco, impostazioni, creazione.
- La casa attuale "Famiglia" diventa il primo negozio, con tutti i suoi articoli, reparti e foto. Il nome lo cambia Andrea dalle impostazioni del negozio.
- Ogni negozio ha **solo i suoi** articoli, reparti e impostazioni. Nulla è condiviso: un articolo comprato in due negozi esiste due volte, una per negozio.
- Un negozio nuovo si crea come oggi una casa nuova, e nasce senza articoli e senza reparti.

### Passare da un negozio all'altro

- Nel pannello del pulsante negozio c'è l'elenco dei negozi: un tocco apre la lista di quello scelto, senza passare dall'elenco completo.
- All'apertura l'app mostra l'ultimo negozio usato. La scorciatoia "Add item" del launcher (feature 002) apre la ricerca nell'ultimo negozio usato.
- Il passaggio è immediato e funziona anche senza rete, per tutti i negozi già aperti almeno una volta sul telefono: ognuno si comporta come la lista di oggi (feature 001), con le modifiche fatte senza rete che partono da sole quando la rete torna.

### Impostazioni per negozio

- Le impostazioni della lista valgono per il singolo negozio: vista a griglia o a elenco, dimensione della griglia, stile dell'elenco, icone nascoste (feature 006), tocco che spunta o seleziona, numero di articoli recenti e loro divisione per reparti, schermo sempre acceso, ordinamento scelto. Esempio: supermercato in griglia, IKEA in elenco.
- Si cambiano dalle stesse impostazioni di oggi, che agiscono sul negozio aperto in quel momento: la sezione della lista mostra il nome del negozio, e senza un negozio aperto non compare.
- Tema e colori restano uguali per tutta l'app.
- Un negozio nuovo parte con le impostazioni di serie (griglia, ordinamento per reparti).
- Le impostazioni restano sul telefono, come oggi: non passano alla versione web.

### Fine dell'ordine del percorso

- L'ordinamento **automatico** (per ordine d'acquisto) non c'è più: restano **alfabetico** e **per reparti**.
- Di notte il server non calcola più l'ordine degli articoli. I suggerimenti degli articoli recenti restano come sono.

### Ordine manuale dentro il reparto

- Nell'ordinamento per reparti gli articoli di ogni reparto seguono un ordine deciso da Andrea col dito, con lo stesso gesto di oggi (feature 004): tenere premuto, trascinare, lasciare sopra un altro articolo.
- L'ordine resta finché Andrea non lo cambia: vale per sempre e per tutti, e non viene più ricalcolato dalle spese.
- Il punto di partenza è l'ordine di oggi: niente si rimescola il giorno del cambio.
- Un articolo mai ordinato a mano, o appena spostato in un altro reparto, va in fondo al reparto.
- Lo spostamento in un altro reparto e il riordino dei reparti fra loro (feature 004 e 005) restano come sono.
- Nell'ordinamento alfabetico il trascinamento non c'è.

## Fuori scope

- Articoli o reparti condivisi fra negozi, e copiare articoli da un negozio all'altro.
- Creare, rinominare o cancellare negozi senza rete.
- Ricette, pianificatore e spese: restano legati al negozio come oggi alla casa, ma Andrea non li usa dal telefono.
