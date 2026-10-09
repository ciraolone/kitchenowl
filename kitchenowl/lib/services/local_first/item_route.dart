/// Percorso nel negozio, cioè l'ordine automatico della lista della spesa
/// (feature 004-riordino-trascinamento del fork di Andrea). Il percorso è il
/// campo ordering degli articoli: zero vuol dire "mai piazzato" e va in fondo,
/// a parità si ordina per nome in minuscolo. Qui stanno il confronto usato
/// dagli ordinamenti automatico e per reparti (compareByRoute) e la regola con
/// cui un articolo trascinato prende posto (placeInRoute), gemella di
/// place_in_route in backend/app/service/item_route.py: se le due divergono,
/// telefono e server mostrano ordini diversi dopo lo stesso trascinamento.
/// arrangeItems mette insieme posto e reparto nuovo ed è usata sia dal cubit
/// sia dall'azione in coda, così schermo e copia locale cambiano allo stesso
/// modo. Gli articoli si riconoscono per nome, perché quelli aggiunti senza
/// rete non hanno ancora un id.
library;

import 'package:collection/collection.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/nullable.dart';

int compareByRoute(Item a, Item b) {
  if (a.ordering != b.ordering) {
    if (a.ordering == 0) return 1;
    if (b.ordering == 0) return -1;
    return a.ordering.compareTo(b.ordering);
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Mette l'articolo movedName subito dopo afterName o subito prima di
/// beforeName e rinumera. Ricevono un numero tutti gli articoli fino allo
/// spostato compreso, quelli dopo solo se ne avevano già uno: uno zero che
/// resta dopo lo spostato deve restare in fondo.
List<ShoppinglistItem> placeInRoute(
  List<ShoppinglistItem> items, {
  required String movedName,
  String? afterName,
  String? beforeName,
}) {
  final route = items.sorted(compareByRoute);
  final moved = route.firstWhereOrNull((e) => e.name == movedName);
  final anchorName = afterName ?? beforeName;
  if (moved == null || anchorName == null || anchorName == movedName) {
    return route;
  }
  route.remove(moved);
  final anchorIndex = route.indexWhere((e) => e.name == anchorName);
  if (anchorIndex < 0) return items.sorted(compareByRoute);
  final movedIndex = afterName != null ? anchorIndex + 1 : anchorIndex;
  route.insert(movedIndex, moved);

  var nextOrdering = 1;
  return [
    for (final (index, item) in route.indexed)
      if (index <= movedIndex || item.ordering != 0)
        item.copyWith(ordering: nextOrdering++)
      else
        item,
  ];
}

/// Applica un trascinamento agli articoli di una lista: reparto nuovo (se
/// category non è null) e posto nel percorso (se c'è afterName o beforeName).
List<ShoppinglistItem> arrangeItems(
  List<ShoppinglistItem> items, {
  required String movedName,
  String? afterName,
  String? beforeName,
  Nullable<Category>? category,
}) {
  final recategorized = category == null
      ? items
      : [
          for (final item in items)
            item.name == movedName ? item.copyWith(category: category) : item,
        ];
  return placeInRoute(
    recategorized,
    movedName: movedName,
    afterName: afterName,
    beforeName: beforeName,
  );
}
