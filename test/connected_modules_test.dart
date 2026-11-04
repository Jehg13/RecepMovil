import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';
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
  'visitor': 'Visitante desde API',
  'email': 'visitor@example.test',
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
  testWidgets('las cinco secciones del menú cargan datos desde la API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requestedPaths = <String>{};
    Map<String, dynamic>? createdEquipmentDeclaration;
    Map<String, dynamic>? createdAppointment;
    final service = _service((request) async {
      requestedPaths.add(request.url.path);
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
            'expiresInDays': 30,
          }),
          201,
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
      await tester.tap(find.text(section.key).last);
      await tester.pumpAndSettle();
      expect(find.text(section.value), findsOneWidget);
      switch (section.key) {
        case 'Contratistas/proveedores y visitantes':
          expect(find.text('Empresa desde API'), findsOneWidget);
          expect(find.text('ABC123456XYZ'), findsOneWidget);
          expect(find.text('Mantenimiento'), findsOneWidget);
          expect(find.text('CATEGORÍA'), findsOneWidget);
          expect(find.text('EMPLEADOS'), findsOneWidget);
          expect(find.text('3'), findsOneWidget);
          expect(find.text('REGISTRADO POR'), findsOneWidget);
          expect(find.text('Administración'), findsOneWidget);
          expect(find.text('Activa'), findsOneWidget);
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
            find.text('Visitante desde API · 04/11/2026 · 09:30'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('PERSONAL EXTERNO REGISTRADO · OPCIONAL'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Personal externo API'));
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
            containsPair('appointmentId', 12),
          );
          expect(
            createdEquipmentDeclaration,
            containsPair('externalStaffId', 3),
          );
          expect(
            createdEquipmentDeclaration,
            containsPair('personName', 'Personal externo API'),
          );
          await tester.tap(find.text('Cerrar').last);
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(1280, 900);
          await tester.pumpAndSettle();
        case 'Agenda de citas':
          expect(find.text('Visitante desde API'), findsOneWidget);
          expect(find.text('Anfitrión API'), findsOneWidget);
          expect(find.text('Ver QR'), findsOneWidget);
          await tester.tap(find.text('Ver QR'));
          await tester.pumpAndSettle();
          expect(find.text('Pase de visita'), findsOneWidget);
          expect(find.text('FOLIO  AB12CD34'), findsOneWidget);
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(390, 844);
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
          expect(
            find.text('Persona desde bitácora API · Llegada'),
            findsOneWidget,
          );
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
