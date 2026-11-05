import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:visitas_recep_mobile/auth_service.dart';
import 'package:visitas_recep_mobile/connected_modules.dart';
import 'package:visitas_recep_mobile/main.dart';

const _partner = {
  'id': 8,
  'name': 'Empresa desde API',
  'description': 'Servicios industriales',
  'rfc': 'ABC123456XYZ',
  'category': 'Mantenimiento',
  'subject': '',
  'employeeCount': 3,
  'type': 'Contratista',
  'status': 'Activa',
  'registeredBy': 'Administración',
};

const _appointment = {
  'id': 12,
  'businessPartnerId': 8,
  'date': '2026-11-04',
  'time': '09:30',
  'visitor': 'Personal externo API',
  'email': 'staff@example.test',
  'referenceCode': 'AB12CD34',
  'company': 'Empresa desde API',
  'partnerType': 'Contratista',
  'host': 'Anfitrión API',
  'status': 'Pendiente',
  'equipmentChecklistRequired': false,
};

const _dailyLog = {
  'entries': [
    {
      'id': 4,
      'date': '2026-11-04',
      'time': '09:30',
      'event': 'Llegada',
      'person': 'Persona desde bitácora API',
      'company': 'Empresa desde API',
      'details': '',
      'actorName': 'Recepción',
    },
  ],
  'recentEntries': [],
  'recentTotal': 0,
  'recentPage': 1,
  'recentPages': 1,
  'summary': {'movementCount': 1, 'insideNow': 0, 'pendingArrivals': 1},
  'hosts': <String>[],
  'total': 1,
  'page': 1,
  'pageSize': 30,
  'pages': 1,
};

const _declaration = {
  'id': 17,
  'personName': 'Personal de equipo API',
  'companyName': 'Empresa desde API',
  'status': 'Enviada',
  'createdBy': 'Administración',
  'createdAt': '2026-11-04 09:00:00',
  'appointmentId': 12,
  'visitDate': '2026-11-04',
  'visitTime': '09:30',
  'itemCount': 2,
  'entryStatus': 'Pendiente',
  'exitStatus': 'Pendiente',
  'incidentCount': 0,
  'items': [],
  'inspections': [],
};

const _admin = AuthenticatedUser(
  login: 'admin',
  name: 'Administración',
  email: 'admin@example.test',
  role: 'Administrador',
  isAdmin: true,
  sectionAccess: ['administrador', 'recepcion', 'anfitriones'],
);

