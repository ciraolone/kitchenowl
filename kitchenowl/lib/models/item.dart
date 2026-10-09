import 'package:fraction/fraction.dart';
import 'package:kitchenowl/helpers/string_scaler.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item_attachment.dart';
import 'package:kitchenowl/models/model.dart';

import 'nullable.dart';

class Item extends Model {
  final int? id;
  final String name;
  final String? icon;
  final int ordering;
  final Category? category;
  final bool? isDefault;
  final String? defaultKey;
  // Filename della prima foto allegata (la "copertina"), inviato dal backend
  // nelle viste compatte per mostrare il thumbnail nella lista spesa.
  final String? coverPhoto;
  // Hash di sfocatura della copertina, usato come placeholder grafico.
  final String? coverHash;
  // Elenco completo degli allegati (foto + PDF). Popolato solo dagli endpoint
  // di dettaglio; null nelle liste compatte per non appesantire le risposte.
  final List<ItemAttachment>? attachments;

  const Item({
    this.id,
    required this.name,
    this.icon,
    this.ordering = 0,
    this.category,
    this.isDefault,
    this.defaultKey,
    this.coverPhoto,
    this.coverHash,
    this.attachments,
  });

  factory Item.fromItem({
    required Item item,
  }) =>
      Item(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        coverPhoto: item.coverPhoto,
        coverHash: item.coverHash,
        attachments: item.attachments,
      );

  factory Item.fromJson(Map<String, dynamic> map) => Item(
        id: map['id'],
        name: map['name'],
        ordering: map['ordering'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        icon: map['icon'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
        coverPhoto: map['cover_photo'],
        coverHash: map['cover_hash'],
        attachments: map['attachments'] != null
            ? List<ItemAttachment>.from(
                (map['attachments'] as List).map(
                  (e) => ItemAttachment.fromJson(e as Map<String, dynamic>),
                ),
              )
            : null,
      );

  Item copyWith({
    String? name,
    Nullable<Category>? category,
    int? ordering,
    Nullable<String>? icon,
    Nullable<String>? coverPhoto,
    Nullable<String>? coverHash,
    Nullable<List<ItemAttachment>>? attachments,
  }) =>
      Item(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        ordering: ordering ?? this.ordering,
        coverPhoto: (coverPhoto ?? Nullable(this.coverPhoto)).value,
        coverHash: (coverHash ?? Nullable(this.coverHash)).value,
        attachments: (attachments ?? Nullable(this.attachments)).value,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        ordering,
        isDefault,
        defaultKey,
        category,
        coverPhoto,
        coverHash,
        attachments,
      ];

  @override
  Map<String, dynamic> toJson() => {
        "name": name,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
      "ordering": ordering,
      "icon": icon,
      "category": category?.toJsonWithId(),
      "default": isDefault,
      "default_key": defaultKey,
    });
}

class ItemWithDescription extends Item {
  final String description;

  const ItemWithDescription({
    super.id,
    required super.name,
    super.ordering = 0,
    super.icon,
    super.isDefault,
    super.defaultKey,
    super.category,
    super.coverPhoto,
    super.coverHash,
    super.attachments,
    this.description = '',
  });

  factory ItemWithDescription.fromJson(Map<String, dynamic> map) =>
      ItemWithDescription(
        id: map['id'],
        name: map['name'],
        description: map['description'] ?? "",
        icon: map['icon'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
        coverPhoto: map['cover_photo'],
        coverHash: map['cover_hash'],
      );

  factory ItemWithDescription.fromItem({
    required Item item,
    String? description,
  }) =>
      ItemWithDescription(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        coverPhoto: item.coverPhoto,
        coverHash: item.coverHash,
        attachments: item.attachments,
        description: description ??
            ((item is ItemWithDescription) ? item.description : ''),
      );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "description": description,
    });

  @override
  ItemWithDescription copyWith({
    String? name,
    Nullable<Category>? category,
    int? ordering,
    Nullable<String>? icon,
    String? description,
    Nullable<String>? coverPhoto,
    Nullable<String>? coverHash,
    Nullable<List<ItemAttachment>>? attachments,
  }) =>
      ItemWithDescription(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        description: description ?? this.description,
        ordering: ordering ?? this.ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
        coverPhoto: (coverPhoto ?? Nullable(this.coverPhoto)).value,
        coverHash: (coverHash ?? Nullable(this.coverHash)).value,
        attachments: (attachments ?? Nullable(this.attachments)).value,
      );

