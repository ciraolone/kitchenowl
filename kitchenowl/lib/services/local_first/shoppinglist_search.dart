/// Risultati della ricerca nella lista della spesa, calcolati tutti sul
/// telefono (feature 001-local-first del fork di Andrea): nessuna richiesta di
/// rete mentre Andrea scrive. Si parte dal catalogo locale (ItemCatalog), si
/// aggiungono gli articoli in lista o recenti che il catalogo non conosce
/// ancora (creati senza rete, non ancora consegnati), si sostituiscono gli
/// articoli già in lista con la loro versione in lista (descrizione, stato) e
/// in fondo si propone il nome scritto come articolo nuovo, se non esiste già.
/// La ricerca accetta "nome, descrizione": la parte dopo la virgola diventa
/// la descrizione dei risultati.
library;

import 'package:collection/collection.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/local_first/item_catalog.dart';

Future<List<Item>> searchShoppinglistLocally(
  Household household,
  String query,
  ShoppingList? shoppinglist,
) async {
  final splitIndex = query.indexOf(',');
  final queryName =
      (splitIndex >= 0 ? query.substring(0, splitIndex) : query).trim();
  final queryDescription =
      splitIndex >= 0 ? query.substring(splitIndex + 1).trim() : null;

  final results = <Item>[
    ...await ItemCatalog.getInstance().search(household, queryName),
  ];
  _addListItemsMissingFromCatalog(results, shoppinglist, queryName);

  final withDescription = results
      .map((e) => shoppinglist?.items.firstWhereOrNull((i) => i.name == e.name) ??
          ItemWithDescription.fromItem(
            item: e,
            description: queryDescription,
          ))
      .toList();

  final hasExactMatch = withDescription
      .any((e) => e.name.toLowerCase() == queryName.toLowerCase());
  if (!hasExactMatch) {
    withDescription.add(ItemWithDescription(
      name: queryName,
      description: queryDescription ?? '',
    ));
  }

  return withDescription;
}

void _addListItemsMissingFromCatalog(
  List<Item> results,
  ShoppingList? shoppinglist,
  String queryName,
) {
  if (shoppinglist == null) return;
  final lowerQuery = queryName.toLowerCase();
  final knownNames = results.map((e) => e.name).toSet();
  final candidates = <Item>[
    ...shoppinglist.items,
    ...shoppinglist.recentItems,
  ];
  for (final item in candidates) {
    if (knownNames.contains(item.name)) continue;
    if (!item.name.toLowerCase().contains(lowerQuery)) continue;
    results.add(item);
    knownNames.add(item.name);
  }
}
