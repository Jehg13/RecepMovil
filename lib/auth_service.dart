import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'src/web_http_client_stub.dart'
    if (dart.library.js_interop) 'src/web_http_client.dart';
import 'src/web_realtime_client_stub.dart'
    if (dart.library.js_interop) 'src/web_realtime_client.dart';

const _sessionCookieName = 'visitas_session';
const _sessionCookieStorageKey = 'reception_session_cookie';
const _tabletDeviceStorageKey = 'reception_tablet_device';
const _mobileOnboardingStorageKey = 'reception_mobile_onboarding_seen';
const _walkInDraftStorageKey = 'reception_walk_in_draft';
const _requestTimeout = Duration(seconds: 15);

abstract interface class MobileOnboardingStorage {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();
}

class SecureMobileOnboardingStorage implements MobileOnboardingStorage {
  SecureMobileOnboardingStorage({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasSeenOnboarding() async =>
      await _storage.read(key: _mobileOnboardingStorageKey) == 'true';

  @override
  Future<void> markOnboardingSeen() =>
      _storage.write(key: _mobileOnboardingStorageKey, value: 'true');
}

abstract interface class VisitorKioskDraftStorage {
  Future<Map<String, dynamic>?> readDraft();
  Future<void> saveDraft(Map<String, dynamic> draft);
  Future<void> clearDraft();
}

class SecureVisitorKioskDraftStorage implements VisitorKioskDraftStorage {
  SecureVisitorKioskDraftStorage({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  @override
  Future<Map<String, dynamic>?> readDraft() async {
    final value = await storage.read(key: _walkInDraftStorageKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthApiException('El avance del registro no es válido.');
    }
    return decoded;
  }

  @override
  Future<void> saveDraft(Map<String, dynamic> draft) =>
      storage.write(key: _walkInDraftStorageKey, value: jsonEncode(draft));

  @override
  Future<void> clearDraft() => storage.delete(key: _walkInDraftStorageKey);
}

class TabletDeviceLink {
  const TabletDeviceLink({
    required this.token,
    required this.companyId,
    required this.companyName,
    required this.deviceId,
    required this.deviceName,
  });

  final String token;
  final int companyId;
  final String companyName;
  final int deviceId;
  final String deviceName;

  factory TabletDeviceLink.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['token'] is! String ||
        (value['token'] as String).isEmpty ||
        value['companyId'] is! int ||
        (value['companyId'] as int) <= 0 ||
        value['companyName'] is! String ||
        value['deviceId'] is! int ||
        (value['deviceId'] as int) <= 0) {
      throw const AuthApiException(
        'La vinculación guardada de esta tablet no es válida.',
      );
    }
    return TabletDeviceLink(
      token: value['token'] as String,
      companyId: value['companyId'] as int,
      companyName: value['companyName'] as String,
      deviceId: value['deviceId'] as int,
      deviceName:
          value['deviceName'] is String &&
              (value['deviceName'] as String).trim().isNotEmpty
          ? (value['deviceName'] as String).trim()
          : 'Tablet de visitas sin cita',
    );
  }
}

abstract interface class TabletDeviceStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureTabletDeviceStorage implements TabletDeviceStorage {
  SecureTabletDeviceStorage({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  @override
  Future<String?> read() => storage.read(key: _tabletDeviceStorageKey);

  @override
  Future<void> write(String value) =>
      storage.write(key: _tabletDeviceStorageKey, value: value);
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.login,
    required this.name,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.sectionAccess,
    this.isCompanyAdmin = false,
    this.companyId,
    this.companyRole,
    this.mustChangePassword = false,
  });

  final String login;
  final String? name;
  final String? email;
  final String? role;
  final bool isAdmin;
  final List<String> sectionAccess;
  final bool isCompanyAdmin;
  final int? companyId;
  final String? companyRole;
  final bool mustChangePassword;

  bool get canAccessReception => isAdmin || sectionAccess.contains('recepcion');

  bool get canAccessApp =>
      canAccessReception ||
      isCompanyAdmin ||
      sectionAccess.contains('anfitriones');

  factory AuthenticatedUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['login'] is! String ||
        value['isAdmin'] is! bool ||
        value['sectionAccess'] is! List ||
        (value['isCompanyAdmin'] != null && value['isCompanyAdmin'] is! bool) ||
        (value['companyId'] != null && value['companyId'] is! num) ||
        (value['companyRole'] != null && value['companyRole'] is! String) ||
        (value['mustChangePassword'] != null &&
            value['mustChangePassword'] is! bool) ||
        (value['name'] != null && value['name'] is! String) ||
        (value['email'] != null && value['email'] is! String) ||
        (value['role'] != null && value['role'] is! String)) {
      throw const AuthApiException('La respuesta del servidor no es válida.');
    }

    final sectionAccess = value['sectionAccess'];
    if (sectionAccess.any((section) => section is! String)) {
      throw const AuthApiException('La respuesta del servidor no es válida.');
    }

    return AuthenticatedUser(
      login: value['login'] as String,
      name: value['name'] as String?,
      email: value['email'] as String?,
      role: value['role'] as String?,
      isAdmin: value['isAdmin'] as bool,
      sectionAccess: List<String>.unmodifiable(sectionAccess.cast<String>()),
      isCompanyAdmin: value['isCompanyAdmin'] as bool? ?? false,
      companyId: (value['companyId'] as num?)?.toInt(),
      companyRole: value['companyRole'] as String?,
      mustChangePassword: value['mustChangePassword'] as bool? ?? false,
    );
  }
}

class MobileAppUpdate {
  const MobileAppUpdate({
    required this.version,
    required this.build,
    required this.installedBuild,
    required this.notes,
    required this.downloadUrl,
  });

  final String version;
  final int build;
  final int installedBuild;
  final String notes;
  final Uri downloadUrl;
}

class AccessAccount {
  const AccessAccount({
    required this.login,
    required this.name,
    required this.email,
    required this.active,
    required this.role,
    required this.phone,
    required this.sectionAccess,
  });

  final String login;
  final String? name;
  final String? email;
  final String? active;
  final String? role;
  final String? phone;
  final List<String> sectionAccess;

  bool get isActive => active == 'Y' || active == '1';

  String get accessLabel => sectionAccess.contains('administrador')
      ? 'Administrador'
      : sectionAccess.contains('recepcion')
      ? 'Recepción'
      : sectionAccess.contains('anfitriones')
      ? 'Anfitrión'
      : 'Sin acceso';

  factory AccessAccount.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['login'] is! String ||
        value['sectionAccess'] is! List ||
        (value['name'] != null && value['name'] is! String) ||
        (value['email'] != null && value['email'] is! String) ||
        (value['active'] != null && value['active'] is! String) ||
        (value['role'] != null && value['role'] is! String) ||
        (value['phone'] != null && value['phone'] is! String)) {
      throw const AuthApiException('La respuesta de cuentas no es válida.');
    }

    final sections = value['sectionAccess'] as List;
    if (sections.any(
      (section) =>
          section is! String ||
          !const {
            'recepcion',
            'anfitriones',
            'administrador',
          }.contains(section),
    )) {
      throw const AuthApiException('La respuesta de cuentas no es válida.');
    }

    return AccessAccount(
      login: value['login'] as String,
      name: value['name'] as String?,
      email: value['email'] as String?,
      active: value['active'] as String?,
      role: value['role'] as String?,
      phone: value['phone'] as String?,
      sectionAccess: List<String>.unmodifiable(sections.cast<String>()),
    );
  }
}

