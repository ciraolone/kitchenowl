# Allegati a un prodotto (Item): foto o PDF.
#
# Un Item puo' avere fino a MAX_PHOTOS_PER_ITEM foto e MAX_PDFS_PER_ITEM PDF.
# La prima foto in ordine di "ordering" e' la copertina mostrata nella lista spesa.
# Per i PDF la "label" e' un nome leggibile rinominabile dall'utente
# (per default = nome del file caricato).
from __future__ import annotations
from typing import Any, Self, TYPE_CHECKING, cast

from app import db
from app.helpers import DbModelAuthorizeMixin
from sqlalchemy.orm import Mapped

Model = db.Model
if TYPE_CHECKING:
    from app.models import Item, File
    from app.helpers.db_model_base import DbModelBase

    Model = DbModelBase


# Tipi di allegato supportati. Estendendo questa lista in futuro
# (es. "audio") basta aggiornare anche il frontend e la validazione.
ATTACHMENT_KIND_PHOTO = "photo"
ATTACHMENT_KIND_PDF = "pdf"
ATTACHMENT_KINDS = (ATTACHMENT_KIND_PHOTO, ATTACHMENT_KIND_PDF)

# Limiti per item (concordati con l'utente, modificabili qui se cambiano i requisiti).
MAX_PHOTOS_PER_ITEM = 20
MAX_PDFS_PER_ITEM = 10


class ItemAttachment(Model, DbModelAuthorizeMixin):
    __tablename__ = "item_attachment"

    id: Mapped[int] = db.Column(db.Integer, primary_key=True)
    item_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("item.id"), nullable=False, index=True
    )
    file_filename: Mapped[str] = db.Column(
        db.String(), db.ForeignKey("file.filename"), nullable=False
    )
    # "photo" o "pdf" — vincolato lato schema marshmallow.
    kind: Mapped[str] = db.Column(db.String(16), nullable=False)
    # Posizione nella griglia/lista. La prima foto (ordering minore) e' la copertina.
    ordering: Mapped[int] = db.Column(
        db.Integer, nullable=False, server_default="0"
    )
    # Nome leggibile (usato per i PDF, null per le foto).
    label: Mapped[str | None] = db.Column(db.String(256), nullable=True)

    item: Mapped["Item"] = cast(
        Mapped["Item"],
        db.relationship(
            "Item",
            back_populates="attachments",
        ),
    )
    file: Mapped["File"] = cast(
        Mapped["File"],
        db.relationship(
            "File",
            back_populates="item_attachments",
        ),
    )

    @property
    def household_id(self) -> int:
        # Permette al mixin di autorizzazione di trovare l'household tramite l'item.
        return self.item.household_id

    def obj_to_dict(
        self,
        skip_columns: list[str] | None = None,
        include_columns: list[str] | None = None,
    ) -> dict[str, Any]:
        res = super().obj_to_dict(skip_columns, include_columns)
        # Espone l'hash di sfocatura per il placeholder grafico in fase di caricamento.
        if self.file is not None:
            res["blur_hash"] = self.file.blur_hash
        return res

    def delete(self):
        # Sgancia il File: se non e' piu' usato altrove viene cancellato fisicamente
        # subito (senza aspettare la routine periodica deleteUnusedFiles).
        from app.models import File

        f: "File" = self.file
        super().delete()
        if f is not None and f.isUnused():
            f.delete()

    @classmethod
    def find_by_id(cls, id: int) -> Self | None:
        return cls.query.filter(cls.id == id).first()

    @classmethod
    def count_for_item(cls, item_id: int, kind: str) -> int:
        return cls.query.filter(cls.item_id == item_id, cls.kind == kind).count()

    @classmethod
    def next_ordering(cls, item_id: int, kind: str) -> int:
        # Restituisce il prossimo "ordering" libero, in modo che il nuovo
        # allegato si accodi in fondo alla griglia/lista esistente.
        last = (
            cls.query.filter(cls.item_id == item_id, cls.kind == kind)
            .order_by(cls.ordering.desc())
            .first()
        )
        return (last.ordering + 1) if last else 0
