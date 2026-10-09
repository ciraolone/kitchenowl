// Trascinamento dei reparti nella lista per reparti (features/005-reparti-dalla-lista, spec "Comportamento"): tenere premuto il nome e lasciare senza muovere non fa nulla; muovendo il dito tutti i reparti diventano righe, anche quelli senza articoli, e lasciando il reparto su un'altra riga arriva lo spostamento con chi è stato spostato e su chi.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_shoppinglist_categories.dart';

const fruit = Category(id: 1, name: 'Frutta', ordering: 0);
const bread = Category(id: 2, name: 'Pane', ordering: 1);
const fridge = Category(id: 3, name: 'Frigo', ordering: 2);

Widget _list(List<String> moves) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverShoppinglistCategories(
            categories: const [fruit, bread, fridge],
            shoppingList: const ShoppingList(id: 1, name: 'Spesa', items: [
              ShoppinglistItem(name: 'Mele', category: fruit),
              ShoppinglistItem(name: 'Latte', category: fridge),
            ]),
            selected: (item) => false,
            isLoading: false,
            shoppingListStyle: const ShoppingListStyle(),
            onArrangeCategory: (moved, target) =>
                moves.add('${moved.name}>${target.name}'),
          ),
        ]),
      ),
    );

void main() {
  testWidgets("holding a category name and releasing does nothing", (
    tester,
  ) async {
    final moves = <String>[];
    await tester.pumpWidget(_list(moves));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Frutta')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moves, isEmpty);
    expect(find.text('Mele'), findsOneWidget);
    expect(find.text('Pane'), findsNothing);
  });

  testWidgets("dragging a category shows every category and drops it on one", (
    tester,
  ) async {
    final moves = <String>[];
    await tester.pumpWidget(_list(moves));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Frutta')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(find.text('Pane'), findsOneWidget);
    expect(find.text('Mele'), findsNothing);
    expect(find.text('Uncategorized'), findsNothing);

    await gesture.moveTo(tester.getCenter(find.text('Frigo').first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moves, ['Frutta>Frigo']);
    expect(find.text('Mele'), findsOneWidget);
  });
}
