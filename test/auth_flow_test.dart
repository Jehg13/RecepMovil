import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';
import 'package:visitas_recep_mobile/company_management.dart';
import 'package:visitas_recep_mobile/main.dart';

void main() {
  testWidgets('el login muestra el dashboard tras validar las credenciales', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
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

  testWidgets('anfitrión puede iniciar sesión y solo ve sus secciones', (
    tester,
  ) async {
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({'user': _hostUserJson}),
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
    await tester.enterText(find.byType(TextField).first, 'anfitrion');
    await tester.enterText(find.byType(TextField).last, 'test-password');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Agenda de citas'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Contratistas/proveedores y visitantes'), findsOneWidget);
    expect(find.text('Personal de externos'), findsOneWidget);
    expect(find.text('Equipo y herramientas'), findsOneWidget);
    expect(find.text('Bitácora diaria'), findsNothing);
    expect(find.text('Accesos'), findsNothing);
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
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
        if (request.url.path == '/api/v1/appointments') {
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
        if (request.url.path == '/api/v1/daily-log') {
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
        if (request.url.path == '/api/v1/daily-log/stats') {
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
    await tester.ensureVisible(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();
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
            request.url.path == '/api/v1/auth/logout') {
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
            request.url.path == '/api/v1/auth/logout') {
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
      if (request.url.path == '/api/v1/auth/session') {
        return http.Response(
          jsonEncode({
            'user': _adminUserJson,
            'accounts': [_accessAccountJson],
          }),
          200,
        );
      }

      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/access/cuenta-1');
      expect(jsonDecode(request.body), {
        'sections': ['anfitriones'],
      });
      return http.Response(
        jsonEncode({
          'accounts': [
            {
              ..._accessAccountJson,
              'sectionAccess': ['anfitriones'],
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
    expect(find.text('Anfitrión'), findsOneWidget);
    await tester.tap(find.text('Anfitrión'));
    await tester.tap(find.text('Guardar acceso'));
    await tester.pumpAndSettle();

    expect(find.text('Permisos actualizados correctamente.'), findsOneWidget);
    expect(find.text('Anfitrión'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('no muestra anfitriones como sección independiente', (
    tester,
  ) async {
    final service = AuthService(
      client: MockClient((request) async => _dashboardResponse(request)),
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

    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Anfitriones'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Accesos')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('navega empresas, departamentos y empleados con tarjetas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = AuthService(
      client: MockClient((request) async {
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/companies') {
          return http.Response(
            jsonEncode({
              'companies': [
                {'id': 1, 'name': 'Empresa de prueba'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/departments') {
          return http.Response(
            jsonEncode({
              'departments': [
                {
                  'id': 4,
                  'name': 'Operaciones',
                  'companyId': 1,
                  'hostCount': 0,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/department-hosts') {
          return http.Response(jsonEncode({'hosts': []}), 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/company-users') {
          expect(request.url.queryParameters['companyId'], '1');
          return http.Response(
            jsonEncode({
              'users': [
                {
                  'login': 'operaciones-1',
                  'name': 'Usuario Operaciones',
                  'email': 'operaciones@example.test',
                  'phone': '5551234567',
                  'role': 'Recepción',
                  'applicationRole': 'recepcion',
                  'active': 'Y',
                  'companyId': 1,
                  'departmentId': 4,
                },
              ],
            }),
            200,
          );
        }
        return _dashboardResponse(request);
      }),
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
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Empresas')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Departamentos'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Empresas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Operaciones'), findsOneWidget);
    await tester.tap(find.text('Operaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario Operaciones'), findsOneWidget);
    expect(find.text('operaciones@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrador de empresa solo ve su directorio', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = AuthService(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/departments') {
          return http.Response(
            jsonEncode({
              'departments': [
                {
                  'id': 14,
                  'name': 'Operaciones',
                  'companyId': 12,
                  'hostCount': 0,
                },
                {
                  'id': 24,
                  'name': 'Finanzas ajena',
                  'companyId': 24,
                  'hostCount': 0,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/department-hosts') {
          return http.Response(jsonEncode({'hosts': []}), 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/company-users') {
          expect(request.url.queryParameters['companyId'], '12');
          return http.Response(
            jsonEncode({
              'users': [
                {
                  'login': 'empresa-user',
                  'name': 'Usuario de mi empresa',
                  'email': 'empresa@example.test',
                  'role': 'Recepción',
                  'applicationRole': 'recepcion',
                  'active': 'Y',
                  'companyId': 12,
                  'departmentId': 14,
                },
                {
                  'login': 'ajeno-user',
                  'name': 'Usuario ajeno',
                  'email': 'ajeno@example.test',
                  'role': 'Recepción',
                  'applicationRole': 'recepcion',
                  'active': 'Y',
                  'companyId': 24,
                  'departmentId': 24,
                },
              ],
            }),
            200,
          );
        }
        return _dashboardResponse(request);
      }),
      cookieStorage: _MemorySessionCookieStorage()
        ..value = 'visitas_session=opaque-token',
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: const AuthenticatedUser(
            login: 'empresa-admin',
            name: 'Administración',
            email: null,
            role: 'Administrador de empresa',
            isAdmin: false,
            isCompanyAdmin: true,
            companyId: 12,
            sectionAccess: [],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Departamentos').last);
    await tester.pumpAndSettle();

    expect(find.text('Operaciones'), findsOneWidget);
    expect(find.text('Finanzas ajena'), findsNothing);
    await tester.tap(find.text('Operaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Usuario de mi empresa'), findsOneWidget);
    expect(find.text('Usuario ajeno'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra historial y código de tablet en tarjetas responsivas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tabletName = 'Recepción principal';
    final service = AuthService(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/companies') {
          return http.Response(
            jsonEncode({
              'companies': [
                {'id': 1, 'name': 'Empresa de prueba'},
                {'id': 2, 'name': 'Empresa secundaria'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/tablet-pairing-codes') {
          return http.Response(
            jsonEncode({
              'codes': [
                {
                  'id': 7,
                  'companyId': 1,
                  'companyName': 'Empresa de prueba',
                  'createdBy': 'admin',
                  'createdAt': '2026-03-01T10:00:00Z',
                  'expiresAt': '2026-03-01T10:10:00Z',
                  'deviceName': tabletName,
                  'status': 'redeemed',
                },
                {
                  'id': 9,
                  'companyId': 2,
                  'companyName': 'Empresa secundaria',
                  'createdBy': 'admin',
                  'createdAt': '2026-03-01T10:01:00Z',
                  'expiresAt': '2026-03-01T10:11:00Z',
                  'deviceName': null,
                  'status': 'active',
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/v1/tablet-pairing-codes/7') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          tabletName = body['deviceName'] as String;
          return http.Response(
            jsonEncode({'message': 'El nombre de la tablet se actualizó.'}),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/tablet-pairing-codes') {
          expect(jsonDecode(request.body), {'companyId': 1});
          return http.Response(
            jsonEncode({
              'code': 'ONEUSE-123',
              'pairingCode': {
                'id': 8,
                'companyId': 1,
                'companyName': 'Empresa de prueba',
                'expiresAt': '2026-03-01T10:10:00Z',
              },
            }),
            201,
          );
        }
        return _dashboardResponse(request);
      }),
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
    await tester.tap(find.text('Tablets').last);
    await tester.pumpAndSettle();

    expect(find.text('Empresa secundaria'), findsOneWidget);
    expect(find.text('Revocar'), findsOneWidget);
    final companyFilter = find.byType(DropdownButtonFormField<int?>).first;
    await tester.tap(companyFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa de prueba').last);
    await tester.pumpAndSettle();

    expect(find.text('Generado por'), findsOneWidget);
    expect(find.text('Vinculada'), findsOneWidget);
    expect(find.text('Recepción principal'), findsWidgets);
    expect(find.text('Editar nombre'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    await tester.ensureVisible(find.text('Editar nombre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar nombre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tablet Recepción 2');
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();

    expect(find.text('Tablet Recepción 2'), findsWidgets);
    await tester.tap(find.text('Generar código'));
    await tester.pumpAndSettle();

    expect(find.text('ONEUSE-123'), findsOneWidget);
    expect(find.textContaining('un solo uso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administra departamentos dentro de empresas', (tester) async {
    final departments = [
      {'id': 1, 'name': 'Calidad', 'hostCount': 2, 'companyId': 1},
      {'id': 2, 'name': 'Compras', 'hostCount': 1, 'companyId': 1},
    ];
    final client = MockClient((request) async {
      expect(request.headers['cookie'], 'visitas_session=opaque-token');
      if (request.method == 'GET' && request.url.path == '/api/v1/companies') {
        return http.Response(
          jsonEncode({
            'companies': [
              {'id': 1, 'name': 'Cymez', 'departmentCount': 2},
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/departments') {
        return http.Response(jsonEncode({'departments': departments}), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/department-hosts') {
        return http.Response(jsonEncode({'hosts': []}), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/company-users') {
        return http.Response(jsonEncode({'users': []}), 200);
      }
      if (request.method == 'POST') {
        expect(request.url.path, '/api/v1/departments');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        departments.add({
          'id': 5,
          'name': body['name'] as String,
          'hostCount': 0,
          'companyId': body['companyId'] as int,
        });
        return http.Response(jsonEncode({'departments': departments}), 201);
      }
      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/v1/departments/1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        departments[0] = {
          'id': 1,
          'name': body['name'] as String,
          'hostCount': 2,
        };
        return http.Response(jsonEncode({'departments': departments}), 200);
      }
      if (request.method == 'DELETE') {
        expect(request.url.path, '/api/v1/departments/1');
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
    await tester.tap(find.text('Empresas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cymez'));
    await tester.pumpAndSettle();

    expect(find.text('Cymez · Departamentos'), findsOneWidget);
    expect(find.text('Calidad'), findsOneWidget);
    expect(find.text('Compras'), findsOneWidget);
    await tester.tap(find.text('Agregar departamento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Recursos Humanos');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Recursos Humanos'), findsOneWidget);
    expect(departments, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrador de empresa ve sus secciones operativas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _service(
            MockClient(
              (request) async =>
                  http.Response(jsonEncode({'departments': []}), 200),
            ),
          ),
          user: const AuthenticatedUser(
            login: 'empresa-admin',
            name: 'Administración Cymez',
            email: null,
            role: 'Administrador de empresa',
            isAdmin: false,
            isCompanyAdmin: true,
            companyId: 12,
            sectionAccess: [],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    for (final section in [
      'Departamentos',
      'Usuarios de empresa',
      'Agenda de citas',
      'Personal de externos',
      'Contratistas/proveedores y visitantes',
      'Equipo y herramientas',
      'Bitácora diaria',
    ]) {
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text(section)),
        findsOneWidget,
      );
    }

    for (final hiddenSection in [
      'Empresas',
      'Administradores de empresa',
      'Tablets',
      'Anfitriones',
      'Accesos',
    ]) {
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text(hiddenSection),
        ),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('las tarjetas y selects usan controles con estilo propio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/api/v1/companies') {
          return http.Response(
            jsonEncode({
              'companies': [
                {'id': 12, 'name': 'Empresa conectada'},
                {'id': 13, 'name': 'Empresa secundaria'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/administrators') {
          return http.Response(
            jsonEncode({
              'administrators': [
                {
                  'login': 'empresa-admin',
                  'name': 'Administradora conectada',
                  'email': 'admin@empresa.test',
                  'active': 'Y',
                  'applicationRole': 'administrador_empresa',
                  'role': 'Gerencia',
                  'phone': '5551234',
                  'companyId': 12,
                  'companyName': 'Empresa conectada',
                },
                {
                  'login': 'empresa-admin-sur',
                  'name': 'Administradora secundaria',
                  'email': 'admin@secundaria.test',
                  'active': 'Y',
                  'applicationRole': 'administrador_empresa',
                  'role': 'Gerencia',
                  'phone': '5554321',
                  'companyId': 13,
                  'companyName': 'Empresa secundaria',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/company-users') {
          final users = <Map<String, dynamic>>[
            {
              'login': 'recepcion-empresa',
              'name': 'Recepción conectada',
              'email': 'recepcion@empresa.test',
              'active': 'Y',
              'applicationRole': 'recepcion',
              'role': 'Recepción',
              'phone': '5559876',
              'companyId': 12,
              'companyName': 'Empresa conectada',
              'departmentId': 14,
              'departmentName': 'Operaciones',
            },
            {
              'login': 'recepcion-secundaria',
              'name': 'Recepción secundaria',
              'email': 'recepcion@secundaria.test',
              'active': 'Y',
              'applicationRole': 'recepcion',
              'role': 'Recepción',
              'phone': '5556789',
              'companyId': 13,
              'companyName': 'Empresa secundaria',
              'departmentId': 15,
              'departmentName': 'Administración',
            },
          ];
          final companyId = request.url.queryParameters['companyId'];
          final filteredUsers = companyId == null
              ? users
              : users
                    .where(
                      (user) => user['companyId'].toString() == companyId,
                    )
                    .toList();
          return http.Response(
            jsonEncode({'users': filteredUsers}),
            200,
          );
        }
        if (request.url.path == '/api/v1/departments') {
          return http.Response(
            jsonEncode({
              'departments': [
                {
                  'id': 14,
                  'name': 'Operaciones',
                  'companyId': 12,
                  'hostCount': 0,
                },
                {
                  'id': 15,
                  'name': 'Administración',
                  'companyId': 13,
                  'hostCount': 0,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('', 404);
      }),
    );

    Future<void> showSection(String section) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanyManagementPage(
              section: section,
              authService: service,
              user: AuthenticatedUser.fromJson(_adminUserJson),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsNWidgets(2));
      expect(find.text('Eliminar'), findsNWidgets(2));
      expect(find.byTooltip('Acciones del registro'), findsNothing);
      expect(tester.takeException(), isNull);
    }

    await showSection('company_admins');
    expect(find.text('Administradora secundaria'), findsOneWidget);
    await showSection('company_users');
    expect(find.text('Recepción secundaria'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Empresa secundaria');
    await tester.pumpAndSettle();
    expect(find.text('Recepción secundaria'), findsOneWidget);
    expect(find.text('Recepción conectada'), findsNothing);
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pumpAndSettle();

    final companyDropdown = find.byType(DropdownButtonFormField<int?>).first;
    await tester.tap(companyDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa conectada').last);
    await tester.pumpAndSettle();

    expect(find.text('Recepción conectada'), findsOneWidget);
    expect(find.text('Recepción secundaria'), findsNothing);
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
  if (request.url.path == '/api/v1/appointments') {
    return http.Response(jsonEncode({'appointments': []}), 200);
  }
  if (request.url.path == '/api/v1/daily-log') {
    return http.Response(
      jsonEncode({
        'summary': {'insideNow': 0, 'pendingArrivals': 0},
        'recentEntries': [],
      }),
      200,
    );
  }
  if (request.url.path == '/api/v1/daily-log/stats') {
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
