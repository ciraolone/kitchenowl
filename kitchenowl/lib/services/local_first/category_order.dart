/// Regole dei reparti della casa fatte sul telefono (feature
/// 005-reparti-dalla-lista del fork di Andrea): spostare un reparto in una
/// posizione (moveCategory) e aggiungerne uno in fondo (addCategoryNamed).
/// Sono usate sia dal cubit, per lo schermo, sia dalle azioni in coda, per la
/// copia locale, così le due cambiano allo stesso modo. Uncategorized non è un
/// reparto vero e non sta in queste liste. Qui anche il ricavo dell'id di un
/// reparto creato senza rete (categoryIdOf) e il ricordo dell'id che il server
/// gli ha dato (rememberCreatedCategory), che le consegne successive in coda
/// usano: si riconosce per nome, come gli articoli nel catalogo locale.
library;

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/storage/mem_storage.dart';

/// La posizione è quella fra i reparti dopo lo spostamento, la stessa che il
/// server riceve come ordering. Gli ordering si rinumerano da zero come fa il
/// server, così l'ordine non dipende da quelli vecchi.
List<Category> moveCategory(
  List<Category> categories, {
  required Category moved,
  required int index,
}) {
  final current = categories.where((e) => isSameCategory(e, moved)).firstOrNull;
  if (current == null) return List.of(categories);
  final others = categories.where((e) => !isSameCategory(e, moved)).toList()
    ..insert(index.clamp(0, categories.length - 1), current);
  return _renumbered(others);
}

List<Category> addCategoryNamed(List<Category> categories, String name) {
  final candidate = Category(name: name.trim());
  if (categories.any((e) => isSameCategory(e, candidate))) {
    return List.of(categories);
  }
  return _renumbered([...categories, candidate]);
}

Future<int?> categoryIdOf(Household household, Category category) async {
  final id = category.id;
  if (id != null) return id;
  final categories = await MemStorage.getInstance().readCategories(household);
  return categories?.where((e) => isSameCategory(e, category)).firstOrNull?.id;
}

Future<void> rememberCreatedCategory(
  Household household,
  Category created,
) async {
  final storage = MemStorage.getInstance();
  final categories = await storage.readCategories(household) ?? [];
  final local = categories.where((e) => isSameCategory(e, created)).firstOrNull;
  final updated = local == null
      ? _renumbered([...categories, created])
      : [
          for (final category in categories)
            identical(category, local)
                ? Category(
                    id: created.id,
                    name: local.name,
                    ordering: local.ordering,
                  )
                : category,
        ];
  await storage.writeCategories(household, updated);
}

List<Category> _renumbered(List<Category> categories) => [
      for (final (index, category) in categories.indexed)
        category.copyWith(ordering: index),
    ];
