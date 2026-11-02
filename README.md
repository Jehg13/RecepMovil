# CYMEZ Recepción móvil

Aplicación móvil de Recepción creada con Flutter. El proyecto inicial incluye
una pantalla de bienvenida con la identidad visual de CYMEZ; los flujos de
recepción y la conexión con la API se incorporarán después.

## Requisitos

- Flutter estable y Dart incluidos en el SDK de Flutter
- Android Studio o Xcode para ejecutar en un dispositivo o emulador

## Ejecutar

Desde esta carpeta:

```powershell
flutter pub get
flutter run
```

Para probar la versión web en Edge con el renderizador WebAssembly de Flutter:

```powershell
flutter run -d web-server --release --wasm
```

Abre en Edge la URL que muestra la terminal. Este modo evita el costo adicional
del modo debug y usa Skwasm cuando el navegador es compatible.

## Validar

```powershell
flutter analyze
flutter test
```
