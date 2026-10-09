/// Punto unico da cui passano le azioni dell'app verso il server e la coda
/// delle azioni non ancora consegnate (TransactionStorage, transactions.json).
/// Due regimi. Le azioni sulla lista della spesa (LocalFirstTransaction,
/// feature 001-local-first del fork di Andrea) si applicano subito alla copia
/// sul telefono, finiscono sempre in coda e vengono consegnate in sottofondo
/// dal postino (runOpenTransactions), una alla volta e in ordine: se una non
/// passa per problemi di rete, le successive aspettano, così il server le
/// riceve nell'ordine in cui sono state fatte. Le altre azioni (pianificatore)
/// seguono il comportamento originale: prima il server, la coda solo se la
/// rete manca. Sul web la coda non esiste, quindi lì vale sempre il regime
/// originale. Quando il server risponde che un'azione è stata superata da una
/// modifica più recente, i nomi degli articoli escono da supersededItems per
/// l'avviso e il riallineo della lista.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/delivery.dart';
import 'package:kitchenowl/services/storage/transaction_storage.dart';
import 'package:kitchenowl/services/transaction.dart';

class TransactionHandler {
  static TransactionHandler? _instance;

  TransactionHandler.internal();

  static TransactionHandler getInstance() {
    _instance ??= TransactionHandler.internal();

    return _instance!;
  }

  final StreamController<List<String>> _supersededItems =
      StreamController.broadcast();
  Future<void>? _delivering;
  bool _shouldDeliverAgain = false;

  Stream<List<String>> get supersededItems => _supersededItems.stream;

  /// Consegna la coda. Se una consegna è già in corso non ne parte una
  /// seconda in parallelo: la si ripete appena finisce, per prendere anche
  /// le azioni arrivate nel frattempo.
  Future<void> runOpenTransactions() {
    final running = _delivering;
    if (running != null) {
      _shouldDeliverAgain = true;
      return running;
    }
    final delivering = _deliverUntilSettled();
    _delivering = delivering;
    return delivering.whenComplete(() => _delivering = null);
  }

  Future<void> _deliverUntilSettled() async {
    do {
      _shouldDeliverAgain = false;
      await _deliverQueue();
    } while (_shouldDeliverAgain);
  }

  Future<void> _deliverQueue() async {
    if (!ApiService.getInstance().isConnected()) return;
    final storage = TransactionStorage.getInstance();
    final supersededItemNames = <String>[];
    var isLocalFirstQueueBlocked = false;

    for (final t in await storage.readTransactions()) {
      if (t is ErrorTransaction) {
        await storage.removeTransaction(t);
      } else if (t is LocalFirstTransaction) {
        if (isLocalFirstQueueBlocked) continue;
        final delivery = await t.deliver();
        supersededItemNames.addAll(delivery.supersededItemNames);
        if (delivery.leavesQueue) {
          await storage.removeTransaction(t);
        } else {
          isLocalFirstQueueBlocked = true;
        }
      } else {
        final dynamic result = await t.runOnline();
        if (result != null && (result is! bool || result)) {
          await storage.removeTransaction(t);
        }
      }
    }
    if (supersededItemNames.isNotEmpty) {
      _supersededItems.add(supersededItemNames);
    }
  }

  /// Azioni sulla lista della spesa ancora da consegnare per una casa, in
  /// ordine: vanno riapplicate sopra ogni copia fresca arrivata dal server,
  /// che ancora non le contiene.
  Future<void> replayPending(Household household) async {
    for (final t in await TransactionStorage.getInstance().readTransactions()) {
      if (t is LocalFirstTransaction && t.household.id == household.id) {
        await t.runLocal();
      }
    }
  }

  Future<T> runTransaction<T>(
    Transaction<T> t, {
    bool forceOffline = false,
    bool saveTransaction = true,
  }) async {
    if (t is LocalFirstTransaction && saveTransaction && !kIsWeb) {
      final result = await t.runLocal();
      await TransactionStorage.getInstance().addTransaction(t);
      unawaited(runOpenTransactions());
      return result;
    }

    forceOffline = forceOffline || App.isForcedOffline;
    if (!ApiService.getInstance().isConnected()) {
      await ApiService.getInstance().refresh();
    }
    if (!forceOffline && ApiService.getInstance().isConnected()) {
      T? res = await t.runOnline();
      if (res != null && (res is! bool || res)) return res;
    }
    if (t.saveTransaction && saveTransaction) {
      await TransactionStorage.getInstance().addTransaction(t);
    }

    return t.runLocal();
  }
}
