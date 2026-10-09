/// Consegna al server delle azioni sui reparti fatte dalla lista della spesa
/// (feature 005-reparti-dalla-lista del fork di Andrea): creazione e
/// spostamento. Traducono la risposta in un Delivery come le consegne della
/// lista (shoppinglist_delivery.dart). Un reparto creato senza rete prende qui
/// l'id che il server gli dà, e le azioni successive in coda lo ritrovano per
/// nome con categoryIdOf.
library;

import 'dart:convert';

import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/category_order.dart';
import 'package:kitchenowl/services/local_first/delivery.dart';

Future<Delivery> deliverAddedCategory({
  required Household household,
  required String name,
}) async {
  final response = await ApiService.getInstance()
      .addCategory(household, Category(name: name));
  final outcome = deliveryOutcomeOf(response);
  if (outcome == DeliveryOutcome.delivered) {
    await rememberCreatedCategory(
      household,
      Category.fromJson(jsonDecode(response.body)),
    );
  }
  return Delivery(outcome);
}

Future<Delivery> deliverMovedCategory({
  required Household household,
  required Category category,
  required int index,
}) async {
  final id = await categoryIdOf(household, category);
  if (id == null) return const Delivery(DeliveryOutcome.rejected);
  final response = await ApiService.getInstance().updateCategory(
    Category(id: id, name: category.name, ordering: index),
  );
  return Delivery(deliveryOutcomeOf(response));
}
