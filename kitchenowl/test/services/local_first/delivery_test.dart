// Esito della consegna di un'azione della lista (feature 001-local-first):
// decide se l'azione lascia la coda o la blocca in attesa di rete.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kitchenowl/services/local_first/delivery.dart';

DeliveryOutcome outcomeOf(int statusCode) =>
    deliveryOutcomeOf(http.Response('', statusCode));

void main() {
  test("an action the server applied leaves the queue", () {
    expect(outcomeOf(200), DeliveryOutcome.delivered);
    expect(const Delivery(DeliveryOutcome.delivered).leavesQueue, isTrue);
  });

  test("an action superseded by a newer server change leaves the queue", () {
    expect(outcomeOf(409), DeliveryOutcome.superseded);
    expect(const Delivery(DeliveryOutcome.superseded).leavesQueue, isTrue);
  });

  test("an action that can never succeed is dropped", () {
    expect(outcomeOf(400), DeliveryOutcome.rejected);
    expect(outcomeOf(404), DeliveryOutcome.rejected);
  });

  test("network errors and server hiccups keep the action for later", () {
    // ApiService turns a missing network into a fake 500
    expect(outcomeOf(500), DeliveryOutcome.retryLater);
    expect(outcomeOf(401), DeliveryOutcome.retryLater);
    expect(outcomeOf(502), DeliveryOutcome.retryLater);
    expect(const Delivery(DeliveryOutcome.retryLater).leavesQueue, isFalse);
  });
}