  @override
  List<Object?> get props => super.props + [description];
}

class ShoppinglistItem extends ItemWithDescription {
  final int? createdById;
  final DateTime? createdAt;

  const ShoppinglistItem({
    super.id,
    required super.name,
    super.description = '',
    super.category,
    super.icon,
    super.ordering = 0,
    super.defaultKey,
    super.isDefault,
    super.coverPhoto,
    super.coverHash,
    this.createdById,
    this.createdAt,
  });

  factory ShoppinglistItem.fromJson(Map<String, dynamic> map) {
    return ShoppinglistItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      ordering: map['ordering'],
      isDefault: map['default'],
      defaultKey: map['default_key'],
      icon: map['icon'],
      category:
          map['category'] != null ? Category.fromJson(map['category']) : null,
      coverPhoto: map['cover_photo'],
      coverHash: map['cover_hash'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'], isUtc: true)
              .toLocal()
          : null,
      createdById: map['created_by'],
    );
  }

  /// Turn an Item into a Shopping list item.
  ///
  /// If description is null and item is an ItemWithDescription the existing description is used.
  factory ShoppinglistItem.fromItem({
    required Item item,
    String? description,
    DateTime? createdAt,
    int? createdById,
  }) =>
      ShoppinglistItem(
        id: item.id,
        name: item.name,
        icon: item.icon,
        description: description ??
            (item is ItemWithDescription ? item.description : ""),
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        coverPhoto: item.coverPhoto,
        coverHash: item.coverHash,
        createdAt: createdAt ?? DateTime.now(),
        createdById: createdById,
      );

  @override
  ShoppinglistItem copyWith({
    String? name,
    Nullable<Category>? category,
    int? ordering,
    Nullable<String>? icon,
    String? description,
    Nullable<String>? coverPhoto,
    Nullable<String>? coverHash,
    Nullable<List<ItemAttachment>>? attachments,
  }) =>
      ShoppinglistItem(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        description: description ?? this.description,
        ordering: ordering ?? this.ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
        coverPhoto: (coverPhoto ?? Nullable(this.coverPhoto)).value,
        coverHash: (coverHash ?? Nullable(this.coverHash)).value,
        createdById: createdById,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => super.props + [createdAt, createdById];

  @override
  Map<String, dynamic> toJsonWithId() => super.toJsonWithId()
    ..addAll({
      "created_at": createdAt?.toUtc().millisecondsSinceEpoch,
      "created_by": createdById,
    });
}

class RecipeItem extends ItemWithDescription {
  final bool optional;

  const RecipeItem({
    super.id,
    required super.name,
    super.description = '',
    super.ordering = 0,
    super.defaultKey,
    super.isDefault,
    super.category,
    super.icon,
    this.optional = false,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> map) => RecipeItem(
        id: map['id'],
        name: map['name'] ?? '',
        description: map['description'],
        icon: map['icon'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        optional: map['optional'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
      );

  factory RecipeItem.fromItem({
    required Item item,
    String description = '',
    bool optional = false,
  }) =>
      RecipeItem(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        description:
            item is ItemWithDescription ? item.description : description,
        optional: optional,
      );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "optional": optional,
    });

  @override
  RecipeItem copyWith({
    String? name,
    Nullable<Category>? category,
    int? ordering,
    Nullable<String>? icon,
    String? description,
    bool? optional,
    Nullable<String>? coverPhoto,
    Nullable<String>? coverHash,
    Nullable<List<ItemAttachment>>? attachments,
  }) =>
      RecipeItem(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        description: description ?? this.description,
        optional: optional ?? this.optional,
        ordering: ordering ?? this.ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
      );

  RecipeItem withFactor(
    Fraction factor, {
    bool addDescriptionWhenEmpty = true,
  }) {
    if (!addDescriptionWhenEmpty) return this;

    return copyWith(description: StringScaler.scale(description, factor));
  }

  Item toItem() => Item(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
      );

  ItemWithDescription toItemWithDescription() => ItemWithDescription(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
        description: description,
      );

  ShoppinglistItem toShoppingListItem() => ShoppinglistItem(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
        description: description,
      );

  @override
  List<Object?> get props => super.props + [optional];
}
