# v3a Migración y Uso

## Resumen
- UI tipo panel Arduino (D13..D02), bloque SEND/GET, 4 sliders (11/10/09/06), consola serial.
- Transporte unificado con modo BLE y Classic (HC-05, Android-only).
- Protocolo textual ArduDroid: `*<cmd>|<pin>|<value>#`.

## Instalación
1. Flutter 3.32.7 / Dart 3.8.1.
2. `flutter pub get`.
3. Android: aceptar permisos Bluetooth/ubicación. iOS: solo BLE.

## Configuración
- UUIDs BLE en `lib/constants/ble_constants.dart` o desde preferencias.
- Modo transporte y último dispositivo se guardan en `SharedPreferences`.
- PIN Classic por defecto `1234` (clave `classic_pin_code`).

## Protocolo
- 10 DIGITALWRITE: value 2=LOW, 3=HIGH.
- 11 ANALOGWRITE: 0–255.
- 12 TEXT: payload libre.
- 13 READ: diagnóstico.

## Uso
- Escanear, conectar, usar pulsadores D13..D02, sliders PWM, consola.
- GET DATA muestra última línea RX.

## iOS
- Classic no soportado. Solo BLE.
- Añadir claves BLE en `Info.plist`.

## Troubleshooting
- No conecta BLE: revisar UUIDs, distancia, reiniciar periférico.
- Classic: emparejar con PIN visible en Android antes de conectar.
- Timeouts y RSSI configurables en preferencias.

## Límites
- Consola guarda últimas ~400 líneas.
- UART BLE MTU/packet <= 128 bytes.

## Comandos rápidos
- D8 down: `*10|8|3#`, up: `*10|8|2#`
- PWM 11 a 180: `*11|11|180#`
- READ: `*13|0|0#`
