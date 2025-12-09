import 'dart:io';
import 'simple_bluetooth_service.dart';
import 'desktop_printer_service.dart';

/// Platform-aware printer service
/// Automatically uses Bluetooth on mobile or USB on desktop
class PlatformPrinterService {
  /// Check if we're on a mobile platform
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Check if we're on a desktop platform
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Get available printers (platform-specific)
  static Future<List<dynamic>> getAvailablePrinters() async {
    if (isMobile) {
      // Return Bluetooth devices on mobile
      try {
        final devices = await SimpleBluetoothService.startDiscovery();
        return devices;
      } catch (e) {
        print('Error scanning Bluetooth devices: $e');
        return [];
      }
    } else if (isDesktop) {
      // Return system printers on desktop
      return await DesktopPrinterService.getAvailablePrinters();
    }
    return [];
  }

  /// Connect to printer (platform-specific)
  static Future<bool> connect(dynamic printer) async {
    if (isMobile) {
      // Connect to Bluetooth device
      return await SimpleBluetoothService.connect(printer);
    } else if (isDesktop) {
      // Save system printer
      return await DesktopPrinterService.savePrinter(printer);
    }
    return false;
  }

  /// Auto-connect to saved printer
  static Future<bool> autoConnect() async {
    if (isMobile) {
      return await SimpleBluetoothService.autoConnect();
    } else if (isDesktop) {
      return await DesktopPrinterService.autoConnect();
    }
    return false;
  }

  /// Check if printer is connected
  static Future<bool> isConnected() async {
    if (isMobile) {
      return SimpleBluetoothService.isConnected();
    } else if (isDesktop) {
      return await DesktopPrinterService.isConnected();
    }
    return false;
  }

  /// Print text (platform-specific)
  static Future<bool> printText(String text) async {
    if (isMobile) {
      return await SimpleBluetoothService.print(text);
    } else if (isDesktop) {
      return await DesktopPrinterService.printText(text);
    }
    return false;
  }

  /// Print test page
  static Future<bool> printTest() async {
    if (isMobile) {
      return await SimpleBluetoothService.printTest();
    } else if (isDesktop) {
      return await DesktopPrinterService.printTest();
    }
    return false;
  }

  /// Disconnect printer
  static Future<void> disconnect() async {
    if (isMobile) {
      await SimpleBluetoothService.disconnect();
    } else if (isDesktop) {
      await DesktopPrinterService.disconnect();
    }
  }

  /// Get printer status
  static Future<Map<String, dynamic>> getPrinterStatus() async {
    if (isMobile) {
      final connected = SimpleBluetoothService.isConnected();
      final device = SimpleBluetoothService.connectedDevice;
      return {
        'connected': connected,
        'printer_name': device?.name ?? 'Not connected',
        'printer_address': device?.address ?? '',
        'platform': 'mobile',
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
