import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _sessionCookieName = 'visitas_session';
const _sessionCookieStorageKey = 'reception_session_cookie';
const _requestTimeout = Duration(seconds: 15);

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.login,
    required this.name,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.sectionAccess,
  });

  final String login;
  final String? name;
  final String? email;
  final String? role;
  final bool isAdmin;
  final List<String> sectionAccess;

  bool get canAccessReception => isAdmin || sectionAccess.contains('recepcion');

  factory AuthenticatedUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['login'] is! String ||
        value['isAdmin'] is! bool ||
        value['sectionAccess'] is! List ||
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
    );
  }
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
  const Department({required this.id, required this.name, this.hostCount = 0});

  final int id;
  final String name;
  final int hostCount;

  factory Department.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! num ||
        value['name'] is! String ||
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
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

class AuthService {
  AuthService({
    http.Client? client,
    SessionCookieStorage? cookieStorage,
    String? baseUrl,
    bool? isWeb,
  }) : _client = client ?? http.Client(),
       _cookieStorage = cookieStorage ?? SecureSessionCookieStorage(),
       _baseUrl = (baseUrl ?? _configuredBaseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _isWeb = isWeb ?? kIsWeb;

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://recep.cymezapi.com',
  );
  static final shared = AuthService();

  final http.Client _client;
  final SessionCookieStorage _cookieStorage;
  final String _baseUrl;
  final bool _isWeb;

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
    if (!user.canAccessReception) {
      if (_isWeb) {
        await _send(() => _client.post(_uri('/api/auth/logout')));
      }
      throw const AuthApiException(
        'Tu cuenta no tiene permiso para usar Recepción.',
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

    return user;
  }

  Future<AuthenticatedUser?> restoreSession() async {
    final headers = await _sessionHeaders();
    if (!_isWeb && !headers.containsKey('Cookie')) return null;

    final response = await _send(
      () => _client.get(_uri('/api/auth/session'), headers: headers),
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
    if (!user.canAccessReception) {
      await logout();
      return null;
    }
    return user;
  }

  Future<void> logout() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.post(_uri('/api/auth/logout'), headers: headers),
    );
    if (response.statusCode != 204) {
      throw _responseError(response);
    }
    if (!_isWeb) await _clearCookie();
  }

  Future<List<AccessAccount>> getAccessAccounts() async {
    final headers = await _sessionHeaders();
    final response = await _send(
      () => _client.get(_uri('/api/auth/session'), headers: headers),
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
          (section) => !const {'recepcion', 'administrador'}.contains(section),
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
    );
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    return _parseDepartments(response.body);
  }

  Future<List<Department>> createDepartment(String name) =>
      _saveDepartment(name);

  Future<List<Department>> updateDepartment(int id, String name) {
    if (id <= 0) {
      throw const AuthApiException(
        'El departamento seleccionado no es válido.',
      );
    }
    return _saveDepartment(name, id: id);
  }

  Future<List<Department>> _saveDepartment(String name, {int? id}) async {
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
              body: jsonEncode({'name': normalizedName}),
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

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

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
        return AuthApiException(message);
      }
    } on AuthApiException {
      // Use the status-specific message below when the error body is invalid.
    }

    if (response.statusCode >= 500) {
      return const AuthApiException(
        'No se pudo validar el acceso. Inténtalo de nuevo.',
      );
    }
    return AuthApiException('La solicitud falló (${response.statusCode}).');
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
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
