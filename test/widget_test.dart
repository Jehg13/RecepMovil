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
                'assets/images/onboarding-benefits-bar.png',
      ),
      findsWidgets,
    );
    expect(find.text('Comenzar'), findsOneWidget);
    expect(find.bySemanticsLabel('Página 1 de 4'), findsOneWidget);
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
      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
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
    expect(find.bySemanticsLabel('Página 2 de 4'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
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
    expect(find.bySemanticsLabel('Página 3 de 4'), findsOneWidget);
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
    expect(find.bySemanticsLabel('Página 4 de 4'), findsOneWidget);
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
    expect(find.text('Registro de visitas sin cita'), findsOneWidget);
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
      expect(find.bySemanticsLabel('Página 2 de 4'), findsOneWidget);
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
