import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth_service.dart';

const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const _firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _firebaseIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

FirebaseOptions? _buildTimeFirebaseOptions() {
  if (_firebaseApiKey.isEmpty ||
      _firebaseAppId.isEmpty ||
      _firebaseMessagingSenderId.isEmpty ||
      _firebaseProjectId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: _firebaseApiKey,
    appId: _firebaseAppId,
    messagingSenderId: _firebaseMessagingSenderId,
    projectId: _firebaseProjectId,
    iosBundleId: _firebaseIosBundleId.isEmpty ? null : _firebaseIosBundleId,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    if (Firebase.apps.isEmpty) {
      final options = _buildTimeFirebaseOptions();
      await Firebase.initializeApp(options: options);
    }
    await TimerNotificationService.instance.initializeLocalNotifications();
    if (message.notification == null) {
      await TimerNotificationService.instance.showPushNotification(message);
    }
  } catch (error, stackTrace) {
    debugPrint('No se pudo mostrar la notificación de visita: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class TimerNotificationService {
  TimerNotificationService._();

  static final instance = TimerNotificationService._();
  static const _channelId = 'visit_timer_alerts';
  static const _channelName = 'Alertas de visitas';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<int> dailyLogRefreshes = ValueNotifier(0);
  String statusMessage = 'Verificando notificaciones…';
  bool _localNotificationsInitialized = false;
  bool _firebaseListenersRegistered = false;
  bool _registrationInProgress = false;
  AuthService? _authService;

  Future<void> initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) => _notifyDailyLogRefresh(),
    );
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Avisos de seguimiento de llegadas e ingresos.',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _localNotificationsInitialized = true;
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _notifyDailyLogRefresh();
    }
  }

  Future<void> configureAndRegister(AuthService authService) async {
    if (_registrationInProgress || kIsWeb) return;
    _registrationInProgress = true;
    _authService = authService;
    try {
      final buildTimeOptions = _buildTimeFirebaseOptions();
      FirebaseOptions? serverOptions;
      try {
        serverOptions = _optionsFromConfig(
          await authService.getNotificationFirebaseConfig(),
        );
      } on AuthApiException catch (error) {
        if (buildTimeOptions == null) rethrow;
        debugPrint('Se usará la configuración Firebase de compilación: $error');
      } catch (error, stackTrace) {
        if (buildTimeOptions == null) rethrow;
        debugPrint('Se usará la configuración Firebase de compilación: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      final options = buildTimeOptions ?? serverOptions;
      if (options == null && defaultTargetPlatform != TargetPlatform.android) {
        statusMessage = 'Las alertas en primer plano están activas. Para recibir notificaciones en segundo plano, solicita la configuración Firebase al administrador y recompila con FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID y FIREBASE_PROJECT_ID.';
        return;
      }

      await initializeLocalNotifications();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _registerFirebaseListeners();
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        statusMessage = 'Notificaciones desactivadas. Activa el permiso de notificaciones para este dispositivo en Ajustes.';
        return;
      }
      final localPermission = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (localPermission == false) {
        statusMessage = 'El permiso de notificaciones está desactivado. Actívalo en Ajustes para recibir avisos.';
        return;
      }
      // The API contract stores the FCM token, not the newer Firebase installation ID.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        statusMessage = 'No se pudo obtener el token FCM. Comprueba los servicios de Google y el permiso de notificaciones.';
        return;
      }
      await authService.registerMobileNotificationToken(token);
      statusMessage = buildTimeOptions == null &&
              defaultTargetPlatform == TargetPlatform.android
          ? 'Este dispositivo está registrado mediante la configuración Firebase de Android. Las alertas en segundo plano están activas.'
          : 'Este dispositivo está registrado para recibir alertas en segundo plano.';
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((token) async {
        try {
          await _authService?.registerMobileNotificationToken(token);
        } catch (error, stackTrace) {
          debugPrint(
            'No se pudo actualizar el token de notificaciones: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      });
    } on AuthApiException catch (error) {
      statusMessage =
          'No se pudo consultar el servicio de notificaciones: ${error.message}';
    } catch (error, stackTrace) {
      statusMessage = 'No se pudieron habilitar las notificaciones. Comprueba la configuración Firebase y los permisos del dispositivo.';
      debugPrint('Error al configurar notificaciones móviles: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _registrationInProgress = false;
    }
  }

  FirebaseOptions? _optionsFromConfig(Map<String, dynamic>? config) {
    if (config == null) return null;
    return FirebaseOptions(
      apiKey: config['apiKey'] as String,
      appId: config['appId'] as String,
      messagingSenderId: config['messagingSenderId'] as String,
      projectId: config['projectId'] as String,
    );
  }

  void _registerFirebaseListeners() {
    if (_firebaseListenersRegistered) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(showPushNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _notifyDailyLogRefresh(),
    );
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _notifyDailyLogRefresh();
    });
    _firebaseListenersRegistered = true;
  }

  Future<void> showPushNotification(RemoteMessage message) async {
    try {
      await initializeLocalNotifications();
      final title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          'Seguimiento de visita';
      final person =
          message.data['personName'] ??
          message.data['visitorName'] ??
          'La visita';
      final phase = message.data['phase']?.toString();
      final body =
          message.notification?.body ??
          message.data['body']?.toString() ??
          (phase == null
              ? '$person tiene una alerta pendiente en la bitácora diaria.'
              : '$person · seguimiento de $phase vencido.');
      final payload = jsonEncode(message.data);
      await _localNotifications.show(
        message.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Avisos de seguimiento de llegadas e ingresos.',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo mostrar la notificación de visita: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _notifyDailyLogRefresh() {
    dailyLogRefreshes.value++;
  }
}
