// lib/services/transport/classic_transport_service.dart
// Bluetooth Classic transport for HC-05/HC-06 modules with PIN pairing

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_prefs.dart';
import '../../models/dispositivo.dart';
import 'transport_service.dart';

class ClassicTransportService implements TransportService {
  final StreamController<String> _rxController = StreamController.broadcast();
  classic.BluetoothConnection? _connection;
  classic.FlutterBluetoothSerial? _adapter;

  @override
  Stream<String> get onData => _rxController.stream;

  @override
  Future<void> init() async {
    if (!Platform.isAndroid) return; // iOS not supported for Classic
    _adapter = classic.FlutterBluetoothSerial.instance;
    await _adapter!.requestEnable();
  }

  @override
  Future<List<Dispositivo>> scan({Duration? timeout, int? rssiMin}) async {
    if (!Platform.isAndroid) return [];
    final bonded = await _adapter!.getBondedDevices();
    return bonded
        .map((d) => Dispositivo(id: d.address, name: d.name ?? 'HC-05', address: d.address))
        .toList();
  }

  @override
  Future<void> connect(Dispositivo device) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Classic not supported on this platform');
    }
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(AppPrefsKeys.classicPinCode) ?? '1234';

    // Try pairing if not bonded
    final bonded = await _adapter!.getBondedDevices();
    final isBonded = bonded.any((d) => d.address == device.address || d.address == device.id);
    if (!isBonded) {
      // Note: flutter_bluetooth_serial pairing API may vary; attempt to bond
      await _adapter!.bondDeviceAtAddress(device.address ?? device.id, pin: pin);
    }

    final address = device.address ?? device.id;
    final conn = await classic.BluetoothConnection.toAddress(address);
    _connection = conn;

    conn.input?.listen((Uint8List data) {
      final text = utf8.decode(data, allowMalformed: true);
      _rxController.add(text);
    }).onDone(() {
      // Remote disconnected
    });
  }

  @override
  Future<void> disconnect() async {
    await _connection?.finish();
    _connection = null;
  }

  @override
  Future<bool> isConnected() async {
    return _connection?.isConnected == true;
  }

  @override
  Future<void> send(String data) async {
    if (_connection == null) {
      throw StateError('Classic not connected');
    }
    _connection!.output.add(utf8.encode(data));
    await _connection!.output.allSent;
  }
}
