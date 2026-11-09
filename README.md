# CYMEZ Recepción móvil

Aplicación móvil de Recepción creada con Flutter y conectada a la API de CYMEZ.

Las solicitudes de la aplicación usan `/api/v1`. El backend conserva las rutas
sin versión para mantener compatibilidad con instalaciones anteriores.

## Release Android

El APK de distribución se firma con una clave local persistente. El archivo
`android/key.properties` contiene credenciales y está excluido de Git; el
keystore se guarda fuera del repositorio en `%USERPROFILE%\.android\visitas-recep`.
No compartas ni subas ninguno de esos archivos. Respalda el keystore y sus
credenciales en un lugar seguro: se necesitan para firmar todas las
actualizaciones futuras.

Genera el APK con `flutter build apk --release`. Antes de desplegar la web, copia
`build\app\outputs\flutter-apk\app-release.apk` a
`frontend\public\downloads\recep-movil.apk` para publicarlo desde el enlace del
login.

## Requisitos

- Flutter estable y Dart incluidos en el SDK de Flutter
- Android Studio o Xcode para ejecutar en un dispositivo o emulador

## Ejecutar

Desde esta carpeta:

```powershell
flutter pub get
flutter run
```

Para probar la versión web en Edge:

```powershell
flutter run -d web-server --web-port 59459
```

La API debe incluir `http://localhost:59459` en `CORS_ALLOWED_ORIGINS`.
Abre en Edge la URL que muestra la terminal; el puerto fijo permite que la
cookie de sesión se comparta con la API autorizada.

## Validar

```powershell
flutter analyze
flutter test
```
