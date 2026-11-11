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

const _reception = AuthenticatedUser(
  login: 'recepcion',
  name: 'Personal de recepción',
  email: 'recepcion@example.test',
  role: 'Recepción',
  isAdmin: false,
  sectionAccess: ['recepcion'],
);

const _host = AuthenticatedUser(
  login: 'host',
  name: 'Anfitrión API',
  email: 'host@example.test',
  role: 'Anfitrión',
  isAdmin: false,
  sectionAccess: ['anfitriones'],
);

void main() {
  testWidgets('la cita muestra QR para cada empleado de la empresa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _service((request) async {
      final Object response = switch (request.url.path) {
        '/api/v1/external-staff' => {
          'externalStaff': [
            {
              'id': 3,
              'businessPartnerId': 8,
              'fullName': 'Empleado con correo',
              'phone': '5551230001',
              'email': 'empleado@example.test',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
            {
              'id': 4,
              'businessPartnerId': 8,
              'fullName': 'Empleado sin correo',
              'phone': '',
              'email': '',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
          ],
        },
        '/api/v1/business-partners' => {
          'businessPartners': [_partner],
        },
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedExternalStaffPage(
            authService: service,
            isAdmin: false,
            canManage: true,
            user: _reception,
            appointment: _appointment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Empleado con correo'), findsOneWidget);
    expect(find.text('Empleado sin correo'), findsOneWidget);
    expect(find.text('Ver QR'), findsNWidgets(2));
    final sendButtons = tester
        .widgetList<FilledButton>(
          find.widgetWithText(FilledButton, 'Enviar QR'),
        )
        .toList();
    expect(sendButtons, hasLength(2));
    expect(
      sendButtons.where((button) => button.onPressed == null),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal externo normal no muestra acciones QR', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _service((request) async {
      final Object response = switch (request.url.path) {
        '/api/v1/external-staff' => {
          'externalStaff': [
            {
              'id': 3,
              'businessPartnerId': 8,
              'fullName': 'Empleado del directorio',
              'phone': '5551230001',
              'email': 'empleado@example.test',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
          ],
        },
        '/api/v1/business-partners' => {
          'businessPartners': [_partner],
        },
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedExternalStaffPage(
            authService: service,
            isAdmin: false,
            canManage: true,
            user: _reception,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver empleados'));
    await tester.pumpAndSettle();
    expect(find.text('Empleado del directorio'), findsOneWidget);
    expect(find.text('Ver QR'), findsNothing);
    expect(find.text('Enviar QR'), findsNothing);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la bitácora abre el pase completo del empleado vinculado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final entry = {
      'id': 91,
      'date': today,
      'time': '09:15',
      'event': 'Llegada',
      'person': 'Empleado individual',
      'company': 'Empresa desde API',
      'appointmentId': 12,
      'externalStaffId': 3,
    };
    final service = _service((request) async {
      final Object response = switch (request.url.path) {
        '/api/v1/daily-log/timers' => {'timers': <Object>[]},
        '/api/v1/daily-log' => {
          ..._dailyLog,
          'entries': [entry],
        },
        '/api/v1/appointments' => {
          'appointments': [_appointment],
        },
        '/api/v1/external-staff' => {
          'externalStaff': [
            {
              'id': 3,
              'businessPartnerId': 8,
              'fullName': 'Empleado individual',
              'phone': '5551230001',
              'email': 'empleado@example.test',
              'relationshipType': 'Contratista',
              'companyName': 'Empresa desde API',
            },
          ],
        },
        '/api/v1/notifications/config' => {'firebase': null},
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedDailyLogbookPage(
            authService: service,
            isAdmin: false,
            user: _reception,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Empleado individual'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Ver QR de visita').first,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Ver QR de visita').first);
    await tester.pumpAndSettle();

    expect(find.text('Pase de visita'), findsOneWidget);
    expect(find.text('Empleado individual'), findsWidgets);
    expect(find.bySemanticsLabel('Logo CyMEZ'), findsOneWidget);
    expect(find.text('CÓDIGO DE REFERENCIA'), findsOneWidget);
    expect(find.text('AB12CD34'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is QrImageView &&
            widget.semanticsLabel ==
                'Código QR de Empleado individual · referencia AB12CD34',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'administración puede actuar en temporizadores en cualquier fase',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final timer = {
        'id': 42,
        'appointmentId': null,
        'visitorRecordId': 7,
        'personName': 'Visitante esperando',
        'phase': 'Llegada',
        'intervalMinutes': 15,
        'startedAt': now.toUtc().toIso8601String(),
        'dueAt': now.add(const Duration(minutes: 15)).toUtc().toIso8601String(),
        'status': 'active',
      };
      final service = _service((request) async {
        final Object response = switch (request.url.path) {
          '/api/v1/daily-log/timers' => {
            'timers': [timer],
          },
          '/api/v1/daily-log' => _dailyLog,
          '/api/v1/appointments' => {'appointments': <Object>[]},
          '/api/v1/notifications/config' => {'firebase': null},
          _ => <String, Object>{},
        };
        return http.Response(jsonEncode(response), 200);
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
      await tester.ensureVisible(find.text('Visitante esperando').first);
      await tester.pumpAndSettle();

      expect(find.text('Repetir 15 min'), findsOneWidget);
      expect(find.text('Cancelar temporizador'), findsOneWidget);
      await tester.tap(find.text('Visitante esperando').first);
      await tester.pumpAndSettle();
      expect(find.text('Repetir 15 min'), findsNWidgets(2));
      expect(find.text('Cancelar temporizador'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el anfitrión puede reagendar una cita que no se presentó', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayString = [
      yesterday.year.toString().padLeft(4, '0'),
      yesterday.month.toString().padLeft(2, '0'),
      yesterday.day.toString().padLeft(2, '0'),
    ].join('-');
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final expectedDate =
        '${tomorrow.day.toString().padLeft(2, '0')}/'
        '${tomorrow.month.toString().padLeft(2, '0')}/${tomorrow.year}';
    final appointment = {
      ..._appointment,
      'date': yesterdayString,
      'status': 'Pendiente',
    };
    final service = _service((request) async {
      final Object response = switch (request.url.path) {
        '/api/v1/appointments' => {
          'appointments': [appointment],
        },
        '/api/v1/business-partners' => {
          'businessPartners': [_partner],
        },
        '/api/v1/host-visitors' => {'visitors': <Object>[]},
        '/api/v1/external-staff' => {'externalStaff': <Object>[]},
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode(response), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedAppointmentsPage(
            authService: service,
            isAdmin: false,
            canManage: true,
            onSendPass: (_) {},
            user: _host,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('No se presentó'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No se presentó'), findsOneWidget);
    await tester.ensureVisible(find.text('Reagendar'));
    await tester.tap(find.text('Reagendar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar cita'), findsOneWidget);
    expect(find.text(expectedDate), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cita tardía avisa al anfitrión y permite reagendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final date = now.toIso8601String().substring(0, 10);
    final previousMinute = now.subtract(const Duration(minutes: 5));
    final time =
        '${previousMinute.hour.toString().padLeft(2, '0')}:'
        '${previousMinute.minute.toString().padLeft(2, '0')}';
    final service = _service((request) async {
      if (request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {..._appointment, 'date': date, 'time': time},
              {..._appointment, 'id': 13, 'date': date, 'status': 'Cancelada'},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedAppointmentsPage(
            authService: service,
            isAdmin: false,
            canManage: true,
            onSendPass: (_) {},
            user: _host,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cita tardía'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tardía'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tardía'), findsOneWidget);
    expect(find.text('Reagendar'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('solo administración ve quién registró movimientos en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final timerStartedAt = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 60))
        .toIso8601String();
    final timerDueAt = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 30))
        .toIso8601String();
    var actorName = '';
    final service = _service((request) async {
      if (request.url.path == '/api/v1/daily-log/timers') {
        return http.Response(
          jsonEncode({
            'timers': List.generate(
              10,
              (index) => {
                'id': 42 + index,
                'appointmentId': null,
                'visitorRecordId': 7 + index,
                'personName': 'Visitante esperando ${index + 1}',
                'phase': 'Ingreso',
                'intervalMinutes': 30,
                'startedAt': timerStartedAt,
                'dueAt': timerDueAt,
                'status': 'active',
              },
            ),
          }),
          200,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(
          jsonEncode({
            ..._dailyLog,
            'entries': [
              {
                'id': 87,
                'date': today,
                'time': '09:15',
                'event': 'Llegada',
                'person': 'Registro de prueba',
                'company': 'Empresa de prueba',
                'details': '',
                'actorName': actorName.isEmpty ? null : actorName,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/v1/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
      }
      return http.Response('{}', 200);
    });

    Widget buildPage(AuthenticatedUser user) => MaterialApp(
      home: Scaffold(
        body: ConnectedDailyLogbookPage(
          key: ValueKey('${user.login}-$actorName'),
          authService: service,
          isAdmin: user.isAdmin,
          user: user,
        ),
      ),
    );

    await tester.pumpWidget(buildPage(_admin));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Temporizadores de seguimiento · 10'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Sin registro'), findsNothing);
    expect(find.textContaining('Registró:'), findsNothing);
    expect(find.text('Visitante esperando 1'), findsOneWidget);
    expect(find.text('Visitante esperando 10'), findsNothing);
    expect(find.textContaining('Repetir 30 min'), findsWidgets);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1 / 2'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(RefreshIndicator).last,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('daily-log-timers-next-page')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('daily-log-timers-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('Visitante esperando 10'), findsOneWidget);

    actorName = 'Administración';
    await tester.pumpWidget(buildPage(_admin));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Registro de prueba'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Registró: Administración'), findsOneWidget);

    await tester.pumpWidget(buildPage(_reception));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Temporizadores de seguimiento · 10'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Registró:'), findsNothing);
    expect(find.text('Visitante esperando 1'), findsOneWidget);
    expect(find.text('Visitante esperando 10'), findsNothing);
    expect(find.textContaining('Repetir 30 min'), findsWidgets);
    expect(find.text('Cancelar temporizador'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('recepción puede repetir una alerta vencida desde su tarjeta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final timer = {
      'id': 42,
      'appointmentId': null,
      'visitorRecordId': 7,
      'personName': 'Visitante esperando',
      'phase': 'Llegada',
      'intervalMinutes': 15,
      'startedAt': now
          .subtract(const Duration(minutes: 17))
          .toUtc()
          .toIso8601String(),
      'dueAt': now
          .subtract(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String(),
      'status': 'active',
    };
    final actions = <String>[];
    var timers = <Map<String, dynamic>>[timer];
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/daily-log/timers') {
        return http.Response(jsonEncode({'timers': timers}), 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/daily-log/timers/42') {
        final action = (jsonDecode(request.body) as Map)['action'] as String;
        actions.add(action);
        timers = [];
        return http.Response(jsonEncode({'timers': timers}), 200);
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/notifications/config') {
        return http.Response(jsonEncode({'firebase': null}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectedDailyLogbookPage(
            authService: service,
            isAdmin: false,
            user: _reception,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Visitante esperando'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(RefreshIndicator).last,
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Visitante esperando').last);
    expect(find.textContaining('desde su llegada'), findsWidgets);
    expect(find.textContaining('Repetir 15 min'), findsWidgets);
    expect(find.text('Cancelar temporizador'), findsNothing);

    await tester.tap(find.text('Visitante esperando').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('desde su llegada'), findsWidgets);
    expect(find.text('Repetir 15 min'), findsWidgets);
    expect(find.text('Cancelar temporizador'), findsNothing);

    await tester.tap(find.text('Repetir 15 min').last);
    await tester.pumpAndSettle();
    expect(actions, ['snooze']);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('cambia entre historial completo, hoy y solo lectura anterior', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final todayString = today.toIso8601String().substring(0, 10);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayString = yesterday.toIso8601String().substring(0, 10);
    final requestedUris = <Uri>[];
    final service = _service((request) async {
      if (request.method == 'GET' && request.url.path == '/api/v1/daily-log') {
        requestedUris.add(request.url);
        final response = Map<String, dynamic>.from(_dailyLog)
          ..['historyRange'] = {
            'firstDate': '2020-01-03',
            'lastDate': yesterdayString,
          }
          ..['entries'] = [
            {
              'id': 87,
              'date': yesterdayString,
              'time': '09:15',
              'event': 'Llegada',
              'person': 'Registro anterior',
              'company': 'Empresa de prueba',
              'details': '',
              'actorName': 'Recepción',
            },
          ];
        return http.Response(jsonEncode(response), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
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
    await tester.scrollUntilVisible(
      find.text('Historial'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(requestedUris.last.queryParameters['from'], '2020-01-03');
    expect(requestedUris.last.queryParameters['to'], yesterdayString);

    await tester.tap(find.text('Actualmente'));
    await tester.pumpAndSettle();
    expect(requestedUris.last.queryParameters['from'], todayString);
    expect(requestedUris.last.queryParameters['to'], todayString);

    await tester.scrollUntilVisible(
      find.text('Registro anterior'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Registro anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Registro histórico · solo lectura'), findsOneWidget);
    expect(find.byTooltip('Eliminar movimiento'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dar entrada'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

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
      if (request.method == 'POST' && request.url.path == '/api/v1/daily-log') {
        recordedEntry = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/v1/appointments') {
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
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
      containsAll(['/api/v1/daily-log', '/api/v1/appointments']),
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

  testWidgets('completa checklist de entrada antes de registrar ingreso', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    Map<String, dynamic>? recordedEntry;
    Map<String, dynamic>? submittedInspection;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 29,
                'businessPartnerId': null,
                'date': today,
                'time': '10:30',
                'visitor': 'Contratista de prueba',
                'email': 'contractor@example.test',
                'referenceCode': 'ENTRY29',
                'company': 'Empresa de prueba',
                'host': 'Anfitrión de prueba',
                'status': 'En proceso',
                'equipmentChecklistRequired': true,
                'equipmentDeclarationId': 9,
                'equipmentEntryChecklistComplete': false,
                'equipmentExitChecklistComplete': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/equipment/declarations/9') {
        return http.Response(
          jsonEncode({
            'declaration': {
              'id': 9,
              'personName': 'Contratista de prueba',
              'companyName': 'Empresa de prueba',
              'status': 'Enviada',
              'items': [
                {
                  'id': 3,
                  'itemType': 'Equipo',
                  'quantity': 1,
                  'product': 'Laptop',
                  'brand': 'Marca',
                  'model': 'Modelo',
                  'serialNumber': 'SERIE-3',
                  'color': 'Negro',
                  'notes': '',
                },
              ],
              'inspections': [],
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.path ==
              '/api/v1/equipment/declarations/9/inspections/entrada') {
        submittedInspection = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'Checklist guardado.'}),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/api/v1/daily-log') {
        recordedEntry = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.tap(find.text('Contratista de prueba'));
    await tester.pumpAndSettle();

    expect(find.text('Completar checklist de entrada'), findsOneWidget);
    expect(find.text('Dar entrada'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dar entrada'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Dar entrada'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Laptop'), findsOneWidget);
    await tester.tap(find.text('Resguardar en recepción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar revisión'));
    await tester.pumpAndSettle();

    expect(submittedInspection?['items']?[0]['keepAtReception'], isTrue);
    expect(submittedInspection?['items']?[0]['checked'], isTrue);
    expect(find.text('Completar checklist de entrada'), findsNothing);
    expect(recordedEntry?['event'], 'Ingreso');
    expect(find.text('Cita programada'), findsOneWidget);
    expect(find.text('Registrar salida'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('mantiene la cita abierta y permite salida desde llegada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    String? latestEvent;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 42,
                'businessPartnerId': 8,
                'date': today,
                'time': '10:30',
                'visitor': 'Personal externo',
                'email': 'contractor@example.test',
                'referenceCode': 'ARRIVAL42',
                'company': 'Empresa contratista',
                'partnerType': 'Contratista',
                'host': 'Anfitrión de prueba',
                'status': 'Pendiente',
                'equipmentChecklistRequired': true,
                'equipmentDeclarationId': 18,
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments/42/employees') {
        final status = switch (latestEvent) {
          'Llegada' => 'En proceso',
          'Ingreso' => 'Dentro',
          'Retiro' => 'Retirado',
          _ => 'Pendiente',
        };
        return http.Response(
          jsonEncode({
            'employees': [
              {'id': 7, 'fullName': 'Contratista de prueba', 'status': status},
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/equipment/declarations/18') {
        return http.Response(
          jsonEncode({
            'declaration': {
              'id': 18,
              'status': 'Enviada',
              'items': [
                {
                  'id': 11,
                  'itemType': 'Equipo',
                  'quantity': 1,
                  'product': 'Laptop',
                  'brand': 'Marca',
                  'model': 'Modelo',
                  'serialNumber': 'SERIE-11',
                  'color': 'Negro',
                  'notes': '',
                },
              ],
              'inspections': [],
            },
          }),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/api/v1/daily-log') {
        latestEvent =
            (jsonDecode(request.body) as Map<String, dynamic>)['event']
                as String;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.tap(find.text('Personal externo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar llegada'));
    await tester.pumpAndSettle();
    expect(find.text('Cita programada'), findsOneWidget);
    expect(find.text('Dar entrada'), findsOneWidget);
    expect(find.text('Registrar salida'), findsOneWidget);

    await tester.tap(find.text('Registrar salida'));
    await tester.pumpAndSettle();
    expect(latestEvent, 'Retiro');
    expect(find.text('Cita programada'), findsOneWidget);
    expect(find.text('Completar checklist de entrada'), findsNothing);
    expect(find.text('Completar checklist de salida'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('permite marcar y corregir la inasistencia de un contratista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    var markedAbsent = false;
    Map<String, dynamic>? attendanceRequest;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 42,
                'businessPartnerId': 8,
                'date': today,
                'time': '10:30',
                'visitor': 'Cuadrilla de prueba',
                'email': '',
                'referenceCode': 'ABSENT42',
                'company': 'Empresa contratista',
                'partnerType': 'Contratista',
                'host': 'Anfitrión de prueba',
                'status': 'Pendiente',
                'equipmentChecklistRequired': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments/42/employees') {
        return http.Response(
          jsonEncode({
            'employees': [
              {
                'id': 7,
                'fullName': 'Empleado ausente',
                'status': markedAbsent ? 'No asistió' : 'Pendiente',
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/v1/appointments/42/employees/7/attendance') {
        attendanceRequest = jsonDecode(request.body) as Map<String, dynamic>;
        markedAbsent = attendanceRequest?['action'] == 'absent';
        return http.Response(
          jsonEncode({'message': 'Asistencia actualizada.'}),
          200,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.tap(find.text('Cuadrilla de prueba'));
    await tester.pumpAndSettle();

    expect(find.text('No asistió'), findsOneWidget);
    await tester.tap(find.text('No asistió'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, no asistió'));
    await tester.pumpAndSettle();

    expect(attendanceRequest, {'action': 'absent'});
    expect(find.text('No asistió'), findsOneWidget);
    expect(find.text('Quitar ausencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('confirma devolución antes de registrar salida', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    Map<String, dynamic>? submittedInspection;
    Map<String, dynamic>? recordedExit;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 30,
                'businessPartnerId': null,
                'date': today,
                'time': '10:30',
                'visitor': 'Contratista en sitio',
                'email': 'contractor@example.test',
                'referenceCode': 'EXIT30',
                'company': 'Empresa de prueba',
                'host': 'Anfitrión de prueba',
                'status': 'Dentro',
                'equipmentChecklistRequired': true,
                'equipmentDeclarationId': 10,
                'equipmentEntryChecklistComplete': true,
                'equipmentExitChecklistComplete': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/equipment/declarations/10') {
        return http.Response(
          jsonEncode({
            'declaration': {
              'id': 10,
              'personName': 'Contratista en sitio',
              'companyName': 'Empresa de prueba',
              'status': 'Enviada',
              'items': [
                {
                  'id': 4,
                  'itemType': 'Herramienta',
                  'quantity': 1,
                  'product': 'Llave',
                  'brand': 'Marca',
                  'model': 'Modelo',
                  'serialNumber': 'SERIE-4',
                  'color': 'Gris',
                  'notes': '',
                },
              ],
              'inspections': [
                {
                  'phase': 'Entrada',
                  'status': 'Completada',
                  'items': [
                    {'declarationItemId': 4, 'keepAtReception': true},
                  ],
                },
              ],
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.path ==
              '/api/v1/equipment/declarations/10/inspections/salida') {
        submittedInspection = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'Checklist guardado.'}),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/api/v1/daily-log') {
        recordedExit = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.tap(find.text('Contratista en sitio'));
    await tester.pumpAndSettle();

    expect(find.text('Completar checklist de salida'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Registrar salida'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Registrar salida'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar devolución al visitante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar revisión'));
    await tester.pumpAndSettle();

    expect(submittedInspection?['items']?[0]['returnedToVisitor'], isTrue);
    expect(recordedExit?['event'], 'Retiro');
    expect(find.text('Cita programada'), findsOneWidget);
    expect(find.text('Visita concluida'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('muestra checklist en el detalle del movimiento de bitácora', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    Map<String, dynamic>? recordedEntry;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(
          jsonEncode({
            'appointments': [
              {
                'id': 31,
                'businessPartnerId': null,
                'date': yesterday,
                'time': '10:30',
                'visitor': 'Contratista desde bitácora',
                'email': 'contractor@example.test',
                'referenceCode': 'ENTRY31',
                'company': 'Empresa de prueba',
                'host': 'Anfitrión de prueba',
                'status': 'En proceso',
                'equipmentChecklistRequired': true,
                'equipmentDeclarationId': 11,
                'equipmentEntryChecklistComplete': false,
                'equipmentExitChecklistComplete': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/equipment/declarations/11') {
        return http.Response(
          jsonEncode({
            'declaration': {
              'id': 11,
              'personName': 'Contratista desde bitácora',
              'companyName': 'Empresa de prueba',
              'status': 'Enviada',
              'items': [
                {
                  'id': 5,
                  'itemType': 'Equipo',
                  'quantity': 1,
                  'product': 'Laptop',
                  'brand': 'Marca',
                  'model': 'Modelo',
                  'serialNumber': 'SERIE-5',
                  'color': 'Negro',
                  'notes': '',
                },
              ],
              'inspections': [],
            },
          }),
          200,
        );
      }
      if (request.method == 'PUT' &&
          request.url.path ==
              '/api/v1/equipment/declarations/11/inspections/entrada') {
        return http.Response(
          jsonEncode({'message': 'Checklist guardado.'}),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/api/v1/daily-log') {
        recordedEntry = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'El movimiento se registró.'}),
          201,
        );
      }
      if (request.url.path == '/api/v1/daily-log') {
        final response = Map<String, dynamic>.from(_dailyLog);
        response['entries'] = [
          {
            'id': 40,
            'date': today,
            'time': '09:30',
            'event': 'Llegada',
            'person': 'Contratista desde bitácora',
            'company': 'Empresa de prueba',
            'details': '',
            'actorName': 'Recepción',
            'appointmentId': 31,
          },
        ];
        return http.Response(jsonEncode(response), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.scrollUntilVisible(
      find.text('Contratista desde bitácora'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Contratista desde bitácora'));
    await tester.pumpAndSettle();

    expect(find.text('Hacer checklist de entrada'), findsOneWidget);
    await tester.tap(find.text('Dar entrada'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar revisión'));
    await tester.pumpAndSettle();
    expect(recordedEntry?['event'], 'Ingreso');
    expect(recordedEntry?['sourceEntryId'], 40);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('rediseña el registro manual y el checklist de salida', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now().toIso8601String().substring(0, 10);
    Map<String, dynamic>? checklistRequest;
    final service = _service((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
      }
      if (request.method == 'GET' && request.url.path == '/api/v1/daily-log') {
        final response = Map<String, dynamic>.from(_dailyLog);
        response['entries'] = [
          {
            'id': 42,
            'date': today,
            'time': '10:15',
            'event': 'Ingreso',
            'person': 'Alberto Gutiérrez',
            'company': 'Público general',
            'details': 'Registro manual · Folio 33872179',
            'actorName': 'Recepción',
            'visitorRecordId': 77,
          },
        ];
        return http.Response(jsonEncode(response), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/visitor-kiosk/registrations') {
        return http.Response(
          jsonEncode({
            'registrations': [
              {
                'id': 55,
                'visitorRecordId': 77,
                'folio': '33872179',
                'visitorName': 'Alberto Gutiérrez',
                'companyName': 'Público general',
                'visitReason': 'Entrevista',
                'identificationType': 'INE, Gafete',
                'authorizationStatus': 'Autorizada',
                'createdAt': '${today}T10:00:00',
                'entryChecklistComplete': true,
                'exitChecklistComplete': false,
                'items': [
                  {
                    'id': 8,
                    'type': 'Herramienta',
                    'description': 'Taladro inalámbrico',
                    'brand': 'Dewalt',
                    'model': 'DCD791',
                    'quantity': 1,
                    'serialNumber': 'DW-24018',
                  },
                ],
                'inspections': [
                  {
                    'phase': 'Entrada',
                    'items': [
                      {'itemId': 8, 'keepAtReception': true},
                    ],
                  },
                ],
                'audit': [
                  {
                    'action': 'Checklist de entrada completado',
                    'actorName': 'Recepción',
                    'createdAt': '$today 10:05',
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/api/v1/visitor-kiosk/registrations/55') {
        checklistRequest = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'Checklist guardado.'}),
          200,
        );
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
    await tester.scrollUntilVisible(
      find.text('Alberto Gutiérrez'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Alberto Gutiérrez').first);
    await tester.pumpAndSettle();

    expect(find.text('Registro de visitante'), findsOneWidget);
    expect(find.text('PROCESO DE VISITA'), findsOneWidget);
    expect(find.text('ACTIVIDAD DEL REGISTRO'), findsOneWidget);
    expect(find.text('Revisar salida'), findsOneWidget);
    final registrationDialog = tester.widget<Dialog>(find.byType(Dialog).last);
    final registrationSurface = registrationDialog.child! as Container;
    final registrationDecoration =
        registrationSurface.decoration! as BoxDecoration;
    expect(registrationDecoration.color, Colors.white);

    await tester.tap(find.text('Revisar salida'));
    await tester.pumpAndSettle();
    expect(find.text('CONTROL DE SALIDA'), findsOneWidget);
    expect(find.text('Devoluciones y revisión final'), findsOneWidget);
    expect(find.text('Taladro inalámbrico'), findsWidgets);
    expect(find.text('Confirmar devolución'), findsOneWidget);
    expect(find.text('Confirmar inspección'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar devolución'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar inspección'));
    await tester.pumpAndSettle();

    expect(checklistRequest?['action'], 'complete-exit-checklist');
    expect(checklistRequest?['items']?[0]['returnedToVisitor'], isTrue);
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
      if (request.url.path == '/api/v1/appointments') {
        return http.Response(jsonEncode({'appointments': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/daily-log') {
        return http.Response(jsonEncode(_dailyLog), 200);
      }
      if (request.url.path == '/api/v1/external-staff') {
        return http.Response(jsonEncode({'externalStaff': <Object>[]}), 200);
      }
      if (request.url.path == '/api/v1/general-visitors') {
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
        if (request.url.path == '/api/v1/equipment/options') {
          return http.Response(
            jsonEncode({
              'partners': <Object>[],
              'staff': <Object>[],
              'appointments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/equipment/declarations') {
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
        if (request.url.path == '/api/v1/equipment/options') {
          return http.Response(
            jsonEncode({
              'partners': <Object>[],
              'staff': <Object>[],
              'appointments': <Object>[],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/equipment/declarations') {
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
    Map<String, String>? appointmentPartnerQuery;
    Map<String, String>? appointmentVisitorsQuery;
    Map<String, dynamic>? createdEquipmentDeclaration;
    Map<String, dynamic>? createdAppointment;
    Map<String, dynamic>? createdVisitorProfile;
    final service = _service((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/api/v1/business-partners') {
        appointmentPartnerQuery = request.url.queryParameters;
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/host-visitors') {
        appointmentVisitorsQuery = request.url.queryParameters;
      }
      if (request.url.path == '/api/v1/daily-log') {
        dailyLogQuery = request.url.queryParameters;
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/appointments') {
        createdAppointment = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'appointments': [_appointment],
          }),
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/host-visitors') {
        createdVisitorProfile =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'visitors': [
              {'id': 42, ...createdVisitorProfile!},
            ],
          }),
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/equipment/declarations') {
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
          request.url.path == '/api/v1/appointments/12/send-qr') {
        expect(jsonDecode(request.body), {'employeeId': 3});
        return http.Response(
          jsonEncode({'message': 'QR enviado a staff@example.test'}),
          200,
        );
      }
      final Object response = switch (request.url.path) {
        '/api/v1/appointments' => {
          'appointments': [_appointment],
        },
        '/api/v1/business-partners' => {
          'businessPartners': [_partner],
        },
        '/api/v1/host-visitors' => {'visitors': <Object>[]},
        '/api/v1/department-hosts' => {
          'hosts': [
            {
              'id': 5,
              'login': 'host.api',
              'name': 'Anfitrión API',
              'departmentId': 2,
              'role': 'Anfitrión',
              'email': 'host@example.test',
              'phone': '5559876543',
            },
          ],
        },
        '/api/v1/external-staff' => {
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
        '/api/v1/daily-log' => _dailyLog,
        '/api/v1/equipment/declarations' => {
          'declarations': [_declaration],
          'total': 1,
          'page': 1,
          'pages': 1,
          'pageSize': 5,
        },
        '/api/v1/equipment/options' => {
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
          expect(deleteAppointmentButton.onPressed, isNotNull);
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
          await tester.tap(find.text('Guardar visitante'));
          await tester.pumpAndSettle();
          expect(find.text('Guardar visitante personal'), findsOneWidget);
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'Visitante personal guardado',
          );
          await tester.tap(find.text('Guardar y usar'));
          await tester.pumpAndSettle();
          expect(
            createdVisitorProfile,
            containsPair('fullName', 'Visitante personal guardado'),
          );
          expect(createdVisitorProfile, containsPair('phone', ''));
          expect(createdVisitorProfile, containsPair('email', ''));
          await tester.tap(find.text('EMPRESA O VISITANTE'));
          await tester.pumpAndSettle();
          expect(find.text('Empresa o visitante'), findsOneWidget);
          await tester.tap(find.text('Empresa desde API').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Selecciona personal o elige “Otro”'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Personal externo API').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Selecciona un anfitrión'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Anfitrión API').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Crear cita'));
          await tester.pumpAndSettle();
          expect(
            createdAppointment,
            containsPair('visitorName', 'Personal externo API'),
          );
          expect(
            createdAppointment,
            containsPair('visitorEmail', 'staff@example.test'),
          );
          expect(createdAppointment, containsPair('businessPartnerId', 8));
          expect(createdAppointment, containsPair('hostName', 'Anfitrión API'));
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
        '/api/v1/business-partners',
        '/api/v1/external-staff',
        '/api/v1/equipment/declarations',
        '/api/v1/equipment/options',
        '/api/v1/appointments',
        '/api/v1/daily-log',
      }),
    );
    expect(dailyLogQuery?['pageSize'], '5');
    expect(dailyLogQuery?['recentPageSize'], '5');
    expect(appointmentPartnerQuery?['scope'], 'appointment');
    expect(appointmentVisitorsQuery?['scope'], 'appointment');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
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
