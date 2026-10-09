/// Esito della consegna al server di un'azione della lista della spesa fatta
/// sul telefono (feature 001-local-first del fork di Andrea). Le azioni local
/// first (LocalFirstTransaction) sono già applicate alla copia locale e
/// aspettano in coda; quando il postino (TransactionHandler) le manda, il
/// codice di risposta decide cosa farne: consegnata o superata si tolgono
/// dalla coda, rifiutata si toglie perché non potrà mai riuscire (articolo o
/// lista cancellati sul server), da riprovare blocca la coda per non mandare
/// le azioni successive fuori ordine.
library;

import 'package:http/http.dart' as http;
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/transaction.dart';

enum DeliveryOutcome { delivered, superseded, rejected, retryLater }

class Delivery {
  final DeliveryOutcome outcome;

  /// Articoli per cui il server aveva una modifica più recente: l'app li
  /// nomina nell'avviso. Una rimozione multipla può essere consegnata e
  /// avere comunque qualche articolo superato.
  final List<String> supersededItemNames;

  const Delivery(this.outcome, [this.supersededItemNames = const []]);

  bool get leavesQueue => outcome != DeliveryOutcome.retryLater;
}

DeliveryOutcome deliveryOutcomeOf(http.Response response) {
  final statusCode = response.statusCode;
  if (statusCode == 200) return DeliveryOutcome.delivered;
  if (statusCode == 409) return DeliveryOutcome.superseded;
  // ApiService trasforma gli errori di rete in un 500 finto: 5xx, 401 e
  // affini vanno riprovati, solo le risposte che non cambieranno mai no
  if (statusCode == 400 || statusCode == 403 || statusCode == 404) {
    return DeliveryOutcome.rejected;
  }
  return DeliveryOutcome.retryLater;
}

/// Azione sulla lista della spesa che si applica subito al telefono e si
/// consegna al server più tardi, con il momento in cui è stata fatta.
mixin LocalFirstTransaction<T> on Transaction<T> {
  Household get household;

  Future<Delivery> deliver();
}
