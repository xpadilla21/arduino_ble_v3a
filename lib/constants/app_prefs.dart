// lib/constants/app_prefs.dart
// Keys and defaults for SharedPreferences

class AppPrefsKeys {
  static const String transportMode = 'transport_mode'; // 'ble' | 'classic'
  static const String lastDeviceJson = 'last_device_json';
  static const String bleServiceUuid = 'ble_service_uuid';
  static const String bleRxCharUuid = 'ble_rx_uuid';
  static const String bleTxCharUuid = 'ble_tx_uuid';
  static const String minRssi = 'min_rssi';
  static const String connectTimeoutMs = 'connect_timeout_ms';
  static const String scanTimeoutMs = 'scan_timeout_ms';
  static const String classicPinCode = 'classic_pin_code'; // '1234' | '0000'
}
