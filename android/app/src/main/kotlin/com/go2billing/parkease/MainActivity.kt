package com.go2billing.parkease

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var usbPrinterChannel: UsbPrinterChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize USB Printer Channel
        usbPrinterChannel = UsbPrinterChannel(this, flutterEngine)
    }

    override fun onDestroy() {
        super.onDestroy()
        usbPrinterChannel?.cleanup()
    }
}
