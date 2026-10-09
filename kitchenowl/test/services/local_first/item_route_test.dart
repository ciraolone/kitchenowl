// Percorso nel negozio e regola di spostamento del trascinamento (features/004-riordino-trascinamento): l'articolo lasciato su un altro prende il posto subito dopo o subito prima, gli zeri restano in fondo, il reparto cambia solo se richiesto, e l'azione in coda sopravvive al riavvio dell'app. Le stesse regole sono provate sul server in backend/tests/api/test_api_item_arrange.py.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/nullable.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/local_first/item_route.dart';
import 'package:kitchenowl/services/transaction.dart';
import 'package:kitchenowl/services/transactions/shoppinglist_arrange.dart';

const fridge = Category(id: 7, name: 'Frigo');

List<ShoppinglistItem> placed(List<String> names, {int unplaced = 0}) => [
      for (final (index, name) in names.indexed)
        ShoppinglistItem(
          name: name,
          ordering: index < names.length - unplaced ? index + 1 : 0,
        ),
    ];

List<String> namesOf(List<Item> items) => items.map((e) => e.name).toList();

void main() {
  test("an item dropped after another takes the place right after it", () {
    final route = placeInRoute(
      placed(['Pane', 'Latte', 'Mele', 'Uova']),
      movedName: 'Pane',
      afterName: 'Mele',
    );

    expect(namesOf(route), ['Latte', 'Mele', 'Pane', 'Uova']);
    expect(route.map((e) => e.ordering), [1, 2, 3, 4]);
  });

  test(
      "a never placed item dropped before another gets a place, the others stay last",
      () {
    final route = placeInRoute(
      placed(['Pane', 'Latte', 'Mele', 'Uova'], unplaced: 2),
      movedName: 'Uova',
      beforeName: 'Latte',
    );

    expect(namesOf(route), ['Pane', 'Uova', 'Latte', 'Mele']);
    expect(route.last.ordering, 0);
  });

  test(
      "by category, items inside a category follow the route and not the alphabet",
      () {
    final items = placed(['Pane', 'Burro', 'Acqua']);

    ShoppinglistSorting.sortShoppinglistItems(
        items, ShoppinglistSorting.category);

    expect(namesOf(items), ['Pane', 'Burro', 'Acqua']);
  });

  test("a drop on a category moves only the dragged item there", () {
    final items = arrangeItems(
      placed(['Latte', 'Pane']),
      movedName: 'Latte',
      category: const Nullable(fridge),
    );

    expect(items.firstWhere((e) => e.name == 'Latte').category, fridge);
    expect(items.firstWhere((e) => e.name == 'Pane').category, isNull);
  });

  test("a queued drag survives an app restart", () {
    final original = TransactionShoppingListArrangeItem(
      household: const Household(id: 1, name: 'Casa'),
      shoppinglist: const ShoppingList(id: 2, name: 'Spesa'),
      item: const ShoppinglistItem(id: 3, name: 'Latte'),
      before: const ShoppinglistItem(id: 4, name: 'Pane'),
      category: const Nullable(null),
      route: placed(['Latte', 'Pane']),
    );

    final restored = Transaction.fromJson(original.toJson())
        as TransactionShoppingListArrangeItem;

    expect(restored.before?.name, 'Pane');
    expect(restored.after, isNull);
    expect(restored.category, isNotNull);
    expect(restored.category?.value, isNull);
    expect(namesOf(restored.route), ['Latte', 'Pane']);
  });
}
