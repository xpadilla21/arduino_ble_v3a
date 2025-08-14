// lib/services/transport/transport_service.dart
// Unified transport interface for BLE and Bluetooth Classic (HC-05)

import 'dart:async';
import '../../models/dispositivo.dart';

abstract class TransportService {
  Future<void> init();
  Stream<String> get onData; // RX textual (UTF-8 decoded)
  Future<void> send(String data); // TX textual
  Future<void> connect(Dispositivo device); // includes pairing if needed
  Future<void> disconnect();
  Future<bool> isConnected();
  Future<List<Dispositivo>> scan({Duration? timeout, int? rssiMin});
}
