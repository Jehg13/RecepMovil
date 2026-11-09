import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';

void main() {
  test('solicita un enlace de recuperación por correo', () async {
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/password-recovery');
        expect(jsonDecode(request.body), {'email': 'persona@example.test'});
        return http.Response(
          jsonEncode({
            'message': 'Si el correo está asociado a una cuenta activa, recibirás instrucciones para recuperar tu contraseña.',
          }),
          202,
        );
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final message = await service.requestPasswordRecovery(
      '  persona@example.test ',
    );

    expect(message, contains('cuenta activa'));
  });

  test(
    'conserva el límite de reintento del servidor en errores de login',
    () async {
      final service = AuthService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/login');
          return http.Response(
            jsonEncode({
              'error': 'Demasiados intentos fallidos. Espera 5 minutos antes de volver a intentarlo.',
            }),
            429,
            headers: {'retry-after': '300'},
          );
        }),
        cookieStorage: _MemorySessionCookieStorage(),
        baseUrl: 'https://example.test',
        isWeb: false,
      );

      await expectLater(
        service.login('persona', 'incorrecta'),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.retryAfterSeconds,
                'retryAfterSeconds',
                300,
              )
              .having(
                (error) => error.message,
                'message',
                contains('5 minutos'),
              ),
        ),
      );
    },
  );

  test(
    'registra una visita manual con clave idempotente y consulta su estado',
    () async {
      const idempotencyKey = '123e4567-e89b-42d3-a456-426614174000';
      Map<String, dynamic>? submittedRegistration;
      final service = AuthService(
        client: MockClient((request) async {
          expect(request.headers['Idempotency-Key'], idempotencyKey);
          if (request.method == 'POST') {
            expect(request.url.path, '/api/v1/visitor-kiosk/registrations');
            submittedRegistration =
                jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({'folio': '12345678', 'visitorName': 'Ana Pérez'}),
              201,
            );
          }
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/visitor-kiosk/status');
          return http.Response(
            jsonEncode({
              'folio': '12345678',
              'visitorName': 'Ana Pérez',
              'authorizationStatus': 'Autorizada',
              'entryChecklistComplete': true,
              'entered': false,
            }),
            200,
          );
        }),
        cookieStorage: _MemorySessionCookieStorage(),
        baseUrl: 'https://example.test',
        isWeb: false,
      );

      final registration = {
        'visitorName': 'Ana Pérez',
        'companyName': 'Público general',
        'visitReason': 'Entrega',
        'carriesItems': true,
        'items': [
          {
            'type': 'Herramienta',
            'description': 'Taladro',
            'quantity': 1,
            'brand': '',
            'model': '',
            'serialNumber': '',
            'color': '',
          },
        ],
        'identificationTypes': ['INE'],
        'identificationHeldForSafekeeping': false,
      };
      final created = await service.createVisitorKioskRegistration(
        idempotencyKey: idempotencyKey,
        registration: registration,
      );
      final status = await service.getVisitorKioskStatus(idempotencyKey);

      expect(submittedRegistration, registration);
      expect(created['folio'], '12345678');
      expect(status['authorizationStatus'], 'Autorizada');
      expect(status['entryChecklistComplete'], isTrue);
      expect(status['entered'], isFalse);
    },
  );

  test(
    'consulta datos reales de Inicio para la fecha local indicada',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        if (request.url.path == '/api/v1/appointments') {
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
        if (request.url.path == '/api/v1/daily-log') {
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
        expect(request.url.path, '/api/v1/daily-log/stats');
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
          expect(request.url.path, '/api/v1/events');
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

  test('conecta al stream SSE de estado con clave del registro', () async {
    const idempotencyKey = '123e4567-e89b-42d3-a456-426614174000';
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/visitor-kiosk/events');
        expect(request.url.queryParameters['key'], idempotencyKey);
        expect(request.headers['accept'], 'text/event-stream');
        expect(request.headers.containsKey('cookie'), isFalse);
        return http.Response(': connected\n\ndata: update\n\n', 200);
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final events = await service
        .watchVisitorKioskUpdates(idempotencyKey)
        .toList();

    expect(events, [RealtimeEvent.connected, RealtimeEvent.update]);
  });

  test(
    'inicia sesión, restaura y cierra la sesión con la cookie segura',
    () async {
      final cookieStorage = _MemorySessionCookieStorage();
      var sessionRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
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

        if (request.url.path == '/api/v1/auth/session') {
          sessionRequests++;
          expect(request.headers['cookie'], 'visitas_session=opaque-token');
          return http.Response(
            jsonEncode({'user': _userJson, 'accounts': []}),
            200,
          );
        }

        if (request.url.path == '/api/v1/auth/logout') {
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
      expect(user.canAccessApp, isTrue);
      expect(cookieStorage.value, 'visitas_session=opaque-token');

      final restoredUser = await authService.restoreSession();
      expect(restoredUser?.login, 'recepcion');
      expect(sessionRequests, 1);

      await authService.logout();
      expect(cookieStorage.value, isNull);
    },
  );

  test('permite iniciar y restaurar sesión a cuentas de anfitrión', () async {
    final cookieStorage = _MemorySessionCookieStorage();
    final hostUser = {..._userJson, ..._hostUserJson};
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({'user': hostUser}),
          200,
          headers: {'set-cookie': 'visitas_session=opaque-token; HttpOnly'},
        );
      }

      if (request.url.path == '/api/v1/auth/session') {
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        return http.Response(jsonEncode({'user': hostUser}), 200);
      }

      return http.Response('', 404);
    });
    final authService = AuthService(
      client: client,
      cookieStorage: cookieStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final user = await authService.login('anfitrion', 'test-password');
    expect(user.login, 'anfitrion');
    expect(user.canAccessReception, isFalse);
    expect(user.canAccessApp, isTrue);
    expect(cookieStorage.value, 'visitas_session=opaque-token');

    final restoredUser = await authService.restoreSession();
    expect(restoredUser?.login, 'anfitrion');
    expect(restoredUser?.canAccessReception, isFalse);
  });

  test('rechaza cuentas sin secciones habilitadas', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {..._userJson, 'sectionAccess': <String>[]},
          }),
          200,
          headers: {'set-cookie': 'visitas_session=opaque-token; HttpOnly'},
        );
      }
      if (request.url.path == '/api/v1/auth/logout') {
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
          'Tu cuenta no tiene permisos habilitados para usar la aplicación.',
        ),
      ),
    );
  });

  test('identifica las cuentas de anfitrión en la lista de Accesos', () {
    final account = AccessAccount.fromJson({
      ..._accessAccountJson,
      'sectionAccess': ['anfitriones'],
    });

    expect(account.accessLabel, 'Anfitrión');
  });

  test('consulta y modifica accesos usando la sesión autenticada', () async {
    final cookieStorage = _MemorySessionCookieStorage()
      ..value = 'visitas_session=opaque-token';
    var sessionRequestCount = 0;
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.url.path == '/api/v1/auth/session') {
        sessionRequestCount++;
        return http.Response(
          jsonEncode({
            'user': {..._userJson, 'isAdmin': true},
            'accounts': [_accessAccountJson],
          }),
          200,
        );
      }

      expect(request.url.path, '/api/v1/access/cuenta-1');
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
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/departments') {
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
        expect(request.url.path, '/api/v1/departments');
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
        expect(request.url.path, '/api/v1/departments/1');
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
        expect(request.url.path, '/api/v1/departments/1');
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
          request.url.path == '/api/v1/department-hosts') {
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/host-accounts') {
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
          request.url.path == '/api/v1/department-hosts') {
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
          request.url.path == '/api/v1/department-hosts/1') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        hosts[0] = {..._departmentHostJson, ...body};
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/api/v1/department-hosts/1') {
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

  test('consulta declaración de cita y guarda inspección de equipo', () async {
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/equipment/declarations/42') {
          return http.Response(
            jsonEncode({
              'declaration': {
                'id': 42,
                'personName': 'Personal externo',
                'companyName': 'Contratista',
                'status': 'Enviada',
                'items': [],
                'inspections': [],
              },
            }),
            200,
          );
        }
        if (request.method == 'PUT' &&
            request.url.path ==
                '/api/v1/equipment/declarations/42/inspections/entrada') {
          expect(jsonDecode(request.body), {
            'items': [
              {
                'declarationItemId': 7,
                'quantity': 1,
                'product': 'Taladro',
                'brand': 'Marca',
                'model': 'Modelo',
                'serialNumber': 'SERIE-1',
                'color': 'Negro',
                'notes': '',
                'incident': false,
                'checked': true,
                'keepAtReception': true,
                'returnedToVisitor': false,
              },
            ],
          });
          return http.Response(
            jsonEncode({'message': 'Verificación guardada.'}),
            200,
          );
        }
        return http.Response('', 404);
      }),
      cookieStorage: _MemorySessionCookieStorage()
        ..value = 'visitas_session=opaque-token',
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    final response = await service.getEquipmentDeclaration(42);
    expect(response['declaration']['id'], 42);
    await service.submitEquipmentInspection(42, 'entrada', [
      {
        'declarationItemId': 7,
        'quantity': 1,
        'product': 'Taladro',
        'brand': 'Marca',
        'model': 'Modelo',
        'serialNumber': 'SERIE-1',
        'color': 'Negro',
        'notes': '',
        'incident': false,
        'checked': true,
        'keepAtReception': true,
        'returnedToVisitor': false,
      },
    ]);
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

const _hostUserJson = {
  'login': 'anfitrion',
  'name': 'Personal anfitrión',
  'email': 'anfitrion@example.test',
  'role': 'Anfitrión',
  'isAdmin': false,
  'sectionAccess': ['anfitriones'],
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
