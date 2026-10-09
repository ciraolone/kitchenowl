/// Catalogo completo degli articoli di una casa tenuto sul telefono (feature
/// 001-local-first del fork di Andrea), così la ricerca della lista della
/// spesa non tocca mai la rete. Il catalogo vive in memoria e in un file
/// `<household>-catalog.json` nella cartella di supporto dell'app (non nella
/// cache, che Android può svuotare: senza rete la ricerca resterebbe vuota).
/// Si aggiorna dal server in sottofondo con refreshFromServer, e si arricchisce
/// a mano con remember quando un articolo nuovo arriva da un evento socket o
/// dalla risposta del server a un'aggiunta. Sul web non c'è file: il catalogo
/// resta solo in memoria.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/catalog_search.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class ItemCatalog {
  static final ItemCatalog _instance = ItemCatalog._internal();
  static ItemCatalog getInstance() => _instance;
  ItemCatalog._internal();

  final Map<int, List<Map<String, dynamic>>> _catalogByHousehold = {};

  Future<List<Map<String, dynamic>>> _catalogOf(Household household) async {
    final householdId = household.id;
    final cached = _catalogByHousehold[householdId];
    if (cached != null) return cached;

    final loaded = await _readFile(householdId);
    _catalogByHousehold[householdId] = loaded;
    return loaded;
  }

  Future<List<Item>> search(Household household, String query) async {
    final catalog = await _catalogOf(household);
    return searchCatalog(catalog, query).map(Item.fromJson).toList();
  }

  Future<int?> idOfName(Household household, String name) async {
    final catalog = await _catalogOf(household);
    final lowerName = name.toLowerCase();
    for (final item in catalog) {
      if ((item['name'] as String?)?.toLowerCase() == lowerName) {
        return item['id'] as int?;
      }
    }
    return null;
  }

  Future<void> refreshFromServer(Household household) async {
    final householdId = household.id;
    final items = await ApiService.getInstance().getAllItemsJson(household);
    if (items == null) return;
    _catalogByHousehold[householdId] = items;
    await _writeFile(householdId, items);
  }

  /// Aggiunge o aggiorna un articolo (mappa JSON del server) nel catalogo.
  Future<void> remember(Household household, Map<String, dynamic> item) async {
    final householdId = household.id;
    if (item['id'] == null) return;
    final catalog = await _catalogOf(household);
    final index = catalog.indexWhere((e) => e['id'] == item['id']);
    if (index >= 0) {
      // Gli eventi socket non portano "support": si tiene quello già noto
      catalog[index] = {...catalog[index], ...item};
    } else {
      catalog.add(item);
    }
    await _writeFile(householdId, catalog);
  }

  Future<File> _file(int householdId) async {
    final directory = await path_provider.getApplicationSupportDirectory();
    return File('${directory.path}/$householdId-catalog.json');
  }

  Future<List<Map<String, dynamic>>> _readFile(int householdId) async {
    if (kIsWeb) return [];
    try {
      final content = await (await _file(householdId)).readAsString();
      return List<Map<String, dynamic>>.from(jsonDecode(content));
    } on FileSystemException {
      return [];
    }
  }

  Future<void> _writeFile(
    int householdId,
    List<Map<String, dynamic>> items,
  ) async {
    if (kIsWeb) return;
    await (await _file(householdId)).writeAsString(jsonEncode(items));
  }
}
