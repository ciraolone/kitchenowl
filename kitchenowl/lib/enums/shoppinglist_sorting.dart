import 'package:flutter/material.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/item.dart';

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
      case ShoppinglistSorting.category:
        shoppinglist.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ShoppinglistSorting.algorithmic:
        shoppinglist.sort((a, b) {
          final int ordering = a.ordering.compareTo(b.ordering);
          // Ordering of 0 means not sortable and should be at the back
          if (ordering != 0 && a.ordering == 0) return 1;
          if (ordering != 0 && b.ordering == 0) return -1;

          return ordering;
        });
        break;
    }
  }
}
