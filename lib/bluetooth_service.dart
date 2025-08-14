// Obsoleto en v3a. Reemplazado por `services/transport/*`.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ArduinoBluetoothService {
  static final ArduinoBluetoothService _instance = ArduinoBluetoothService._internal();
  factory ArduinoBluetoothService() => _instance;
  ArduinoBluetoothService._internal();

  // Estados
  bool _isInitialized = false;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  
  // Comandos para Arduino
  static const String ledOnCommand = "LED_ON";
  static const String ledOffCommand = "LED_OFF";
  static const String statusCommand = "GET_STATUS";
  
  // Comandos de control de pines
  // Formato: DIGITAL_[PIN]_HIGH/LOW (ej: DIGITAL_2_HIGH)
  // Formato: PWM_[PIN]_[VALUE] (ej: PWM_3_128)
  // Comando de lectura: READ_DIGITAL_[PIN] (ej: READ_DIGITAL_2)
  // Comando de lectura: READ_ANALOG_[PIN] (ej: READ_ANALOG_A0)

  // Streams para notificaciones
  final StreamController<List<ScanResult>> _scanResultsController = 
      StreamController<List<ScanResult>>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();
  final StreamController<String> _messagesController = 
      StreamController<String>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  // Streams públicos
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get messagesStream => _messagesController.stream;

  /// Inicializar Bluetooth
  Future<bool> initialize() async {
    try {
      debugPrint('Inicializando Bluetooth...');

      // Verificar soporte BLE
      if (!await FlutterBluePlus.isSupported) {
        _updateStatus('BLE no soportado en este dispositivo');
        return false;
      }

      // Verificar si Bluetooth está encendido
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateStatus('Bluetooth desactivado - Por favor actívalo');
        return false;
      }

      // Solicitar permisos
      if (!await _requestPermissions()) {
        _updateStatus('Permisos BLE denegados');
        return false;
      }

      _isInitialized = true;
      _updateStatus('Bluetooth inicializado correctamente');
      debugPrint('Bluetooth inicializado exitosamente');
      return true;

    } catch (e) {
      _updateStatus('Error inicializando Bluetooth: $e');
      debugPrint('Error en initialize: $e');
      return false;
    }
  }

  /// Solicitar permisos necesarios
  Future<bool> _requestPermissions() async {
    try {
      // Solicitar permisos básicos
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Verificar permisos concedidos
      bool allGranted = permissions.values.every(
        (status) => status == PermissionStatus.granted
      );

      if (!allGranted) {
        debugPrint('Algunos permisos no fueron concedidos');
        // Intentar continuar - algunos dispositivos no requieren todos los permisos
      }

      return true; // Ser permisivo en esta fase de prueba
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      return true; // Continuar a pesar de errores
    }
  }

  /// Iniciar escaneo de dispositivos
  Future<void> startScan() async {
    if (!_isInitialized) {
      _updateStatus('Bluetooth no inicializado');
      return;
    }

    if (_isScanning) {
      debugPrint('Ya se está escaneando');
      return;
    }

    try {
      _isScanning = true;
      _scanResults.clear();
      _updateStatus('Escaneando dispositivos BLE...');

      // Iniciar escaneo
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false, // Evitar problemas de ubicación
      );

      // Escuchar resultados
      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        _scanResultsController.add(results);
        
        // Filtrar dispositivos con nombre
        final devicesWithName = results.where(
          (result) => result.device.platformName.isNotEmpty
        ).toList();
        
        debugPrint('Dispositivos encontrados: ${devicesWithName.length}');
      });

      // Auto-detener después de 10 segundos
      Timer(const Duration(seconds: 10), () {
        stopScan();
      });

    } catch (e) {
      _isScanning = false;
      _updateStatus('Error escaneando: $e');
      debugPrint('Error en startScan: $e');
    }
  }

  /// Detener escaneo
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _updateStatus('Escaneo completado - ${_scanResults.length} dispositivos');
      debugPrint('Escaneo detenido');
    } catch (e) {
      debugPrint('Error deteniendo escaneo: $e');
    }
  }

  /// Conectar a un dispositivo
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _updateStatus('Conectando a ${device.platformName.isNotEmpty ? device.platformName : "dispositivo"}...');
      
      // Conectar al dispositivo
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      _updateStatus('Conectado - Descubriendo servicios...');
      
      // Descubrir servicios
      List<BluetoothService> services = await device.discoverServices();
      debugPrint('Servicios encontrados: ${services.length}');
      
      // Buscar servicios y características compatibles
      bool foundCompatibleService = false;
      
      for (BluetoothService service in services) {
        debugPrint('Servicio: ${service.uuid}');
        
        // Revisar características de este servicio
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          debugPrint('Característica: ${characteristic.uuid} - Propiedades: ${characteristic.properties}');
          
          // Buscar característica para escribir (comandos al Arduino)
          if (characteristic.properties.write && _writeCharacteristic == null) {
            _writeCharacteristic = characteristic;
            debugPrint('Característica de escritura encontrada: ${characteristic.uuid}');
          }
          
          // Buscar característica para notificaciones (respuestas del Arduino)
          if ((characteristic.properties.notify || characteristic.properties.indicate) && _notifyCharacteristic == null) {
            _notifyCharacteristic = characteristic;
            debugPrint('Característica de notificación encontrada: ${characteristic.uuid}');
          }
        }
        
        // Si encontramos ambas características, configurar notificaciones
        if (_writeCharacteristic != null && _notifyCharacteristic != null) {
          foundCompatibleService = true;
          
          try {
            // Habilitar notificaciones
            await _notifyCharacteristic!.setNotifyValue(true);
            debugPrint('Notificaciones habilitadas');
            
            // Escuchar notificaciones del Arduino
            _notifyCharacteristic!.lastValueStream.listen((data) {
              if (data.isNotEmpty) {
                String message = String.fromCharCodes(data);
                debugPrint('Mensaje recibido del Arduino: $message');
                _messagesController.add(message);
              }
            });
            
          } catch (e) {
            debugPrint('Error configurando notificaciones: $e');
          }
          
          break;
        }
      }
      
      if (foundCompatibleService) {
        _updateStatus('Conectado y listo para comandos');
        
        // Enviar comando de estado inicial
        await Future.delayed(Duration(seconds: 1));
        await sendCommand(statusCommand);
        
        return true;
      } else {
        _updateStatus('Dispositivo conectado pero sin servicios compatibles');
        return false;
      }

    } catch (e) {
      _updateStatus('Error conectando: $e');
      debugPrint('Error en connectToDevice: $e');
      return false;
    }
  }

  /// Desconectar dispositivo actual
  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _updateStatus('Desconectado');
      debugPrint('Dispositivo desconectado');
    } catch (e) {
      debugPrint('Error desconectando: $e');
    }
  }

  /// Enviar comando al Arduino
  Future<bool> sendCommand(String command) async {
    if (_connectedDevice == null || _writeCharacteristic == null) {
      debugPrint('No hay dispositivo conectado o característica no disponible');
      _updateStatus('Error: dispositivo no conectado');
      return false;
    }

    try {
      List<int> data = command.codeUnits;
      await _writeCharacteristic!.write(data, withoutResponse: false);
      
      debugPrint('Comando enviado: $command');
      _updateStatus('Comando "$command" enviado');
      return true;
      
    } catch (e) {
      debugPrint('Error enviando comando: $e');
      _updateStatus('Error enviando comando: $e');
      return false;
    }
  }

  /// Encender LED del Arduino
  Future<bool> turnOnLed() async {
    return await sendCommand(ledOnCommand);
  }

  /// Apagar LED del Arduino
  Future<bool> turnOffLed() async {
    return await sendCommand(ledOffCommand);
  }

  /// Solicitar estado del Arduino
  Future<bool> getStatus() async {
    return await sendCommand(statusCommand);
  }

  /// ===== MÉTODOS DE CONTROL DE PINES =====
  
  /// Controlar pin digital
  Future<bool> setDigitalPin(int pin, bool state) async {
    String command = state ? 'DIGITAL_${pin}_HIGH' : 'DIGITAL_${pin}_LOW';
    return await sendCommand(command);
  }
  
  /// Controlar pin PWM
  Future<bool> setPwmPin(int pin, int value) async {
    String command = 'PWM_${pin}_$value';
    return await sendCommand(command);
  }
  
  /// Leer estado de pin digital
  Future<bool> readDigitalPin(int pin) async {
    String command = 'READ_DIGITAL_$pin';
    return await sendCommand(command);
  }
  
  /// Leer valor de pin analógico
  Future<bool> readAnalogPin(String pin) async {
    String command = 'READ_ANALOG_$pin';
    return await sendCommand(command);
  }
  
  /// Leer todos los pines digitales
  Future<bool> readAllDigitalPins() async {
    return await sendCommand('READ_ALL_DIGITAL');
  }
  
  /// Leer todos los pines analógicos
  Future<bool> readAllAnalogPins() async {
    return await sendCommand('READ_ALL_ANALOG');
  }

  /// Actualizar estado
  void _updateStatus(String status) {
    _statusController.add(status);
    debugPrint('Estado BLE: $status');
  }

  /// Limpiar recursos
  void dispose() {
    stopScan();
    disconnect();
    _scanResultsController.close();
    _statusController.close();
    _messagesController.close();
  }
}