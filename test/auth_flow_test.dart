import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';
import 'package:visitas_recep_mobile/main.dart';

void main() {
  testWidgets('el login muestra el dashboard tras validar las credenciales', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({'user': _userJson}),
            200,
            headers: {'set-cookie': 'visitas_session=opaque-token; HttpOnly'},
          );
        }
        return _dashboardResponse(request);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReceptionLoginPage(authService: service)),
    );
    await tester.enterText(find.byType(TextField).first, 'recepcion');
    await tester.enterText(find.byType(TextField).last, 'test-password');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Citas de hoy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra errores de autenticación sin navegar al dashboard', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Usuario o contraseña incorrectos.'}),
          401,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReceptionLoginPage(authService: service)),
    );
    await tester.enterText(find.byType(TextField).first, 'recepcion');
    await tester.enterText(find.byType(TextField).last, 'incorrecta');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Citas de hoy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restaura una sesión válida al iniciar la app', (tester) async {
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/auth/session') {
          return http.Response(
            jsonEncode({'user': _userJson, 'accounts': []}),
            200,
          );
        }
        return _dashboardResponse(request);
      }),
      isWeb: true,
    );

    await tester.pumpWidget(
      ReceptionApp(showSplash: false, authService: service),
    );
    await tester.pumpAndSettle();

    expect(find.text('Citas de hoy'), findsOneWidget);
    expect(find.text('Comenzar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inicio muestra datos reales y la identidad de la sesión', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/appointments') {
          return http.Response(
            jsonEncode({
              'appointments': [
                {
                  'date':
                      request.url.queryParameters['from'] ??
                      DateTime.now().toIso8601String().substring(0, 10),
                  'time': '09:30',
                  'visitor': 'Visitante de prueba',
                  'status': 'Pendiente',
                  'equipmentChecklistRequired': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/daily-log') {
          return http.Response(
            jsonEncode({
              'summary': {'insideNow': 2, 'pendingArrivals': 1},
              'recentEntries': [
                {
                  'date': request.url.queryParameters['from'],
                  'time': '09:00',
                  'event': 'Llegada',
                  'person': 'Visitante de prueba',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('', 404);
      }),
      isWeb: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: AuthenticatedUser.fromJson(_adminUserJson),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Visitante de prueba'), findsWidgets);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Administrador'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra y actualiza las cuentas en la sección Accesos', (
    tester,
  ) async {
    final cookieStorage = _MemorySessionCookieStorage()
      ..value = 'visitas_session=opaque-token';
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.url.path == '/api/auth/session') {
        return http.Response(
          jsonEncode({
            'user': _adminUserJson,
            'accounts': [_accessAccountJson],
          }),
          200,
        );
      }

      expect(request.method, 'PUT');
      expect(request.url.path, '/api/access/cuenta-1');
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
    final service = AuthService(
      client: client,
      cookieStorage: cookieStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: AuthenticatedUser.fromJson(_adminUserJson),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accesos').last);
    await tester.pumpAndSettle();

    expect(find.text('cuenta-1'), findsOneWidget);
    expect(find.text('persona@example.test'), findsOneWidget);
    expect(find.text('Recepción'), findsWidgets);

    await tester.tap(find.text('Editar acceso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador').last);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Permisos actualizados correctamente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consulta, registra y elimina anfitriones desde la API', (
    tester,
  ) async {
    final hosts = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.method == 'GET' &&
          request.url.path == '/api/department-hosts') {
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'GET' && request.url.path == '/api/departments') {
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 4, 'name': 'Recursos Humanos', 'hostCount': 0},
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path == '/api/host-accounts') {
        return http.Response(jsonEncode({'accounts': []}), 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/department-hosts') {
        expect(jsonDecode(request.body), {
          'login': 'host-nuevo',
          'name': 'Anfitrión Nuevo',
          'departmentId': 4,
          'role': '',
          'email': '',
          'phone': '',
        });
        hosts.add({
          'id': 8,
          'login': 'host-nuevo',
          'name': 'Anfitrión Nuevo',
          'departmentId': 4,
          'role': '',
          'email': '',
          'phone': '',
          'accessRoles': [],
        });
        return http.Response(jsonEncode({'hosts': hosts}), 201);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/api/department-hosts/8') {
        hosts.clear();
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      return http.Response('', 404);
    });
    final service = AuthService(
      client: client,
      cookieStorage: _MemorySessionCookieStorage()
        ..value = 'visitas_session=opaque-token',
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: AuthenticatedUser.fromJson(_adminUserJson),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anfitriones').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no hay anfitriones registrados.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Registrar anfitrión'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Anfitrión Nuevo');
    await tester.enterText(find.byType(TextFormField).at(1), 'host-nuevo');
    await tester.ensureVisible(find.text('Registrar anfitrión').last);
    await tester.tap(find.text('Registrar anfitrión').last);
    await tester.pumpAndSettle();

    expect(find.text('Anfitrión Nuevo'), findsOneWidget);
    expect(find.text('Recursos Humanos'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar anfitrión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no hay anfitriones registrados.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra departamentos en dos columnas y guarda cambios', (
    tester,
  ) async {
    final departments = [
      {'id': 1, 'name': 'Calidad', 'hostCount': 2},
      {'id': 2, 'name': 'Compras', 'hostCount': 1},
      {'id': 3, 'name': 'Capacitación', 'hostCount': 0},
      {'id': 4, 'name': 'Dirección', 'hostCount': 0},
    ];
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.method == 'GET' && request.url.path == '/api/departments') {
        return http.Response(jsonEncode({'departments': departments}), 200);
      }
      if (request.method == 'POST') {
        expect(request.url.path, '/api/departments');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        departments.add({
          'id': 5,
          'name': body['name'] as String,
          'hostCount': 0,
        });
        return http.Response(jsonEncode({'departments': departments}), 201);
      }
      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/departments/1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        departments[0] = {
          'id': 1,
          'name': body['name'] as String,
          'hostCount': 2,
        };
        return http.Response(jsonEncode({'departments': departments}), 200);
      }
      if (request.method == 'DELETE') {
        expect(request.url.path, '/api/departments/1');
        departments.removeWhere((department) => department['id'] == 1);
        return http.Response(jsonEncode({'departments': departments}), 200);
      }
      return http.Response('', 404);
    });
    final service = AuthService(
      client: client,
      cookieStorage: _MemorySessionCookieStorage()
        ..value = 'visitas_session=opaque-token',
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: AuthenticatedUser.fromJson(_adminUserJson),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Departamento'));
    await tester.pumpAndSettle();

    final firstCard = tester.getRect(
      find.byKey(const ValueKey('department-card-1')),
    );
    final secondCard = tester.getRect(
      find.byKey(const ValueKey('department-card-2')),
    );
    expect(firstCard.center.dy, closeTo(secondCard.center.dy, 1));
    expect(firstCard.center.dx, lessThan(secondCard.center.dx));
    expect(find.text('2 anfitriones vinculados'), findsOneWidget);

    await tester.tap(find.text('Registrar departamento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Recursos Humanos');
    await tester.tap(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.text('Registrar departamento'),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('5 departamentos'), findsOneWidget);
    expect(departments, hasLength(5));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Recursos Humanos'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('department-card-1')),
        matching: find.byIcon(Icons.edit_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Calidad e Innovación');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Calidad e Innovación'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('department-card-1')),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('department-card-1')), findsNothing);
    expect(departments, hasLength(4));
    expect(tester.takeException(), isNull);
  });
}

AuthService _service(http.Client client, {bool isWeb = false}) {
  return AuthService(
    client: client,
    cookieStorage: _MemorySessionCookieStorage(),
    baseUrl: 'https://example.test',
    isWeb: isWeb,
  );
}

http.Response _dashboardResponse(http.Request request) {
  if (request.url.path == '/api/appointments') {
    return http.Response(jsonEncode({'appointments': []}), 200);
  }
  if (request.url.path == '/api/daily-log') {
    return http.Response(
      jsonEncode({
        'summary': {'insideNow': 0, 'pendingArrivals': 0},
        'recentEntries': [],
      }),
      200,
    );
  }
  return http.Response('', 404);
}

const _userJson = {
  'login': 'recepcion',
  'name': 'Personal de recepción',
  'email': 'recepcion@example.test',
  'role': 'Recepción',
  'isAdmin': false,
  'sectionAccess': ['recepcion'],
};

const _adminUserJson = {
  'login': 'admin',
  'name': 'Administración',
  'email': 'admin@example.test',
  'role': 'Administrador',
  'isAdmin': true,
  'sectionAccess': ['administrador'],
};

const _accessAccountJson = {
  'login': 'cuenta-1',
  'name': 'Persona Uno',
  'email': 'persona@example.test',
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
