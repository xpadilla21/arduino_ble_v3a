# Arduino Controller v3a (BLE + HC-05)

## Build APK

1) Instala Flutter (canal estable) y Android SDK 35.
2) En la raíz del proyecto:

```bash
flutter pub get
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

Permisos: al abrir, concede Bluetooth/ubicación cuando se solicite.
