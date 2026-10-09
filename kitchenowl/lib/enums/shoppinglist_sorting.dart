import 'package:flutter/material.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/services/local_first/item_route.dart';

enum ShoppinglistSorting {
  alphabetical,
  algorithmic,
  category;

  String toLocalizedString(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return [
      loc.sortingAlphabetical,
      loc.sortingAlgorithmic,
      loc.category
    ][index];
  }

  // Il pulsante dell'ordinamento è solo un'icona (features/003): l'icona
  // stessa dice quale ordinamento è attivo.
  IconData toIcon() {
    return [
      Icons.sort_by_alpha_rounded,
      Icons.route_rounded,
      Icons.category_rounded,
    ][index];
  }

  static void sortShoppinglistItems(
    List<Item> shoppinglist,
    ShoppinglistSorting sorting,
  ) {
    if (shoppinglist.isEmpty) return;
    switch (sorting) {
      case ShoppinglistSorting.alphabetical:
        shoppinglist.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      // Per reparti: dentro ogni reparto si segue il percorso, così un
      // articolo trascinato resta dove lo si è lasciato (features/004)
      case ShoppinglistSorting.algorithmic:
      case ShoppinglistSorting.category:
        shoppinglist.sort(compareByRoute);
        break;
    }
  }
}
