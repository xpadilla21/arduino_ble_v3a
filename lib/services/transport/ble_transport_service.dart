// lib/services/transport/ble_transport_service.dart
// BLE transport implementing UART over GATT with configurable UUIDs

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/ble_constants.dart';
import '../../constants/app_prefs.dart';
import '../../models/dispositivo.dart';
import 'transport_service.dart';

class BleTransportService implements TransportService {
  final StreamController<String> _rxController = StreamController.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar; // write
  BluetoothCharacteristic? _txChar; // notify
  StreamSubscription<List<int>>? _notifySub;

  @override
  Stream<String> get onData => _rxController.stream;

  @override
  Future<void> init() async {
    // Permissions
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  Future<List<Dispositivo>> scan({Duration? timeout, int? rssiMin}) async {
    final prefs = await SharedPreferences.getInstance();
    final int minRssi = rssiMin ?? prefs.getInt(AppPrefsKeys.minRssi) ?? BleConstants.defaultMinRssi;
    final Duration scanTimeout = timeout ?? (prefs.getInt(AppPrefsKeys.scanTimeoutMs) != null
        ? Duration(milliseconds: prefs.getInt(AppPrefsKeys.scanTimeoutMs)!)
        : BleConstants.scanTimeout);

    if (!await FlutterBluePlus.isSupported) return [];
    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) return [];

    await FlutterBluePlus.startScan(timeout: scanTimeout);
    final results = await FlutterBluePlus.scanResults.firstWhere((_) => true);
    await FlutterBluePlus.stopScan();

    final dispositivos = <Dispositivo>[];
    for (final r in results) {
      if (r.rssi < minRssi) continue;
      final id = r.device.remoteId.str;
      final name = r.device.platformName.isNotEmpty ? r.device.platformName : 'BLE $id';
      dispositivos.add(Dispositivo(
        id: id,
        name: name,
        rssi: r.rssi,
      ));
    }
    return dispositivos;
  }

  @override
  Future<void> connect(Dispositivo device) async {
    // Resolve UUIDs
    final prefs = await SharedPreferences.getInstance();
    final serviceUuid = prefs.getString(AppPrefsKeys.bleServiceUuid) ?? BleConstants.defaultUartServiceUuid;
    final rxUuid = prefs.getString(AppPrefsKeys.bleRxCharUuid) ?? BleConstants.defaultUartRxCharacteristicUuid;
    final txUuid = prefs.getString(AppPrefsKeys.bleTxCharUuid) ?? BleConstants.defaultUartTxCharacteristicUuid;

    final target = BluetoothDevice.fromId(device.id);
    await target.connect(timeout: BleConstants.connectTimeout);
    _device = target;

    final services = await target.discoverServices();
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;

    for (final s in services) {
      if (s.uuid.str.toLowerCase() == serviceUuid.toLowerCase()) {
        for (final c in s.characteristics) {
          final cuuid = c.uuid.str.toLowerCase();
          if (cuuid == rxUuid.toLowerCase() && c.properties.write) {
            rx = c;
          }
          if (cuuid == txUuid.toLowerCase() && (c.properties.notify || c.properties.indicate)) {
            tx = c;
          }
        }
      }
    }

    // Fallback: accept first write/notify if not explicitly matched
    rx ??= services.expand((s) => s.characteristics).firstWhere(
      (c) => c.properties.write,
      orElse: () => throw Exception('BLE RX characteristic not found'),
    );
    tx ??= services.expand((s) => s.characteristics).firstWhere(
      (c) => c.properties.notify || c.properties.indicate,
      orElse: () => throw Exception('BLE TX characteristic not found'),
    );

    _rxChar = rx;
    _txChar = tx;

    await _txChar!.setNotifyValue(true);
    _notifySub?.cancel();
    _notifySub = _txChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      final text = utf8.decode(data, allowMalformed: true);
      _rxController.add(text);
    });
  }

  @override
  Future<void> disconnect() async {
    _notifySub?.cancel();
    _notifySub = null;
    _rxChar = null;
    _txChar = null;
    if (_device != null) {
      await _device!.disconnect();
      _device = null;
    }
  }

  @override
  Future<bool> isConnected() async {
    return _device != null;
  }

  @override
  Future<void> send(String data) async {
    if (_rxChar == null) {
      throw StateError('BLE not connected');
    }
    final bytes = utf8.encode(data);
    await _rxChar!.write(bytes, withoutResponse: false);
  }
}
