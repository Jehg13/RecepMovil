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

## Notificaciones de temporizadores

Las alertas de la bitácora se sincronizan con el servidor. La app muestra y hace
sonar las alertas vencidas mientras está abierta; las notificaciones cuando la
app está en segundo plano requieren un proyecto Firebase Cloud Messaging
configurado y los mensajes push de temporizadores del backend.

En Android, coloca el archivo `google-services.json` de la app dentro de
`android/app/google-services.json`. El proyecto aplica el plugin de Google
Services para generar la configuración nativa que FCM necesita, también cuando
la app se inicia en segundo plano. El endpoint autenticado de recepción
`GET /api/notifications/config` proporciona los datos públicos de Firebase para
registrar el token; al cerrar sesión, la app intenta retirar ese token sin
retrasar el cierre si falla la solicitud.

```powershell
flutter build apk --release
```

No agregues la clave privada de Firebase Admin SDK a la app. En iOS, añade
`--dart-define=FIREBASE_IOS_BUNDLE_ID=<bundle-id>`, configura APNs en Firebase
y habilita Remote Notifications en la firma/capabilities de la aplicación.
Android e iOS solicitarán el permiso de notificaciones. El archivo de
configuración Android contiene identificadores de cliente, no la clave privada
Admin; aun así, mantenlo asociado únicamente a este proyecto. Sin configuración
Firebase, la app mantiene las alertas sonoras en primer plano y muestra el
estado de configuración; no afirma que las notificaciones en segundo plano
estén activas.

## Validar

```powershell
flutter analyze
flutter test
```
