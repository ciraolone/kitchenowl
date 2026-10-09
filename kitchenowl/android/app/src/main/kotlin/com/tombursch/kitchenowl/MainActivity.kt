// Attività Android dell'app. Oltre a quanto fa FlutterActivity, espone il canale "kitchenowl/haptics" con il metodo "strongClick": un colpo di vibrazione corto e alla massima intensità, usato quando parte il trascinamento di un articolo (features/004-riordino-trascinamento). Le vibrazioni di Flutter (HapticFeedback) passano dagli effetti di sistema, che su molti telefoni sono troppo deboli per accorgersene.
package com.tombursch.kitchenowl

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kitchenowl/haptics")
            .setMethodCallHandler { call, result ->
                if (call.method == "strongClick") {
                    strongClick()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun strongClick() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        // 40 ms a intensità piena: abbastanza corto da sembrare un colpo secco, non un ronzio
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(STRONG_CLICK_MS, 255))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(STRONG_CLICK_MS)
        }
    }

    companion object {
        private const val STRONG_CLICK_MS = 40L
    }
}
