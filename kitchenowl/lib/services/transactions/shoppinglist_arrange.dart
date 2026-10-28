/// Trascinamento di un articolo nella lista della spesa (feature
/// 004-riordino-trascinamento del fork di Andrea), come azione local first:
/// si applica subito alla copia sul telefono, va in coda e il postino la
/// consegna al server (deliverArrangedItem). Porta l'articolo spostato,
/// l'articolo dopo cui o prima di cui va e l'eventuale reparto nuovo. Le
/// azioni salvate da versioni vecchie possono portare anche un campo route,
/// che si ignora. runLocal è idempotente, perché le azioni non ancora consegnate
/// si riapplicano sopra ogni copia fresca del server.
library;

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/nullable.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/local_first/delivery.dart';
import 'package:kitchenowl/services/local_first/item_route.dart';
import 'package:kitchenowl/services/local_first/shoppinglist_delivery.dart';
import 'package:kitchenowl/services/storage/mem_storage.dart';
import 'package:kitchenowl/services/transaction.dart';

class TransactionShoppingListArrangeItem extends Transaction<bool>
    with LocalFirstTransaction<bool> {
  @override
  final Household household;
  final ShoppingList shoppinglist;
  final ShoppinglistItem item;
  final ShoppinglistItem? after;
  final ShoppinglistItem? before;

  /// null se il reparto non cambia; Nullable(null) toglie il reparto.
  final Nullable<Category>? category;

  TransactionShoppingListArrangeItem({
    required this.household,
    required this.shoppinglist,
    required this.item,
    this.after,
    this.before,
    this.category,
    DateTime? timestamp,
  }) : super.internal(
          timestamp ?? DateTime.now(),
          "TransactionShoppingListArrangeItem",
        );

  factory TransactionShoppingListArrangeItem.fromJson(
    Map<String, dynamic> map,
    DateTime timestamp,
  ) =>
      TransactionShoppingListArrangeItem(
        household: Household.fromJson(map['household']),
        shoppinglist: ShoppingList.fromJson(map['shoppinglist']),
        item: ShoppinglistItem.fromJson(map['item']),
        after: map['after'] != null
            ? ShoppinglistItem.fromJson(map['after'])
            : null,
        before: map['before'] != null
            ? ShoppinglistItem.fromJson(map['before'])
            : null,
        category: map['changes_category'] == true
            ? Nullable(map['category'] != null
                ? Category.fromJson(map['category'])
                : null)
            : null,
        timestamp: timestamp,
      );

  @override
  bool get saveTransaction => true;

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "household": household.toJsonWithId(),
      "shoppinglist": shoppinglist.toJsonWithId(),
      "item": item.toJsonWithId(),
      "after": after?.toJsonWithId(),
      "before": before?.toJsonWithId(),
      "changes_category": category != null,
      "category": category?.value?.toJsonWithId(),
    });

  @override
  Future<bool> runLocal() async {
    final shoppingLists =
        await MemStorage.getInstance().readShoppingLists(household) ?? [];
    final latestShoppingList =
        shoppingLists.where((e) => e.id == shoppinglist.id).firstOrNull;
    if (latestShoppingList == null) return false;
    final arranged = arrangeItems(
      latestShoppingList.items,
      movedName: item.name,
      afterName: after?.name,
      beforeName: before?.name,
      category: category,
    );
    latestShoppingList.items
      ..clear()
      ..addAll(arranged);
    MemStorage.getInstance().writeShoppingLists(household, shoppingLists);

    return true;
  }

  @override
  Future<Delivery> deliver() => deliverArrangedItem(
        household: household,
        item: item,
        after: after,
        before: before,
        category: category,
      );

  @override
  Future<bool?> runOnline() async =>
      (await deliver()).outcome == DeliveryOutcome.delivered;
}
