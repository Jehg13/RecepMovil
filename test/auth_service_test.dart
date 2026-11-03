import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';

void main() {
  test(
    'inicia sesión, restaura y cierra la sesión con la cookie segura',
    () async {
      final cookieStorage = _MemorySessionCookieStorage();
      var sessionRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'identifier': 'recepcion',
            'password': 'test-password',
          });
          return http.Response(
            jsonEncode({'user': _userJson}),
            200,
            headers: {'set-cookie': 'visitas_session=opaque-token; HttpOnly'},
          );
        }

        if (request.url.path == '/api/auth/session') {
          sessionRequests++;
          expect(request.headers['cookie'], 'visitas_session=opaque-token');
          return http.Response(
            jsonEncode({'user': _userJson, 'accounts': []}),
            200,
          );
        }

        if (request.url.path == '/api/auth/logout') {
          expect(request.method, 'POST');
          expect(request.headers['cookie'], 'visitas_session=opaque-token');
          return http.Response('', 204);
        }

        return http.Response('', 404);
      });
      final authService = AuthService(
        client: client,
        cookieStorage: cookieStorage,
        baseUrl: 'https://example.test/',
        isWeb: false,
      );

      final user = await authService.login(' recepcion ', 'test-password');
      expect(user.login, 'recepcion');
      expect(user.canAccessReception, isTrue);
      expect(cookieStorage.value, 'visitas_session=opaque-token');

      final restoredUser = await authService.restoreSession();
      expect(restoredUser?.login, 'recepcion');
      expect(sessionRequests, 1);

      await authService.logout();
      expect(cookieStorage.value, isNull);
    },
  );

  test('rechaza cuentas que no tienen permiso para Recepción', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {..._userJson, 'sectionAccess': <String>[]},
          }),
          200,
          headers: {'set-cookie': 'visitas_session=opaque-token; HttpOnly'},
        );
      }
      if (request.url.path == '/api/auth/logout') {
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final authService = AuthService(
      client: client,
      cookieStorage: _MemorySessionCookieStorage(),
      baseUrl: 'https://example.test',
      isWeb: true,
    );

    await expectLater(
      authService.login('otra-cuenta', 'test-password'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Tu cuenta no tiene permiso para usar Recepción.',
        ),
      ),
    );
  });

  test('consulta y modifica accesos usando la sesión autenticada', () async {
    final cookieStorage = _MemorySessionCookieStorage()
      ..value = 'visitas_session=opaque-token';
    var sessionRequestCount = 0;
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.url.path == '/api/auth/session') {
        sessionRequestCount++;
        return http.Response(
          jsonEncode({
            'user': {..._userJson, 'isAdmin': true},
            'accounts': [_accessAccountJson],
          }),
          200,
        );
      }

      expect(request.url.path, '/api/access/cuenta-1');
      expect(request.method, 'PUT');
      expect(jsonDecode(request.body), {
        'sections': ['administrador'],
      });
      return http.Response(
        jsonEncode({
          'accounts': [
            {
              ..._accessAccountJson,
              'sectionAccess': ['administrador'],
            },
          ],
        }),
        200,
      );
    });
    final authService = AuthService(
      client: client,
      cookieStorage: cookieStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final accounts = await authService.getAccessAccounts();
    expect(sessionRequestCount, 1);
    expect(accounts, hasLength(1));
    expect(accounts.single.login, 'cuenta-1');
    expect(accounts.single.accessLabel, 'Recepción');

    final updatedAccounts = await authService.updateAccess('cuenta-1', [
      'administrador',
    ]);
    expect(updatedAccounts.single.accessLabel, 'Administrador');
  });

  test('consulta, crea, edita y elimina departamentos con sesión', () async {
    final cookieStorage = _MemorySessionCookieStorage()
      ..value = 'visitas_session=opaque-token';
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.method == 'GET' && request.url.path == '/api/departments') {
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 1, 'name': 'Calidad', 'hostCount': 3},
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST') {
        expect(request.url.path, '/api/departments');
        expect(jsonDecode(request.body), {'name': 'Recursos Humanos'});
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 1, 'name': 'Calidad', 'hostCount': 3},
              {'id': 2, 'name': 'Recursos Humanos', 'hostCount': 0},
            ],
          }),
          201,
        );
      }
      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/departments/1');
        expect(jsonDecode(request.body), {'name': 'Calidad e Innovación'});
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 1, 'name': 'Calidad e Innovación', 'hostCount': 3},
              {'id': 2, 'name': 'Recursos Humanos', 'hostCount': 0},
            ],
          }),
          200,
        );
      }
      if (request.method == 'DELETE') {
        expect(request.url.path, '/api/departments/1');
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 2, 'name': 'Recursos Humanos', 'hostCount': 0},
            ],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    final authService = AuthService(
      client: client,
      cookieStorage: cookieStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final departments = await authService.getDepartments();
    expect(departments.single.name, 'Calidad');
    expect(departments.single.hostCount, 3);

    final created = await authService.createDepartment(' Recursos Humanos ');
    expect(created, hasLength(2));
    expect(created.last.id, 2);

    final updated = await authService.updateDepartment(
      1,
      ' Calidad e Innovación ',
    );
    expect(updated.first.name, 'Calidad e Innovación');

    final remaining = await authService.deleteDepartment(1);
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 2);
  });
}

const _userJson = {
  'login': 'recepcion',
  'name': 'Personal de recepción',
  'email': 'recepcion@example.test',
  'role': 'Recepción',
  'isAdmin': false,
  'sectionAccess': ['recepcion'],
};

const _accessAccountJson = {
  'login': 'cuenta-1',
  'name': 'Personal Uno',
  'email': 'personal@example.test',
  'active': 'Y',
  'role': 'Recepción',
  'phone': '5550000000',
  'picture': '',
  'sectionAccess': ['recepcion'],
};

class _MemorySessionCookieStorage implements SessionCookieStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
