// lib/providers/app_state.dart
// App state with unified TransportService (BLE or Classic) and v3a UI state

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_prefs.dart';
import '../constants/ble_constants.dart';
import '../models/dispositivo.dart';
import '../services/transport/transport_service.dart';
import '../services/transport/ble_transport_service.dart';
import '../services/transport/classic_transport_service.dart';

enum TransportMode { ble, classic }

class AppState extends ChangeNotifier {
  // Active transport
  late TransportMode _mode;
  late TransportService _transport;

  // Connection/device
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  List<Dispositivo> _scanResults = [];
  Dispositivo? _lastDevice;

  // UI state
  final List<String> _console = [];
  String _status = 'Inicializando...';
  String _lastRxLine = '';

  // Pins state
  final Map<int, bool> _digitalPinStates = {for (var p in [13,12,11,10,9,8,7,6,5,4,3,2]) p: false};
  final Map<int, int> _pwmPinValues = {11: 0, 10: 0, 9: 0, 6: 0};

  // Subscriptions
  StreamSubscription<String>? _rxSub;

  AppState() {
    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(AppPrefsKeys.transportMode);
    _mode = savedMode == 'classic' ? TransportMode.classic : TransportMode.ble;
    _transport = _mode == TransportMode.ble ? BleTransportService() : ClassicTransportService();

    await _transport.init();
    _rxSub = _transport.onData.listen((data) {
      for (final line in _splitLines(data)) {
        _lastRxLine = line;
        _appendConsole('RX', line);
      }
      notifyListeners();
    });

    _isInitialized = true;
    _status = 'Listo';
    notifyListeners();

    // Auto-restore last device
    final jsonStr = prefs.getString(AppPrefsKeys.lastDeviceJson);
    if (jsonStr != null) {
      try {
        final d = Dispositivo.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
        _lastDevice = d;
      } catch (_) {}
    }
  }

  // Getters
  TransportMode get mode => _mode;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String get status => _status;
  List<Dispositivo> get scanResults => List.unmodifiable(_scanResults);
  List<String> get console => List.unmodifiable(_console);
  String get lastRxLine => _lastRxLine;
  bool get isBleMode => _mode == TransportMode.ble;

  // Mode switching
  Future<void> setMode(TransportMode newMode) async {
    if (_mode == newMode) return;
    await disconnect();
    _mode = newMode;
    _transport = _mode == TransportMode.ble ? BleTransportService() : ClassicTransportService();
    await _transport.init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPrefsKeys.transportMode, _mode.name);
    _status = 'Modo ${_mode.name.toUpperCase()} activo';
    notifyListeners();
  }

  // Scan/connect
  Future<void> scan({Duration? timeout, int? rssiMin}) async {
    _isScanning = true;
    notifyListeners();
    try {
      _scanResults = await _transport.scan(
        timeout: timeout ?? BleConstants.scanTimeout,
        rssiMin: rssiMin,
      );
    } catch (e) {
      _appendConsole('ERROR', 'Scan: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(Dispositivo d) async {
    try {
      _status = 'Conectando a ${d.name}...';
      notifyListeners();
      await _transport.connect(d);
      _isConnected = await _transport.isConnected();
      if (_isConnected) {
        _status = 'Conectado a ${d.name}';
        _lastDevice = d;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppPrefsKeys.lastDeviceJson, json.encode(d.toJson()));
      } else {
        _status = 'Fallo de conexión';
      }
    } catch (e) {
      _status = 'Error conectando: $e';
      _appendConsole('ERROR', 'Connect: $e');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } catch (_) {}
    _isConnected = false;
    _status = 'Desconectado';
    notifyListeners();
  }

  // Console
  Future<void> sendText(String text) async {
    if (!_isConnected) {
      _appendConsole('ERROR', 'No conectado');
      return;
    }
    final payload = _buildTextCommand(text);
    _appendConsole('TX', payload);
    await _transport.send(payload);
  }

  void clearConsole() {
    _console.clear();
    notifyListeners();
  }

  // Panel actions mapping to protocol
  Future<void> digitalMomentary(int pin, bool pressed) async {
    if (!_isConnected) return;
    _digitalPinStates[pin] = pressed;
    notifyListeners();
    final payload = _buildDigitalWrite(pin, pressed ? 3 : 2);
    _appendConsole('TX', payload);
    await _transport.send(payload);
  }

  Future<void> setAnalogWrite(int pin, int value) async {
    if (!_isConnected) return;
    _pwmPinValues[pin] = value.clamp(0, 255);
    notifyListeners();
    final payload = _buildAnalogWrite(pin, _pwmPinValues[pin]!);
    _appendConsole('TX', payload);
    await _transport.send(payload);
  }

  Future<void> requestRead() async {
    if (!_isConnected) return;
    final payload = _buildReadCommand();
    _appendConsole('TX', payload);
    await _transport.send(payload);
  }

  // Getters for pins
  bool getDigitalState(int pin) => _digitalPinStates[pin] ?? false;
  int getPwmValue(int pin) => _pwmPinValues[pin] ?? 0;

  // Protocol builders (ArduDroid-compatible)
  String _buildDigitalWrite(int pin, int valueCode) => '*10|$pin|$valueCode#';
  String _buildAnalogWrite(int pin, int value) => '*11|$pin|$value#';
  String _buildTextCommand(String text) => '*12|0|${text.replaceAll('#', '')}#';
  String _buildReadCommand() => '*13|0|0#';

  // Helpers
  Iterable<String> _splitLines(String raw) sync* {
    // Split by \n or # as end markers
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '\n' || ch == '#') {
        final line = buffer.toString().trim();
        buffer.clear();
        if (line.isNotEmpty) yield line;
      } else if (ch != '\r') {
        buffer.write(ch);
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) yield tail;
  }

  void _appendConsole(String kind, String text) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _console.add('[$ts] $kind: $text');
    if (_console.length > 400) {
      _console.removeRange(0, _console.length - 400);
    }
  }

  @override
  void dispose() {
    _rxSub?.cancel();
    super.dispose();
  }
}
