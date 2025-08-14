// lib/models/dispositivo.dart
// Represents a Bluetooth device (BLE or Classic) unified for the app

class Dispositivo {
  final String id; // BLE deviceId (MAC on Android) or Classic address
  final String name;
  final String? address; // For Classic explicitly
  final String? serviceUuid; // For BLE (UART service)
  final String? txCharacteristicUuid; // BLE TX (notify)
  final String? rxCharacteristicUuid; // BLE RX (write)
  final int? rssi;

  const Dispositivo({
    required this.id,
    required this.name,
    this.address,
    this.serviceUuid,
    this.txCharacteristicUuid,
    this.rxCharacteristicUuid,
    this.rssi,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'serviceUuid': serviceUuid,
        'txCharacteristicUuid': txCharacteristicUuid,
        'rxCharacteristicUuid': rxCharacteristicUuid,
        'rssi': rssi,
      };

  static Dispositivo fromJson(Map<String, dynamic> json) => Dispositivo(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unknown',
        address: json['address'] as String?,
        serviceUuid: json['serviceUuid'] as String?,
        txCharacteristicUuid: json['txCharacteristicUuid'] as String?,
        rxCharacteristicUuid: json['rxCharacteristicUuid'] as String?,
        rssi: json['rssi'] as int?,
      );
}
