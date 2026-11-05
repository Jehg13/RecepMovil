import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';

void main() {
  test(
    'consulta datos reales de Inicio para la fecha local indicada',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        if (request.url.path == '/api/appointments') {
          return http.Response(
            jsonEncode({
              'appointments': [
                {
                  'id': 12,
                  'date': '2026-11-03',
                  'time': '09:30',
                  'visitor': 'Visitante de hoy',
                  'company': 'Empresa de hoy',
                  'host': 'Anfitrión de hoy',
                  'status': 'Pendiente',
                  'equipmentChecklistRequired': true,
                },
                {
                  'id': 13,
                  'date': '2026-11-04',
                  'time': '10:00',
                  'visitor': 'Visitante de mañana',
                  'company': 'Otra empresa',
                  'host': 'Otro anfitrión',
                  'status': 'Pendiente',
                  'equipmentChecklistRequired': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/daily-log') {
          if (request.url.queryParameters['from'] == '2026-11-03') {
            expect(request.url.queryParameters['to'], '2026-11-03');
            return http.Response(
              jsonEncode({
                'summary': {'insideNow': 2, 'pendingArrivals': 1},
                'recentEntries': [
                  {
                    'date': '2026-11-03',
                    'time': '09:00',
                    'event': 'Llegada',
                    'person': 'Visitante de bitácora',
                  },
                ],
              }),
              200,
            );
          }
          expect(request.url.queryParameters['from'], '2026-10-28');
          expect(request.url.queryParameters['to'], '2026-11-03');
          expect(request.url.queryParameters['recentPageSize'], '6');
          return http.Response(
            jsonEncode({
              'recentEntries': [
                {
                  'date': '2026-11-03',
                  'time': '09:00',
                  'event': 'Retiro',
                  'person': 'Visitante de bitácora',
                  'details': 'Registro manual · Folio 12345',
                  'company': 'Empresa de bitácora',
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/daily-log/stats');
        expect(request.url.queryParameters['from'], '2026-10-28');
        expect(request.url.queryParameters['to'], '2026-11-03');
        return http.Response(
          jsonEncode({
            'stats': [
              {
                'date': '2026-11-03',
                'arrivals': 2,
                'entries': 1,
                'exits': 0,
                'observations': 1,
              },
            ],
          }),
          200,
        );
      });
      final service = AuthService(
        client: client,
        cookieStorage: _MemorySessionCookieStorage()
          ..value = 'visitas_session=opaque-token',
        baseUrl: 'https://example.test',
        isWeb: false,
      );

      final data = await service.getDashboardData(DateTime(2026, 11, 3));

      expect(data.appointments, hasLength(1));
      expect(data.appointments.single.visitor, 'Visitante de hoy');
      expect(data.appointments.single.company, 'Empresa de hoy');
      expect(data.appointments.single.host, 'Anfitrión de hoy');
      expect(data.insideNow, 2);
      expect(data.pendingArrivals, 1);
      expect(data.recentEntries.single.person, 'Visitante de bitácora');
      expect(data.dailyActivity, hasLength(7));
      expect(data.dailyActivity.first.date, '2026-10-28');
      expect(data.dailyActivity.last.arrivals, 2);
      expect(data.dailyActivity.last.entries, 1);
      expect(data.recentEntries.single.event, 'Retiro');
      expect(data.recentEntries.single.company, 'Empresa de bitácora');
      expect(
        data.recentEntries.single.details,
        'Registro manual · Folio 12345',
      );
    },
  );

  test(
    'envía tamaño de cinco registros a las dos páginas de bitácora',
    () async {
      final service = AuthService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['pageSize'], '5');
          expect(request.url.queryParameters['recentPageSize'], '5');
          return http.Response(
            jsonEncode({
              'entries': [],
              'summary': <String, Object>{},
              'hosts': [],
              'total': 0,
              'pages': 1,
            }),
            200,
          );
        }),
        baseUrl: 'https://example.test',
        isWeb: true,
      );

      await service.getDailyLog(
        from: '2026-11-03',
        to: '2026-11-03',
        pageSize: 5,
        recentPageSize: 5,
      );
    },
  );

  test(
    'conecta al stream SSE autenticado y detecta sus actualizaciones',
    () async {
      final service = AuthService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/events');
          expect(request.headers['accept'], 'text/event-stream');
          expect(request.headers['cookie'], 'visitas_session=opaque-token');
          return http.Response(': connected\n\ndata: update\n\n', 200);
        }),
        cookieStorage: _MemorySessionCookieStorage()
          ..value = 'visitas_session=opaque-token',
        baseUrl: 'https://example.test',
        isWeb: false,
      );

      final events = await service.watchRealtimeUpdates().toList();

      expect(events, [RealtimeEvent.connected, RealtimeEvent.update]);
    },
  );

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

  test('consulta y administra anfitriones con sesión', () async {
    final cookieStorage = _MemorySessionCookieStorage()
      ..value = 'visitas_session=opaque-token';
    final hosts = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.method == 'GET' &&
          request.url.path == '/api/department-hosts') {
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'GET' && request.url.path == '/api/host-accounts') {
        return http.Response(
          jsonEncode({
            'accounts': [
              {
                'login': 'host-1',
                'name': 'Host One',
                'email': 'host@example.test',
                'role': 'Gerente',
                'phone': '5551234567',
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/host-access/host-1') {
        return http.Response(
          jsonEncode({
            'sectionAccess': ['anfitriones'],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/department-hosts') {
        expect(jsonDecode(request.body), {
          'login': 'host-1',
          'name': 'Host One',
          'departmentId': 4,
          'role': 'Gerente',
          'email': 'host@example.test',
          'phone': '5551234567',
        });
        hosts.add(_departmentHostJson);
        return http.Response(jsonEncode({'hosts': hosts}), 201);
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/api/department-hosts/1') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        hosts[0] = {..._departmentHostJson, ...body};
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/api/department-hosts/1') {
        hosts.clear();
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      return http.Response('', 404);
    });
    final authService = AuthService(
      client: client,
      cookieStorage: cookieStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final accounts = await authService.getHostAccounts();
    expect(accounts.single.login, 'host-1');
    await authService.grantHostAccess(accounts.single.login);
    final created = await authService.createDepartmentHost(
      login: accounts.single.login,
      name: accounts.single.name!,
      departmentId: 4,
      role: accounts.single.role!,
      email: accounts.single.email!,
      phone: accounts.single.phone!,
    );
    expect(created.single.name, 'Host One');
    expect((await authService.getDepartmentHosts()).single.departmentId, 4);

    final updated = await authService.updateDepartmentHost(
      id: 1,
      login: 'host-1',
      name: 'Host Updated',
      departmentId: 4,
    );
    expect(updated.single.name, 'Host Updated');

    expect(await authService.deleteDepartmentHost(1), isEmpty);
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

const _departmentHostJson = {
  'id': 1,
  'login': 'host-1',
  'name': 'Host One',
  'departmentId': 4,
  'role': 'Gerente',
  'email': 'host@example.test',
  'phone': '5551234567',
  'accessRoles': ['Anfitriones'],
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