class Department {
  const Department({
    required this.id,
    required this.name,
    this.hostCount = 0,
    this.companyId,
  });

  final int id;
  final String name;
  final int hostCount;
  final int? companyId;

  factory Department.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! num ||
        value['name'] is! String ||
        (value['companyId'] != null && value['companyId'] is! num) ||
        (value['hostCount'] != null &&
            (value['hostCount'] is! num || (value['hostCount'] as num) < 0))) {
      throw const AuthApiException(
        'La respuesta de departamentos no es válida.',
      );
    }
    return Department(
      id: (value['id'] as num).toInt(),
      name: value['name'] as String,
      hostCount: (value['hostCount'] as num?)?.toInt() ?? 0,
      companyId: (value['companyId'] as num?)?.toInt(),
    );
  }
}

class DepartmentHost {
  const DepartmentHost({
    required this.id,
    required this.login,
    required this.name,
    required this.departmentId,
    required this.role,
    required this.email,
    required this.phone,
    this.accessRoles = const [],
  });

  final int id;
  final String login;
  final String name;
  final int departmentId;
  final String role;
  final String email;
  final String phone;
  final List<String> accessRoles;

  factory DepartmentHost.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! num ||
        value['login'] is! String ||
        value['name'] is! String ||
        value['departmentId'] is! num ||
        value['role'] is! String ||
        value['email'] is! String ||
        value['phone'] is! String ||
        (value['accessRoles'] != null && value['accessRoles'] is! List)) {
      throw const AuthApiException('La respuesta de anfitriones no es válida.');
    }

    final accessRoles = value['accessRoles'] as List? ?? const [];
    if (accessRoles.any(
      (role) =>
          role is! String ||
          !const {'Administrador', 'Recepción', 'Anfitriones'}.contains(role),
    )) {
      throw const AuthApiException('La respuesta de anfitriones no es válida.');
    }

    return DepartmentHost(
      id: (value['id'] as num).toInt(),
      login: value['login'] as String,
      name: value['name'] as String,
      departmentId: (value['departmentId'] as num).toInt(),
      role: value['role'] as String,
      email: value['email'] as String,
      phone: value['phone'] as String,
      accessRoles: List<String>.unmodifiable(accessRoles.cast<String>()),
    );
  }
}

class HostAccountOption {
  const HostAccountOption({
    required this.login,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
  });

  final String login;
  final String? name;
  final String? email;
  final String? role;
  final String? phone;

  factory HostAccountOption.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['login'] is! String ||
        (value['name'] != null && value['name'] is! String) ||
        (value['email'] != null && value['email'] is! String) ||
        (value['role'] != null && value['role'] is! String) ||
        (value['phone'] != null && value['phone'] is! String)) {
      throw const AuthApiException(
        'La respuesta de cuentas disponibles no es válida.',
      );
    }
    return HostAccountOption(
      login: value['login'] as String,
      name: value['name'] as String?,
      email: value['email'] as String?,
      role: value['role'] as String?,
      phone: value['phone'] as String?,
    );
  }
}

class DashboardAppointment {
  const DashboardAppointment({
    required this.id,
    required this.date,
    required this.time,
    required this.visitor,
    required this.company,
    required this.host,
    required this.status,
    required this.equipmentChecklistRequired,
  });

  final int id;
  final String date;
  final String time;
  final String visitor;
  final String company;
  final String host;
  final String status;
  final bool equipmentChecklistRequired;

  factory DashboardAppointment.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! num ||
        value['date'] is! String ||
        value['time'] is! String ||
        value['visitor'] is! String ||
        value['company'] is! String ||
        value['host'] is! String ||
        value['status'] is! String ||
        value['equipmentChecklistRequired'] is! bool) {
      throw const AuthApiException('La respuesta de citas no es válida.');
    }
    return DashboardAppointment(
      id: (value['id'] as num).toInt(),
      date: value['date'] as String,
      time: value['time'] as String,
      visitor: value['visitor'] as String,
      company: value['company'] as String,
      host: value['host'] as String,
      status: value['status'] as String,
      equipmentChecklistRequired: value['equipmentChecklistRequired'] as bool,
    );
  }
}

class DashboardLogEntry {
  const DashboardLogEntry({
    required this.date,
    required this.time,
    required this.event,
    required this.person,
    required this.details,
    required this.company,
  });

  final String date;
  final String time;
  final String event;
  final String person;
  final String details;
  final String company;

  factory DashboardLogEntry.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['date'] is! String ||
        value['time'] is! String ||
        value['event'] is! String ||
        value['person'] is! String ||
        (value['details'] != null && value['details'] is! String) ||
        (value['company'] != null && value['company'] is! String)) {
      throw const AuthApiException('La respuesta de bitácora no es válida.');
    }
    return DashboardLogEntry(
      date: value['date'] as String,
      time: value['time'] as String,
      event: value['event'] as String,
      person: value['person'] as String,
      details: value['details'] as String? ?? '',
      company: value['company'] as String? ?? '',
    );
  }
}

class DashboardDailyActivity {
  const DashboardDailyActivity({
    required this.date,
    required this.arrivals,
    required this.entries,
    required this.exits,
    required this.observations,
  });

  final String date;
  final int arrivals;
  final int entries;
  final int exits;
  final int observations;

  factory DashboardDailyActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['date'] is! String ||
        DateTime.tryParse(value['date'] as String) == null ||
        value['arrivals'] is! num ||
        value['entries'] is! num ||
        value['exits'] is! num ||
        value['observations'] is! num) {
      throw const AuthApiException(
        'La respuesta de estadísticas de Inicio no es válida.',
      );
    }
    return DashboardDailyActivity(
      date: value['date'] as String,
      arrivals: (value['arrivals'] as num).toInt(),
      entries: (value['entries'] as num).toInt(),
      exits: (value['exits'] as num).toInt(),
      observations: (value['observations'] as num).toInt(),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.appointments,
    required this.insideNow,
    required this.pendingArrivals,
    required this.recentEntries,
    required this.dailyActivity,
  });

  final List<DashboardAppointment> appointments;
  final int insideNow;
  final int pendingArrivals;
  final List<DashboardLogEntry> recentEntries;
  final List<DashboardDailyActivity> dailyActivity;
}

class AuthApiException implements Exception {
  const AuthApiException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
  });

  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

enum RealtimeEvent { connected, update, disconnected }

abstract interface class SessionCookieStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionCookieStorage implements SessionCookieStorage {
  SecureSessionCookieStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _sessionCookieStorageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _sessionCookieStorageKey, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _sessionCookieStorageKey);
}

class EquipmentDeclarationsPage {
  const EquipmentDeclarationsPage({
    required this.declarations,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
  });

  final List<Map<String, dynamic>> declarations;
  final int total;
  final int page;
  final int pages;
  final int pageSize;
}

http.Client _createHttpClient(bool isWeb) {
  if (!isWeb) return http.Client();
  return createWebHttpClient();
}

