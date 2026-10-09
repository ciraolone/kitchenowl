/// Azioni sui reparti della casa. TransactionCategoriesGet legge i reparti
/// (dal server, o dalla copia locale senza rete). TransactionCategoryAdd e
/// TransactionCategoryArrange (feature 005-reparti-dalla-lista del fork di
/// Andrea) creano e spostano un reparto dalla lista della spesa come azioni
/// local first: si applicano subito alla copia locale, vanno in coda e il
/// postino le consegna (category_delivery.dart). Il loro runLocal è
/// idempotente, perché le azioni non ancora consegnate si riapplicano sopra
/// ogni copia fresca del server.
library;

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/category_delivery.dart';
import 'package:kitchenowl/services/local_first/category_order.dart';
import 'package:kitchenowl/services/local_first/delivery.dart';
import 'package:kitchenowl/services/storage/mem_storage.dart';
import 'package:kitchenowl/services/transaction.dart';

class TransactionCategoriesGet extends Transaction<List<Category>> {
  final Household household;

  TransactionCategoriesGet({required this.household, DateTime? timestamp})
      : super.internal(timestamp ?? DateTime.now(), "TransactionCategoriesGet");

  @override
  Future<List<Category>> runLocal() async {
    return await MemStorage.getInstance().readCategories(household) ?? const [];
  }

  @override
  Future<List<Category>?> runOnline() async {
    final categories = await ApiService.getInstance().getCategories(household);
    if (categories != null) {
      MemStorage.getInstance().writeCategories(household, categories);
    }

    return categories;
  }
}

class TransactionCategoryAdd extends Transaction<bool>
    with LocalFirstTransaction<bool> {
  @override
  final Household household;
  final String name;

  TransactionCategoryAdd({
    required this.household,
    required this.name,
    DateTime? timestamp,
  }) : super.internal(timestamp ?? DateTime.now(), "TransactionCategoryAdd");

  factory TransactionCategoryAdd.fromJson(
    Map<String, dynamic> map,
    DateTime timestamp,
  ) =>
      TransactionCategoryAdd(
        household: Household.fromJson(map['household']),
        name: map['name'],
        timestamp: timestamp,
      );

  @override
  bool get saveTransaction => true;

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "household": household.toJsonWithId(),
      "name": name,
    });

  @override
  Future<bool> runLocal() async {
    final storage = MemStorage.getInstance();
    final categories = await storage.readCategories(household) ?? [];
    await storage.writeCategories(
      household,
      addCategoryNamed(categories, name),
    );
    return true;
  }

  @override
  Future<Delivery> deliver() =>
      deliverAddedCategory(household: household, name: name);

  @override
  Future<bool?> runOnline() async =>
      (await deliver()).outcome == DeliveryOutcome.delivered;
}

class TransactionCategoryArrange extends Transaction<bool>
    with LocalFirstTransaction<bool> {
  @override
  final Household household;
  final Category category;

  /// Posizione d'arrivo fra i reparti, la stessa misura che il server
  /// riceve come ordering.
  final int index;

  TransactionCategoryArrange({
    required this.household,
    required this.category,
    required this.index,
    DateTime? timestamp,
  }) : super.internal(
          timestamp ?? DateTime.now(),
          "TransactionCategoryArrange",
        );

  factory TransactionCategoryArrange.fromJson(
    Map<String, dynamic> map,
    DateTime timestamp,
  ) =>
      TransactionCategoryArrange(
        household: Household.fromJson(map['household']),
        category: Category.fromJson(map['category']),
        index: map['index'],
        timestamp: timestamp,
      );

  @override
  bool get saveTransaction => true;

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "household": household.toJsonWithId(),
      "category": category.toJsonWithId(),
      "index": index,
    });

  @override
  Future<bool> runLocal() async {
    final storage = MemStorage.getInstance();
    final categories = await storage.readCategories(household) ?? [];
    await storage.writeCategories(
      household,
      moveCategory(categories, moved: category, index: index),
    );
    return true;
  }

  @override
  Future<Delivery> deliver() => deliverMovedCategory(
        household: household,
        category: category,
        index: index,
      );

  @override
  Future<bool?> runOnline() async =>
      (await deliver()).outcome == DeliveryOutcome.delivered;
}
