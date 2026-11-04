# CYMEZ Recepción móvil

Aplicación móvil de Recepción creada con Flutter y conectada a la API de CYMEZ.

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
