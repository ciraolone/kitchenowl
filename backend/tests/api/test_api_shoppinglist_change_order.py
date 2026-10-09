# Sovrapposizioni della lista della spesa (feature 001-local-first): l'app manda le azioni fatte senza rete in ritardo, con il momento in cui sono state fatte (changed_at). Per ogni articolo vince l'azione fatta per ultima; un'azione superata risponde 409 con lo stato del server e non cambia niente. Le chiamate senza changed_at si applicano sempre come prima.

import time
from datetime import datetime, timezone

from app.models import History, Status

MINUTE_MS = 60_000


def now_ms():
    return int(time.time() * 1000)


def add(client, shoppinglist_id, name, **extra):
    return client.post(
        f"/api/shoppinglist/{shoppinglist_id}/add-item-by-name",
        json={"name": name, **extra},
    )


def remove(client, shoppinglist_id, item_id, **extra):
    return client.delete(
        f"/api/shoppinglist/{shoppinglist_id}/item",
        json={"item_id": item_id, **extra},
    )


def names_in_list(client, shoppinglist_id):
    response = client.get(f"/api/shoppinglist/{shoppinglist_id}/items")
    return [item["name"] for item in response.get_json()]


def test_offline_check_off_older_than_a_server_re_add_is_discarded(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    checked_off_offline_at = now_ms() - MINUTE_MS
    item_id = add(client, shoppinglist_id, "Latte").get_json()["id"]

    response = remove(
        client, shoppinglist_id, item_id, changed_at=checked_off_offline_at
    )

    assert response.status_code == 409
    assert response.get_json()["server_item"]["name"] == "Latte"
    assert names_in_list(client, shoppinglist_id) == ["Latte"]


def test_check_off_newer_than_the_last_server_change_is_applied_with_its_own_time(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    item_id = add(client, shoppinglist_id, "Latte").get_json()["id"]
    checked_off_at = now_ms() + 1000

    response = remove(client, shoppinglist_id, item_id, changed_at=checked_off_at)

    assert response.status_code == 200
    assert names_in_list(client, shoppinglist_id) == []
    dropped = History.query.filter(History.status == Status.DROPPED).one()
    expected = datetime.fromtimestamp(checked_off_at / 1000, timezone.utc)
    assert dropped.created_at == expected.replace(tzinfo=None)


def test_offline_add_older_than_a_server_check_off_is_discarded(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    added_offline_at = now_ms() - MINUTE_MS
    item_id = add(client, shoppinglist_id, "Pane").get_json()["id"]
    remove(client, shoppinglist_id, item_id)

    response = add(client, shoppinglist_id, "Pane", changed_at=added_offline_at)

    assert response.status_code == 409
    assert response.get_json()["server_item"] is None
    assert names_in_list(client, shoppinglist_id) == []


def test_offline_description_older_than_the_server_one_is_discarded(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    edited_offline_at = now_ms() - MINUTE_MS
    item_id = add(client, shoppinglist_id, "Uova", description="6").get_json()["id"]

    response = client.put(
        f"/api/shoppinglist/{shoppinglist_id}/item/{item_id}",
        json={"description": "12", "changed_at": edited_offline_at},
    )

    assert response.status_code == 409
    assert response.get_json()["server_item"]["description"] == "6"


def test_calls_without_changed_at_always_apply(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    item_id = add(client, shoppinglist_id, "Mele").get_json()["id"]
    remove(client, shoppinglist_id, item_id, changed_at=now_ms() + MINUTE_MS)

    response = add(client, shoppinglist_id, "Mele")

    assert response.status_code == 200
    assert names_in_list(client, shoppinglist_id) == ["Mele"]


def test_bulk_check_off_reports_the_superseded_items_and_applies_the_others(
    user_client_with_household, shoppinglist_id
):
    client = user_client_with_household
    checked_off_offline_at = now_ms() - MINUTE_MS
    pasta_id = add(client, shoppinglist_id, "Pasta").get_json()["id"]
    sale_id = add(client, shoppinglist_id, "Sale").get_json()["id"]

    response = client.delete(
        f"/api/shoppinglist/{shoppinglist_id}/items",
        json={
            "items": [
                {"item_id": pasta_id, "changed_at": checked_off_offline_at},
                {"item_id": sale_id, "changed_at": now_ms() + 1000},
            ]
        },
    )

    assert response.status_code == 200
    assert response.get_json()["superseded_item_ids"] == [pasta_id]
    assert names_in_list(client, shoppinglist_id) == ["Pasta"]