void main() {
  testWidgets('registra la entrada de una cita activa', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    Map<String, dynamic>? recordedEntry;
    final requestedPaths = <String>[];
    final service = _service((request) async {
      requestedPaths.add(request.url.path);
      if (request.method == 'POST' && request.url.path == '/api/daily-log') {
        recordedEntry = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 19,
                'businessPartnerId': null,
                'date': today,
                'time': '10:30',
                'visitor': 'Visita de prueba',
                'email': 'visitor@example.test',
                'referenceCode': 'ENTRY19',
                'company': 'Empresa de prueba',
                'host': 'Anfitrión de prueba',
                'status': 'En proceso',
                'equipmentChecklistRequired': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/general-visitors') {
        return http.Response(jsonEncode({'generalVisitors': <Object>[]}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedDailyLogbookPage(
            authService: service,
            isAdmin: true,
            user: _admin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bitácora diaria'), findsOneWidget);
    expect(
      requestedPaths,
      containsAll(['/api/daily-log', '/api/appointments']),
    );
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.tap(find.text('Visita de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar entrada'));
    await tester.pumpAndSettle();

    expect(recordedEntry, containsPair('event', 'Ingreso'));
    expect(recordedEntry, containsPair('appointmentId', 19));
    expect(recordedEntry, containsPair('personName', 'Visita de prueba'));
    expect(find.text('Visita de prueba: entrada registrada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('el modal de bitácora usa superficies claras en modo claro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _service((request) async {
      if (request.url.path == '/api/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
      }
      if (request.url.path == '/api/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/general-visitors') {
        return http.Response(jsonEncode({'generalVisitors': <Object>[]}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: ConnectedDailyLogbookPage(
            authService: service,
            isAdmin: true,
            user: _admin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nuevo registro'));
    await tester.tap(find.text('Nuevo registro'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog).last);
    final dialogSurface = dialog.child! as Container;
    final decoration = dialogSurface.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(
      tester.widget<Text>(find.text('¿A quién vas a registrar?')).style?.color,
      const Color(0xFF17243A),
    );

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    final textField = tester.widget<TextField>(find.byType(TextField).last);
    expect(textField.style?.color, const Color(0xFF17243A));
    expect(textField.decoration?.fillColor, const Color(0xFFF3F6FB));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'anfitriones solo pueden eliminar declaraciones pendientes y admin cualquiera',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _service((request) async {
        if (request.url.path == '/api/equipment/options') {
          return http.Response(
            jsonEncode({
              'partners': <Object>[],
              'staff': <Object>[],
              'appointments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path == '/api/equipment/declarations') {
          return http.Response(
            jsonEncode({
              'declarations': [
                {..._declaration, 'id': 31, 'status': 'Pendiente'},
                {..._declaration, 'id': 32, 'status': 'Enviada'},
              ],
              'total': 2,
              'page': 1,
              'pages': 1,
              'pageSize': 5,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectedEquipmentPage(
              authService: service,
              isAdmin: false,
              canManage: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eliminar'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectedEquipmentPage(
              authService: service,
              isAdmin: true,
              canManage: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eliminar'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'las declaraciones se paginan de cinco en cinco bajo las tarjetas',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requestedPages = <String>[];
      final service = _service((request) async {
        if (request.url.path == '/api/equipment/options') {
          return http.Response(
            jsonEncode({
              'partners': <Object>[],
              'staff': <Object>[],
              'appointments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path == '/api/equipment/declarations') {
          final page = request.url.queryParameters['page']!;
          requestedPages.add(page);
          final firstId = page == '1' ? 1 : 6;
          final declarations = List.generate(
            page == '1' ? 5 : 1,
            (index) => {
              'id': firstId + index,
              'personName': 'Personal ${firstId + index}',
              'companyName': 'Contratista',
              'status': 'Enviada',
              'createdBy': 'Administración',
              'createdAt': '2026-11-04 09:00:00',
              'itemCount': 0,
              'incidentCount': 0,
              'entryStatus': 'Pendiente',
              'exitStatus': 'Pendiente',
            },
          );
          return http.Response(
            jsonEncode({
              'declarations': declarations,
              'total': 6,
              'page': int.parse(page),
              'pages': 2,
              'pageSize': 5,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectedEquipmentPage(
              authService: service,
              isAdmin: true,
              canManage: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();

      expect(requestedPages, ['1']);
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.text('Personal 5'), findsOneWidget);
      expect(find.text('Personal 6'), findsNothing);

      await tester.tap(find.byTooltip('Más registros'));
      await tester.pumpAndSettle();

      expect(requestedPages, ['1', '2']);
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(find.text('Personal 6'), findsOneWidget);
      expect(find.text('Personal 1'), findsNothing);
    },
  );

  test('el cliente tolera la paginación del backend anterior', () async {
    final service = _service((request) async {
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['pageSize'], '5');
      return http.Response(
        jsonEncode({
          'declarations': [
            {..._declaration, 'id': 22},
          ],
          'total': 6,
          'page': 2,
          'pages': 2,
          'pageSize': 7,
        }),
        200,
      );
    });

    final result = await service.getEquipmentDeclarations(page: 2);

    expect(result.declarations, hasLength(1));
    expect(result.total, 6);
    expect(result.page, 2);
    expect(result.pages, 2);
    expect(result.pageSize, 7);
  });

  test(
    'el cliente admite respuestas de paginación sin metadatos opcionales',
    () async {
      final service = _service(
        (request) async => http.Response(
          jsonEncode({
            'declarations': List.generate(
              3,
              (index) => {..._declaration, 'id': index + 1},
            ),
          }),
          200,
        ),
      );

      final result = await service.getEquipmentDeclarations();

      expect(result.declarations, hasLength(3));
      expect(result.total, 3);
      expect(result.page, 1);
      expect(result.pages, 1);
      expect(result.pageSize, 3);
    },
  );

  testWidgets('las cinco secciones del menú cargan datos desde la API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requestedPaths = <String>{};
    Map<String, String>? dailyLogQuery;
    Map<String, dynamic>? createdEquipmentDeclaration;
    Map<String, dynamic>? createdAppointment;
    final service = _service((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/api/daily-log') {
        dailyLogQuery = request.url.queryParameters;
      }
      if (request.method == 'POST' && request.url.path == '/api/appointments') {
        createdAppointment = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'appointments': [_appointment],
          }),
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/equipment/declarations') {
        createdEquipmentDeclaration =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 42,
            'personName': createdEquipmentDeclaration?['personName'],
            'token': 'equipment-link-token',
            'url': 'https://example.test/#equipo=equipment-link-token',
            'expiresInDays': 30,
          }),
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/appointments/12/send-qr') {
        expect(jsonDecode(request.body), {'employeeId': 3});
        return http.Response(
          jsonEncode({'message': 'QR enviado a staff@example.test'}),
          200,
        );
      }
      final Object response = switch (request.url.path) {
        '/api/appointments' => {
          'appointments': [_appointment],
        },
        '/api/business-partners' => {
          'businessPartners': [_partner],
        },
        '/api/external-staff' => {
          'externalStaff': [
            {
              'id': 3,
              'businessPartnerId': 8,
              'fullName': 'Personal externo API',
              'phone': '5551234567',
              'email': 'staff@example.test',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
          ],
        },
        '/api/daily-log' => _dailyLog,
        '/api/equipment/declarations' => {
          'declarations': [_declaration],
          'total': 1,
          'page': 1,
          'pages': 1,
          'pageSize': 5,
        },
        '/api/equipment/options' => {
          'partners': [
            {'id': 8, 'name': 'Empresa desde API', 'type': 'Contratista'},
          ],
          'staff': [
            {
              'id': 3,
              'businessPartnerId': 8,
              'fullName': 'Personal externo API',
              'phone': '5551234567',
              'email': 'staff@example.test',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
          ],
          'appointments': [_appointment],
        },
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(authService: service, user: _admin),
      ),
    );
    await tester.pumpAndSettle();

    const sections = {
      'Contratistas/proveedores y visitantes': 'Empresas y visitantes',
      'Personal de externos': 'Personal externo',
      'Equipo y herramientas': 'Equipo y herramientas',
      'Agenda de citas': 'Agenda de citas',
      'Bitácora diaria': 'Bitácora diaria',
    };

    for (final section in sections.entries) {
      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(section.key),
        350,
        scrollable: find
            .descendant(
              of: find.byType(Drawer),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(section.key).last);
      await tester.pumpAndSettle();
      expect(find.text(section.value), findsOneWidget);
      expect(find.text('RECEP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connected-session-user')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connected-session-user')),
          matching: find.text('Administración'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connected-session-user')),
          matching: find.text('Administrador'),
        ),
        findsOneWidget,
      );
      switch (section.key) {
        case 'Contratistas/proveedores y visitantes':
          expect(find.text('Empresa desde API'), findsOneWidget);
          expect(find.text('ABC123456XYZ'), findsOneWidget);
          expect(find.text('Mantenimiento'), findsOneWidget);
          expect(find.text('CATEGORÍA'), findsOneWidget);
          expect(find.text('EMPLEADOS'), findsOneWidget);
          expect(find.text('3'), findsOneWidget);
          expect(find.text('REGISTRADO POR'), findsOneWidget);
          expect(find.text('Administración'), findsWidgets);
          expect(find.text('Activa'), findsOneWidget);
          expect(find.byTooltip('Acciones del registro'), findsNothing);
          expect(find.text('Editar'), findsOneWidget);
          expect(find.text('Eliminar'), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          await tester.tap(find.text('Registrar'));
          await tester.pumpAndSettle();
          expect(find.text('TIPO DE REGISTRO'), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          await tester.tap(find.text('Visitante').last);
          await tester.pumpAndSettle();
          expect(find.text('Asunto de la visita'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        case 'Personal de externos':
          expect(find.text('Empresa desde API'), findsOneWidget);
          expect(find.text('registrado'), findsOneWidget);
          expect(find.text('Agregar'), findsNothing);
          await tester.tap(find.text('Ver empleados'));
          await tester.pumpAndSettle();
          expect(find.text('Personal externo API'), findsOneWidget);
          expect(find.text('staff@example.test'), findsOneWidget);
          expect(find.text('5551234567'), findsOneWidget);
          expect(find.text('Empresa desde API'), findsNWidgets(2));
          expect(find.text('TIPO DE VÍNCULO'), findsOneWidget);
          expect(find.text('Contratista'), findsWidgets);
          expect(find.byTooltip('Acciones del empleado'), findsNothing);
          expect(find.text('Editar'), findsOneWidget);
          expect(find.text('Eliminar'), findsOneWidget);
          await tester.tap(find.text('Registrar empleado'));
          await tester.pumpAndSettle();
          expect(find.text('Registrar personal externo'), findsOneWidget);
          expect(find.text('DATOS BÁSICOS'), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<int>), findsNothing);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        case 'Equipo y herramientas':
          expect(find.text('Personal de equipo API'), findsOneWidget);
          expect(find.text('Empresa desde API'), findsOneWidget);
          expect(find.text('CITA'), findsOneWidget);
          expect(find.text('04/11/2026 · 09:30'), findsOneWidget);
          expect(find.text('DECLARACIÓN'), findsOneWidget);
          expect(find.text('2 artículos'), findsOneWidget);
          expect(find.text('Enviada'), findsOneWidget);
          expect(find.text('VERIFICACIÓN DE ENTRADA'), findsOneWidget);
          expect(find.text('VERIFICACIÓN DE SALIDA'), findsOneWidget);
          expect(find.text('Pendiente'), findsNWidgets(2));
          expect(find.byTooltip('Acciones de declaración'), findsNothing);
          expect(find.text('Eliminar'), findsOneWidget);
          expect(
            find.widgetWithText(FilledButton, 'Abrir declaración'),
            findsOneWidget,
          );
          expect(find.widgetWithText(FilledButton, 'Eliminar'), findsOneWidget);
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Nueva'));
          await tester.pumpAndSettle();
          expect(find.text('Crear declaración de equipo'), findsOneWidget);
          expect(find.text('CITA VINCULADA · OPCIONAL'), findsOneWidget);
          expect(
            find.text('PERSONAL EXTERNO REGISTRADO · OPCIONAL'),
            findsOneWidget,
          );
          expect(find.text('Nombre de la persona'), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<int>), findsNothing);
          await tester.tap(find.text('CITA VINCULADA · OPCIONAL'));
          await tester.pumpAndSettle();
          expect(find.text('Cita vinculada'), findsOneWidget);
          await tester.tap(
            find.text('Personal externo API · 04/11/2026 · 09:30'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('PERSONAL EXTERNO REGISTRADO · OPCIONAL'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Personal externo API').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Crear enlace'));
          await tester.pumpAndSettle();
          expect(find.text('Enlace generado'), findsOneWidget);
          expect(
            createdEquipmentDeclaration,
            containsPair('businessPartnerId', 8),
          );
          expect(
            createdEquipmentDeclaration,
            containsPair('appointmentId', null),
          );
          expect(
            createdEquipmentDeclaration,
            containsPair('externalStaffId', 3),
          );
          expect(
            createdEquipmentDeclaration,
            containsPair('personName', 'Personal externo API'),
          );
          expect(
            find.text('https://example.test/#equipo=equipment-link-token'),
            findsOneWidget,
          );
          expect(find.text('Copiar enlace'), findsOneWidget);
          await tester.tap(find.text('Cerrar').last);
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(1280, 900);
          await tester.pumpAndSettle();
        case 'Agenda de citas':
          await tester.ensureVisible(find.text('Del día'));
          await tester.tap(find.text('Del día'));
          await tester.pumpAndSettle();
          expect(find.text('Crear cita'), findsNothing);
          final calendarDay = find.byKey(
            const ValueKey('appointment-calendar-day-2026-11-04'),
          );
          await tester.ensureVisible(calendarDay);
          await tester.tap(calendarDay);
          await tester.pumpAndSettle();
          expect(find.text('04/11/2026'), findsOneWidget);
          expect(find.text('1 cita programada'), findsOneWidget);
          expect(find.text('Anfitrión: Anfitrión API'), findsOneWidget);
          expect(find.text('Personal externo API'), findsOneWidget);
          await tester.tap(find.text('Cerrar').last);
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Todas'));
          await tester.tap(find.text('Todas'));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).last, const Offset(0, -900));
          await tester.pumpAndSettle();
          final deleteAppointmentButton = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Eliminar'),
          );
          expect(deleteAppointmentButton.onPressed, isNull);
          expect(find.text('Ver QR'), findsOneWidget);
          await tester.tap(find.text('Ver QR'));
          await tester.pumpAndSettle();
          expect(find.text('Pase de visita'), findsOneWidget);
          expect(find.byType(QrImageView), findsOneWidget);
          expect(find.text('AB12CD34'), findsWidgets);
          await tester.ensureVisible(find.text('Cerrar').last);
          await tester.tap(find.text('Cerrar').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Enviar pase'));
          await tester.pumpAndSettle();
          expect(find.text('Personal externo'), findsOneWidget);
          expect(find.text('Ver QR'), findsOneWidget);
          expect(find.text('Enviar QR'), findsOneWidget);
          await tester.tap(find.text('Enviar QR'));
          await tester.pumpAndSettle();
          expect(find.text('Enviar pase QR'), findsOneWidget);
          await tester.tap(find.text('Enviar QR').last);
          await tester.pumpAndSettle();
          expect(
            find.text(
              'El pase de Personal externo API se envió a staff@example.test.',
            ),
            findsOneWidget,
          );
          expect(find.text('QR enviado'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.menu_rounded).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Agenda de citas').last);
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ver QR').last);
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is QrImageView &&
                  widget.semanticsLabel ==
                      'Código QR de Personal externo API · referencia AB12CD34',
            ),
            findsOneWidget,
          );
          expect(find.text('Personal externo API'), findsWidgets);
          expect(find.bySemanticsLabel('Logo CyMEZ'), findsOneWidget);
          expect(find.text('CÓDIGO DE REFERENCIA'), findsOneWidget);
          expect(find.text('AB12CD34'), findsWidgets);
          expect(find.text('Descargar PNG'), findsOneWidget);
          await tester.ensureVisible(find.text('Cerrar').last);
          await tester.tap(find.text('Cerrar').last);
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Nueva'));
          await tester.pumpAndSettle();
          expect(find.text('Programar una cita'), findsOneWidget);
          expect(find.text('EMPRESA O VISITANTE'), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<int>), findsNothing);
          await tester.tap(find.text('EMPRESA O VISITANTE'));
          await tester.pumpAndSettle();
          expect(find.text('Empresa o visitante'), findsOneWidget);
          await tester.tap(find.text('Empresa desde API').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'Visitante nuevo',
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'nuevo@example.test',
          );
          await tester.enterText(
            find.byType(TextFormField).at(2),
            'Anfitrión nuevo',
          );
          await tester.tap(find.text('Crear cita'));
          await tester.pumpAndSettle();
          expect(
            createdAppointment,
            containsPair('visitorName', 'Visitante nuevo'),
          );
          expect(
            createdAppointment,
            containsPair('visitorEmail', 'nuevo@example.test'),
          );
          expect(createdAppointment, containsPair('businessPartnerId', 8));
          expect(
            createdAppointment,
            containsPair('hostName', 'Anfitrión nuevo'),
          );
          tester.view.physicalSize = const Size(1280, 900);
          await tester.pumpAndSettle();
        case 'Bitácora diaria':
          await tester.drag(
            find.byType(RefreshIndicator).last,
            const Offset(0, -700),
          );
          await tester.pumpAndSettle();
          expect(find.text('Filtrar registros'), findsOneWidget);
          expect(find.text('TIPO DE MOVIMIENTO'), findsNothing);
          await tester.tap(find.byTooltip('Mostrar filtros'));
          await tester.pumpAndSettle();
          expect(find.text('TIPO DE MOVIMIENTO'), findsOneWidget);
          expect(find.text('CATEGORÍA'), findsOneWidget);
          expect(tester.takeException(), isNull);
      }
    }

    expect(
      requestedPaths,
      containsAll({
        '/api/business-partners',
        '/api/external-staff',
        '/api/equipment/declarations',
        '/api/equipment/options',
        '/api/appointments',
        '/api/daily-log',
      }),
    );
    expect(dailyLogQuery?['pageSize'], '5');
    expect(dailyLogQuery?['recentPageSize'], '5');
    expect(tester.takeException(), isNull);
  });
}

AuthService _service(Future<http.Response> Function(http.Request) handler) =>
    AuthService(
      client: MockClient(handler),
      cookieStorage: _MemorySessionCookieStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );

class _MemorySessionCookieStorage implements SessionCookieStorage {
  @override
  Future<String?> read() async => 'visitas_session=test-token';

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}
