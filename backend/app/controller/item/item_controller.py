from app.helpers import validate_args, authorize_household
from flask import jsonify, Blueprint
from app.errors import InvalidUsage, NotFoundRequest
import app.util.description_splitter as description_splitter
from flask_jwt_extended import jwt_required
from app.models import Item, RecipeItems, Recipe, Category, ItemAttachment
from app.models.item_attachment import (
    ATTACHMENT_KIND_PHOTO,
    ATTACHMENT_KIND_PDF,
    MAX_PHOTOS_PER_ITEM,
    MAX_PDFS_PER_ITEM,
)
from app.service.file_has_access_or_download import file_has_access_or_download
from app.service.item_route import place_in_route
from app import db
from .schemas import (
    SearchByNameRequest,
    UpdateItem,
    AddItem,
    AddItemAttachment,
    UpdateItemAttachment,
    ReorderItemAttachments,
    ArrangeItem,
)

item = Blueprint("item", __name__)
itemHousehold = Blueprint("item", __name__)


@itemHousehold.route("", methods=["GET"])
@jwt_required()
@authorize_household()
def getAllItems(household_id):
    return jsonify(
        [e.obj_to_dict() for e in Item.all_from_household_by_name(household_id)]
    )


@item.route("/<int:id>", methods=["GET"])
@jwt_required()
def getItem(id):
    item = Item.find_by_id(id)
    if not item:
        raise NotFoundRequest()
    item.checkAuthorized()
    # Risposta "full" per la pagina dettaglio: include foto e PDF.
    return jsonify(item.obj_to_full_dict())


@item.route("/<int:id>/recipes", methods=["GET"])
@jwt_required()
def getItemRecipes(id):
    item = Item.find_by_id(id)
    if not item:
        raise NotFoundRequest()
    item.checkAuthorized()
    recipe = (
        RecipeItems.query.filter(RecipeItems.item_id == id)
        .join(RecipeItems.recipe)  # noqa
        .order_by(Recipe.name)
        .all()
    )
    return jsonify([e.obj_to_recipe_dict() for e in recipe])


@item.route("/<int:id>", methods=["DELETE"])
@jwt_required()
def deleteItemById(id):
    item = Item.find_by_id(id)
    if not item:
        raise NotFoundRequest()
    item.checkAuthorized()
    item.delete()
    return jsonify({"msg": "DONE"})


@itemHousehold.route("/search", methods=["GET"])
@jwt_required()
@authorize_household()
@validate_args(SearchByNameRequest)
def searchItemByName(args, household_id):
    query, description = description_splitter.split(args["query"])
    return jsonify(
        [
            e.obj_to_dict() | {"description": description}
            for e in Item.search_name(query, household_id)
        ]
    )


