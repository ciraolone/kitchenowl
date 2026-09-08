from marshmallow import fields, Schema, EXCLUDE, validate

from app.models.item_attachment import ATTACHMENT_KINDS


class SearchByNameRequest(Schema):
    query = fields.String(required=True, validate=lambda a: a and not a.isspace())


class UpdateItem(Schema):
    class Meta:
        unknown = EXCLUDE

    class Category(Schema):
        class Meta:
            unknown = EXCLUDE

        id = fields.Integer(required=True, validate=lambda a: a > 0)
        name = fields.String(validate=lambda a: not a or a and not a.isspace())

    category = fields.Nested(Category(), allow_none=True)
    icon = fields.String(
        validate=lambda a: not a or not a.isspace(),
        allow_none=True,
    )
    name = fields.String(
        validate=lambda a: not a or not a.isspace(),
        allow_none=True,
    )

    # if set this merges the specified item into this item thus combining them to one
    merge_item_id = fields.Integer(
        validate=lambda a: a > 0,
        allow_none=True,
    )


class AddItem(Schema):
    class Meta:
        unknown = EXCLUDE

    class Category(Schema):
        class Meta:
            unknown = EXCLUDE

        id = fields.Integer(required=True, validate=lambda a: a > 0)
        name = fields.String(validate=lambda a: not a or a and not a.isspace())

    category = fields.Nested(Category(), allow_none=True)
    icon = fields.String(
        validate=lambda a: not a or not a.isspace(),
        allow_none=True,
    )
    name = fields.String(
        validate=lambda a: not a or not a.isspace(),
        allow_none=False,
        required=True,
    )


# Schema usati dagli endpoint /api/item/<id>/attachment*
# Il client carica prima il file con POST /api/upload (gia' esistente), riceve
# un "filename" e poi crea l'allegato passando quel filename qui sotto.
class AddItemAttachment(Schema):
    class Meta:
        unknown = EXCLUDE

    filename = fields.String(required=True, validate=lambda a: a and not a.isspace())
    kind = fields.String(required=True, validate=validate.OneOf(ATTACHMENT_KINDS))
    # Etichetta facoltativa, usata solo per i PDF (le foto la ignorano).
    label = fields.String(allow_none=True)


class UpdateItemAttachment(Schema):
    class Meta:
        unknown = EXCLUDE

    # Per ora si aggiorna solo l'etichetta (rinomina dei PDF).
    label = fields.String(allow_none=True, required=True)


class ReorderItemAttachments(Schema):
    class Meta:
        unknown = EXCLUDE

    kind = fields.String(required=True, validate=validate.OneOf(ATTACHMENT_KINDS))
    # Lista ordinata di id ItemAttachment: la posizione nella lista determina il
    # nuovo "ordering" (la prima diventa la copertina nel caso delle foto).
    order = fields.List(
        fields.Integer(validate=lambda a: a > 0), required=True
    )
