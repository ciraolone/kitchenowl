/// Consegna al server delle azioni sulla lista della spesa fatte sul telefono
/// (feature 001-local-first del fork di Andrea): aggiunta, modifica della
/// descrizione, spunta singola e multipla, trascinamento (feature 004). Ogni funzione manda l'azione con il
/// momento in cui è stata fatta e traduce la risposta in un Delivery. Gli
/// articoli aggiunti senza rete non hanno ancora un id: lo si ricava dal
/// catalogo locale, che la consegna dell'aggiunta (sempre precedente in coda)
/// ha già aggiornato con l'articolo creato dal server. Allo stesso modo un
/// reparto creato senza rete (feature 005) si ricava per nome dalla copia
/// locale dei reparti con categoryIdOf. Le transazioni in
/// services/transactions/shoppinglist.dart chiamano queste funzioni dal loro
/// deliver().
library;

import 'dart:convert';

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/nullable.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/category_order.dart';
import 'package:kitchenowl/services/local_first/delivery.dart';
import 'package:kitchenowl/services/local_first/item_catalog.dart';

Future<Delivery> deliverAddedItem({
  required Household household,
  required ShoppingList shoppinglist,
  required Item item,
  required DateTime changedAt,
}) async {
  final description = item is ItemWithDescription ? item.description : '';
  final itemId = item.id;
  final response = itemId != null
      ? await ApiService.getInstance().putItem(
          shoppinglist,
          ItemWithDescription.fromItem(item: item, description: description),
          changedAt,
        )
      : await ApiService.getInstance().addItemByName(
          shoppinglist,
          item.name,
          description,
          changedAt,
        );
  final outcome = deliveryOutcomeOf(response);
  if (outcome == DeliveryOutcome.delivered) {
    await ItemCatalog.getInstance().remember(
      household,
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }
  return _singleItemDelivery(outcome, item.name);
}

Future<Delivery> deliverDescription({
  required Household household,
  required ShoppingList shoppinglist,
  required Item item,
  required String description,
  required DateTime changedAt,
}) async {
  final itemId = await _resolveItemId(household, item);
  if (itemId == null) return const Delivery(DeliveryOutcome.rejected);
  final response = await ApiService.getInstance().putItem(
    shoppinglist,
    ItemWithDescription(id: itemId, name: item.name, description: description),
    changedAt,
  );
  return _singleItemDelivery(deliveryOutcomeOf(response), item.name);
}

Future<Delivery> deliverRemovedItem({
  required Household household,
  required ShoppingList shoppinglist,
  required Item item,
  required DateTime changedAt,
}) async {
  final itemId = await _resolveItemId(household, item);
  if (itemId == null) return const Delivery(DeliveryOutcome.rejected);
  final response = await ApiService.getInstance()
      .removeItem(shoppinglist, itemId, changedAt);
  return _singleItemDelivery(deliveryOutcomeOf(response), item.name);
}

Future<Delivery> deliverRemovedItems({
  required Household household,
  required ShoppingList shoppinglist,
  required List<Item> items,
  required DateTime changedAt,
}) async {
  final namesById = <int, String>{};
  for (final item in items) {
    final itemId = await _resolveItemId(household, item);
    if (itemId != null) namesById[itemId] = item.name;
  }
  if (namesById.isEmpty) return const Delivery(DeliveryOutcome.rejected);

  final response = await ApiService.getInstance()
      .removeItems(shoppinglist, namesById.keys.toList(), changedAt);
  final outcome = deliveryOutcomeOf(response);
  if (outcome != DeliveryOutcome.delivered) return Delivery(outcome);

  final supersededIds = List<int>.from(
    jsonDecode(response.body)['superseded_item_ids'] ?? const [],
  );
  return Delivery(
    outcome,
    supersededIds.map((id) => namesById[id]).nonNulls.toList(),
  );
}

/// category è null se il reparto non cambia; Nullable(null) toglie il
/// reparto.
Future<Delivery> deliverArrangedItem({
  required Household household,
  required Item item,
  Item? after,
  Item? before,
  Nullable<Category>? category,
}) async {
  final itemId = await _resolveItemId(household, item);
  if (itemId == null) return const Delivery(DeliveryOutcome.rejected);
  final body = <String, dynamic>{
    'item_id': itemId,
  };
  if (after != null)
    body['after_item_id'] = await _resolveItemId(household, after);
  if (before != null) {
    body['before_item_id'] = await _resolveItemId(household, before);
  }
  if (category != null) {
    final target = category.value;
    final categoryId =
        target == null ? null : await categoryIdOf(household, target);
    if (target != null && categoryId == null) {
      return const Delivery(DeliveryOutcome.rejected);
    }
    body['category'] = target == null ? null : {'id': categoryId};
  }

  final response = await ApiService.getInstance().arrangeItem(household, body);
  return Delivery(deliveryOutcomeOf(response));
}

Future<int?> _resolveItemId(Household household, Item item) async =>
    item.id ?? await ItemCatalog.getInstance().idOfName(household, item.name);

Delivery _singleItemDelivery(DeliveryOutcome outcome, String itemName) =>
    Delivery(
      outcome,
      outcome == DeliveryOutcome.superseded ? [itemName] : const [],
    );
