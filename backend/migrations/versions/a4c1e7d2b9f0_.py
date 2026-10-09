"""create item_route_hint table for drag reordering (fork feature 004)

Revision ID: a4c1e7d2b9f0
Revises: 557bf7115481
Create Date: 2026-10-09 12:00:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a4c1e7d2b9f0"
down_revision = "557bf7115481"
branch_labels = None
depends_on = None


def upgrade():
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


def downgrade():
    with op.batch_alter_table("item_route_hint", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_item_route_hint_household_id"))
    op.drop_table("item_route_hint")
