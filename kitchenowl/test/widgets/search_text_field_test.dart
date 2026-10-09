// Ordine fra invio e svuotamento della ricerca in SearchTextField. Con la ricerca locale (features/001-local-first) svuotare la ricerca è istantaneo: se avviene prima di onSubmitted, Invio nella lista della spesa non trova più l'articolo da aggiungere.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/gen/l10n/app_localizations.dart';
import 'package:kitchenowl/widgets/search_text_field.dart';

void main() {
  testWidgets('Enter submits before the search is cleared', (tester) async {
    final searches = <String>[];
    List<String>? searchesSeenOnSubmit;
    final controller = TextEditingController();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SearchTextField(
          controller: controller,
          searchDelay: 0,
          onSearch: (query) async => searches.add(query),
          onSubmitted: () => searchesSeenOnSubmit = List.of(searches),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'Latte');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(searchesSeenOnSubmit, ['Latte']);
    expect(searches.last, '');
  });
}
