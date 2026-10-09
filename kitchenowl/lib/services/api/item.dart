import 'dart:convert';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_attachment.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension ItemApi on ApiService {
  static const baseRoute = '/item';

  Future<List<Item>?> getAllItems(
    Household household,
  ) async {
    final res = await get('${householdPath(household)}$baseRoute');
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));

    return body.map((e) => Item.fromJson(e)).toList();
  }

  /// Catalogo completo della casa come mappe JSON grezze: a differenza di
  /// getAllItems conserva "support", che serve alla ricerca sul telefono
  /// (services/local_first/catalog_search.dart).
  Future<List<Map<String, dynamic>>?> getAllItemsJson(
    Household household,
  ) async {
    final res = await get('${householdPath(household)}$baseRoute');
    if (res.statusCode != 200) return null;

    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  Future<Item?> getItem(Item item) async {
    final res = await get('$baseRoute/${item.id}');
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);

    return Item.fromJson(body);
  }

  Future<List<Recipe>?> getItemRecipes(Item item) async {
    final res = await get('$baseRoute/${item.id}/recipes');
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));

    return body.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<ItemWithDescription>?> searchItem(
    Household household,
    String query,
  ) async {
    final res = await get(
      '${householdPath(household)}$baseRoute/search',
      queryParameters: {
        "query": query,
      },
    );
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));

    return body.map((e) => ItemWithDescription.fromJson(e)).toList();
  }

  Future<bool> deleteItem(Item item) async {
    final res = await delete('$baseRoute/${item.id}');

    return res.statusCode == 200;
  }

  Future<bool> updateItem(Item item) async {
    final res =
        await post('$baseRoute/${item.id}', jsonEncode(item.toJsonWithId()));

    return res.statusCode == 200;
  }

  Future<bool> addItem(Household household, Item item) async {
    final res = await post('${householdPath(household)}$baseRoute',
        jsonEncode(item.toJsonWithId()));

    return res.statusCode == 200;
  }

  Future<bool> mergeItems(Item item, Item other) async {
    final res = await post(
      '$baseRoute/${item.id}',
      jsonEncode({
        "merge_item_id": other.id,
      }),
    );

    return res.statusCode == 200;
  }

  // ---------------------------------------------------------------------------
  // Allegati: il client carica prima il file con uploadBytes() che ritorna un
  // filename, poi associa il filename all'item con addItemAttachment().
  // ---------------------------------------------------------------------------

  Future<ItemAttachment?> addItemAttachment(
    Item item,
    String filename,
    ItemAttachmentKind kind, {
    String? label,
  }) async {
    final res = await post(
      '$baseRoute/${item.id}/attachment',
      jsonEncode({
        "filename": filename,
        "kind": kind.toJson(),
        if (label != null) "label": label,
      }),
    );
    if (res.statusCode != 200) return null;
    return ItemAttachment.fromJson(jsonDecode(res.body));
  }

  Future<ItemAttachment?> renameItemAttachment(
    Item item,
    ItemAttachment attachment,
    String? label,
  ) async {
    final res = await post(
      '$baseRoute/${item.id}/attachment/${attachment.id}',
      jsonEncode({"label": label}),
    );
    if (res.statusCode != 200) return null;
    return ItemAttachment.fromJson(jsonDecode(res.body));
  }

  Future<bool> deleteItemAttachment(
    Item item,
    ItemAttachment attachment,
  ) async {
    final res =
        await delete('$baseRoute/${item.id}/attachment/${attachment.id}');
    return res.statusCode == 200;
  }

  Future<List<ItemAttachment>?> reorderItemAttachments(
    Item item,
    ItemAttachmentKind kind,
    List<int> orderedIds,
  ) async {
    final res = await put(
      '$baseRoute/${item.id}/attachment/reorder',
      jsonEncode({
        "kind": kind.toJson(),
        "order": orderedIds,
      }),
    );
    if (res.statusCode != 200) return null;
    final body = List.from(jsonDecode(res.body));
    return body
        .map((e) => ItemAttachment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
