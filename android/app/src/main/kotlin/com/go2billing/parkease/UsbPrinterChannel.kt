package com.go2billing.parkease

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class UsbPrinterChannel(private val context: Context, flutterEngine: FlutterEngine) {
    private val CHANNEL = "com.go2billing.parkease/usb_printer"
    private val ACTION_USB_PERMISSION = "com.go2billing.parkease.USB_PERMISSION"
    private val TAG = "UsbPrinter"

    private var usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var connection: UsbDeviceConnection? = null
    private var currentDevice: UsbDevice? = null
    private var printerInterface: UsbInterface? = null
    private var bulkOutEndpoint: UsbEndpoint? = null
    private var methodChannel: MethodChannel
    private var permissionResult: MethodChannel.Result? = null

    // Known thermal printer vendor IDs
    private val PRINTER_VENDOR_IDS = setOf(
        0x0483, // STMicroelectronics (Xprinter, many Chinese printers)
        0x1FC9, // NXP (some Xprinter models)
        0x04B8, // Epson
        0x0DD4, // TVS
        0x0416, // Winbond (Generic POS)
        0x0493, // Generic POS-58/80
        0x1A86, // QinHeng (CH340 - USB-Serial printers)
        0x067B, // Prolific (PL2303 - USB-Serial printers)
        0x0FE6, // ICS (Kontron)
        0x20D1, // Dmax
        0x0525, // Netchip (Linux USB gadget)
        0x4348, // WCH (CH34x)
        0x1CBE, // Luminary Micro
        0x0B00, // Star Micronics
    )

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    Log.d(TAG, "Permission result: $granted")
                    permissionResult?.success(granted)
                    permissionResult = null
                }
            }
        }
    }

    init {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listDevices" -> result.success(listPrinters())
                "hasPermission" -> {
                    val id = call.argument<Int>("deviceId")
                    result.success(if (id != null) hasPermission(id) else false)
                }
                "requestPermission" -> {
                    val id = call.argument<Int>("deviceId")
                    if (id != null) requestPermission(id, result) else result.error("ARG", "deviceId required", null)
                }
                "connect" -> {
                    val id = call.argument<Int>("deviceId")
                    if (id != null) connect(id, result) else result.error("ARG", "deviceId required", null)
                }
                "disconnect" -> { disconnect(); result.success(true) }
                "isConnected" -> result.success(connection != null && bulkOutEndpoint != null)
                "printBytes" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) result.success(sendBytes(bytes)) else result.error("ARG", "bytes required", null)
                }
                "printText" -> {
                    val text = call.argument<String>("text")
                    if (text != null) result.success(sendBytes(text.toByteArray(Charsets.UTF_8))) else result.error("ARG", "text required", null)
                }
                "getConnectedDevice" -> result.success(currentDevice?.let { deviceToMap(it) })
                else -> result.notImplemented()
            }
        }

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }
        Log.d(TAG, "Initialized")
    }

    /** List all USB devices that could be printers */
    private fun listPrinters(): List<Map<String, Any>> {
        return usbManager.deviceList.values
            .filter { isPrinterDevice(it) }
            .map { deviceToMap(it) }
    }

    /** Check if a USB device is likely a printer */
    private fun isPrinterDevice(device: UsbDevice): Boolean {
        // Class 7 = Printer
        if (device.deviceClass == 7) return true
        // Check interfaces for printer class
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == 7) return true
        }
        // Known vendor IDs
        if (device.vendorId in PRINTER_VENDOR_IDS) return true
        // Has bulk OUT endpoint (likely a printer or serial device)
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK && ep.direction == UsbConstants.USB_DIR_OUT) {
                    return true
                }
            }
        }
        return false
    }

    /** Find the best interface and endpoint for printing */
    private fun findPrinterEndpoint(device: UsbDevice): Pair<UsbInterface, UsbEndpoint>? {
        // Priority 1: Printer class interface (class 7)
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == 7) {
                val ep = findBulkOut(intf)
                if (ep != null) {
                    Log.d(TAG, "Found printer class interface $i with bulk OUT")
                    return Pair(intf, ep)
                }
            }
        }
        // Priority 2: Any interface with bulk OUT endpoint
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            val ep = findBulkOut(intf)
            if (ep != null) {
                Log.d(TAG, "Found bulk OUT on interface $i")
                return Pair(intf, ep)
            }
        }
        // Priority 3: Interrupt OUT (some cheap printers use this)
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.direction == UsbConstants.USB_DIR_OUT) {
                    Log.d(TAG, "Fallback: using interrupt/other OUT on interface $i")
                    return Pair(intf, ep)
                }
            }
        }
        return null
    }

    private fun findBulkOut(intf: UsbInterface): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK && ep.direction == UsbConstants.USB_DIR_OUT) {
                return ep
            }
        }
        return null
    }

    private fun hasPermission(deviceId: Int): Boolean {
        val device = usbManager.deviceList.values.find { it.deviceId == deviceId } ?: return false
        return usbManager.hasPermission(device)
    }

    private fun requestPermission(deviceId: Int, result: MethodChannel.Result) {
        val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
        if (device == null) { result.error("NOT_FOUND", "Device not found", null); return }
        if (usbManager.hasPermission(device)) { result.success(true); return }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val intent = PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), flags)
        permissionResult = result
        usbManager.requestPermission(device, intent)
    }

    private fun connect(deviceId: Int, result: MethodChannel.Result) {
        disconnect() // Close any existing connection

        val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
        if (device == null) { result.error("NOT_FOUND", "Device not found", null); return }
        if (!usbManager.hasPermission(device)) { result.error("NO_PERM", "Permission not granted", null); return }

        // Find printer endpoint
        val pair = findPrinterEndpoint(device)
        if (pair == null) {
            result.error("NO_ENDPOINT", "No suitable print endpoint found on this device", null)
            return
        }

        val (intf, endpoint) = pair

        // Open device
        val conn = usbManager.openDevice(device)
        if (conn == null) { result.error("OPEN_FAIL", "Failed to open device", null); return }

        // Claim interface
        if (!conn.claimInterface(intf, true)) {
            conn.close()
            result.error("CLAIM_FAIL", "Failed to claim interface", null)
            return
        }

        connection = conn
        currentDevice = device
        printerInterface = intf
        bulkOutEndpoint = endpoint

        Log.d(TAG, "✅ Connected: ${device.productName ?: "USB Printer"} (VID:${device.vendorId} PID:${device.productId})")
        result.success(true)
    }

    private fun disconnect() {
        if (printerInterface != null && connection != null) {
            try { connection?.releaseInterface(printerInterface) } catch (_: Exception) {}
        }
        connection?.close()
        connection = null
        currentDevice = null
        printerInterface = null
        bulkOutEndpoint = null
    }

    /** Send raw bytes to printer via bulk transfer */
    private fun sendBytes(bytes: ByteArray): Boolean {
        val conn = connection ?: return false
        val ep = bulkOutEndpoint ?: return false

        Log.d(TAG, "Sending ${bytes.size} bytes...")

        // Send in chunks of 16KB (some printers can't handle large transfers)
        val chunkSize = 16384
        var offset = 0
        while (offset < bytes.size) {
            val len = minOf(chunkSize, bytes.size - offset)
            val chunk = bytes.copyOfRange(offset, offset + len)
            val sent = conn.bulkTransfer(ep, chunk, chunk.size, 5000)
            if (sent < 0) {
                Log.e(TAG, "❌ Transfer failed at offset $offset, code: $sent")
                return false
            }
            offset += sent
        }

        Log.d(TAG, "✅ Sent ${bytes.size} bytes successfully")
        return true
    }

    private fun deviceToMap(device: UsbDevice): Map<String, Any> {
        return mapOf(
            "deviceId" to device.deviceId,
            "deviceName" to device.deviceName,
            "productName" to (device.productName ?: "USB Printer"),
            "manufacturerName" to (device.manufacturerName ?: "Unknown"),
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "deviceClass" to device.deviceClass,
            "interfaceCount" to device.interfaceCount,
            "isPrinterClass" to (device.deviceClass == 7 || (0 until device.interfaceCount).any { device.getInterface(it).interfaceClass == 7 })
        )
    }

    fun cleanup() {
        try { context.unregisterReceiver(usbReceiver) } catch (_: Exception) {}
        disconnect()
    }
}
