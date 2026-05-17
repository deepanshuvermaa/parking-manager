import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'simple_bluetooth_service.dart';
import 'desktop_printer_service.dart';
import 'native_usb_printer_service.dart';
import 'windows_native_printer_service.dart';

/// Platform-aware printer service
/// Automatically uses Bluetooth on mobile or USB/Native on desktop
class PlatformPrinterService {
  /// Check if we're on a mobile platform
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Check if we're on a desktop platform
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Get available printers (platform-specific)
  static Future<List<dynamic>> getAvailablePrinters() async {
    if (isDesktop) {
      // Return system printers on desktop
      return await DesktopPrinterService.getAvailablePrinters();
    }
    // Mobile: Bluetooth scanning is handled in printer settings screen
    return [];
  }

  /// Connect to printer (platform-specific)
  static Future<bool> connect(dynamic printer) async {
    if (isDesktop) {
      // Save system printer
      await DesktopPrinterService.selectPrinter(printer);
      return true;
    }
    // Mobile: Connection is handled in printer settings screen
    return false;
  }

  /// Get printer connection type (for Android - bluetooth or usb)
  static Future<String> _getPrinterConnectionType() async {
    if (Platform.isAndroid) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('printer_connection_type') ?? 'bluetooth';
    }
    return 'bluetooth'; // Default for other platforms
  }

  /// Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        // Use native USB service instead of old usb_serial
        return await NativeUsbPrinterService.autoConnect();
      }
      return await SimpleBluetoothService.autoConnect();
    } else if (Platform.isWindows) {
      return await WindowsNativePrinterService.autoConnect();
    } else if (isDesktop) {
      return await DesktopPrinterService.autoConnect();
    }
    return false;
  }

  /// Check if printer is connected
  static Future<bool> isConnected() async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        return NativeUsbPrinterService.isConnected;
      }
      return SimpleBluetoothService.isConnected;
    } else if (Platform.isWindows) {
      return WindowsNativePrinterService.isConnected;
    } else if (isDesktop) {
      return await DesktopPrinterService.isConnected();
    }
    return false;
  }

  /// Print text (platform-specific)
  static Future<bool> printText(String text) async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        return await NativeUsbPrinterService.printText(text);
      }
      return await SimpleBluetoothService.printReceipt(text);
    } else if (Platform.isWindows) {
      return await WindowsNativePrinterService.printText(text);
    } else if (isDesktop) {
      return await DesktopPrinterService.printText(text);
    }
    return false;
  }

  /// Print test page
  static Future<bool> printTest() async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        return await NativeUsbPrinterService.printTestReceipt();
      }
      const testReceipt = '================================\n'
          '       TEST RECEIPT\n'
          '================================\n'
          'This is a test print\n'
          '================================\n';
      return await SimpleBluetoothService.printReceipt(testReceipt);
    } else if (Platform.isWindows) {
      return await WindowsNativePrinterService.printTestReceipt();
    } else if (isDesktop) {
      return await DesktopPrinterService.printTest();
    }
    return false;
  }

  /// Disconnect printer
  static Future<void> disconnect() async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        await NativeUsbPrinterService.disconnect();
      } else {
        await SimpleBluetoothService.disconnect();
      }
    } else if (Platform.isWindows) {
      await WindowsNativePrinterService.disconnect();
    } else if (isDesktop) {
      await DesktopPrinterService.disconnect();
    }
  }

  /// Get printer status
  static Future<Map<String, dynamic>> getPrinterStatus() async {
    if (isMobile) {
      final connectionType = await _getPrinterConnectionType();
      if (connectionType == 'usb' && Platform.isAndroid) {
        final connected = NativeUsbPrinterService.isConnected;
        final deviceName = NativeUsbPrinterService.connectedDeviceName;
        return {
          'connected': connected,
          'printer_name': deviceName ?? 'Not connected',
          'printer_address': '',
          'platform': 'mobile',
          'connection_type': 'usb',
        };
      }
      final connected = SimpleBluetoothService.isConnected;
      final deviceName = SimpleBluetoothService.connectedDeviceName;
      return {
        'connected': connected,
        'printer_name': deviceName ?? 'Not connected',
        'printer_address': '',
        'platform': 'mobile',
        'connection_type': 'bluetooth',
      };
    } else if (isDesktop) {
      final status = await DesktopPrinterService.getPrinterStatus();
      return {...status, 'platform': 'desktop'};
    }
    return {
      'connected': false,
      'printer_name': 'Not connected',
      'platform': 'unknown',
    };
  }

  /// Get platform name
  static String get platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
