// lib/constants/ble_constants.dart
// BLE UART configuration constants (editable by user)

class BleConstants {
  // Default UART service/characteristics (Nordic UART Service as example)
  // Replace with UNO R4 BLE UART UUIDs as needed.
  static const String defaultUartServiceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String defaultUartRxCharacteristicUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // Write
  static const String defaultUartTxCharacteristicUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // Notify

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration scanTimeout = Duration(seconds: 8);

  // RSSI filter
  static const int defaultMinRssi = -85;
}