@itemHousehold.route("", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(AddItem)
def addItem(args, household_id):
    name: str = args["name"].strip()[:128]
    if Item.find_by_name(household_id, name):
        raise InvalidUsage()

    item = Item(household_id=household_id, name=name)
    if "category" in args:
        if not args["category"]:
            item.category = None
        elif "id" in args["category"]:
            item.category = Category.find_by_id(args["category"]["id"])
        else:
            raise InvalidUsage()
    if "icon" in args:
        item.icon = args["icon"]
    item.save()

    return jsonify(item.obj_to_dict())


# Trascinamento nella lista della spesa (fork di Andrea, feature 004 e 007): sposta l'articolo nell'ordine manuale del suo reparto, oppure in un altro reparto, dove va in fondo (ordering 0, come fa arrangeItems nell'app: se lo facesse un lato solo, l'articolo salterebbe di posto al primo aggiornamento). Vince l'ultimo arrivato, senza la regola delle sovrapposizioni della feature 001.
@itemHousehold.route("/arrange", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(ArrangeItem)
def arrangeItem(args, household_id):
    moved = _household_item(household_id, args["item_id"])
    after = _household_item(household_id, args.get("after_item_id"))
    before = _household_item(household_id, args.get("before_item_id"))

    if "category" in args:
        _move_to_category(household_id, moved, args["category"])
        db.session.commit()
        return jsonify(moved.obj_to_dict())

    place_in_route(household_id, moved, after=after, before=before)
    db.session.commit()

    return jsonify(moved.obj_to_dict())


def _move_to_category(household_id: int, moved: Item, category_ref: dict | None):
    category = Category.find_by_id(category_ref["id"]) if category_ref else None
    if category is not None and category.household_id != household_id:
        raise InvalidUsage()
    moved.category = category
    moved.ordering = 0
    db.session.add(moved)


def _household_item(household_id: int, item_id: int | None) -> Item | None:
    if item_id is None:
        return None
    item = Item.find_by_id(item_id)
    if not item or item.household_id != household_id:
        raise NotFoundRequest()
    return item


@item.route("/<int:id>", methods=["POST"])
@jwt_required()
@validate_args(UpdateItem)
def updateItem(args, id):
    item = Item.find_by_id(id)
    if not item:
        raise NotFoundRequest()
    item.checkAuthorized()

    if "category" in args:
        if not args["category"]:
            item.category = None
        elif "id" in args["category"]:
            item.category = Category.find_by_id(args["category"]["id"])
        else:
            raise InvalidUsage()
    if "icon" in args:
        item.icon = args["icon"]
    if "name" in args and args["name"] != item.name:
        newName: str = args["name"].strip()[:128]
        if not Item.find_by_name(item.household_id, newName):
            item.name = newName
    item.save()

    if "merge_item_id" in args and args["merge_item_id"] != id:
        mergeItem = Item.find_by_id(args["merge_item_id"])
        if mergeItem:
            item.merge(mergeItem)

    return jsonify(item.obj_to_full_dict())


# -----------------------------------------------------------------------------
# Endpoint per gli allegati (foto e PDF) di un Item.
# Flusso lato client: prima POST /api/upload -> riceve "filename", poi
# POST /api/item/<id>/attachment con quel filename per associarlo all'item.
# -----------------------------------------------------------------------------


def _get_authorized_item(id: int) -> Item:
    item = Item.find_by_id(id)
    if not item:
        raise NotFoundRequest()
    item.checkAuthorized()
    return item


@item.route("/<int:id>/attachment", methods=["POST"])
@jwt_required()
@validate_args(AddItemAttachment)
def addItemAttachment(args, id):
    item = _get_authorized_item(id)

    kind = args["kind"]
    # Limite numero allegati per tipo, per evitare abuso di spazio disco.
    current = ItemAttachment.count_for_item(item.id, kind)
    cap = MAX_PHOTOS_PER_ITEM if kind == ATTACHMENT_KIND_PHOTO else MAX_PDFS_PER_ITEM
    if current >= cap:
        raise InvalidUsage()

    # Risolve il filename: se gia' usato altrove fa una copia, altrimenti lo
    # "consuma" lasciandolo intatto. Restituisce None se il file non esiste o
    # l'utente non ne ha l'accesso.
    resolved = file_has_access_or_download(args["filename"])
    if not resolved:
        raise InvalidUsage()

    label = args.get("label")
    # Per i PDF, se il client non passa l'etichetta, la default e' il nome originale.
    if kind == ATTACHMENT_KIND_PDF and not label:
        label = args["filename"]

    attachment = ItemAttachment(
        item_id=item.id,
        file_filename=resolved,
        kind=kind,
        ordering=ItemAttachment.next_ordering(item.id, kind),
        label=label,
    )
    attachment.save()
    return jsonify(attachment.obj_to_dict())


@item.route("/<int:id>/attachment/<int:attachment_id>", methods=["POST"])
@jwt_required()
@validate_args(UpdateItemAttachment)
def updateItemAttachment(args, id, attachment_id):
    item = _get_authorized_item(id)
    attachment = ItemAttachment.find_by_id(attachment_id)
    if not attachment or attachment.item_id != item.id:
        raise NotFoundRequest()

    # La rinomina ha senso solo per i PDF; per le foto la ignoriamo silenziosamente.
    if attachment.kind == ATTACHMENT_KIND_PDF:
        attachment.label = args["label"]
        attachment.save()
    return jsonify(attachment.obj_to_dict())


@item.route("/<int:id>/attachment/<int:attachment_id>", methods=["DELETE"])
@jwt_required()
def deleteItemAttachment(id, attachment_id):
    item = _get_authorized_item(id)
    attachment = ItemAttachment.find_by_id(attachment_id)
    if not attachment or attachment.item_id != item.id:
        raise NotFoundRequest()

    attachment.delete()
    return jsonify({"msg": "DONE"})


@item.route("/<int:id>/attachment/reorder", methods=["PUT"])
@jwt_required()
@validate_args(ReorderItemAttachments)
def reorderItemAttachments(args, id):
    item = _get_authorized_item(id)

    kind = args["kind"]
    requested_ids: list[int] = args["order"]

    # Carica solo gli allegati del tipo richiesto e indicizzali per id.
    existing = {
        a.id: a
        for a in ItemAttachment.query.filter(
            ItemAttachment.item_id == item.id, ItemAttachment.kind == kind
        ).all()
    }

    # Sicurezza: l'elenco deve essere una permutazione esatta degli id esistenti.
    if set(requested_ids) != set(existing.keys()):
        raise InvalidUsage()

    for new_pos, att_id in enumerate(requested_ids):
        existing[att_id].ordering = new_pos
        db.session.add(existing[att_id])
    db.session.commit()

    return jsonify([existing[att_id].obj_to_dict() for att_id in requested_ids])
