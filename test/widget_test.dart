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
    expect(find.text('Más\nseguridad'), findsOneWidget);
    expect(find.text('Registro\nrápido'), findsOneWidget);
    expect(find.text('Mejor control\nde accesos'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
    expect(find.bySemanticsLabel('Página 1 de 4'), findsOneWidget);
  });

  testWidgets('Se adapta a una pantalla pequeña', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [const Size(320, 568), const Size(375, 667)]) {
      tester.view.physicalSize = size;

      await tester.pumpWidget(const ReceptionApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.text('Más\nseguridad'), findsOneWidget);
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

  testWidgets('El onboarding no desborda en pantallas compactas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [const Size(320, 568), const Size(375, 667)]) {
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
}
