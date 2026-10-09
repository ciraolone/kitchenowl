// Ricerca sul telefono (feature 001-local-first): deve dare gli stessi
// risultati della ricerca del backend su PostgreSQL (Item.search_name), cioè
// inizio del nome a distanza di Levenshtein < 4, ordine per distanza e poi per
// "support", al massimo 11 risultati.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/services/local_first/catalog_search.dart';

Map<String, dynamic> item(int id, String name, [double support = 0]) =>
    {'id': id, 'name': name, 'support': support};

List<String> names(List<Map<String, dynamic>> items) =>
    items.map((e) => e['name'] as String).toList();

void main() {
  test("finds items by the start of the name, tolerating typos", () {
    final catalog = [item(1, 'Latte'), item(2, 'Lattuga'), item(3, 'Uova')];

    expect(names(searchCatalog(catalog, 'latt')), ['Latte', 'Lattuga']);
    expect(names(searchCatalog(catalog, 'lsttw')), ['Latte', 'Lattuga']);
    expect(names(searchCatalog(catalog, 'UOVA')), ['Uova']);
  });

  test("closer names come first, then the most bought ones", () {
    final catalog = [
      item(1, 'Mele', 0.1),
      item(2, 'Melanzane', 0.9),
      item(3, 'Miele', 0.5),
    ];

    expect(names(searchCatalog(catalog, 'mele')), ['Mele', 'Melanzane', 'Miele']);
    expect(names(searchCatalog(catalog, 'mel')), ['Melanzane', 'Mele', 'Miele']);
  });

  test("returns at most 11 items and nothing for an empty query", () {
    final catalog = List.generate(20, (i) => item(i, 'Pasta $i'));

    expect(searchCatalog(catalog, 'pasta'), hasLength(catalogSearchLimit));
    expect(searchCatalog(catalog, '  '), isEmpty);
  });
}
