# Percorso nel negozio, cioè l'ordine automatico della lista della spesa (fork di Andrea, feature 004-riordino-trascinamento). Il percorso è il campo ordering degli articoli della casa: zero vuol dire "mai piazzato" e va in fondo, a parità si ordina per nome in minuscolo (lo stesso confronto di compareByRoute nell'app, altrimenti telefono e server sposterebbero in modo diverso). Qui stanno la regola con cui un articolo trascinato prende posto (place_in_route, gemella di placeInRoute nell'app), il salvataggio dell'ordine lasciato da Andrea come ricordo per l'analisi notturna (remember_route) e la fusione di spese e ricordi in ordine di tempo che l'analisi passa al calcolo dell'ordine (route_instances).

from datetime import datetime

from app import db
from app.models import Item, ItemRouteHint


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


def remember_route(household_id: int, item_ids: list[int], changed_at: datetime | None):
    if len(item_ids) < 2:
        return
    hint = ItemRouteHint(household_id=household_id, item_ids=item_ids)
    if changed_at is not None:
        hint.created_at = changed_at
    db.session.add(hint)


def route_instances(
    household_id: int, shoppings: list[tuple[datetime, list[int]]]
) -> list[list[int]]:
    hints = [
        (hint.created_at, hint.item_ids)
        for hint in ItemRouteHint.all_by_household(household_id)
    ]
    # L'ordine di tempo conta: il calcolo fa pesare di più ciò che arriva per ultimo
    merged = sorted(shoppings + hints, key=lambda instance: instance[0])
    return [item_ids for _, item_ids in merged]
