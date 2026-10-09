# KitchenOwl — fork di Andrea

Fork personale di [KitchenOwl](https://github.com/TomBursch/kitchenowl) (lista della spesa, ricette, spese). Da qui nascono sia il server che gira sul home server (container `kitchenowl`, stack `~/homelab/stacks/house`, pubblico su `kitchen.ciraolo.cloud`) sia l'app Android che Andrea usa sul telefono, compilata e firmata da noi al posto di quella dello store.

## Rami e upstream

- Si lavora sul ramo `feature/item-photos`, che è l'unica linea del fork: da lì si compilano server e app. Il nome è storico (la prima modifica furono foto e PDF sugli articoli).
- `upstream` è il progetto originale, con push disabilitato. Per portare dentro una versione nuova: `git fetch upstream` e merge nel ramo del fork, poi si ricompilano server e app.

## Le modifiche del fork

Ogni modifica non banale ha la sua cartella in `features/` (spec, plan, tasks). Quelle fatte prima di questa convenzione:

- Foto e PDF allegati agli articoli (backend + app).
- Ordinamento "per ordine d'acquisto": l'analisi notturna imparava l'ordine di creazione degli articoli invece di quello di spunta (corretto in `backend/app/jobs/cluster_shoppings.py`, prova in `backend/tests/api/test_api_item_ordering.py`).

## Prove

- Backend: le dipendenze non si installano sul server (manca ICU per `sqlite-icu`), quindi si usano quelle dell'immagine già compilata:
  `docker run --rm -v ~/projects/kitchenowl/backend:/src -w /src --entrypoint sh ciraolone/kitchenowl:v0.7.8-photos -c "/opt/venv/bin/python -m ensurepip >/dev/null; /opt/venv/bin/python -m pip install -q pytest; /opt/venv/bin/python -m pytest tests -q -p no:cacheprovider"`
- App: nel container Flutter, dalla cartella `kitchenowl/`:
  `docker run --rm -v $PWD:/app -v kitchenowl-pub-cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:3.41.7 sh -c "flutter pub get && flutter analyze && flutter test"`
  I file creati dal container sono di root: a fine giro va fatto `chown` di `build/` e `.dart_tool/` (lo script di compilazione lo fa da sé).

## Rilascio

- Server: `docker build -t ciraolone/kitchenowl:v0.7.8-photos ~/projects/kitchenowl` e poi `docker compose up -d kitchenowl` in `~/homelab/stacks/house`. L'immagine contiene anche la versione web dell'app.
- App Android: `./build-android.sh`, l'APK finisce in `dist/` e si manda ad Andrea in chat. La chiave di firma sta in `~/services/kitchenowl/firma-android/` (dentro il backup della home): senza quella, l'app installata non si aggiorna più.