class AuthService {
  AuthService({
    http.Client? client,
    SessionCookieStorage? cookieStorage,
    TabletDeviceStorage? tabletDeviceStorage,
    String? baseUrl,
    bool? isWeb,
  }) : _client = client ?? _createHttpClient(isWeb ?? kIsWeb),
       _cookieStorage = cookieStorage ?? SecureSessionCookieStorage(),
       _tabletDeviceStorage =
           tabletDeviceStorage ?? SecureTabletDeviceStorage(),
       _baseUrl = (baseUrl ?? _configuredBaseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _isWeb = isWeb ?? kIsWeb;

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://recep.cymezapi.com',
  );
  static const _configuredPublicAppUrl = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: '',
  );
  static final shared = AuthService();

  final http.Client _client;
  final SessionCookieStorage _cookieStorage;
  final TabletDeviceStorage _tabletDeviceStorage;
  final String _baseUrl;
  final bool _isWeb;
  final StreamController<void> _successfulLoginEvents =
      StreamController<void>.broadcast();
  String? _registeredMobileNotificationToken;

  Stream<void> get successfulLoginEvents => _successfulLoginEvents.stream;

  Future<MobileAppUpdate?> checkForMobileAppUpdate({
    required String channel,
  }) async {
    if (channel != 'phone' && channel != 'tablet') {
      throw const AuthApiException('El canal de actualización no es válido.');
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final build = int.tryParse(packageInfo.buildNumber);
    if (build == null || build < 0) {
      throw const AuthApiException(
        'No se pudo determinar la compilación instalada de la aplicación.',
      );
    }
    final response = await _send(
      () => _client.get(
        _uri('/api/app-releases/latest?channel=$channel&build=$build'),
      ),
      retrySafe: true,
    );
    if (response.statusCode != 200) throw _responseError(response);
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['updateAvailable'] is! bool) {
      throw const AuthApiException(
        'La respuesta de actualización no tiene un formato válido.',
      );
    }
    if (payload['updateAvailable'] != true) return null;
    final release = payload['release'];
    if (release is! Map<String, dynamic> ||
        release['version'] is! String ||
        release['build'] is! int ||
        release['notes'] is! String ||
        release['downloadUrl'] is! String) {
      throw const AuthApiException(
        'Los datos de la actualización no tienen un formato válido.',
      );
    }
    if ((release['build'] as int) <= build) return null;
    final downloadUrl = _uri(release['downloadUrl'] as String);
    if (downloadUrl.scheme != 'https' && downloadUrl.scheme != 'http') {
      throw const AuthApiException('El enlace de descarga no es válido.');
    }
    return MobileAppUpdate(
      version: release['version'] as String,
      build: release['build'] as int,
      installedBuild: build,
      notes: release['notes'] as String,
      downloadUrl: downloadUrl,
    );
  }

  String equipmentDeclarationUrl(String token) {
    final configuredUrl = _configuredPublicAppUrl.trim();
    final appUri = _isWeb
        ? Uri.base
        : Uri.parse(configuredUrl.isNotEmpty ? configuredUrl : _baseUrl);
    return '${appUri.origin}/#equipo=${Uri.encodeComponent(token)}';
  }

  Future<AuthenticatedUser> login(String identifier, String password) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/auth/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier.trim(),
          'password': password,
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _responseError(response);
    }

    final data = _decodeObject(response.body);
    final user = AuthenticatedUser.fromJson(data['user']);
    if (!user.canAccessApp) {
      if (_isWeb) {
        await _send(() => _client.post(_uri('/api/auth/logout')));
      }
      throw const AuthApiException(
        'Tu cuenta no tiene permisos habilitados para usar la aplicación.',
      );
    }

    if (!_isWeb) {
      final cookie = _extractSessionCookie(response.headers['set-cookie']);
      if (cookie == null) {
        throw const AuthApiException(
          'El servidor no inició una sesión segura. Inténtalo de nuevo.',
        );
      }
      await _writeCookie(cookie);
    }

    _successfulLoginEvents.add(null);
    return user;
  }

  Future<String> requestPasswordRecovery(String email) async {
    final data = await _requestApi(
      'POST',
      '/api/auth/password-recovery',
      body: {'email': email.trim()},
      successCodes: const {202},
    );
    final message = data['message'];
    if (message is! String || message.isEmpty) {
      throw const AuthApiException(
        'La respuesta de recuperación de contraseña no es válida.',
      );
    }
    return message;
  }

  Future<AuthenticatedUser?> restoreSession() async {
    final headers = await _sessionHeaders();
    if (!_isWeb && !headers.containsKey('Cookie')) return null;

    final response = await _send(
      () => _client.get(_uri('/api/auth/session'), headers: headers),
      retrySafe: true,
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }

    final data = _decodeObject(response.body);
    if (data['user'] == null) {
      if (!_isWeb) await _clearCookie();
      return null;
    }

    final user = AuthenticatedUser.fromJson(data['user']);
    if (!user.canAccessApp) {
      await logout();
      return null;
    }
    return user;
  }

  Future<void> logout() async {
    final headers = await _sessionHeaders();
    final notificationToken = _registeredMobileNotificationToken;
    if (notificationToken != null) {
      unawaited(
        _removeMobileNotificationTokenBestEffort(
          notificationToken,
          sessionHeaders: headers,
        ),
      );
    }
    final response = await _send(
      () => _client.post(_uri('/api/auth/logout'), headers: headers),
    );
    if (response.statusCode != 204) {
      throw _responseError(response);
    }
    if (!_isWeb) await _clearCookie();
  }

  Future<TabletDeviceLink?> getTabletDeviceLink() async {
    final value = await _tabletDeviceStorage.read();
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic> && decoded['pendingToken'] is String) {
      return null;
    }
    return TabletDeviceLink.fromJson(decoded);
  }

  Future<TabletDeviceLink> pairTablet(
    String code, {
    required String deviceName,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{5}-?[A-HJ-NP-Z2-9]{5}$')
        .hasMatch(normalizedCode)) {
      throw const AuthApiException('Escribe un código de vinculación válido.');
    }
    final normalizedDeviceName = deviceName.trim();
    if (normalizedDeviceName.isEmpty || normalizedDeviceName.length > 120) {
      throw const AuthApiException(
        'Escribe un nombre de tablet de hasta 120 caracteres.',
      );
    }
    final storedValue = await _tabletDeviceStorage.read();
    String deviceToken;
    if (storedValue != null) {
      final decoded = jsonDecode(storedValue);
      if (decoded is Map<String, dynamic> &&
          decoded['pendingToken'] is String) {
        deviceToken = decoded['pendingToken'] as String;
      } else {
        return TabletDeviceLink.fromJson(decoded);
      }
    } else {
      final random = math.Random.secure();
      deviceToken = base64Url
          .encode(List<int>.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      await _tabletDeviceStorage.write(
        jsonEncode({'pendingToken': deviceToken}),
      );
    }
    final response = await _send(
      () => _client.post(
        _uri('/api/tablet-pairing-codes/redeem'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': normalizedCode,
          'deviceToken': deviceToken,
          'deviceName': normalizedDeviceName,
        }),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _responseError(response);
    }
    final data = _decodeObject(response.body);
    final company = data['company'];
    if (data['token'] != deviceToken ||
        data['deviceId'] is! int ||
        company is! Map<String, dynamic> ||
        company['id'] is! int ||
        company['name'] is! String) {
      throw const AuthApiException(
        'La respuesta de vinculación de la tablet no es válida.',
      );
    }
    final link = TabletDeviceLink(
      token: data['token'] as String,
      companyId: company['id'] as int,
      companyName: company['name'] as String,
      deviceId: data['deviceId'] as int,
      deviceName:
          data['deviceName'] is String &&
              (data['deviceName'] as String).trim().isNotEmpty
          ? (data['deviceName'] as String).trim()
          : normalizedDeviceName,
    );
    await _tabletDeviceStorage.write(
      jsonEncode({
        'token': link.token,
        'companyId': link.companyId,
        'companyName': link.companyName,
        'deviceId': link.deviceId,
        'deviceName': link.deviceName,
      }),
    );
    return link;
  }

  Future<Map<String, String>> _tabletDeviceHeaders() async {
    final link = await getTabletDeviceLink();
    return link == null ? const {} : {'Authorization': 'Bearer ${link.token}'};
  }

  Future<AuthenticatedUser> changePassword({
    required String password,
    required String confirmation,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _sessionHeaders(),
    };
    final response = await _send(
      () => _client.post(
        _uri('/api/auth/change-password'),
        headers: headers,
        body: jsonEncode({'password': password, 'confirmation': confirmation}),
      ),
    );
    if (response.statusCode != 200) throw _responseError(response);
    final data = _decodeObject(response.body);
    final user = AuthenticatedUser.fromJson(data['user']);
    final cookie = _extractSessionCookie(response.headers['set-cookie']);
    if (!_isWeb && cookie == null) {
      throw const AuthApiException(
        'No se pudo renovar la sesión después de cambiar la contraseña.',
      );
    }
    if (cookie != null) await _writeCookie(cookie);
    return user;
  }

  Future<List<Map<String, dynamic>>> getCompanies() async =>
      _apiRecords(await _requestApi('GET', '/api/companies'), 'companies');

  Future<List<Map<String, dynamic>>> saveCompany(
    String name, {
    int? id,
  }) async => _apiRecords(
    await _requestApi(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/api/companies' : '/api/companies/$id',
      body: {'name': name.trim()},
      successCodes: id == null ? const {200, 201} : const {200},
    ),
    'companies',
  );

  Future<List<Map<String, dynamic>>> deleteCompany(int id) async => _apiRecords(
    await _requestApi('DELETE', '/api/companies/$id'),
    'companies',
  );

  Future<List<Map<String, dynamic>>> getCompanyAdministrators() async =>
      _apiRecords(
        await _requestApi('GET', '/api/administrators'),
        'administrators',
      );

  Future<Map<String, dynamic>> saveCompanyAdministrator(
    Map<String, Object?> administrator, {
    String? login,
  }) => _requestApi(
    login == null ? 'POST' : 'PATCH',
    login == null
        ? '/api/administrators'
        : '/api/administrators/${Uri.encodeComponent(login)}',
    body: administrator,
    successCodes: login == null ? const {200, 201} : const {200},
  );

  Future<void> deleteCompanyAdministrator(String login) async {
    await _requestApi(
      'DELETE',
      '/api/administrators/${Uri.encodeComponent(login)}',
    );
  }

  Future<List<Map<String, dynamic>>> getCompanyUsers([int? companyId]) async =>
      _apiRecords(
        await _requestApi(
          'GET',
          companyId == null
              ? '/api/company-users'
              : '/api/company-users?companyId=$companyId',
        ),
        'users',
      );

  Future<Map<String, dynamic>> saveCompanyUser(
    int companyId,
    Map<String, Object?> account, {
    String? login,
  }) => _requestApi(
    login == null ? 'POST' : 'PATCH',
    '/api/company-users${login == null ? '' : '/${Uri.encodeComponent(login)}'}?companyId=$companyId',
    body: account,
    successCodes: login == null ? const {200, 201} : const {200},
  );

  Future<void> deleteCompanyUser(int companyId, String login) async {
    await _requestApi(
      'DELETE',
      '/api/company-users/${Uri.encodeComponent(login)}?companyId=$companyId',
    );
  }

  Future<Map<String, dynamic>> getTabletPairingCodes() =>
      _requestApi('GET', '/api/tablet-pairing-codes');

  Future<Map<String, dynamic>> createTabletPairingCode(int companyId) =>
      _requestApi(
        'POST',
        '/api/tablet-pairing-codes',
        body: {'companyId': companyId},
        successCodes: const {200, 201},
      );

  Future<void> revokeTabletPairingCode(int id) async {
    await _requestApi('POST', '/api/tablet-pairing-codes/$id/revoke');
  }

  Future<void> updateTabletDeviceName(int pairingCodeId, String name) async {
    await _requestApi(
      'PATCH',
      '/api/tablet-pairing-codes/$pairingCodeId',
      body: {'deviceName': name.trim()},
    );
  }

  Future<void> deleteTabletPairingCode(int id) async {
    await _requestApi('DELETE', '/api/tablet-pairing-codes/$id');
  }

  Future<DashboardData> getDashboardData(DateTime date) async {
    String formatDate(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    final dateString = formatDate(date);
    final fromDate = formatDate(date.subtract(const Duration(days: 6)));
    final headers = await _sessionHeaders();
    final responses = await Future.wait([
      _send(
        () => _client.get(_uri('/api/appointments'), headers: headers),
        retrySafe: true,
      ),
      _send(
        () => _client.get(
          _uri(
            '/api/daily-log?from=$dateString&to=$dateString&page=1&pageSize=8',
          ),
          headers: headers,
        ),
        retrySafe: true,
      ),
      _send(
        () => _client.get(
          _uri('/api/daily-log/stats?from=$fromDate&to=$dateString'),
          headers: headers,
        ),
        retrySafe: true,
      ),
      _send(
        () => _client.get(
          _uri(
            '/api/daily-log?from=$fromDate&to=$dateString&page=1&pageSize=1&recentPage=1&recentPageSize=6',
          ),
          headers: headers,
        ),
        retrySafe: true,
      ),
    ]);
    for (final response in responses) {
      if (response.statusCode != 200) throw _responseError(response);
    }

    final appointmentValues = _decodeObject(responses[0].body)['appointments'];
    final logData = _decodeObject(responses[1].body);
    final statsData = _decodeObject(responses[2].body);
    final periodLogData = _decodeObject(responses[3].body);
    final summary = logData['summary'];
    final recentValues = periodLogData['recentEntries'];
    final statsValues = statsData['stats'];
    if (appointmentValues is! List ||
        summary is! Map<String, dynamic> ||
        summary['insideNow'] is! num ||
        summary['pendingArrivals'] is! num ||
        recentValues is! List ||
        statsValues is! List) {
      throw const AuthApiException(
        'La respuesta de datos del inicio no es válida.',
      );
    }
    final appointments = appointmentValues
        .map(DashboardAppointment.fromJson)
        .where((appointment) => appointment.date == dateString)
        .toList();
    final recentEntries = recentValues.map(DashboardLogEntry.fromJson).toList();
    final statsByDate = {
      for (final value in statsValues.map(DashboardDailyActivity.fromJson))
        value.date: value,
    };
    final dailyActivity = List.generate(7, (index) {
      final day = date.subtract(Duration(days: 6 - index));
      final dayString = formatDate(day);
      return statsByDate[dayString] ??
          DashboardDailyActivity(
            date: dayString,
            arrivals: 0,
            entries: 0,
            exits: 0,
            observations: 0,
          );
    });
    return DashboardData(
      appointments: List.unmodifiable(appointments),
      insideNow: (summary['insideNow'] as num).toInt(),
      pendingArrivals: (summary['pendingArrivals'] as num).toInt(),
      recentEntries: List.unmodifiable(recentEntries),
      dailyActivity: List.unmodifiable(dailyActivity),
    );
  }

  Future<List<AccessAccount>> getAccessAccounts() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.get(_uri('/api/auth/session'), headers: headers),
      retrySafe: true,
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }

    final data = _decodeObject(response.body);
    if (data['user'] == null) {
      if (!_isWeb) await _clearCookie();
      throw const AuthApiException('La sesión expiró. Inicia sesión de nuevo.');
    }
    if (data['user'] is! Map<String, dynamic> ||
        (data['user'] as Map<String, dynamic>)['isAdmin'] != true) {
      throw const AuthApiException(
        'Solo una cuenta administradora puede consultar los accesos.',
      );
    }

    final accounts = data['accounts'];
    if (accounts is! List) {
      throw const AuthApiException('La respuesta de cuentas no es válida.');
    }
    return List<AccessAccount>.unmodifiable(
      accounts.map(AccessAccount.fromJson),
    );
  }

  Future<List<AccessAccount>> updateAccess(
    String login,
    List<String> sections,
  ) async {
    if (login.isEmpty ||
        login.length > 255 ||
        sections.length > 1 ||
        sections.any(
          (section) => !const {
            'recepcion',
            'anfitriones',
            'administrador',
          }.contains(section),
        )) {
      throw const AuthApiException(
        'Los permisos seleccionados no son válidos.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _sessionHeaders(),
    };
    final response = await _send(
      () => _client.put(
        _uri('/api/access/${Uri.encodeComponent(login)}'),
        headers: headers,
        body: jsonEncode({'sections': sections}),
      ),
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }

    final data = _decodeObject(response.body);
    final accounts = data['accounts'];
    if (accounts is! List) {
      throw const AuthApiException('La respuesta de cuentas no es válida.');
    }
    return List<AccessAccount>.unmodifiable(
      accounts.map(AccessAccount.fromJson),
    );
  }

  Future<List<Department>> getDepartments() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.get(_uri('/api/departments'), headers: headers),
      retrySafe: true,
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartments(response.body);
  }

  Future<List<Department>> createDepartment(String name, {int? companyId}) =>
      _saveDepartment(name, companyId: companyId);

  Future<List<Department>> updateDepartment(int id, String name) {
    if (id <= 0) {
      throw const AuthApiException(
        'El departamento seleccionado no es válido.',
      );
    }
    return _saveDepartment(name, id: id);
  }

  Future<List<Department>> _saveDepartment(
    String name, {
    int? id,
    int? companyId,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 120) {
      throw const AuthApiException(
        'Escribe un nombre de departamento de hasta 120 caracteres.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _sessionHeaders(),
    };
    final response = await _send(
      () => id == null
          ? _client.post(
              _uri('/api/departments'),
              headers: headers,
              body: jsonEncode({
                'name': normalizedName,
                'companyId': ?companyId,
              }),
            )
          : _client.patch(
              _uri('/api/departments/$id'),
              headers: headers,
              body: jsonEncode({'name': normalizedName}),
            ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _responseError(response);
    }
    return _parseDepartments(response.body);
  }

  Future<List<Department>> deleteDepartment(int id) async {
    if (id <= 0) {
      throw const AuthApiException(
        'El departamento seleccionado no es válido.',
      );
    }
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.delete(_uri('/api/departments/$id'), headers: headers),
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartments(response.body);
  }

  Future<List<DepartmentHost>> getDepartmentHosts() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.get(_uri('/api/department-hosts'), headers: headers),
      retrySafe: true,
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartmentHosts(response.body);
  }

  Future<List<Map<String, dynamic>>> getBusinessPartners() async =>
      _getApiRecords('/api/business-partners', 'businessPartners');

  Future<List<Map<String, dynamic>>> getAppointmentBusinessPartners() async =>
      _getApiRecords(
        '/api/business-partners?scope=appointment',
        'businessPartners',
      );

  Future<List<Map<String, dynamic>>> saveBusinessPartner(
    Map<String, Object?> partner, {
    int? id,
  }) async {
    final data = await _requestApi(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/api/business-partners' : '/api/business-partners/$id',
      body: partner,
      successCodes: const {200, 201},
    );
    return _apiRecords(data, 'businessPartners');
  }

  Future<List<Map<String, dynamic>>> deleteBusinessPartner(int id) async =>
      _getApiRecords(
        '/api/business-partners/$id',
        'businessPartners',
        method: 'DELETE',
      );

  Future<List<Map<String, dynamic>>> getExternalStaff() async =>
      _getApiRecords('/api/external-staff', 'externalStaff');

  Future<List<Map<String, dynamic>>> getGeneralVisitors() async =>
      _getApiRecords('/api/general-visitors', 'generalVisitors');

  Future<List<Map<String, dynamic>>> saveExternalStaff(
    Map<String, Object?> staff, {
    int? id,
  }) async {
    final data = await _requestApi(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/api/external-staff' : '/api/external-staff/$id',
      body: staff,
      successCodes: const {200, 201},
    );
    return _apiRecords(data, 'externalStaff');
  }

  Future<List<Map<String, dynamic>>> deleteExternalStaff(int id) async =>
      _getApiRecords(
        '/api/external-staff/$id',
        'externalStaff',
        method: 'DELETE',
      );

  Future<List<Map<String, dynamic>>> getAppointments() async =>
      _getApiRecords('/api/appointments', 'appointments');

  Future<List<Map<String, dynamic>>> getHostVisitors({
    bool forAppointment = false,
  }) async {
    final path = forAppointment
        ? '/api/host-visitors?scope=appointment'
        : '/api/host-visitors';
    final data = await _requestApi('GET', path);
    final visitors = data['visitors'];
    if (visitors is! List ||
        visitors.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['id'] is! num ||
              item['fullName'] is! String ||
              item['phone'] is! String ||
              item['email'] is! String,
        )) {
      throw const AuthApiException(
        'La respuesta de visitantes guardados no es válida.',
      );
    }
    return List<Map<String, dynamic>>.unmodifiable(
      visitors.cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> saveHostVisitor({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final data = await _requestApi(
      'POST',
      '/api/host-visitors',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
      },
      successCodes: const {200, 201},
    );
    final visitors = data['visitors'];
    if (visitors is! List ||
        visitors.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['id'] is! num ||
              item['fullName'] is! String ||
              item['phone'] is! String ||
              item['email'] is! String,
        )) {
      throw const AuthApiException(
        'La respuesta de visitantes guardados no es válida.',
      );
    }
    return List<Map<String, dynamic>>.unmodifiable(
      visitors.cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> saveAppointment(
    Map<String, Object?> appointment, {
    int? id,
  }) async {
    final data = await _requestApi(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/api/appointments' : '/api/appointments/$id',
      body: appointment,
      successCodes: const {200, 201},
    );
    return _apiRecords(data, 'appointments');
  }

  List<Map<String, dynamic>> _parseDailyLogTimers(Map<String, dynamic> data) {
    final timers = data['timers'];
    if (timers is! List ||
        timers.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['id'] is! num ||
              (item['appointmentId'] != null &&
                  item['appointmentId'] is! num) ||
              (item['visitorRecordId'] != null &&
                  item['visitorRecordId'] is! num) ||
              item['personName'] is! String ||
              !const {'Llegada', 'Ingreso'}.contains(item['phase']) ||
              item['intervalMinutes'] is! num ||
              item['startedAt'] is! String ||
              item['dueAt'] is! String ||
              item['status'] is! String,
        )) {
      throw const AuthApiException(
        'La respuesta de temporizadores de visitas no es válida.',
      );
    }
    return List<Map<String, dynamic>>.unmodifiable(
      timers.cast<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> getDailyLogTimers() async {
    final data = await _requestApi('GET', '/api/daily-log/timers');
    return _parseDailyLogTimers(data);
  }

  Future<List<Map<String, dynamic>>> actOnDailyLogTimer(
    int id, {
    required String action,
  }) async {
    if (id <= 0 || !const {'snooze', 'cancel'}.contains(action)) {
      throw const AuthApiException('La acción del temporizador no es válida.');
    }
    final data = await _requestApi(
      'POST',
      '/api/daily-log/timers/$id',
      body: {'action': action},
    );
    return _parseDailyLogTimers(data);
  }

  Future<Map<String, dynamic>?> getNotificationFirebaseConfig() async {
    final data = await _requestApi('GET', '/api/notifications/config');
    final firebase = data['firebase'];
    if (firebase == null) return null;
    if (firebase is! Map<String, dynamic> ||
        firebase['apiKey'] is! String ||
        firebase['appId'] is! String ||
        firebase['messagingSenderId'] is! String ||
        firebase['projectId'] is! String) {
      throw const AuthApiException(
        'La configuración de notificaciones no es válida.',
      );
    }
    return firebase;
  }

  Future<void> registerMobileNotificationToken(String token) async {
    if (token.trim().isEmpty) {
      throw const AuthApiException('El token de notificaciones no es válido.');
    }
    await _requestApi(
      'POST',
      '/api/notifications/config',
      body: {'platform': 'mobile', 'token': token},
      successCodes: const {200, 201},
    );
    _registeredMobileNotificationToken = token;
  }

  Future<void> _removeMobileNotificationTokenBestEffort(
    String token, {
    required Map<String, String> sessionHeaders,
  }) async {
    try {
      await _requestApi(
        'DELETE',
        '/api/notifications/config',
        body: {'platform': 'mobile', 'token': token},
        extraHeaders: sessionHeaders,
        successCodes: const {200, 204},
      );
      if (_registeredMobileNotificationToken == token) {
        _registeredMobileNotificationToken = null;
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo retirar el token FCM al cerrar sesión: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> updateAppointmentStatus(
    int id,
    String status,
  ) async {
    final data = await _requestApi(
      'PATCH',
      '/api/appointments/$id',
      body: {'status': status},
    );
    return _apiRecords(data, 'appointments');
  }

  Future<List<Map<String, dynamic>>> deleteAppointment(int id) async {
    final data = await _requestApi('DELETE', '/api/appointments/$id');
    return _apiRecords(data, 'appointments');
  }

  Future<String> sendAppointmentQr(int id, {int? employeeId}) async {
    final data = await _requestApi(
      'POST',
      '/api/appointments/$id/send-qr',
      body: employeeId == null ? const {} : {'employeeId': employeeId},
    );
    final message = data['message'];
    if (message is! String || message.isEmpty) {
      throw const AuthApiException(
        'La respuesta del envío del pase no es válida.',
      );
    }
    return message;
  }

  Future<Map<String, dynamic>> getDailyLog({
    required String from,
    required String to,
    String query = '',
    String event = '',
    String category = '',
    String host = '',
    int page = 1,
    int pageSize = 7,
    int recentPage = 1,
    int recentPageSize = 7,
  }) async {
    final uri = _uri('/api/daily-log').replace(
      queryParameters: {
        'from': from,
        'to': to,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (event.isNotEmpty) 'event': event,
        if (category.isNotEmpty) 'category': category,
        if (host.isNotEmpty) 'host': host,
        'page': '$page',
        'pageSize': '$pageSize',
        'recentPage': '$recentPage',
        'recentPageSize': '$recentPageSize',
      },
    );
    final data = await _requestApi(
      'GET',
      uri.toString().replaceFirst(_baseUrl, ''),
    );
    if (data['entries'] is! List ||
        data['summary'] is! Map<String, dynamic> ||
        data['hosts'] is! List ||
        data['total'] is! num ||
        data['pages'] is! num) {
      throw const AuthApiException('La respuesta de la bitácora no es válida.');
    }
    return data;
  }

  Future<void> createDailyLogEntry(Map<String, Object?> entry) async {
    await _requestApi(
      'POST',
      '/api/daily-log',
      body: entry,
      successCodes: const {200, 201},
    );
  }

  Future<void> deleteDailyLogEntry(int id) async {
    if (id <= 0) {
      throw const AuthApiException('El movimiento seleccionado no es válido.');
    }
    await _requestApi('DELETE', '/api/daily-log/$id');
  }

  Future<List<Map<String, dynamic>>> getVisitorKioskRegistrations() async {
    final data = await _requestApi('GET', '/api/visitor-kiosk/registrations');
    final registrations = data['registrations'];
    if (registrations is! List ||
        registrations.any((item) => item is! Map<String, dynamic>)) {
      throw const AuthApiException(
        'La respuesta de registros manuales no es válida.',
      );
    }
    return registrations.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateVisitorKioskRegistration(
    int id, {
    required String action,
    List<Map<String, Object?>>? items,
  }) async {
    if (id <= 0) {
      throw const AuthApiException(
        'El registro manual seleccionado no es válido.',
      );
    }
    return _requestApi(
      'PATCH',
      '/api/visitor-kiosk/registrations/$id',
      body: {'action': action, 'items': items},
    );
  }

  Future<Map<String, dynamic>> createVisitorKioskRegistration({
    required String idempotencyKey,
    required Map<String, Object?> registration,
  }) async {
    final tabletHeaders = await _tabletDeviceHeaders();
    final data = await _requestApi(
      'POST',
      '/api/visitor-kiosk/registrations',
      body: registration,
      extraHeaders: {'Idempotency-Key': idempotencyKey, ...tabletHeaders},
      successCodes: const {200, 201},
    );
    if (data['folio'] is! String || data['visitorName'] is! String) {
      throw const AuthApiException(
        'La respuesta del registro de visitante no es válida.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> getVisitorKioskStatus(
    String idempotencyKey,
  ) async {
    final tabletHeaders = await _tabletDeviceHeaders();
    final data = await _requestApi(
      'GET',
      '/api/visitor-kiosk/status',
      extraHeaders: {'Idempotency-Key': idempotencyKey, ...tabletHeaders},
    );
    if (data['authorizationStatus'] is! String ||
        data['entryChecklistComplete'] is! bool ||
        data['entered'] is! bool ||
        data['folio'] is! String ||
        data['visitorName'] is! String) {
      throw const AuthApiException(
        'La respuesta del estado de la visita no es válida.',
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getAppointmentEmployees(int id) async {
    if (id <= 0) {
      throw const AuthApiException('La cita seleccionada no es válida.');
    }
    final data = await _requestApi('GET', '/api/appointments/$id/employees');
    return _apiRecords(data, 'employees');
  }

  Future<void> updateAppointmentEmployeeAttendance(
    int appointmentId,
    int externalStaffId,
    String action,
  ) async {
    if (appointmentId <= 0 ||
        externalStaffId <= 0 ||
        !const {'absent', 'restore'}.contains(action)) {
      throw const AuthApiException(
        'La cita o el empleado seleccionado no es válido.',
      );
    }
    await _requestApi(
      'POST',
      '/api/appointments/$appointmentId/employees/$externalStaffId/attendance',
      body: {'action': action},
    );
  }

  Future<Map<String, dynamic>> getEquipmentOptions() async {
    final data = await _requestApi('GET', '/api/equipment/options');
    for (final key in const ['partners', 'staff', 'appointments']) {
      final records = data[key];
      if (records is! List ||
          records.any((record) => record is! Map<String, dynamic>)) {
        throw const AuthApiException(
          'La respuesta de opciones de equipo no es válida.',
        );
      }
    }
    return data;
  }

  Future<EquipmentDeclarationsPage> getEquipmentDeclarations({
    String query = '',
    int page = 1,
  }) async {
    final uri = _uri(
      '/api/equipment/declarations',
    ).replace(queryParameters: {'q': query, 'page': '$page', 'pageSize': '5'});
    final data = await _requestApi(
      'GET',
      uri.toString().replaceFirst(_baseUrl, ''),
    );
    final declarations = _apiRecords(data, 'declarations');
    final totalValue = data['total'];
    final pageValue = data['page'];
    final pagesValue = data['pages'];
    final pageSizeValue = data['pageSize'];
    if ((totalValue != null &&
            (totalValue is! num ||
                totalValue < 0 ||
                totalValue != totalValue.toInt())) ||
        (pageValue != null &&
            (pageValue is! num ||
                pageValue < 1 ||
                pageValue != pageValue.toInt())) ||
        (pagesValue != null &&
            (pagesValue is! num ||
                pagesValue < 1 ||
                pagesValue != pagesValue.toInt())) ||
        (pageSizeValue != null &&
            (pageSizeValue is! num ||
                pageSizeValue < 1 ||
                pageSizeValue > 100 ||
                pageSizeValue != pageSizeValue.toInt()))) {
      throw const AuthApiException(
        'La respuesta de paginación de declaraciones no es válida.',
      );
    }
    final total = (totalValue as num?)?.toInt() ?? declarations.length;
    final responsePage = (pageValue as num?)?.toInt() ?? page;
    final pageSize =
        (pageSizeValue as num?)?.toInt() ??
        (declarations.isEmpty ? 5 : declarations.length);
    final pages =
        (pagesValue as num?)?.toInt() ??
        (total == 0 ? 1 : (total / pageSize).ceil());
    if (responsePage != page) {
      throw const AuthApiException(
        'La respuesta de paginación de declaraciones no es válida.',
      );
    }
    return EquipmentDeclarationsPage(
      declarations: List<Map<String, dynamic>>.unmodifiable(
        declarations.cast<Map<String, dynamic>>(),
      ),
      total: total,
      page: responsePage,
      pages: pages,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> createEquipmentDeclaration(
    Map<String, Object?> declaration,
  ) => _requestApi(
    'POST',
    '/api/equipment/declarations',
    body: declaration,
    successCodes: const {200, 201},
  );

  Future<Map<String, dynamic>> getEquipmentDeclaration(int id) async {
    final data = await _requestApi('GET', '/api/equipment/declarations/$id');
    final declaration = data['declaration'];
    if (declaration is! Map<String, dynamic> ||
        declaration['id'] is! num ||
        declaration['personName'] is! String ||
        declaration['companyName'] is! String ||
        declaration['status'] is! String ||
        declaration['items'] is! List ||
        declaration['inspections'] is! List) {
      throw const AuthApiException(
        'La respuesta de detalle de equipo no es válida.',
      );
    }
    return data;
  }

  Future<String> createEquipmentDeclarationLink(int id) async {
    final data = await _requestApi(
      'POST',
      '/api/equipment/declarations/$id/link',
      body: const {},
    );
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthApiException('El servidor no generó un enlace válido.');
    }
    final link = data['url'];
    return link is String && link.isNotEmpty
        ? link
        : equipmentDeclarationUrl(token);
  }

  Future<void> revokeEquipmentDeclarationLink(int id) async {
    await _requestApi(
      'POST',
      '/api/equipment/declarations/$id/revoke',
      body: const {},
    );
  }

  Future<void> submitEquipmentInspection(
    int id,
    String phase,
    List<Map<String, Object?>> items,
  ) async {
    await _requestApi(
      'PUT',
      '/api/equipment/declarations/$id/inspections/$phase',
      body: {'items': items},
    );
  }

  Future<void> deleteEquipmentDeclaration(int id) async {
    await _requestApi('DELETE', '/api/equipment/declarations/$id');
  }

  Future<List<Map<String, dynamic>>> _getApiRecords(
    String path,
    String key, {
    String method = 'GET',
  }) async {
    final data = await _requestApi(method, path);
    return _apiRecords(data, key);
  }

  List<Map<String, dynamic>> _apiRecords(
    Map<String, dynamic> data,
    String key,
  ) {
    final records = data[key];
    if (records is! List ||
        records.any(
          (record) =>
              record is! Map<String, dynamic> ||
              !_isValidApiRecord(key, record),
        )) {
      throw AuthApiException('La respuesta de $key no es válida.');
    }
    return List<Map<String, dynamic>>.unmodifiable(
      records.cast<Map<String, dynamic>>(),
    );
  }

  bool _isValidApiRecord(String key, Map<String, dynamic> record) {
    bool hasStrings(List<String> fields) =>
        fields.every((field) => record[field] is String);
    bool hasNumbers(List<String> fields) =>
        fields.every((field) => record[field] is num);
    return switch (key) {
      'businessPartners' =>
        hasNumbers(['id', 'employeeCount']) &&
            hasStrings([
              'name',
              'description',
              'rfc',
              'category',
              'subject',
              'type',
              'status',
            ]),
      'externalStaff' =>
        hasNumbers(['id', 'businessPartnerId']) &&
            hasStrings([
              'fullName',
              'phone',
              'email',
              'relationshipType',
              'companyName',
            ]),
      'appointments' =>
        hasNumbers(['id']) &&
            (record['businessPartnerId'] == null ||
                record['businessPartnerId'] is num) &&
            (record['visitorRecordId'] == null ||
                record['visitorRecordId'] is num) &&
            hasStrings([
              'date',
              'time',
              'visitor',
              'email',
              'referenceCode',
              'company',
              'host',
              'status',
            ]),
      'declarations' =>
        hasNumbers(['id', 'itemCount', 'incidentCount']) &&
            hasStrings([
              'personName',
              'companyName',
              'status',
              'createdBy',
              'createdAt',
            ]),
      _ => true,
    };
  }

  Future<Map<String, dynamic>> _requestApi(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> extraHeaders = const {},
    Set<int> successCodes = const {200},
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      ...await _sessionHeaders(),
      ...extraHeaders,
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = _uri(path);
    final response = await _send(() {
      final encodedBody = body == null ? null : jsonEncode(body);
      return switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        'DELETE' => _client.delete(uri, headers: headers, body: encodedBody),
        _ => throw ArgumentError.value(method, 'method', 'Método no admitido'),
      };
    }, retrySafe: method.toUpperCase() == 'GET');
    if (!successCodes.contains(response.statusCode)) {
      throw _responseError(response);
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    return _decodeObject(response.body);
  }

  Stream<RealtimeEvent> watchRealtimeUpdates() =>
      _watchRealtimeEventStream(_uri('/api/events'), authenticated: true);

  Stream<RealtimeEvent> watchVisitorKioskUpdates(String idempotencyKey) async* {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(idempotencyKey)) {
      throw const AuthApiException('La clave del registro no es válida.');
    }
    final uri = _uri('/api/visitor-kiosk/events')
        .replace(queryParameters: {'key': idempotencyKey});
    await for (final event in _watchRealtimeEventStream(
      uri,
      extraHeaders: await _tabletDeviceHeaders(),
    )) {
      yield event;
    }
  }

  Stream<RealtimeEvent> _watchRealtimeEventStream(
    Uri uri, {
    bool authenticated = false,
    Map<String, String> extraHeaders = const {},
  }) async* {
    if (_isWeb) {
      await for (final event in watchWebRealtimeEvents(uri)) {
        yield switch (event) {
          'connected' => RealtimeEvent.connected,
          'update' => RealtimeEvent.update,
          _ => RealtimeEvent.disconnected,
        };
      }
      return;
    }

    final headers = {
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      if (authenticated) ...await _sessionHeaders(),
      ...extraHeaders,
    };
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw _responseError(http.Response(body, response.statusCode));
    }

    yield RealtimeEvent.connected;
    var hasData = false;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (hasData) {
          yield RealtimeEvent.update;
          hasData = false;
        }
      } else if (line.startsWith('data:')) {
        hasData = true;
      }
    }
  }

  Future<List<HostAccountOption>> getHostAccounts() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.get(_uri('/api/host-accounts'), headers: headers),
      retrySafe: true,
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    final accounts = _decodeObject(response.body)['accounts'];
    if (accounts is! List) {
      throw const AuthApiException(
        'La respuesta de cuentas disponibles no es válida.',
      );
    }
    return List<HostAccountOption>.unmodifiable(
      accounts.map(HostAccountOption.fromJson),
    );
  }

  Future<List<DepartmentHost>> createDepartmentHost({
    required String login,
    required String name,
    required int departmentId,
    String role = '',
    String email = '',
    String phone = '',
  }) => _saveDepartmentHost(
    login: login,
    name: name,
    departmentId: departmentId,
    role: role,
    email: email,
    phone: phone,
  );

  Future<List<DepartmentHost>> updateDepartmentHost({
    required int id,
    required String login,
    required String name,
    required int departmentId,
    String role = '',
    String email = '',
    String phone = '',
  }) {
    if (id <= 0) {
      throw const AuthApiException('El anfitrión seleccionado no es válido.');
    }
    return _saveDepartmentHost(
      id: id,
      login: login,
      name: name,
      departmentId: departmentId,
      role: role,
      email: email,
      phone: phone,
    );
  }

  Future<List<DepartmentHost>> updateDepartmentHostDepartment({
    required int id,
    required int departmentId,
  }) async {
    if (id <= 0 || departmentId <= 0) {
      throw const AuthApiException(
        'El anfitrión o departamento seleccionado no es válido.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _sessionHeaders(),
    };
    final response = await _send(
      () => _client.patch(
        _uri('/api/department-hosts/$id'),
        headers: headers,
        body: jsonEncode({'departmentId': departmentId}),
      ),
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartmentHosts(response.body);
  }

  Future<List<DepartmentHost>> _saveDepartmentHost({
    int? id,
    required String login,
    required String name,
    required int departmentId,
    required String role,
    required String email,
    required String phone,
  }) async {
    final normalizedLogin = login.trim();
    final normalizedName = name.trim();
    final normalizedRole = role.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    if (normalizedLogin.isEmpty ||
        normalizedLogin.length > 255 ||
        normalizedName.isEmpty ||
        normalizedName.length > 180 ||
        departmentId <= 0 ||
        normalizedRole.length > 120 ||
        normalizedEmail.length > 254 ||
        normalizedPhone.length > 30) {
      throw const AuthApiException(
        'Revisa los datos del anfitrión y su departamento.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _sessionHeaders(),
    };
    final path = id == null
        ? '/api/department-hosts'
        : '/api/department-hosts/$id';
    final body = jsonEncode({
      'login': normalizedLogin,
      'name': normalizedName,
      'departmentId': departmentId,
      'role': normalizedRole,
      'email': normalizedEmail,
      'phone': normalizedPhone,
    });
    final response = await _send(
      () => id == null
          ? _client.post(_uri(path), headers: headers, body: body)
          : _client.patch(_uri(path), headers: headers, body: body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _responseError(response);
    }
    return _parseDepartmentHosts(response.body);
  }

  Future<List<DepartmentHost>> deleteDepartmentHost(int id) async {
    if (id <= 0) {
      throw const AuthApiException('El anfitrión seleccionado no es válido.');
    }
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.delete(_uri('/api/department-hosts/$id'), headers: headers),
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartmentHosts(response.body);
  }

  List<DepartmentHost> _parseDepartmentHosts(String body) {
    final hosts = _decodeObject(body)['hosts'];
    if (hosts is! List) {
      throw const AuthApiException('La respuesta de anfitriones no es válida.');
    }
    return List<DepartmentHost>.unmodifiable(
      hosts.map(DepartmentHost.fromJson),
    );
  }

  List<Department> _parseDepartments(String body) {
    final data = _decodeObject(body);
    final departments = data['departments'];
    if (departments is! List) {
      throw const AuthApiException(
        'La respuesta de departamentos no es válida.',
      );
    }
    return List<Department>.unmodifiable(departments.map(Department.fromJson));
  }

  Uri _uri(String path) {
    final versionedPath = path == '/api/v1' || path.startsWith('/api/v1/')
        ? path
        : path.startsWith('/api/')
        ? '/api/v1/${path.substring('/api/'.length)}'
        : path;
    return Uri.parse('$_baseUrl$versionedPath');
  }

  Future<Map<String, String>> _sessionHeaders() async {
    if (_isWeb) return const {};
    final cookie = await _readCookie();
    return cookie == null ? const {} : {'Cookie': cookie};
  }

  String? _extractSessionCookie(String? setCookie) {
    if (setCookie == null) return null;
    for (final part in setCookie.split(';')) {
      final cookie = part.trim();
      if (cookie.startsWith('$_sessionCookieName=') &&
          cookie.length > _sessionCookieName.length + 1) {
        return cookie;
      }
    }
    return null;
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      throw const AuthApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    throw const AuthApiException(
      'El servidor devolvió una respuesta inválida.',
    );
  }

  AuthApiException _responseError(http.Response response) {
    try {
      final data = _decodeObject(response.body);
      final message = data['error'];
      if (message is String && message.isNotEmpty) {
        return AuthApiException(
          message,
          statusCode: response.statusCode,
          retryAfterSeconds: int.tryParse(
            response.headers['retry-after'] ?? '',
          ),
        );
      }
    } on AuthApiException {
      // Use the status-specific message below when the error body is invalid.
    }

    if (response.statusCode >= 500) {
      return AuthApiException(
        'No se pudo validar el acceso. Inténtalo de nuevo.',
        statusCode: response.statusCode,
      );
    }
    return AuthApiException(
      'La solicitud falló (${response.statusCode}).',
      statusCode: response.statusCode,
      retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool retrySafe = false,
  }) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        final response = await request().timeout(_requestTimeout);
        final isTransientServiceError = const {
          502,
          503,
          504,
        }.contains(response.statusCode);
        if (!retrySafe || !isTransientServiceError || attempt >= 2) {
          return response;
        }
      } on TimeoutException {
        throw const AuthApiException(
          'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        );
      } on http.ClientException {
        if (!retrySafe || attempt >= 2) {
          throw const AuthApiException(
            'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
          );
        }
      }

      await Future<void>.delayed(Duration(milliseconds: 250 * (1 << attempt)));
    }
  }

  Future<String?> _readCookie() async {
    try {
      return await _cookieStorage.read();
    } on PlatformException {
      throw const AuthApiException(
        'No se pudo leer la sesión segura del dispositivo.',
      );
    }
  }

  Future<void> _writeCookie(String value) async {
    try {
      await _cookieStorage.write(value);
    } on PlatformException {
      throw const AuthApiException(
        'No se pudo guardar la sesión segura en el dispositivo.',
      );
    }
  }

  Future<void> _clearCookie() async {
    try {
      await _cookieStorage.clear();
    } on PlatformException {
      throw const AuthApiException(
        'No se pudo borrar la sesión segura del dispositivo.',
      );
    }
  }
}
