# Riordino a trascinamento della lista della spesa (fork di Andrea, feature 004): POST /api/household/<id>/item/arrange mette un articolo subito dopo o subito prima di un altro nel percorso (campo ordering), può cambiargli reparto e ricorda l'ordine del gruppo per l'analisi notturna, che lo tratta come una spesa fatta in quel momento. Qui anche la finestra di 2 ore che tiene insieme le spunte della stessa spesa.

import time

from app import db
from app.jobs.jobs import daily
from app.models import Item

HOUR_MS = 3_600_000


def now_ms():
    return int(time.time() * 1000)


def add_items(client, shoppinglist_id, names):
    for name in names:
        response = client.post(
            f"/api/shoppinglist/{shoppinglist_id}/add-item-by-name",
            json={"name": name},
        )
        assert response.status_code == 200
    response = client.get(f"/api/shoppinglist/{shoppinglist_id}/items")
    return {item["name"]: item["id"] for item in response.get_json()}


def place_in_order(item_ids, names):
    for ordering, name in enumerate(names, start=1):
        Item.find_by_id(item_ids[name]).ordering = ordering
    db.session.commit()


def route_of(item_ids):
    items = [Item.find_by_id(item_id) for item_id in item_ids.values()]
    placed = sorted(
        (item for item in items if item.ordering != 0), key=lambda i: i.ordering
    )
    unplaced = sorted(item.name for item in items if item.ordering == 0)
    return [item.name for item in placed] + unplaced


def arrange(client, household_id, **body):
    return client.post(f"/api/household/{household_id}/item/arrange", json=body)


def test_item_dropped_after_another_takes_the_place_right_after_it(
    user_client_with_household, household_id, shoppinglist_id
):
    client = user_client_with_household
    item_ids = add_items(client, shoppinglist_id, ["Pane", "Latte", "Mele", "Uova"])
    place_in_order(item_ids, ["Pane", "Latte", "Mele", "Uova"])

    response = arrange(
        client,
        household_id,
        item_id=item_ids["Pane"],
        after_item_id=item_ids["Mele"],
    )

    assert response.status_code == 200
    assert route_of(item_ids) == ["Latte", "Mele", "Pane", "Uova"]


def test_never_placed_item_dropped_before_another_gets_a_place_and_the_others_stay_last(
    user_client_with_household, household_id, shoppinglist_id
):
    client = user_client_with_household
    item_ids = add_items(client, shoppinglist_id, ["Pane", "Latte", "Mele", "Uova"])
    place_in_order(item_ids, ["Pane", "Latte"])

    arrange(
        client,
        household_id,
        item_id=item_ids["Uova"],
        before_item_id=item_ids["Latte"],
    )

    assert route_of(item_ids) == ["Pane", "Uova", "Latte", "Mele"]
    assert Item.find_by_id(item_ids["Mele"]).ordering == 0


def test_item_dropped_on_another_category_changes_category_for_good(
    user_client_with_household, household_id, shoppinglist_id
):
    client = user_client_with_household
    item_ids = add_items(client, shoppinglist_id, ["Latte"])
    category_id = client.post(
        f"/api/household/{household_id}/category", json={"name": "Frigo"}
    ).get_json()["id"]

    arrange(
        client, household_id, item_id=item_ids["Latte"], category={"id": category_id}
    )
    assert Item.find_by_id(item_ids["Latte"]).category_id == category_id

    arrange(client, household_id, item_id=item_ids["Latte"], category=None)
    assert Item.find_by_id(item_ids["Latte"]).category_id is None


def test_nightly_analysis_keeps_a_drag_made_after_the_last_shopping(
    user_client_with_household, household_id, shoppinglist_id
):
    client = user_client_with_household
    names = ["Pane", "Latte", "Mele", "Pasta", "Uova"]
    item_ids = add_items(client, shoppinglist_id, names)
    shopping_started_at = now_ms() + 1000
    for minute, name in enumerate(names):
        client.delete(
            f"/api/shoppinglist/{shoppinglist_id}/item",
            json={"item_id": item_ids[name], "changed_at": shopping_started_at + minute * 60_000},
        )
    daily()
    assert route_of(item_ids) == names

    dragged_route = ["Latte", "Pane", "Mele", "Pasta", "Uova"]
    arrange(
        client,
        household_id,
        item_id=item_ids["Pane"],
        after_item_id=item_ids["Latte"],
        route=[item_ids[name] for name in dragged_route],
        changed_at=shopping_started_at + HOUR_MS,
    )
    daily()

    assert route_of(item_ids) == dragged_route


def test_five_check_offs_half_an_hour_apart_are_one_shopping(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    names = ["Pasta", "Pane", "Caffè", "Latte", "Uova"]
    item_ids = add_items(client, shoppinglist_id, names)
    shopping_started_at = now_ms() + 1000
    for index, name in enumerate(names):
        client.delete(
            f"/api/shoppinglist/{shoppinglist_id}/item",
            json={
                "item_id": item_ids[name],
                "changed_at": shopping_started_at + index * HOUR_MS // 2,
            },
        )

    daily()

    assert route_of(item_ids) == names
