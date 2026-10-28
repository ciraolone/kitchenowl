# Ordine manuale degli articoli dentro i reparti della lista della spesa (fork di Andrea, feature 004 e 007). L'ordine è il campo ordering degli articoli della casa, dato solo col trascinamento: zero vuol dire "mai ordinato a mano" e va in fondo, a parità si ordina per nome in minuscolo (lo stesso confronto di compareByRoute nell'app, altrimenti telefono e server sposterebbero in modo diverso). Qui sta la regola con cui un articolo trascinato prende posto (place_in_route, gemella di placeInRoute nell'app). Il nome "route" è storico: non c'è più un percorso imparato dalle spese.

from app import db
from app.models import Item


def route_key(item: Item):
    return (item.ordering == 0, item.ordering, item.name.lower())


def place_in_route(
    household_id: int,
    moved: Item,
    after: Item | None = None,
    before: Item | None = None,
):
    anchor = after or before
    if anchor is None or anchor.id == moved.id:
        return
    route = sorted(
        Item.query.filter(Item.household_id == household_id).all(), key=route_key
    )
    route.remove(moved)
    moved_index = route.index(anchor) + (1 if after else 0)
    route.insert(moved_index, moved)

    # Numerati fino allo spostato compreso; dopo, solo chi aveva già un posto: uno zero che resta dopo lo spostato deve restare in fondo
    next_ordering = 1
    for index, item in enumerate(route):
        if index <= moved_index or item.ordering != 0:
            item.ordering = next_ordering
            next_ordering += 1
            db.session.add(item)
