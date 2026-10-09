/// Colpo di vibrazione forte (feature 004-riordino-trascinamento del fork di
/// Andrea), per quando parte il trascinamento di un articolo. Su Android
/// chiede a MainActivity (canale "kitchenowl/haptics") un colpo corto alla
/// massima intensità, perché gli effetti di HapticFeedback dipendono dal
/// telefono e spesso quasi non si sentono. Altrove (web, iOS) ripiega su
/// HapticFeedback.heavyImpact.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('kitchenowl/haptics');

Future<void> strongHapticClick() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    await HapticFeedback.heavyImpact();
    return;
  }
  try {
    await _channel.invokeMethod('strongClick');
  } on MissingPluginException {
    await HapticFeedback.heavyImpact();
  }
}
