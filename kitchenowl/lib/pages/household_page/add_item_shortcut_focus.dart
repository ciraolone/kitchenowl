/// Arrivo dalla scorciatoia "Aggiungi articolo" del launcher Android
/// (features/002-scorciatoia-aggiungi). La rotta /add-item del router porta
/// alla lista della spesa con ?add=<istante>, un valore nuovo a ogni tocco;
/// questo mixin, usato dalla pagina della lista, a ogni valore nuovo dà il
/// fuoco al campo di ricerca e apre la tastiera. Va chiamato da
/// didChangeDependencies, che si riattiva quando cambia l'indirizzo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

mixin AddItemShortcutFocus<T extends StatefulWidget> on State<T> {
  String? _handledAddRequest;
  AppLifecycleListener? _resumeListener;

  @override
  void dispose() {
    _resumeListener?.dispose();
    super.dispose();
  }

  // Si aspetta il primo disegno perché il campo deve già esistere.
  void focusOnAddItemShortcut(FocusNode searchFocusNode) {
    final addRequest = GoRouterState.of(context).uri.queryParameters['add'];
    if (addRequest == null || addRequest == _handledAddRequest) return;
    _handledAddRequest = addRequest;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusWhenResumed(searchFocusNode));
  }

  // Ad app in sottofondo il link arriva prima che Android ridia la finestra
  // all'app: un fuoco dato in quel momento resta senza tastiera. Per questo
  // si aspetta lo stato resumed, che su Android arriva con la finestra attiva.
  void _focusWhenResumed(FocusNode searchFocusNode) {
    if (!mounted) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _focus(searchFocusNode);
      return;
    }
    _resumeListener?.dispose();
    _resumeListener = AppLifecycleListener(onResume: () {
      _resumeListener?.dispose();
      _resumeListener = null;
      if (mounted) _focus(searchFocusNode);
    });
  }

  // Se il campo ha ancora il fuoco ma la tastiera è stata chiusa (tasto
  // indietro), requestFocus non fa nulla: lì la tastiera va riaperta a mano.
  void _focus(FocusNode searchFocusNode) {
    if (searchFocusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return;
    }
    searchFocusNode.requestFocus();
  }
}
