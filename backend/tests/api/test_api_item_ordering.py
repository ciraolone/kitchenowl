# Ordinamento automatico della lista ("in base all'ordine d'acquisto"): gli articoli spuntati durante una spesa finiscono nella cronologia, e l'analisi notturna (jobs.daily) ne ricava il campo ordering di ogni articolo. Questi test spuntano gli articoli in un ordine diverso da quello di creazione, lanciano l'analisi e controllano che l'ordine imparato sia quello di spunta.

from app.jobs.jobs import daily
from app.models import Item

ITEM_NAMES = ["Pane", "Latte", "Mele", "Pasta", "Uova", "Caffè"]
PURCHASE_ORDER = ["Pasta", "Pane", "Caffè", "Latte", "Uova", "Mele"]


def add_items(client, shoppinglist_id):
    for name in ITEM_NAMES:
        response = client.post(
            f"/api/shoppinglist/{shoppinglist_id}/add-item-by-name",
            json={"name": name},
        )
        assert response.status_code == 200
    response = client.get(f"/api/shoppinglist/{shoppinglist_id}/items")
    return {item["name"]: item["id"] for item in response.get_json()}


def check_off(client, shoppinglist_id, item_ids, names):
    for name in names:
        response = client.delete(
            f"/api/shoppinglist/{shoppinglist_id}/item",
            json={"item_id": item_ids[name]},
        )
        assert response.status_code == 200


def learned_order(item_ids):
    items = [Item.find_by_id(item_id) for item_id in item_ids.values()]
    return [item.name for item in sorted(items, key=lambda item: item.ordering)]


def test_ordering_follows_the_order_items_were_checked_off(
    user_client_with_household, shoppinglist_id
):
    item_ids = add_items(user_client_with_household, shoppinglist_id)
    check_off(user_client_with_household, shoppinglist_id, item_ids, PURCHASE_ORDER)

    daily()

    assert learned_order(item_ids) == PURCHASE_ORDER
