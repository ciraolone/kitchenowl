// Impostazione "Hide item icons" (features/006-icone-nascoste, spec "Comportamento"): con lo stile della lista che nasconde le icone, la casella dell'articolo mostra il solo nome, in griglia e in elenco; di serie l'icona c'è.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/item_icons.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/item.dart';

const apples = ShoppinglistItem(name: 'Mele', icon: 'apple');

Widget _list(ShoppingListStyle style) => MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverItemGridList<ShoppinglistItem>(
            items: const [apples],
            shoppingListStyle: style,
            onPressed: Nullable((item) {}),
          ),
        ]),
      ),
    );

void main() {
  for (final isList in [false, true]) {
    final view = isList ? 'list' : 'grid';

    testWidgets("by default the $view shows the item icon", (tester) async {
      await tester.pumpWidget(_list(ShoppingListStyle(isList: isList)));

      expect(find.text('Mele'), findsOneWidget);
      expect(find.byIcon(ItemIcons.get(apples)!), findsOneWidget);
    });

    testWidgets("with hidden icons the $view shows only the name", (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(ShoppingListStyle(isList: isList, hideIcons: true)),
      );

      expect(find.text('Mele'), findsOneWidget);
      expect(find.byIcon(ItemIcons.get(apples)!), findsNothing);
    });
  }
}
