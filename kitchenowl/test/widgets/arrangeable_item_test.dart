// Gesto del trascinamento nella lista (features/004-riordino-trascinamento, spec "Comportamento"): tenere premuto e lasciare senza muovere apre la scheda; tenere premuto e muovere trascina, e lasciando l'articolo su un altro arriva il rilascio con chi è stato spostato e dove.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_item.dart';

class _Gestures {
  final opened = <String>[];
  final started = <String>[];
  final drops = <String>[];
  var ended = 0;

  ItemArrangement<ShoppinglistItem> get arrangement => ItemArrangement(
        onStart: (item) => started.add(item.name),
        onEnd: () => ended++,
        onDrop: (moved, target) => drops.add('${moved.name}>${target.name}'),
      );
}

Widget _list(_Gestures gestures, List<String> names) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (final name in names)
              ArrangeableItem<ShoppinglistItem>(
                key: ValueKey(name),
                item: ShoppinglistItem(name: name),
                arrangement: gestures.arrangement,
                onOpen: () => gestures.opened.add(name),
                child: SizedBox(height: 80, child: Card(child: Text(name))),
              ),
          ],
        ),
      ),
    );

void main() {
  testWidgets("holding and releasing without moving opens the item", (
    tester,
  ) async {
    final gestures = _Gestures();
    await tester.pumpWidget(_list(gestures, ['Pane', 'Latte']));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Pane')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(gestures.opened, ['Pane']);
    expect(gestures.started, isEmpty);
  });

  testWidgets("holding and dragging onto another item drops it there", (
    tester,
  ) async {
    final gestures = _Gestures();
    await tester.pumpWidget(_list(gestures, ['Pane', 'Latte', 'Mele']));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Pane')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Mele').first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(gestures.started, ['Pane']);
    expect(gestures.drops, ['Pane>Mele']);
    expect(gestures.ended, 1);
    expect(gestures.opened, isEmpty);
  });
}
