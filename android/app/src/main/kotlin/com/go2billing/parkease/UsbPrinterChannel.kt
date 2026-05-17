package com.go2billing.parkease

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class UsbPrinterChannel(private val context: Context, flutterEngine: FlutterEngine) {
    private val CHANNEL = "com.go2billing.parkease/usb_printer"
    private val ACTION_USB_PERMISSION = "com.go2billing.parkease.USB_PERMISSION"
    private val TAG = "UsbPrinterChannel"

    private var usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var connection: UsbDeviceConnection? = null
    private var currentDevice: UsbDevice? = null
    private var methodChannel: MethodChannel
    private var permissionResult: MethodChannel.Result? = null

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    Log.d(TAG, "USB permission result: $granted")

                    permissionResult?.success(granted)
                    permissionResult = null
                }
            }
        }
    }

    init {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call: ${call.method}")

            when (call.method) {
                "listDevices" -> {
                    try {
                        val devices = listUsbDevices()
                        Log.d(TAG, "Found ${devices.size} USB devices")
                        result.success(devices)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error listing devices", e)
                        result.error("LIST_ERROR", e.message, null)
                    }
                }
                "hasPermission" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        val hasPermission = checkPermission(deviceId)
                        result.success(hasPermission)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    }
                }
                "requestPermission" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        requestPermission(deviceId, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    }
                }
                "connect" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        connectToDevice(deviceId, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    }
                }
                "disconnect" -> {
                    disconnect()
                    result.success(true)
                }
                "isConnected" -> {
                    result.success(connection != null && currentDevice != null)
                }
                "printBytes" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        val success = printBytes(bytes)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Bytes required", null)
                    }
                }
                "getConnectedDevice" -> {
                    if (currentDevice != null) {
                        result.success(deviceToMap(currentDevice!!))
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Register USB permission receiver
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }

        Log.d(TAG, "UsbPrinterChannel initialized")
    }

    private fun listUsbDevices(): List<Map<String, Any>> {
        val deviceList = usbManager.deviceList.values.map { device ->
            deviceToMap(device)
        }
        return deviceList
    }

    private fun deviceToMap(device: UsbDevice): Map<String, Any> {
        return mapOf(
            "deviceId" to device.deviceId,
            "deviceName" to device.deviceName,
            "productName" to (device.productName ?: "Unknown"),
            "manufacturerName" to (device.manufacturerName ?: "Unknown"),
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "interfaceCount" to device.interfaceCount
        )
    }

    private fun checkPermission(deviceId: Int): Boolean {
        val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
        if (device == null) {
            Log.w(TAG, "Device not found: $deviceId")
            return false
        }

        val hasPermission = usbManager.hasPermission(device)
        Log.d(TAG, "Permission check for device $deviceId: $hasPermission")
        return hasPermission
    }

    private fun requestPermission(deviceId: Int, result: MethodChannel.Result) {
        Log.d(TAG, "Requesting permission for device: $deviceId")

        val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
        if (device == null) {
            Log.e(TAG, "Device not found: $deviceId")
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
            return
        }

        if (usbManager.hasPermission(device)) {
            Log.d(TAG, "Permission already granted")
            result.success(true)
            return
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }

        val intent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(ACTION_USB_PERMISSION),
            flags
        )

        Log.d(TAG, "Requesting USB permission from system...")
        permissionResult = result
        usbManager.requestPermission(device, intent)
        // Result will be sent via BroadcastReceiver
    }

    private fun connectToDevice(deviceId: Int, result: MethodChannel.Result) {
        Log.d(TAG, "Connecting to device: $deviceId")

        // Disconnect existing connection
        if (connection != null) {
            Log.d(TAG, "Closing existing connection")
            disconnect()
        }

        val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
        if (device == null) {
            Log.e(TAG, "Device not found: $deviceId")
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
            return
        }

        if (!usbManager.hasPermission(device)) {
            Log.e(TAG, "No USB permission for device: $deviceId")
            result.error("NO_PERMISSION", "USB permission not granted", null)
            return
        }

        Log.d(TAG, "Opening USB device: ${device.productName}")
        connection = usbManager.openDevice(device)
        if (connection == null) {
            Log.e(TAG, "Failed to open USB device")
            result.error("CONNECTION_FAILED", "Failed to open USB device", null)
            return
        }

        Log.d(TAG, "Device opened successfully")

        // Claim interface 0 (default for printers)
        if (device.interfaceCount > 0) {
            val intf = device.getInterface(0)
            Log.d(TAG, "Claiming interface: ${intf.id}")

            val claimed = connection?.claimInterface(intf, true)
            if (claimed != true) {
                Log.e(TAG, "Failed to claim USB interface")
                connection?.close()
                connection = null
                result.error("INTERFACE_CLAIM_FAILED", "Failed to claim USB interface", null)
                return
            }

            Log.d(TAG, "Interface claimed successfully")
        }

        currentDevice = device
        Log.d(TAG, "✅ Connected successfully to: ${device.productName}")
        result.success(true)
    }

    private fun disconnect() {
        Log.d(TAG, "Disconnecting USB device")

        if (currentDevice != null && connection != null) {
            try {
                // Release all interfaces
                for (i in 0 until currentDevice!!.interfaceCount) {
                    val intf = currentDevice!!.getInterface(i)
                    connection?.releaseInterface(intf)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing interface", e)
            }
        }

        connection?.close()
        connection = null
        currentDevice = null
        Log.d(TAG, "Disconnected")
    }

    private fun printBytes(bytes: ByteArray): Boolean {
        if (connection == null || currentDevice == null) {
            Log.e(TAG, "Not connected to any device")
            return false
        }

        Log.d(TAG, "Printing ${bytes.size} bytes")

        // Find bulk OUT endpoint
        val device = currentDevice!!
        if (device.interfaceCount == 0) {
            Log.e(TAG, "Device has no interfaces")
            return false
        }

        val intf = device.getInterface(0)
        var endpoint: android.hardware.usb.UsbEndpoint? = null

        // Find the bulk OUT endpoint
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            Log.d(TAG, "Endpoint $i: type=${ep.type}, direction=${ep.direction}")

            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                ep.direction == UsbConstants.USB_DIR_OUT) {
                endpoint = ep
                Log.d(TAG, "Found bulk OUT endpoint: ${ep.address}")
                break
            }
        }

        if (endpoint == null) {
            Log.e(TAG, "No bulk OUT endpoint found")

            // Try interrupt OUT endpoint as fallback
            for (i in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(i)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT &&
                    ep.direction == UsbConstants.USB_DIR_OUT) {
                    endpoint = ep
                    Log.d(TAG, "Using interrupt OUT endpoint as fallback: ${ep.address}")
                    break
                }
            }
        }

        if (endpoint == null) {
            Log.e(TAG, "No OUT endpoint found at all")
            return false
        }

        // Send data
        val timeout = 5000 // 5 seconds
        Log.d(TAG, "Sending ${bytes.size} bytes to endpoint ${endpoint.address}...")

        val transferred = connection!!.bulkTransfer(endpoint, bytes, bytes.size, timeout)

        if (transferred == bytes.size) {
            Log.d(TAG, "✅ Successfully sent $transferred bytes")
            return true
        } else if (transferred >= 0) {
            Log.w(TAG, "⚠️ Partial transfer: $transferred / ${bytes.size} bytes")
            return false
        } else {
            Log.e(TAG, "❌ Transfer failed with code: $transferred")
            return false
        }
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up UsbPrinterChannel")
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Error unregistering receiver", e)
        }
        disconnect()
    }
}
