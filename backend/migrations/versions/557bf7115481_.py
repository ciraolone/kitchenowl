"""create item_attachment table for photo+pdf attachments

Revision ID: 557bf7115481
Revises: bd383e73ef4d
Create Date: 2026-05-08 11:00:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "557bf7115481"
down_revision = "bd383e73ef4d"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "item_attachment",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("file_filename", sa.String(), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column(
            "ordering", sa.Integer(), server_default="0", nullable=False
        ),
        sa.Column("label", sa.String(length=256), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(
            ["file_filename"],
            ["file.filename"],
            name=op.f("fk_item_attachment_file_filename_file"),
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["item.id"],
            name=op.f("fk_item_attachment_item_id_item"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_item_attachment")),
    )
    with op.batch_alter_table("item_attachment", schema=None) as batch_op:
        batch_op.create_index(
            batch_op.f("ix_item_attachment_item_id"), ["item_id"], unique=False
        )


def downgrade():
    with op.batch_alter_table("item_attachment", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_item_attachment_item_id"))
    op.drop_table("item_attachment")
