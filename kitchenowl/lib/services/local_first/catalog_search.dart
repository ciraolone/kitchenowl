/// Ricerca degli articoli sul telefono (feature 001-local-first del fork di
/// Andrea). Riproduce sul catalogo locale la stessa regola che il backend usa
/// su PostgreSQL in Item.search_name: si confronta l'inizio del nome
/// dell'articolo, lungo quanto la ricerca, con la ricerca stessa; passano gli
/// articoli a distanza di Levenshtein minore di 4, ordinati per distanza e poi
/// per "support" (quanto spesso l'articolo viene comprato), al massimo 11.
/// Se la regola del backend cambia, va riallineata qui, altrimenti la ricerca
/// sul telefono e quella sul web daranno risultati diversi.
library;

const int catalogSearchLimit = 11;
const int _maxDistance = 4;

/// Restituisce gli articoli del catalogo (mappe JSON come arrivano da
/// GET /household/<id>/item) che corrispondono alla ricerca, nell'ordine in
/// cui vanno mostrati.
List<Map<String, dynamic>> searchCatalog(
  List<Map<String, dynamic>> catalog,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return [];

  final matches = <_CatalogMatch>[];
  for (final item in catalog) {
    final name = (item['name'] as String? ?? '').toLowerCase();
    final prefixLength = normalizedQuery.length < name.length
        ? normalizedQuery.length
        : name.length;
    final distance =
        levenshtein(name.substring(0, prefixLength), normalizedQuery);
    if (distance < _maxDistance) {
      matches.add(_CatalogMatch(item, distance));
    }
  }
  matches.sort((a, b) {
    final byDistance = a.distance.compareTo(b.distance);
    if (byDistance != 0) return byDistance;
    return b.support.compareTo(a.support);
  });

  return matches.take(catalogSearchLimit).map((m) => m.item).toList();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitutionCost = a[i] == b[j] ? 0 : 1;
      currentRow[j + 1] = [
        currentRow[j] + 1,
        previousRow[j + 1] + 1,
        previousRow[j] + substitutionCost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previousRow = currentRow;
  }

  return previousRow[b.length];
}

class _CatalogMatch {
  final Map<String, dynamic> item;
  final int distance;

  _CatalogMatch(this.item, this.distance);

  double get support => (item['support'] as num?)?.toDouble() ?? 0;
}
