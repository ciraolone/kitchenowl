/// Ordine manuale degli articoli dentro i reparti della lista della spesa
/// (feature 004 e 007 del fork di Andrea). L'ordine è il campo ordering degli
/// articoli, dato solo col trascinamento: zero vuol dire "mai ordinato a
/// mano" e va in fondo, a parità si ordina per nome in minuscolo. Qui stanno
/// il confronto usato dall'ordinamento per reparti (compareByRoute) e la
/// regola con cui un articolo trascinato prende posto (placeInRoute), gemella
/// di place_in_route in backend/app/service/item_route.py: se le due
/// divergono, telefono e server mostrano ordini diversi dopo lo stesso
/// trascinamento. arrangeItems applica un trascinamento (posto o reparto
/// nuovo) ed è usata sia dal cubit sia dall'azione in coda, così schermo e
/// copia locale cambiano allo stesso modo. Gli articoli si riconoscono per
/// nome, perché quelli aggiunti senza rete non hanno ancora un id. Il nome
/// "route" è storico: non c'è più un percorso imparato dalle spese.
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

/// Applica un trascinamento agli articoli di una lista. Con un reparto nuovo
/// (category non null) l'articolo ci va in fondo, con ordering 0 come fa il
/// server: se lo azzerasse un lato solo, l'articolo salterebbe di posto al
/// primo aggiornamento. Altrimenti prende posto dopo afterName o prima di
/// beforeName.
List<ShoppinglistItem> arrangeItems(
  List<ShoppinglistItem> items, {
  required String movedName,
  String? afterName,
  String? beforeName,
  Nullable<Category>? category,
}) {
  if (category != null) {
    return [
      for (final item in items)
        item.name == movedName
            ? item.copyWith(category: category, ordering: 0)
            : item,
    ];
  }
  return placeInRoute(
    items,
    movedName: movedName,
    afterName: afterName,
    beforeName: beforeName,
  );
}
