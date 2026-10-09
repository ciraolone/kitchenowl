# Ricordo di un riordino a trascinamento della lista della spesa (fork di Andrea, feature 004-riordino-trascinamento): l'ordine in cui Andrea ha lasciato un gruppo di articoli (tutta la lista o un reparto), con created_at uguale al momento del gesto. L'analisi notturna (jobs.daily) lo tratta come una spesa fatta in quell'ordine e in quel momento, così l'ordine automatico impara anche dai trascinamenti. Scritto solo da service/item_route.py.
from typing import List, TYPE_CHECKING

from app import db
from app.helpers.db_list_type import DbListType
from sqlalchemy.orm import Mapped

Model = db.Model
if TYPE_CHECKING:
    from app.helpers.db_model_base import DbModelBase

    Model = DbModelBase


class ItemRouteHint(Model):
    __tablename__ = "item_route_hint"

    id: Mapped[int] = db.Column(db.Integer, primary_key=True)
    household_id: Mapped[int] = db.Column(
        db.Integer, db.ForeignKey("household.id"), nullable=False, index=True
    )
    # Id degli articoli nell'ordine lasciato da Andrea; possono riferirsi ad articoli poi cancellati, l'analisi li salta
    item_ids: Mapped[List[int]] = db.Column(DbListType(), default=list())

    @classmethod
    def all_by_household(cls, household_id: int) -> List["ItemRouteHint"]:
        return (
            cls.query.filter(cls.household_id == household_id)
            .order_by(cls.created_at)
            .all()
        )
