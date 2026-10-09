// Scelta dell'articolo che il tasto Invio aggiunge dalla ricerca della lista (features/001-local-first, spec "Cercare un articolo"): vince il nome scritto esattamente, altrimenti il primo risultato non ancora in lista.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/services/local_first/shoppinglist_search.dart';

void main() {
  test("a new item similar to one already in the list is still added", () {
    final results = <Item>[
      const ShoppinglistItem(name: 'Pane'),
      const ItemWithDescription(name: 'Mele'),
    ];

    expect(itemToAddOnSubmit(results, 'Mele')?.name, 'Mele');
  });

  test("a partial name adds the first result not yet in the list", () {
    final results = <Item>[
      const ShoppinglistItem(name: 'Latte'),
      const ItemWithDescription(name: 'Lattuga'),
      const ItemWithDescription(name: 'Latt'),
    ];

    expect(itemToAddOnSubmit(results, 'Latt')?.name, 'Latt');
    expect(itemToAddOnSubmit(results.take(2).toList(), 'Lat')?.name, 'Lattuga');
  });

  test("an item already in the list is not added again", () {
    final results = <Item>[
      const ShoppinglistItem(name: 'Pane'),
      const ItemWithDescription(name: 'Panna'),
    ];

    expect(itemToAddOnSubmit(results, 'pane, integrale'), isNull);
  });
}
