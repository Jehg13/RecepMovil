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

    expect(find.text('Agenda de citas'), findsOneWidget);
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

    expect(find.text('Agenda de citas'), findsOneWidget);
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
                  'id': 42,
                  'date':
                      request.url.queryParameters['from'] ??
                      DateTime.now().toIso8601String().substring(0, 10),
                  'time': '09:30',
                  'visitor': 'Visitante de prueba',
                  'company': 'Empresa de prueba',
                  'host': 'Anfitrión de prueba',
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
                  'details': 'Registro manual · Folio 12345',
                  'company': 'Empresa de prueba',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/daily-log/stats') {
          return http.Response(
            jsonEncode({
              'stats': [
                {
                  'date': DateTime.now().toIso8601String().substring(0, 10),
                  'arrivals': 1,
                  'entries': 2,
                  'exits': 0,
                  'observations': 0,
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
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Visitante de prueba'), findsWidgets);
    expect(find.text('Composición de movimientos'), findsOneWidget);
    expect(find.text('Tendencia diaria'), findsOneWidget);
    expect(find.text('Agenda de citas de hoy'), findsOneWidget);
    expect(find.text('Hora'), findsOneWidget);
    expect(find.text('Visitante'), findsOneWidget);
    expect(find.text('Empresa'), findsOneWidget);
    expect(find.text('Anfitrión'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Acciones'), findsOneWidget);
    expect(find.text('Registros del periodo'), findsOneWidget);
    expect(find.text('Registro manual · Folio 12345'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Administrador'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el menú de usuario cambia el tema del dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _service(
            MockClient((request) async => _dashboardResponse(request)),
          ),
          user: AuthenticatedUser.fromJson(_adminUserJson),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('dashboard-home-background'))),
      ).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-theme-switch')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('reception-dashboard-scaffold')),
          )
          .backgroundColor,
      const Color(0xFFF3F7FC),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('dashboard-home-background'))),
      ).brightness,
      Brightness.light,
    );
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final activeHomeItem = find.byKey(const ValueKey('drawer-item-Inicio'));
    final activeHomeTile = tester.widget<ListTile>(activeHomeItem);
    expect(activeHomeTile.selected, isTrue);
    expect(activeHomeTile.selectedTileColor, const Color(0xFFFFE6EC));
    final activeHomeText = tester.widget<Text>(
      find.descendant(of: activeHomeItem, matching: find.text('Inicio')),
    );
    expect(activeHomeText.style?.color, const Color(0xFF9E1230));

    await tester.scrollUntilVisible(
      find.text('Agenda de citas'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Agenda de citas').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('connected-section-root')),
      findsOneWidget,
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('connected-section-root'))),
      ).brightness,
      Brightness.light,
    );

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bitácora diaria'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('connected-section-root')),
      findsOneWidget,
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('connected-section-root'))),
      ).brightness,
      Brightness.light,
    );

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-theme-switch')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('reception-dashboard-scaffold')),
          )
          .backgroundColor,
      const Color(0xFF07101F),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el menú de usuario funciona en las secciones conectadas', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/logout') {
          return http.Response('', 204);
        }
        return _dashboardResponse(request);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: AuthenticatedUser.fromJson(_userJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('connected-section-root')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('connected-session-user')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dashboard-theme-switch')),
      findsOneWidget,
    );
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-theme-switch')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('connected-section-root'))),
      ).brightness,
      Brightness.light,
    );

    await tester.tapAt(const Offset(8, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connected-session-user')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connected-profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el drawer muestra la sesión y permite cerrar sesión', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/logout') {
          return http.Response('', 204);
        }
        return _dashboardResponse(request);
      }),
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

    final sessionHeader = find.byKey(const ValueKey('drawer-session-user'));
    expect(
      find.descendant(of: sessionHeader, matching: find.text('Administración')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sessionHeader, matching: find.text('Administrador')),
      findsOneWidget,
    );
    expect(find.text('Programador'), findsNothing);
    expect(find.text('Acceso corporativo'), findsNothing);
    expect(find.byKey(const ValueKey('drawer-logout')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer-logout')));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recepción solo ve Agenda de citas y Bitácora diaria', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _service(
            MockClient((request) async => _dashboardResponse(request)),
          ),
          user: AuthenticatedUser.fromJson(_userJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Agenda de citas'), findsWidgets);
    expect(find.text('Bitácora diaria'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Departamento'), findsNothing);
    expect(find.text('Anfitriones'), findsNothing);
    expect(find.text('Accesos'), findsNothing);
    expect(find.text('Personal de externos'), findsNothing);
    expect(find.text('Equipo y herramientas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anfitriones solo ven sus cuatro secciones permitidas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _service(
            MockClient((request) async => _dashboardResponse(request)),
          ),
          user: AuthenticatedUser.fromJson(_hostUserJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Contratistas/proveedores y visitantes'), findsOneWidget);
    expect(find.text('Personal de externos'), findsOneWidget);
    expect(find.text('Agenda de citas'), findsWidgets);
    expect(find.text('Equipo y herramientas'), findsOneWidget);
    expect(find.text('Bitácora diaria'), findsNothing);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Departamento'), findsNothing);
    expect(find.text('Anfitriones'), findsNothing);
    expect(find.text('Accesos'), findsNothing);
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

    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('cuenta-1'), findsOneWidget);
    expect(find.text('persona@example.test'), findsOneWidget);
    expect(find.text('Recepción'), findsWidgets);
    final accessCard = tester.widget<Container>(
      find.byKey(const ValueKey('access-account-card-cuenta-1')),
    );
    expect(accessCard.child, isA<Column>());

    await tester.tap(find.text('Editar acceso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador').last);
    await tester.tap(find.text('Guardar acceso'));
    await tester.pumpAndSettle();

    expect(find.text('Permisos actualizados correctamente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('edita solo departamento y elimina anfitriones', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hosts = <Map<String, dynamic>>[
      {
        'id': 8,
        'login': 'host-ana',
        'name': 'Ana García López',
        'departmentId': 4,
        'role': 'Analista',
        'email': 'ana.garcia@example.test',
        'phone': '5551234567',
        'accessRoles': [],
      },
    ];
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
              {'id': 5, 'name': 'Operaciones', 'hostCount': 0},
            ],
          }),
          200,
        );
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/api/department-hosts/8') {
        expect(jsonDecode(request.body), {'departmentId': 5});
        hosts[0]['departmentId'] = 5;
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/api/department-hosts/8') {
        hosts.clear();
        return http.Response(jsonEncode({'hosts': hosts}), 200);
      }
      fail('La pantalla de anfitriones solo debe consultar datos.');
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

    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Ana García López'), findsOneWidget);
    expect(find.text('host-ana'), findsOneWidget);
    expect(find.text('ana.garcia@example.test'), findsOneWidget);
    expect(find.text('Recursos Humanos'), findsOneWidget);
    expect(find.text('Analista'), findsOneWidget);
    expect(find.text('5551234567'), findsOneWidget);
    expect(find.byTooltip('Registrar anfitrión'), findsNothing);
    expect(find.byTooltip('Editar anfitrión'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    await tester.ensureVisible(find.text('Cambiar departamento'));
    await tester.tap(find.text('Cambiar departamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operaciones').last);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Operaciones'), findsOneWidget);
    expect(find.text('Ana García López'), findsOneWidget);
    expect(find.text('ana.garcia@example.test'), findsOneWidget);
    expect(find.text('Analista'), findsOneWidget);
    expect(find.text('5551234567'), findsOneWidget);

    await tester.ensureVisible(find.text('Eliminar').last);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no hay anfitriones registrados.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
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

    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 5));
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
  if (request.url.path == '/api/daily-log/stats') {
    return http.Response(jsonEncode({'stats': []}), 200);
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
