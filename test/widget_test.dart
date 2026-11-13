import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visitas_recep_mobile/auth_service.dart';

import 'package:visitas_recep_mobile/main.dart';

class _MemoryOnboardingStorage implements MobileOnboardingStorage {
  bool seen = false;

  @override
  Future<bool> hasSeenOnboarding() async => seen;

  @override
  Future<void> markOnboardingSeen() async {
    seen = true;
  }
}

class _MemorySessionCookieStorage implements SessionCookieStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

class _MemoryVisitorKioskDraftStorage implements VisitorKioskDraftStorage {
  Map<String, dynamic>? draft;

  @override
  Future<Map<String, dynamic>?> readDraft() async =>
      draft == null ? null : Map<String, dynamic>.from(draft!);

  @override
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    this.draft = Map<String, dynamic>.from(draft);
  }

  @override
  Future<void> clearDraft() async {
    draft = null;
  }
}

class _MemoryTabletDeviceStorage implements TabletDeviceStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
}

void main() {
  testWidgets('Muestra la bienvenida de Recepción', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ReceptionApp(showSplash: false));

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Bienvenido')).style?.fontWeight,
      FontWeight.w900,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      find.text('Registra tus visitas de forma rápida,\nsegura y sencilla.'),
      findsOneWidget,
    );
    final titleWidth = tester.getSize(find.text('Bienvenido')).width;
    final logoWidth = tester
        .getSize(find.byKey(const ValueKey('reception-logo')))
        .width;
    expect(titleWidth, greaterThan(0));
    expect(logoWidth, greaterThan(0));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/onboarding-benefits-bar.webp',
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('Página 1 de 3'), findsNothing);
  });

  testWidgets('Muestra la splash móvil antes de la bienvenida', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ReceptionApp(
        visitorKioskDraftStorage: _MemoryVisitorKioskDraftStorage(),
        tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      ),
    );

    expect(
      tester.getRect(find.byType(Scaffold).first),
      Offset.zero & const Size(390, 844),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/reception-mobile-splash.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Bienvenido'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('startup-splash-loading-bar')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Bienvenido'), findsOneWidget);
  });

  testWidgets('Muestra la splash panorámica con progreso en tablet', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ReceptionApp(
        visitorKioskDraftStorage: _MemoryVisitorKioskDraftStorage(),
        tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      ),
    );

    expect(
      tester.getRect(find.byType(Scaffold).first),
      Offset.zero & const Size(1024, 768),
    );
    final tabletSplash = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/reception-tablet-splash.png' &&
          widget.fit == BoxFit.cover,
    );
    expect(tabletSplash, findsOneWidget);
    expect(tester.getRect(tabletSplash), Offset.zero & const Size(1024, 768));
    expect(
      find.byKey(const ValueKey('startup-splash-loading-bar')),
      findsOneWidget,
    );
    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump();
    expect(find.text('Vincula esta tablet'), findsOneWidget);
    expect(find.text('Vincular tablet'), findsOneWidget);
  });

  testWidgets('Se adapta a una pantalla pequeña', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(492, 682),
    ]) {
      tester.view.physicalSize = size;

      await tester.pumpWidget(const ReceptionApp(showSplash: false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      if (size.shortestSide < 600 || size.height > size.width) {
        expect(find.byType(Image), findsWidgets);
      }
    }
  });

  testWidgets('Se adapta a celulares y tabletas', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(360, 640),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1366, 1024),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ReceptionApp(
          key: ValueKey(size),
          showSplash: false,
          visitorKioskDraftStorage: _MemoryVisitorKioskDraftStorage(),
          tabletDeviceStorage: _MemoryTabletDeviceStorage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Welcome: $size');
      if (size.width >= 600 && size.height > size.width) {
        expect(find.text('Gira tu tablet'), findsOneWidget);
        expect(find.text('Volver al inicio de sesión'), findsNothing);
      } else if (size.shortestSide >= 600) {
        expect(find.text('Vincula esta tablet'), findsOneWidget);
        expect(find.text('Vincular tablet'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsNothing);
      } else {
        expect(find.text('Comenzar'), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
      }
    }
  });

  testWidgets('La vinculación solicita nombre e informa el uso del código', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ReceptionApp(
        showSplash: false,
        tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vincula esta tablet'), findsOneWidget);
    expect(find.text('Nombre de la tablet'), findsOneWidget);
    expect(find.text('Código de vinculación'), findsOneWidget);
    expect(
      find.textContaining('El código se usa una sola vez'),
      findsOneWidget,
    );
    expect(
      find.textContaining('contacta a soporte; no intentes reutilizarlo'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('La tablet vinculada muestra su nombre y empresa', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final tabletStorage = _MemoryTabletDeviceStorage()
      ..value = jsonEncode({
        'token': 'tablet-token',
        'companyId': 12,
        'companyName': 'Cymez Norte',
        'deviceId': 7,
        'deviceName': 'Recepción principal',
      });
    final service = AuthService(
      client: MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/app-releases/latest')) {
          return http.Response(jsonEncode({'updateAvailable': false}), 200);
        }
        expect(request.url.path, '/api/v1/tablet-pairing/device');
        expect(request.headers['authorization'], 'Bearer tablet-token');
        return http.Response(
          jsonEncode({
            'deviceId': 7,
            'companyId': 12,
            'companyName': 'Cymez Norte',
            'deviceName': 'Recepción principal actualizada',
          }),
          200,
        );
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      tabletDeviceStorage: tabletStorage,
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      ReceptionApp(
        showSplash: false,
        authService: service,
        tabletDeviceStorage: tabletStorage,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tablet-device-identity')),
      findsOneWidget,
    );
    expect(find.text('Recepción principal actualizada'), findsOneWidget);
    expect(find.text('Cymez Norte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'La bienvenida móvil agranda logo y botón y los separa del borde',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const ReceptionApp(showSplash: false));
      await tester.pumpAndSettle();

      final logo = tester.widget<Image>(
        find.byKey(const ValueKey('reception-logo')),
      );
      final startButton = tester.getRect(find.text('Comenzar'));
      final welcomeTitle = tester.widget<Text>(find.text('Bienvenido'));
      final startLabel = tester.widget<Text>(find.text('Comenzar'));

      expect(logo.width, greaterThanOrEqualTo(300));
      expect(welcomeTitle.style!.fontSize, greaterThanOrEqualTo(48));
      expect(startLabel.style!.fontSize, greaterThanOrEqualTo(20));
      expect(startButton.bottom, lessThanOrEqualTo(814));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('El kiosco no bloquea por orientación', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(800, 600),
      const Size(900, 600),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
      await tester.pumpAndSettle();

      if (size.shortestSide >= 600 && size.height > size.width) {
        expect(find.text('Gira tu tablet'), findsOneWidget, reason: '$size');
        expect(
          find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
          findsNothing,
          reason: '$size',
        );
        expect(
          find.byKey(const ValueKey('tablet-walk-in-form-card')),
          findsNothing,
          reason: '$size',
        );
      } else if (size.shortestSide >= 600) {
        expect(find.text('Gira tu celular'), findsNothing, reason: '$size');
        expect(
          find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
          findsOneWidget,
          reason: '$size',
        );
        expect(find.text('CONTROL DE ACCESO'), findsOneWidget, reason: '$size');
        expect(find.text('Comenzar registro'), findsOneWidget, reason: '$size');
        expect(
          find.byKey(const ValueKey('walk-in-tablet-header')),
          findsOneWidget,
          reason: '$size',
        );
        final panelRect = tester.getRect(
          find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
        );
        final buttonRect = tester.getRect(
          find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
        );
        expect(
          panelRect.center.dx,
          closeTo(size.width / 2, 1),
          reason: 'Welcome panel is centered: $size',
        );
        expect(
          buttonRect.top,
          greaterThan(panelRect.top),
          reason: 'Welcome action stays inside the panel: $size',
        );
        expect(
          buttonRect.bottom,
          lessThan(panelRect.bottom),
          reason: 'Welcome action stays inside the panel: $size',
        );
        final benefitsRect = tester.getRect(
          find.byKey(const ValueKey('tablet-kiosk-benefits')),
        );
        final copyRect = tester.getRect(
          find.byKey(const ValueKey('tablet-kiosk-welcome-copy')),
        );
        expect(
          copyRect.center.dy,
          lessThan((panelRect.top + benefitsRect.top) / 2 + 20),
          reason: 'Welcome copy remains near the center of its area: $size',
        );
        final benefitsContentTransform = tester.widget<Transform>(
          find.byKey(const ValueKey('tablet-kiosk-benefits-content')),
        );
        expect(
          benefitsContentTransform.transform.storage[13],
          lessThan(0),
          reason: 'Benefits content is raised within its bar: $size',
        );
        for (final title in [
          'Proceso rápido',
          'Seguro y confiable',
          'Acceso controlado',
        ]) {
          final benefitRect = tester.getRect(
            find.byKey(ValueKey('walk-in-benefit-$title')),
          );
          final subtitleRect = tester.getRect(
            find.byKey(ValueKey('walk-in-benefit-subtitle-$title')),
          );
          expect(
            benefitRect.center.dy,
            lessThan(benefitsRect.center.dy),
            reason: '$title is centered slightly higher in the bar: $size',
          );
          expect(
            subtitleRect.left,
            greaterThanOrEqualTo(benefitRect.left),
            reason: '$title subtitle stays in its cell: $size',
          );
          expect(
            subtitleRect.right,
            lessThanOrEqualTo(benefitRect.right),
            reason: '$title subtitle stays in its cell: $size',
          );
          expect(
            subtitleRect.bottom,
            lessThanOrEqualTo(benefitsRect.bottom),
            reason: '$title subtitle stays in benefits bar: $size',
          );
        }
      } else {
        expect(find.text('Gira tu celular'), findsNothing, reason: '$size');
        expect(find.text('Comenzar registro'), findsOneWidget, reason: '$size');
      }
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('El botón de bienvenida tablet inicia el registro', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 600),
      const Size(1024, 768),
      const Size(1366, 1024),
      const Size(1200, 800),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(key: ValueKey(size), home: const WalkInVisitorPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('PASO 1 DE 4'), findsOneWidget, reason: '$size');
      expect(find.text('IDENTIFICACIÓN DE VISITA'), findsOneWidget);
      expect(find.text('Soy público general'), findsOneWidget);
      expect(find.text('REGISTRO DE VISITANTES'), findsOneWidget);
      final brandLogo = tester.widget<Image>(
        find.byKey(const ValueKey('walk-in-tablet-brand-logo')),
      );
      expect(
        (brandLogo.image as AssetImage).assetName,
        'assets/images/cymez-visitor-logo.webp',
      );
      expect(find.byType(ImageFiltered), findsWidgets);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('walk-in-tablet-header')))
            .height,
        closeTo(88 * (size.width / 1024).clamp(.75, 1.25), 1),
      );
      expect(
        find.byKey(const ValueKey('tablet-walk-in-form-card')),
        findsOneWidget,
        reason: '$size',
      );
      final formCard = tester.widget<Container>(
        find.byKey(const ValueKey('tablet-walk-in-form-card')),
      );
      expect(
        (formCard.decoration! as BoxDecoration).image!.image,
        isA<AssetImage>().having(
          (image) => image.assetName,
          'assetName',
          'assets/images/visitor-feature-card.webp',
        ),
      );
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('tablet-walk-in-form-card')),
      );
      expect(cardRect.width, lessThan(size.width * .93), reason: '$size');
      expect(cardRect.center.dx, closeTo(size.width / 2, 1), reason: '$size');
      expect(
        cardRect.width / cardRect.height,
        closeTo(1191 / 719, .01),
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }

    await tester.ensureVisible(find.text('Anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsOneWidget,
    );
  });

  testWidgets('Completa registro sin cita y muestra estado del checklist', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 1024);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? submittedRegistration;
    String? registrationKey;
    final service = AuthService(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/visitor-kiosk/registrations' &&
            request.method == 'POST') {
          registrationKey = request.headers['Idempotency-Key'];
          submittedRegistration =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'folio': '12345678', 'visitorName': 'Ana Pérez'}),
            201,
          );
        }
        if (request.url.path == '/api/v1/visitor-kiosk/status') {
          expect(request.headers['Idempotency-Key'], registrationKey);
          return http.Response(
            jsonEncode({
              'folio': '12345678',
              'visitorName': 'Ana Pérez',
              'authorizationStatus': 'Autorizada',
              'entryChecklistComplete': true,
              'entered': true,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/visitor-kiosk/events') {
          expect(request.url.queryParameters['key'], registrationKey);
          return http.Response(': connected\n\ndata: update\n\n', 200);
        }
        return http.Response('{}', 404);
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );
    final storage = _MemoryVisitorKioskDraftStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: WalkInVisitorPage(authService: service, draftStorage: storage),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ana Pérez');
    await tester.enterText(find.byType(TextField).at(1), 'Público general');
    await tester.enterText(find.byType(TextField).at(2), 'Entrega');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Equipo y herramientas'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tablet-equipment-no')));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tablet-identification-title')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tablet-identification-option-INE')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tablet-identification-option-Pasaporte')),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tablet-review-title')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tablet-review-confirmation')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('tablet-review-submit')),
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('tablet-review-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('tablet-review-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(submittedRegistration?['visitorName'], 'Ana Pérez');
    expect(submittedRegistration?['carriesItems'], isFalse);
    expect(submittedRegistration?['identificationTypes'], ['INE', 'Pasaporte']);
    expect(
      submittedRegistration?.containsKey('identificationHeldForSafekeeping'),
      isFalse,
    );
    expect(find.text('Visita registrada correctamente'), findsOneWidget);
    expect(find.text('12345678'.split('').join(' ')), findsOneWidget);
    expect(storage.draft?['step'], 5);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('tablet-walk-in-home-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsOneWidget,
    );
    expect(storage.draft, isNull);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Restaura una visita enviada después de reabrir el kiosco', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 1024);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const idempotencyKey = '123e4567-e89b-42d3-a456-426614174000';
    final storage = _MemoryVisitorKioskDraftStorage()
      ..draft = {
        'started': true,
        'step': 5,
        'visitorName': 'Ana Pérez',
        'companyName': 'Público general',
        'visitReason': 'Entrega',
        'publicGeneral': true,
        'carriesItems': true,
        'items': <Object>[],
        'editingItem': <String, Object?>{},
        'identificationType': 'INE',
        'identificationHeldForSafekeeping': false,
        'idempotencyKey': idempotencyKey,
        'folio': '12345678',
        'authorizationStatus': 'Pendiente',
        'entryChecklistComplete': false,
        'entered': false,
      };
    final service = AuthService(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/visitor-kiosk/status') {
          expect(request.headers['Idempotency-Key'], idempotencyKey);
          return http.Response(
            jsonEncode({
              'folio': '12345678',
              'visitorName': 'Ana Pérez',
              'authorizationStatus': 'Pendiente',
              'entryChecklistComplete': false,
              'entered': false,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/visitor-kiosk/events') {
          expect(request.url.queryParameters['key'], idempotencyKey);
          return http.Response(': connected\n\n', 200);
        }
        return http.Response('{}', 404);
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WalkInVisitorPage(authService: service, draftStorage: storage),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('Esperando autorización de entrada'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('1 2 3 4 5 6 7 8'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Regresa a Inicio al restaurar una visita ya confirmada', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 1024);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const idempotencyKey = '123e4567-e89b-42d3-a456-426614174001';
    final storage = _MemoryVisitorKioskDraftStorage()
      ..draft = {
        'started': true,
        'step': 5,
        'visitorName': 'Ana Pérez',
        'companyName': 'Público general',
        'visitReason': 'Entrega',
        'publicGeneral': true,
        'carriesItems': false,
        'items': <Object>[],
        'editingItem': <String, Object?>{},
        'identificationTypes': <String>['INE'],
        'idempotencyKey': idempotencyKey,
        'folio': '12345678',
        'authorizationStatus': 'Pendiente',
        'entryChecklistComplete': false,
        'entered': false,
      };
    final service = AuthService(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/visitor-kiosk/status') {
          expect(request.headers['Idempotency-Key'], idempotencyKey);
          return http.Response(
            jsonEncode({
              'folio': '12345678',
              'visitorName': 'Ana Pérez',
              'authorizationStatus': 'Autorizada',
              'entryChecklistComplete': true,
              'entered': true,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
      cookieStorage: _MemorySessionCookieStorage(),
      tabletDeviceStorage: _MemoryTabletDeviceStorage(),
      baseUrl: 'https://example.test',
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WalkInVisitorPage(authService: service, draftStorage: storage),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsOneWidget,
    );
    expect(find.text('Visita registrada correctamente'), findsNothing);
    expect(storage.draft, isNull);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('El kiosco tolera una ventana temporalmente diminuta', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(2, 2);
    await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El teclado no reduce el formulario del kiosco ni el login', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const MaterialApp(home: ReceptionLoginPage()));
    await tester.pumpAndSettle();
    final loginFormSize = tester.getSize(
      find.byKey(const ValueKey('mobile-login-form-card')),
    );
    final loginLogoSize = tester.getSize(
      find.byKey(const ValueKey('mobile-login-logo')),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-login-form-card'))),
      loginFormSize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-login-logo'))),
      loginLogoSize,
    );

    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
    );
    await tester.pumpAndSettle();
    final kioskCardSize = tester.getSize(
      find.byKey(const ValueKey('tablet-walk-in-form-card')),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('tablet-walk-in-form-card'))),
      kioskCardSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('La visita sin cita bloquea orientación vertical en tablets', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tablet-walk-in-form-card')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpAndSettle();
    expect(find.text('Gira tu tablet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tablet-walk-in-form-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsNothing,
    );

    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();
    expect(find.text('Gira tu tablet'), findsNothing);
    expect(
      find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El paso de equipo de tablet muestra opciones y formulario', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 600),
      const Size(1024, 768),
      const Size(1366, 1024),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(key: ValueKey(size), home: const WalkInVisitorPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Ana Pérez');
      await tester.enterText(find.byType(TextField).at(1), 'Cymez');
      await tester.enterText(find.byType(TextField).at(2), 'Visita de prueba');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('PASO 2 DE 4'), findsOneWidget, reason: '$size');
      expect(
        find.text('Equipo y herramientas'),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        find.byKey(const ValueKey('walk-in-tablet-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tablet-equipment-yes')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tablet-equipment-no')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tablet-equipment-entry-form')),
        findsNothing,
        reason: '$size',
      );
      final compactCardHeight = tester
          .getRect(find.byKey(const ValueKey('tablet-walk-in-form-card')))
          .height;

      await tester.tap(find.byKey(const ValueKey('tablet-equipment-yes')));
      await tester.pumpAndSettle();
      final expandedCardHeight = tester
          .getRect(find.byKey(const ValueKey('tablet-walk-in-form-card')))
          .height;
      expect(
        find.byKey(const ValueKey('tablet-equipment-entry-form')),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        expandedCardHeight,
        greaterThan(compactCardHeight),
        reason: 'The card grows to fit the item form: $size',
      );
      expect(find.text('Agregar artículo'), findsOneWidget, reason: '$size');
      final nameLabel = tester.getRect(
        find.byKey(
          const ValueKey('tablet-equipment-label-Nombre o descripción *'),
        ),
      );
      final nameInput = tester.getRect(find.byType(TextField).first);
      expect(
        nameLabel.bottom,
        lessThan(nameInput.top),
        reason: 'Field labels appear above their inputs: $size',
      );
      await tester.tap(
        find.byKey(const ValueKey('tablet-equipment-type-select')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Equipo').last, findsOneWidget);
      expect(find.text('Herramienta'), findsOneWidget);
      await tester.tap(find.text('Herramienta'));
      await tester.pumpAndSettle();
      expect(find.text('Herramienta'), findsOneWidget);
      await tester.ensureVisible(find.text('Agregar artículo'));
      await tester.tap(find.text('Agregar artículo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe el nombre o la descripción del artículo.'),
        findsOneWidget,
        reason: '$size',
      );
      await tester.enterText(find.byType(TextField).first, 'Laptop');
      await tester.tap(find.text('Agregar artículo'));
      await tester.pumpAndSettle();
      expect(find.text('Herramienta: Laptop'), findsOneWidget, reason: '$size');
      await tester.tap(find.byKey(const ValueKey('tablet-equipment-edit-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Laptop de prueba');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(
        find.text('Herramienta: Laptop de prueba'),
        findsOneWidget,
        reason: '$size',
      );
      await tester.tap(find.byKey(const ValueKey('tablet-equipment-delete-0')));
      await tester.pumpAndSettle();
      expect(
        find.text('Herramienta: Laptop de prueba'),
        findsNothing,
        reason: '$size',
      );

      await tester.tap(find.byKey(const ValueKey('tablet-equipment-no')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tablet-equipment-none-message')),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('El paso de identificación se adapta a tablets', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 600),
      const Size(1024, 768),
      const Size(1366, 1024),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('tablet-identification-$size'),
          home: const WalkInVisitorPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('tablet-kiosk-welcome-start-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Ana Pérez');
      await tester.enterText(find.byType(TextField).at(1), 'Cymez');
      await tester.enterText(find.byType(TextField).at(2), 'Visita de prueba');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tablet-equipment-no')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('PASO 3 DE 4'), findsOneWidget, reason: '$size');
      expect(find.text('Identificación'), findsOneWidget, reason: '$size');
      expect(
        find.byKey(const ValueKey('walk-in-tablet-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tablet-identification-safekeeping')),
        findsNothing,
        reason: '$size',
      );
      for (final type in [
        'INE',
        'Gafete',
        'Pasaporte',
        'Licencia de conducir',
        'Otra identificación',
      ]) {
        expect(
          find.byKey(ValueKey('tablet-identification-option-$type')),
          findsOneWidget,
          reason: '$size',
        );
      }

      await tester.tap(
        find.byKey(const ValueKey('tablet-identification-option-Pasaporte')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('tablet-identification-option-INE')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull, reason: '$size');

      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('PASO 4 DE 4'), findsOneWidget, reason: '$size');
      expect(find.text('Revisa tu registro'), findsOneWidget, reason: '$size');
      expect(find.text('Pasaporte, INE'), findsOneWidget, reason: '$size');
      for (final section in [
        'NOMBRE',
        'EMPRESA O PROCEDENCIA',
        'ASUNTO',
        'EQUIPO Y HERRAMIENTAS',
        'IDENTIFICACIÓN',
      ]) {
        expect(
          find.byKey(ValueKey('tablet-review-summary-$section')),
          findsOneWidget,
          reason: '$size',
        );
      }
      expect(find.text('Declaración de resguardo'), findsNothing);
      expect(tester.takeException(), isNull, reason: '$size');

      final cardRect = tester.getRect(
        find.byKey(const ValueKey('tablet-walk-in-form-card')),
      );
      expect(cardRect.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(cardRect.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(cardRect.bottom, lessThanOrEqualTo(size.height), reason: '$size');

      await tester.ensureVisible(find.text('Anterior'));
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('PASO 3 DE 4'), findsOneWidget, reason: '$size');
    }
  });

  testWidgets('La bienvenida reduce escala en tablets pequeñas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
    await tester.pumpAndSettle();
    final compactTitleSize = tester
        .widget<Text>(find.text('Bienvenido a nuestras'))
        .style!
        .fontSize!;

    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('larger-tablet'),
        home: WalkInVisitorPage(),
      ),
    );
    await tester.pumpAndSettle();
    final largeTitleSize = tester
        .widget<Text>(find.text('Bienvenido a nuestras'))
        .style!
        .fontSize!;
    expect(compactTitleSize, lessThan(largeTitleSize));
  });

  testWidgets('Los beneficios se reducen y suben en tablets pequeñas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
    await tester.pumpAndSettle();
    final smallTitle = tester
        .widget<Text>(find.text('Proceso rápido'))
        .style!
        .fontSize!;
    final smallBarRect = tester.getRect(
      find.byKey(const ValueKey('tablet-kiosk-benefits')),
    );
    final smallBenefitRect = tester.getRect(
      find.byKey(const ValueKey('walk-in-benefit-Proceso rápido')),
    );
    expect(smallBenefitRect.center.dy, lessThan(smallBarRect.center.dy));

    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('large-tablet-benefits'),
        home: WalkInVisitorPage(),
      ),
    );
    await tester.pumpAndSettle();
    final largeTitle = tester
        .widget<Text>(find.text('Proceso rápido'))
        .style!
        .fontSize!;
    expect(smallTitle, lessThan(largeTitle));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Comenzar abre la segunda pantalla del onboarding', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ReceptionApp(showSplash: false));

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Registra tus'), findsOneWidget);
    expect(find.text('visitas'), findsOneWidget);
    expect(find.text('Entrada de visitantes'), findsOneWidget);
    expect(
      find.textContaining('Registra cada ingreso fácilmente'),
      findsOneWidget,
    );
    expect(find.text('02.'), findsNothing);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.bySemanticsLabel('Página 1 de 3'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Omitir finaliza el onboarding y evita mostrarlo otra vez', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final storage = _MemoryOnboardingStorage();

    await tester.pumpWidget(
      ReceptionApp(
        key: const ValueKey('onboarding-first-launch'),
        showSplash: false,
        onboardingStorage: storage,
      ),
    );
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    expect(storage.seen, isTrue);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    await tester.pumpWidget(
      ReceptionApp(
        key: const ValueKey('onboarding-second-launch'),
        showSplash: false,
        onboardingStorage: storage,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Entrada de visitantes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Omitir funciona en las tres pantallas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final pageBuilders = <Widget Function(MobileOnboardingStorage)>[
      (storage) => ReceptionOnboardingPage(onboardingStorage: storage),
      (storage) => ReceptionControlOnboardingPage(onboardingStorage: storage),
      (storage) => ReceptionReadyOnboardingPage(onboardingStorage: storage),
    ];
    for (var index = 0; index < pageBuilders.length; index++) {
      final storage = _MemoryOnboardingStorage();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('onboarding-skip-$index'),
          home: pageBuilders[index](storage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
      expect(storage.seen, isTrue);
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Completar el onboarding también se guarda como visto', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final storage = _MemoryOnboardingStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionReadyOnboardingPage(onboardingStorage: storage),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(storage.seen, isTrue);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El primer onboarding separa imagen, logo y texto en tablet', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ReceptionOnboardingPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tablet-onboarding-left-background')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tablet-onboarding-right-background')),
      findsOneWidget,
    );
    final leftBackgroundWidth = tester
        .getSize(
          find.byKey(const ValueKey('tablet-onboarding-left-background')),
        )
        .width;
    final rightBackgroundWidth = tester
        .getSize(
          find.byKey(const ValueKey('tablet-onboarding-right-background')),
        )
        .width;
    expect(
      leftBackgroundWidth / (leftBackgroundWidth + rightBackgroundWidth),
      closeTo(0.6, 0.01),
    );
    expect(
      find.byKey(const ValueKey('tablet-registration-onboarding-logo')),
      findsOneWidget,
    );
    final leftPanelWidth = tester
        .getSize(find.byKey(const ValueKey('tablet-registration-left-panel')))
        .width;
    final rightPanelWidth = tester
        .getSize(find.byKey(const ValueKey('tablet-registration-right-panel')))
        .width;
    expect(
      leftPanelWidth / (leftPanelWidth + rightPanelWidth),
      closeTo(0.6, 0.01),
    );
    final logo = find.byKey(
      const ValueKey('tablet-registration-onboarding-logo'),
    );
    expect(tester.getTopLeft(logo).dx, lessThan(70));
    expect(tester.getTopLeft(logo).dy, lessThan(70));
    expect(tester.getSize(logo).width, lessThanOrEqualTo(220));
    final indicator = find.byKey(
      const ValueKey('tablet-registration-page-indicator'),
    );
    expect(indicator, findsOneWidget);
    final omitButton = tester.getRect(
      find.ancestor(of: find.text('Omitir'), matching: find.byType(TextButton)),
    );
    final continueButton = tester.getRect(
      find.byKey(const ValueKey('tablet-registration-continue-button')),
    );
    final pageDots = tester.getRect(indicator);
    expect(
      pageDots.center.dx,
      closeTo((omitButton.right + continueButton.left) / 2, 1),
    );
    expect(pageDots.center.dy, closeTo(continueButton.center.dy, 1));
    final copyLeft = tester
        .getTopLeft(
          find.byKey(const ValueKey('tablet-registration-copy-center')),
        )
        .dx;
    for (final text in [
      find.text('Registra tus'),
      find.text('visitas'),
      find.text('Entrada de visitantes'),
      find.textContaining('Registra cada ingreso fácilmente'),
    ]) {
      expect(tester.getTopLeft(text).dx, closeTo(copyLeft, 1));
    }
    expect(
      tester.getSize(
        find.byKey(const ValueKey('tablet-onboarding-step-number')),
      ),
      isNot(Size.zero),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('tablet-registration-copy')))
          .dy,
      closeTo(
        tester
            .getCenter(
              find.byKey(const ValueKey('tablet-registration-copy-center')),
            )
            .dy,
        1,
      ),
    );
    expect(
      tester.widget<Text>(find.text('Registra tus')).style?.fontSize,
      inInclusiveRange(40, 78),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El primer onboarding se adapta a distintos tamaños de tablet', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    double? narrowTitleSize;
    double? wideTitleSize;
    for (final size in [
      const Size(800, 600),
      const Size(900, 600),
      const Size(1024, 768),
      const Size(1280, 800),
      const Size(1366, 768),
      const Size(1600, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('onboarding-tablet-${size.width}x${size.height}'),
          home: const ReceptionOnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Tablet: $size');
      expect(
        tester.getRect(find.text('Registra tus')).right,
        lessThanOrEqualTo(size.width),
        reason: 'Title fits: $size',
      );
      expect(
        tester.getRect(find.text('Continuar')).bottom,
        lessThan(size.height),
        reason: 'Navigation fits: $size',
      );
      if (size.width <= 1024) {
        final leftPanelRight = tester
            .getRect(
              find.byKey(const ValueKey('tablet-registration-left-panel')),
            )
            .right;
        final copyLeft = tester
            .getRect(
              find.byKey(const ValueKey('tablet-registration-copy-center')),
            )
            .left;
        expect(
          copyLeft - leftPanelRight,
          greaterThanOrEqualTo(30),
          reason: 'Registration copy has space from left panel: $size',
        );
      }
      expect(
        find.byKey(const ValueKey('tablet-registration-page-indicator')),
        findsOneWidget,
        reason: 'Page indicator remains visible: $size',
      );
      final titleSize = tester
          .widget<Text>(find.text('Registra tus'))
          .style!
          .fontSize!;
      if (size.width == 800) narrowTitleSize = titleSize;
      if (size.width == 1600) wideTitleSize = titleSize;
    }
    expect(narrowTitleSize, lessThan(wideTitleSize!));
  });

  testWidgets('Onboarding 2 y 3 se adaptan a distintos tamaños de tablet', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tabletSizes = [
      const Size(800, 600),
      const Size(900, 600),
      const Size(1024, 768),
      const Size(1366, 768),
      const Size(1600, 900),
    ];
    final pages = [
      (
        step: '02',
        leftBackground: 'tablet-control-left-background',
        rightBackground: 'tablet-control-right-background',
        home: const ReceptionControlOnboardingPage(),
        copy: find.text('Controla entradas'),
      ),
      (
        step: '03',
        leftBackground: 'tablet-ready-left-background',
        rightBackground: 'tablet-ready-right-background',
        home: const ReceptionReadyOnboardingPage(),
        copy: find.text('Todo listo para'),
      ),
    ];

    for (final page in pages) {
      for (final size in tabletSizes) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('${page.step}-${size.width}x${size.height}'),
            home: page.home,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: '${page.step}: $size');
        expect(find.text(page.step), findsOneWidget);
        expect(find.text('Omitir'), findsOneWidget);
        expect(
          find.text(page.step == '02' ? 'Continuar' : 'Iniciar sesión'),
          findsOneWidget,
        );
        expect(page.copy, findsOneWidget);
        expect(find.byKey(ValueKey(page.leftBackground)), findsOneWidget);
        expect(find.byKey(ValueKey(page.rightBackground)), findsOneWidget);
        if (size.width <= 1024) {
          final leftPanelRight = tester
              .getRect(find.byKey(ValueKey(page.leftBackground)))
              .right;
          final copyLeft = tester
              .getRect(
                find.byKey(ValueKey('tablet-onboarding-${page.step}-content')),
              )
              .left;
          expect(
            copyLeft - leftPanelRight,
            greaterThanOrEqualTo(28),
            reason: '${page.step} content has space from left panel: $size',
          );
        }
        final titleFinder = page.step == '02'
            ? find.text('Controla entradas')
            : find.text('Todo listo para');
        expect(
          tester.widget<Text>(titleFinder).style!.fontSize!,
          allOf(
            greaterThanOrEqualTo(size.width < 1000 ? 24 : 34),
            lessThanOrEqualTo(75),
          ),
          reason:
              'Tablet title keeps its original responsive size: ${page.step}, $size',
        );
        final subtitleFinder = find.text(
          page.step == '02' ? 'Seguimiento y seguridad' : 'Acceso a tu cuenta',
        );
        expect(
          tester.widget<Text>(subtitleFinder).style!.fontSize!,
          lessThanOrEqualTo(27),
        );
        if (page.step == '03') {
          final descriptionFinder = find.text(
            'Tu acceso está listo. Ingresa con tu cuenta\ny comienza a gestionar las visitas.',
          );
          final description = tester.widget<Text>(descriptionFinder);
          expect(description.maxLines, isNull);
          expect(description.style!.fontSize!, lessThanOrEqualTo(21));
          expect(description.style!.fontSize!, greaterThan(0));
          final descriptionLayout = TextPainter(
            text: TextSpan(text: description.data, style: description.style),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: tester.getSize(descriptionFinder).width);
          expect(
            descriptionLayout.computeLineMetrics().length,
            2,
            reason: 'Onboarding 3 description fits in two lines at $size',
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      'assets/images/onboarding-benefits-bar.webp',
            ),
            findsNothing,
          );
        }
      }
    }
  });

  testWidgets('Continuar abre la tercera pantalla del onboarding', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ReceptionApp(showSplash: false));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Controla entradas'), findsOneWidget);
    expect(find.text('y '), findsOneWidget);
    expect(find.text('salidas'), findsOneWidget);
    expect(find.text('03.'), findsNothing);
    expect(find.bySemanticsLabel('Página 2 de 3'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Los degradados de los pasos 1 y 3 son nítidos y contrastantes', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ReceptionOnboardingPage()));
    await tester.pumpAndSettle();

    final registrationGradient = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('registration-onboarding-gradient-word')),
    );
    final registrationText = registrationGradient.child as Text;
    expect(registrationText.style!.fontWeight, FontWeight.w900);
    expect(registrationText.style!.shadows, hasLength(1));
    expect(
      registrationText.style!.shadows!.single.blurRadius,
      lessThanOrEqualTo(2),
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final readyGradient = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('ready-onboarding-gradient-word')),
    );
    final readyGradientText = find.descendant(
      of: find.byKey(const ValueKey('ready-onboarding-gradient-word')),
      matching: find.byType(Text),
    );
    expect(readyGradient.child, isA<FittedBox>());
    expect(
      tester.widgetList<Text>(readyGradientText).single.style!.fontWeight,
      FontWeight.w900,
    );
    expect(
      tester.widgetList<Text>(readyGradientText).single.style!.shadows,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El logo del paso 2 iguala al del paso 3 y mejora el degradado', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: ReceptionControlOnboardingPage()),
    );
    await tester.pumpAndSettle();

    final controlLogo = tester.widget<Image>(
      find.byKey(const ValueKey('mobile-control-onboarding-logo')),
    );
    expect(controlLogo.width, 220);
    expect(controlLogo.height, 148);

    final gradient = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('control-onboarding-gradient-word')),
    );
    final gradientText = gradient.child as Text;
    expect(gradientText.style!.fontWeight, FontWeight.w900);
    expect(gradientText.style!.shadows, hasLength(1));

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final readyLogo = tester.widget<Image>(
      find.byKey(const ValueKey('mobile-ready-onboarding-logo')),
    );
    expect(readyLogo.width, controlLogo.width);
    expect(readyLogo.height, controlLogo.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continuar abre la pantalla final del onboarding', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ReceptionApp(showSplash: false));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Todo listo para'), findsOneWidget);
    expect(find.text('comenzar'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.bySemanticsLabel('Página 3 de 3'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Iniciar sesión abre la pantalla de acceso', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ReceptionApp(showSplash: false));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Usuario o correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Visitas sin cita'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El onboarding navega con gestos y puntos con límites', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ReceptionOnboardingPage()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('mobile-registration-onboarding-logo')),
          )
          .width,
      greaterThanOrEqualTo(180),
    );
    await tester.drag(find.byType(Scaffold).first, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Registra tus'), findsOneWidget);

    await tester.drag(find.byType(Scaffold).first, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Controla entradas'), findsOneWidget);
    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('mobile-control-onboarding-logo')),
          )
          .width,
      greaterThanOrEqualTo(180),
    );

    await tester.tap(
      find.byKey(const ValueKey('onboarding-page-indicator-dot-2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Todo listo para'), findsOneWidget);
    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('mobile-ready-onboarding-logo')),
          )
          .width,
      greaterThanOrEqualTo(190),
    );

    await tester.drag(find.byType(Scaffold).first, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Todo listo para'), findsOneWidget);

    await tester.drag(find.byType(Scaffold).first, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Controla entradas'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('onboarding-page-indicator-dot-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registra tus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La tablet sin vincular bloquea el acceso al kiosco', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 600),
      const Size(900, 600),
      const Size(1024, 768),
      const Size(1366, 910),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ReceptionApp(
          key: ValueKey(size),
          showSplash: false,
          visitorKioskDraftStorage: _MemoryVisitorKioskDraftStorage(),
          tabletDeviceStorage: _MemoryTabletDeviceStorage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vincula esta tablet'), findsOneWidget, reason: '$size');
      expect(find.text('Vincular tablet'), findsOneWidget, reason: '$size');
      expect(
        find.byKey(const ValueKey('tablet-visitor-landing')),
        findsNothing,
      );
      expect(find.text('Iniciar sesión'), findsNothing, reason: '$size');
      expect(
        find.byKey(const ValueKey('tablet-kiosk-welcome-panel')),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('El login tablet se adapta a distintas resoluciones', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 600),
      const Size(900, 600),
      const Size(1024, 768),
      const Size(1180, 820),
      const Size(1376, 1032),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('tablet-login-${size.width}x${size.height}'),
          home: const ReceptionLoginPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Tablet login: $size');
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.text('Usuario o correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Registro de visitantes'), findsOneWidget);
      expect(find.text('Visitas sin cita'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-forgot-password')), findsNothing);

      final formCard = tester.getRect(
        find.byKey(const ValueKey('tablet-login-form-card')),
      );
      final visitorCard = tester.getRect(
        find.byKey(const ValueKey('tablet-walk-in-card')),
      );
      expect(formCard.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(formCard.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(formCard.top, greaterThanOrEqualTo(0), reason: '$size');
      expect(formCard.bottom, lessThan(size.height), reason: '$size');
      expect(visitorCard.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(visitorCard.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(visitorCard.bottom, lessThan(size.height), reason: '$size');
    }
  });

  testWidgets('El onboarding no desborda en pantallas compactas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(445, 726),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ReceptionApp(
          key: ValueKey(size),
          showSplash: false,
          onboardingStorage: _MemoryOnboardingStorage(),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'Welcome: $size');
      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Navigation: $size');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.bySemanticsLabel('Página 1 de 3'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    }
  });

  testWidgets('El inicio de sesión no desborda en pantalla compacta', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(445, 726),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ReceptionApp(
          key: ValueKey(size),
          showSplash: false,
          onboardingStorage: _MemoryOnboardingStorage(),
        ),
      );
      await tester.tap(find.text('Comenzar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Login: $size');
      expect(find.byType(SingleChildScrollView), findsNothing);
    }
  });

  testWidgets('El login móvil centra y adapta su contenido', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(375, 667),
      const Size(390, 844),
      const Size(445, 726),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('mobile-centered-login-$size'),
          home: const ReceptionLoginPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.byKey(const ValueKey('mobile-login-logo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-login-form-card')),
        findsOneWidget,
      );
      expect(find.text('Visitas sin cita'), findsNothing, reason: '$size');
      expect(
        find.text('Registro de visitantes'),
        findsNothing,
        reason: '$size',
      );

      final logoRect = tester.getRect(
        find.byKey(const ValueKey('mobile-login-logo')),
      );
      if (size.width >= 360) {
        expect(
          logoRect.width,
          greaterThanOrEqualTo(255),
          reason: 'Mobile login logo is large enough: $size',
        );
      }
      final formRect = tester.getRect(
        find.byKey(const ValueKey('mobile-login-form-card')),
      );
      final contentCenterY = (logoRect.top + formRect.bottom) / 2;
      expect(
        contentCenterY,
        closeTo(size.height / 2, 24),
        reason: 'Logo and login form are centered together: $size',
      );
      expect(formRect.bottom, lessThan(size.height), reason: '$size');
      final passwordField = tester.getRect(
        find.widgetWithText(TextField, 'Escribe tu contraseña'),
      );
      final forgotPassword = tester.getRect(
        find.text('¿Olvidaste tu contraseña?'),
      );
      expect(
        forgotPassword.top,
        greaterThanOrEqualTo(passwordField.bottom),
        reason: 'Password recovery link is below the password field: $size',
      );
      expect(
        formRect.height,
        lessThanOrEqualTo(401),
        reason: 'The mobile login card has less dead space: $size',
      );
      expect(
        tester.getSize(find.byType(TextField).first).height,
        greaterThanOrEqualTo(46),
        reason: 'Mobile input stays comfortably tappable: $size',
      );
      final loginButtonRect = tester.getRect(find.text('Iniciar sesión').last);
      expect(
        loginButtonRect.height,
        greaterThanOrEqualTo(16),
        reason: 'Login action text is not scaled down: $size',
      );
    }
  });

  testWidgets('La recuperación de contraseña móvil envía el correo', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? recoveryRequest;
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/password-recovery');
        recoveryRequest = jsonDecode(request.body) as Map<String, dynamic>;
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

    await tester.pumpWidget(
      MaterialApp(home: ReceptionLoginPage(authService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login-forgot-password')));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.textContaining('cada 2 minutos'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('password-recovery-email')),
      'persona@example.test',
    );
    await tester.tap(find.byKey(const ValueKey('password-recovery-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(recoveryRequest, {'email': 'persona@example.test'});
    expect(
      find.byKey(const ValueKey('password-recovery-success')),
      findsOneWidget,
    );
    expect(find.text('Volver al inicio de sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El login bloquea nuevos intentos durante el Retry-After', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = AuthService(
      client: MockClient((request) async {
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

    await tester.pumpWidget(
      MaterialApp(home: ReceptionLoginPage(authService: service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'persona');
    await tester.enterText(find.byType(TextField).last, 'incorrecta');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Espera 5 minutos'), findsOneWidget);
    expect(find.text('Intenta de nuevo en 05:00'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('login-submit-action')))
          .onTap,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Intenta de nuevo en 04:59'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El panel móvil se adapta sin desbordamientos', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _homeDashboardService(),
          user: const AuthenticatedUser(
            login: 'recepcion',
            name: 'Recepción Principal',
            email: null,
            role: 'Administrador',
            isAdmin: true,
            sectionAccess: ['administrador'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Panel'), findsNothing);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Agenda de citas de hoy'), findsOneWidget);
    expect(find.text('Registros del periodo'), findsOneWidget);
    expect(find.text('Composición de movimientos'), findsOneWidget);
    expect(find.text('Tendencia diaria'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Recepción Principal'), findsWidgets);
    expect(find.text('Administrador'), findsWidgets);
    expect(find.text('Modo oscuro'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Departamento'), findsOneWidget);
    expect(find.text('Anfitriones'), findsOneWidget);
    await tester.drag(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Agenda de citas'), findsOneWidget);
    expect(find.text('Bitácora diaria'), findsOneWidget);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ver toda la bitácora  →'), 300);
    expect(find.text('Ver toda la bitácora  →'), findsOneWidget);
  });

  testWidgets('Departamentos y accesos de bitácora caben en móvil', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = AuthService(
      client: MockClient((request) async {
        final dashboardResponse = _homeDashboardResponse(request);
        if (dashboardResponse != null) return dashboardResponse;
        if (request.url.path == '/api/v1/companies') {
          expect(request.headers['cookie'], 'visitas_session=opaque-token');
          return http.Response(
            jsonEncode({
              'companies': [
                {'id': 1, 'name': 'Cymez', 'departmentCount': 2},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/daily-log/timers') {
          return http.Response(jsonEncode({'timers': []}), 200);
        }
        if (request.url.path == '/api/v1/notifications/config') {
          return http.Response(jsonEncode({'firebase': null}), 200);
        }
        if (request.url.path == '/api/v1/events') {
          return http.Response('', 200);
        }
        expect(request.url.path, '/api/v1/departments');
        expect(request.headers['cookie'], 'visitas_session=opaque-token');
        return http.Response(
          jsonEncode({
            'departments': [
              {'id': 1, 'name': 'Calidad', 'hostCount': 3},
              {'id': 2, 'name': 'Compras', 'hostCount': 1},
            ],
          }),
          200,
        );
      }),
      cookieStorage: _WidgetTestSessionStorage()
        ..value = 'visitas_session=opaque-token',
      baseUrl: 'https://example.test',
      isWeb: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: service,
          user: const AuthenticatedUser(
            login: 'admin',
            name: 'Admin',
            email: null,
            role: 'Administrador',
            isAdmin: true,
            sectionAccess: ['administrador'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Departamento'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Departamentos'), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
    final departmentButton = tester.getRect(find.text('Agregar'));
    expect(departmentButton.right, lessThanOrEqualTo(375));

    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await tester.pumpAndSettle();
    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Bitácora diaria'),
      250,
      scrollable: drawerScrollable,
    );
    await tester.ensureVisible(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();

    expect(find.text('Bitácora diaria'), findsOneWidget);
    expect(find.text('Nuevo registro'), findsOneWidget);
    final pageScrollable = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Persona API página 1'),
      220,
      scrollable: pageScrollable,
    );
    expect(find.text('Persona API página 1'), findsOneWidget);
    expect(find.text('Llegada'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('La bitácora muestra datos y paginación de la API', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceptionHomePage(
          authService: _homeDashboardService(),
          user: const AuthenticatedUser(
            login: 'recepcion',
            name: 'Recepción',
            email: null,
            role: 'Recepción',
            isAdmin: false,
            sectionAccess: ['recepcion'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Bitácora diaria'),
      250,
      scrollable: drawerScrollable,
    );
    await tester.ensureVisible(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitácora diaria').last);
    await tester.pumpAndSettle();

    final contentScrollable = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Movimientos'),
      220,
      scrollable: contentScrollable,
    );
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Dentro ahora'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(
      find.byKey(const ValueKey('log-metric-icon-Movimientos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('log-metric-icon-Dentro ahora')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Persona API página 1'),
      220,
      scrollable: contentScrollable,
    );
    expect(find.text('Persona API página 1'), findsOneWidget);
    expect(find.text('Llegada'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1 de 2'),
      220,
      scrollable: contentScrollable,
    );
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Persona API página 2'), findsWidgets);
    expect(find.text('Llegada'), findsWidgets);
    expect(find.text('2 de 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AuthService _homeDashboardService() => AuthService(
  client: MockClient((request) async {
    final response = _homeDashboardResponse(request);
    return response ?? http.Response('', 404);
  }),
  baseUrl: 'https://example.test',
  isWeb: true,
);

http.Response? _homeDashboardResponse(http.Request request) {
  if (request.url.path == '/api/v1/appointments') {
    return http.Response(jsonEncode({'appointments': []}), 200);
  }
  if (request.url.path == '/api/v1/daily-log') {
    final page = int.tryParse(request.url.queryParameters['page'] ?? '') ?? 1;
    return http.Response(
      jsonEncode({
        'entries': [
          {
            'id': page,
            'date': '2026-11-04',
            'time': '09:30',
            'event': 'Llegada',
            'person': 'Persona API página $page',
            'company': 'Empresa API',
            'details': '',
            'actorName': 'Recepción',
          },
        ],
        'recentEntries': [
          {
            'date': '2026-11-04',
            'time': '09:30',
            'event': 'Llegada',
            'person': 'Persona API página $page',
          },
        ],
        'summary': {'movementCount': 4, 'insideNow': 2, 'pendingArrivals': 1},
        'hosts': ['Anfitrión API'],
        'total': 2,
        'page': page,
        'pageSize': 1,
        'pages': 2,
      }),
      200,
    );
  }
  if (request.url.path == '/api/v1/daily-log/stats') {
    return http.Response(
      jsonEncode({
        'stats': [
          {
            'date': '2026-11-04',
            'arrivals': 2,
            'entries': 1,
            'exits': 0,
            'observations': 1,
          },
        ],
      }),
      200,
    );
  }
  return null;
}

class _WidgetTestSessionStorage implements SessionCookieStorage {
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
