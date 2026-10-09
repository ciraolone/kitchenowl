import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension CategoryApi on ApiService {
  static const baseRoute = '/category';

  Future<List<Category>?> getCategories(Household household) async {
    final res = await get(householdPath(household) + baseRoute);
    if (res.statusCode != 200) return null;

    return List<Category>.from(jsonDecode(res.body).map(
      (e) => Category.fromJson(e),
    ));
  }

  // Le risposte intere servono al postino della coda (feature 005), che
  // distingue "riprova" da "rifiutata" e prende l'id del reparto creato
  Future<http.Response> addCategory(Household household, Category category) =>
      post(householdPath(household) + baseRoute, jsonEncode(category.toJson()));

  Future<http.Response> updateCategory(Category category) =>
      post('$baseRoute/${category.id}', jsonEncode(category.toJson()));

  Future<bool> mergeCategories(Category category, Category other) async {
    final res = await post(
      '$baseRoute/${category.id}',
      jsonEncode({
        "merge_category_id": other.id,
      }),
    );

    return res.statusCode == 200;
  }

  Future<bool> deleteCategory(Category category) async {
    final res = await delete('$baseRoute/${category.id}');

    return res.statusCode == 200;
  }
}
