import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension ShoppinglistApi on ApiService {
  static const baseRoute = '/shoppinglist';
  String route({Household? household, ShoppingList? shoppinglist}) =>
      "${household != null ? householdPath(household) : ""}$baseRoute${shoppinglist?.id != null ? "/${shoppinglist!.id}" : ""}";

  Future<List<ShoppingList>?> getShoppingLists(
    Household household, {
    ShoppinglistSorting sorting = ShoppinglistSorting.alphabetical,
    int recentItemlimit = 9,
  }) async {
    recentItemlimit = recentItemlimit > 120 ? 120 : recentItemlimit;
    final res = await get(
      route(household: household),
      queryParameters: {
        'orderby': sorting.index.toString(),
        'recent_limit': recentItemlimit.toString(),
      },
    );
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));

    return body.map((e) => ShoppingList.fromJson(e)).toList();
  }

  Future<bool> addShoppingList(
    Household household,
    ShoppingList shoppingList,
  ) async {
    final res = await post(
      route(household: household),
      jsonEncode(shoppingList.toJson()),
    );

    return res.statusCode == 200;
  }

  Future<bool> updateShoppingList(
    ShoppingList shoppingList,
  ) async {
    final res = await post(
      route(shoppinglist: shoppingList),
      jsonEncode(shoppingList.toJson()),
    );

    return res.statusCode == 200;
  }

  Future<bool> deleteShoppingList(
    ShoppingList shoppingList,
  ) async {
    final res = await delete(route(shoppinglist: shoppingList));

    return res.statusCode == 200;
  }

  // Le quattro chiamate che cambiano gli articoli della lista restituiscono la
  // risposta intera: la coda local first (TransactionHandler) deve distinguere
  // consegnato (200), superato da una modifica più recente (409), rifiutato e
  // da riprovare. changedAt è il momento in cui Andrea ha fatto l'azione sul
  // telefono: il backend lo usa per decidere chi vince nelle sovrapposizioni.
  Future<http.Response> putItem(
    ShoppingList shoppinglist,
    Item item,
    DateTime changedAt,
  ) {
    final Map<String, dynamic> data = {
      'changed_at': changedAt.toUtc().millisecondsSinceEpoch,
    };
    if (item is ItemWithDescription) {
      data['description'] = item.description;
    }
    return put(
      '${route(shoppinglist: shoppinglist)}/item/${item.id}',
      jsonEncode(data),
    );
  }

  Future<http.Response> addItemByName(
    ShoppingList shoppinglist,
    String name,
    String? description,
    DateTime changedAt,
  ) {
    final data = <String, dynamic>{
      'name': name,
      'changed_at': changedAt.toUtc().millisecondsSinceEpoch,
    };
    if (description != null) data['description'] = description;
    return post(
      '${route(shoppinglist: shoppinglist)}/add-item-by-name',
      jsonEncode(data),
    );
  }

  Future<bool> addRecipeItems(
    ShoppingList shoppinglist,
    List<RecipeItem> items,
  ) async {
    final res = await post(
      '${route(shoppinglist: shoppinglist)}/recipeitems',
      jsonEncode({'items': items.map((e) => e.toJsonWithId()).toList()}),
    );

    return res.statusCode == 200;
  }

  Future<http.Response> removeItem(
    ShoppingList shoppinglist,
    int itemId,
    DateTime changedAt,
  ) {
    return delete(
      '${route(shoppinglist: shoppinglist)}/item',
      body: jsonEncode({
        'item_id': itemId,
        'changed_at': changedAt.toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  Future<http.Response> removeItems(
    ShoppingList shoppinglist,
    List<int> itemIds,
    DateTime changedAt,
  ) {
    return delete(
      '${route(shoppinglist: shoppinglist)}/items',
      body: jsonEncode({
        "items": itemIds
            .map(
              (itemId) => {
                'item_id': itemId,
                'changed_at': changedAt.toUtc().millisecondsSinceEpoch,
              },
            )
            .toList(),
      }),
    );
  }

  void onShoppinglistAdd(dynamic Function(dynamic) handler) {
    socket.on("shoppinglist:add", handler);
  }

  void offShoppinglistAdd(dynamic Function(dynamic) handler) {
    socket.off("shoppinglist:add", handler);
  }

  void onShoppinglistDelete(dynamic Function(dynamic) handler) {
    socket.on("shoppinglist:delete", handler);
  }

  void offShoppinglistDelete(dynamic Function(dynamic) handler) {
    socket.off("shoppinglist:delete", handler);
  }

  void onShoppinglistItemAdd(dynamic Function(dynamic) handler) {
    socket.on("shoppinglist_item:add", handler);
  }

  void offShoppinglistItemAdd(dynamic Function(dynamic) handler) {
    socket.off("shoppinglist_item:add", handler);
  }

  void onShoppinglistItemRemove(dynamic Function(dynamic) handler) {
    socket.on("shoppinglist_item:remove", handler);
  }

  void offShoppinglistItemRemove(dynamic Function(dynamic) handler) {
    socket.off("shoppinglist_item:remove", handler);
  }
}
