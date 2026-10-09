// Regole dei reparti fatte dalla lista (features/005-reparti-dalla-lista): un reparto lasciato su un altro ne prende la posizione, uno nuovo va in fondo e non si duplica, la lista riconosce lo stesso reparto anche con un ordering vecchio o senza id, e le azioni in coda sopravvivono al riavvio dell'app. La regola gemella del server è provata in backend/tests/api/test_api_category_order.py.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/local_first/category_order.dart';
import 'package:kitchenowl/services/transaction.dart';
import 'package:kitchenowl/services/transactions/category.dart';

List<Category> categoriesNamed(List<String> names) => [
      for (final (index, name) in names.indexed)
        Category(id: index + 1, name: name, ordering: index),
    ];

List<String> namesOf(List<Category> categories) =>
    categories.map((e) => e.name).toList();

void main() {
  final categories = categoriesNamed(['Frutta', 'Pane', 'Frigo', 'Casa']);

  test("a category moving down takes the place right after the target", () {
    final moved = moveCategory(categories, moved: categories[0], index: 2);

    expect(namesOf(moved), ['Pane', 'Frigo', 'Frutta', 'Casa']);
    expect(moved.map((e) => e.ordering), [0, 1, 2, 3]);
  });

  test("a category moving up takes the place right before the target", () {
    final moved = moveCategory(categories, moved: categories[3], index: 1);

    expect(namesOf(moved), ['Frutta', 'Casa', 'Pane', 'Frigo']);
  });

  test("a new category goes last and is not added twice", () {
    final added = addCategoryNamed(categories, ' Surgelati ');

    expect(namesOf(added).last, 'Surgelati');
    expect(added.last.ordering, 4);
    expect(added.last.id, isNull);
    expect(namesOf(addCategoryNamed(added, 'surgelati')), namesOf(added));
  });

  test("the same category is recognised with an old ordering or without id",
      () {
    const fridge = Category(id: 3, name: 'Frigo', ordering: 2);

    expect(isSameCategory(fridge, fridge.copyWith(ordering: 0)), isTrue);
    expect(isSameCategory(const Category(name: 'frigo'), fridge), isTrue);
    expect(
        isSameCategory(const Category(id: 4, name: 'Frigo'), fridge), isFalse);
    expect(isSameCategory(null, fridge), isFalse);
    expect(isSameCategory(null, null), isTrue);
  });

  test("queued category actions survive an app restart", () {
    const household = Household(id: 1, name: 'Casa');
    final arrange = Transaction.fromJson(TransactionCategoryArrange(
      household: household,
      category: categories[0],
      index: 2,
    ).toJson()) as TransactionCategoryArrange;
    final add = Transaction.fromJson(
      TransactionCategoryAdd(household: household, name: 'Surgelati').toJson(),
    ) as TransactionCategoryAdd;

    expect(arrange.category, categories[0]);
    expect(arrange.index, 2);
    expect(add.name, 'Surgelati');
  });
}
