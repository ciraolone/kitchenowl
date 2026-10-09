# Regola delle sovrapposizioni della lista della spesa (fork di Andrea, feature 001-local-first): l'app Android lavora sulla sua copia locale e manda le azioni al server anche ore dopo, ciascuna con il momento in cui è stata fatta (changed_at, millisecondi). Per ogni articolo di una lista vince l'azione fatta per ultima: questo modulo converte changed_at in data, calcola l'ultimo momento in cui l'articolo è cambiato sul server (articolo in lista o cronologia di aggiunte e spunte) e dice se un'azione arrivata in ritardo è stata superata. Le chiamate senza changed_at (web, automazioni) non passano da qui e si applicano sempre.

from datetime import datetime, timezone

from flask import jsonify

from app.models import History, ShoppinglistItems


def changed_at_to_datetime(changed_at_ms: int | None) -> datetime | None:
    if changed_at_ms is None:
        return None
    # Le colonne di data sono senza fuso e contengono UTC (DbModelTimestampMixin)
    return datetime.fromtimestamp(changed_at_ms / 1000, timezone.utc).replace(
        tzinfo=None
    )


def last_change_of(shoppinglist_id: int, item_id: int) -> datetime | None:
    moments = []
    con = ShoppinglistItems.find_by_ids(shoppinglist_id, item_id)
    if con:
        moments.append(con.updated_at)
    latest_history = (
        History.query.filter(
            History.shoppinglist_id == shoppinglist_id,
            History.item_id == item_id,
        )
        .order_by(History.created_at.desc())
        .first()
    )
    if latest_history:
        moments.append(latest_history.created_at)
    return max((_as_naive_utc(moment) for moment in moments), default=None)


def is_superseded(
    shoppinglist_id: int, item_id: int | None, changed_at: datetime | None
) -> bool:
    if changed_at is None or item_id is None:
        return False
    last_change = last_change_of(shoppinglist_id, item_id)
    return last_change is not None and last_change > changed_at


def superseded_response(shoppinglist_id: int, item_id: int):
    con = ShoppinglistItems.find_by_ids(shoppinglist_id, item_id)
    return (
        jsonify(
            {
                "applied": False,
                "item_id": item_id,
                "server_item": con.obj_to_item_dict() if con else None,
            }
        ),
        409,
    )


def _as_naive_utc(moment: datetime) -> datetime:
    if moment.tzinfo is None:
        return moment
    return moment.astimezone(timezone.utc).replace(tzinfo=None)
