"""drop item_route_hint table: no more nightly route learning (fork feature 007)

Revision ID: b7e2d4f1c3a8
Revises: a4c1e7d2b9f0
Create Date: 2026-10-28 12:00:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b7e2d4f1c3a8"
down_revision = "a4c1e7d2b9f0"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("item_route_hint", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_item_route_hint_household_id"))
    op.drop_table("item_route_hint")


def downgrade():
    op.create_table(
        "item_route_hint",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("household_id", sa.Integer(), nullable=False),
        sa.Column("item_ids", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["household_id"],
            ["household.id"],
            name=op.f("fk_item_route_hint_household_id_household"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_item_route_hint")),
    )
    with op.batch_alter_table("item_route_hint", schema=None) as batch_op:
        batch_op.create_index(
            batch_op.f("ix_item_route_hint_household_id"),
            ["household_id"],
            unique=False,
        )
