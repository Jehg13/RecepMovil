import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visitas_recep_mobile/main.dart';

void main() {
  testWidgets('Muestra la bienvenida de Recepción', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReceptionApp());

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

      await tester.pumpWidget(const ReceptionApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(Image), findsWidgets);
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
      await tester.pumpWidget(ReceptionApp(key: ValueKey(size)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Welcome: $size');
      if (size.width >= 600 && size.height > size.width) {
        expect(find.text('Voltea tu tablet'), findsOneWidget);
      } else {
        expect(find.text('Comenzar'), findsOneWidget);
      }
      expect(find.byType(Image), findsWidgets);
    }
  });

  testWidgets('El kiosco no bloquea por orientación', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const MaterialApp(home: WalkInVisitorPage()));
      await tester.pumpAndSettle();

      expect(find.text('Gira tu celular'), findsNothing, reason: '$size');
      expect(find.text('Comenzar registro'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('Comenzar abre la segunda pantalla del onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReceptionApp());

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
    expect(
      find.byKey(const ValueKey('tablet-registration-onboarding-logo')),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('tablet-registration-onboarding-logo')),
          )
          .dx,
      lessThan(512),
    );
    expect(tester.getCenter(find.text('Registra tus')).dx, greaterThan(512));
    final copyCenter = tester
        .getCenter(
          find.byKey(const ValueKey('tablet-registration-copy-center')),
        )
        .dx;
    for (final text in [
      find.text('Registra tus'),
      find.text('visitas'),
      find.text('Entrada de visitantes'),
      find.textContaining('Registra cada ingreso fácilmente'),
    ]) {
      expect(tester.getCenter(text).dx, closeTo(copyCenter, 1));
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
    expect(tester.widget<Text>(find.text('Registra tus')).style?.fontSize, 78);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continuar abre la tercera pantalla del onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReceptionApp());
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

  testWidgets('Continuar abre la pantalla final del onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReceptionApp());
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
    await tester.pumpWidget(const ReceptionApp());
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
    expect(find.text('Visitas sin cita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El registro sin cita se destaca solo en el login de tablet', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(const MaterialApp(home: ReceptionLoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('Registro de visitantes'), findsOneWidget);
    expect(find.text('Visitas sin cita'), findsOneWidget);
    expect(find.text('Ingresa tu visita sin iniciar sesión'), findsOneWidget);
    expect(find.text('Iniciar registro'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.shield_outlined)).size, 48);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('tablet-login-form-card')))
          .width,
      greaterThan(470),
    );
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('tablet-walk-in-card')))
          .dy,
      lessThanOrEqualTo(690),
    );
    expect(
      tester.widget<Text>(find.text('Registro de visitantes')).style?.fontSize,
      21,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tablet-walk-in-card'))).dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('tablet-visitor-divider')),
              )
              .dy,
      greaterThanOrEqualTo(20),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Iniciar registro'));
    await tester.pumpAndSettle();
    expect(find.text('Comenzar registro'), findsOneWidget);

    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('mobile-login'),
        home: ReceptionLoginPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registro de visitantes'), findsNothing);
    expect(find.text('Visitas sin cita'), findsNothing);
    expect(find.text('Iniciar registro'), findsNothing);
    expect(tester.takeException(), isNull);
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
      tester.view.physicalSize = size;
      await tester.pumpWidget(ReceptionApp(key: ValueKey(size)));
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
      tester.view.physicalSize = size;
      await tester.pumpWidget(ReceptionApp(key: ValueKey(size)));
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

  testWidgets('El panel móvil se adapta sin desbordamientos', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: ReceptionHomePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Panel'), findsNothing);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Historial de movimientos'), findsOneWidget);
    expect(find.text('Composición de movimientos'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Recepción Principal'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Modo oscuro'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Departamento'), findsOneWidget);
    expect(find.text('Anfitriones'), findsOneWidget);
    expect(find.text('Agenda de citas'), findsOneWidget);
    await tester.drag(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acceso corporativo'), findsOneWidget);
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tendencia diaria'), 300);
    expect(find.text('Tendencia diaria'), findsOneWidget);
  });
}
