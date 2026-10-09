import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kitchenowl/services/transaction.dart';
import 'package:path_provider/path_provider.dart' as pathProvider;

class TransactionStorage {
  static TransactionStorage? _instance;
  Future<void> _lastUpdate = Future.value();

  TransactionStorage._internal();
  static TransactionStorage getInstance() {
    _instance ??= TransactionStorage._internal();

    return _instance!;
  }

  Future<String> get _localPath async {
    return pathProvider
        .getApplicationSupportDirectory()
        .then((dir) => dir.path);
  }

  Future<File> get _localFile async {
    final path = await _localPath;

    return File('$path/transactions.json');
  }

  Future<List<Transaction>> readTransactions() async {
    if (!kIsWeb) {
      try {
        final file = await _localFile;
        final String content = await file.readAsString();

        return List<Transaction>.from(
          json.decode(content).map((e) => Transaction.fromJson(e)),
        );
      } catch (_) {}
    }

    return [];
  }

  Future<void> clearTransactions() async {
    if (!kIsWeb) {
      try {
        final file = await _localFile;
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> addTransaction(Transaction t) =>
      _updateQueue((transactions) => transactions.add(t));

  /// Toglie una transazione consegnata. Si cerca per uguaglianza (classe e
  /// momento) e non per posizione, perché mentre il postino consegnava
  /// possono essere state accodate azioni nuove.
  Future<void> removeTransaction(Transaction t) =>
      _updateQueue((transactions) => transactions.remove(t));

  // Ogni modifica legge, cambia e riscrive il file: le si mette in fila,
  // altrimenti due modifiche quasi simultanee si sovrascriverebbero a vicenda
  Future<void> _updateQueue(void Function(List<Transaction>) change) {
    final update = _lastUpdate.then((_) async {
      if (kIsWeb) return;
      final transactions = await readTransactions();
      change(transactions);
      final file = await _localFile;
      await file.writeAsString(
        json.encode(transactions.map((t) => t.toJson()).toList()),
      );
    });
    _lastUpdate = update.catchError((_) {});
    return update;
  }
}
