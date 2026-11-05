import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitas_recep_mobile/app_feedback.dart';

void main() {
  testWidgets('el aviso de error muestra título y texto sin subrayado', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    AppFeedback.show(
      context,
      'Verifica el folio o vuelve a escanear el pase de visita.',
      type: AppFeedbackType.error,
      title: 'Código no encontrado',
    );
    await tester.pumpAndSettle();

    expect(find.text('Código no encontrado'), findsOneWidget);
    final message = tester.widget<Text>(
      find.text('Verifica el folio o vuelve a escanear el pase de visita.'),
    );
    expect(message.style?.decoration, TextDecoration.none);

    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(find.text('Código no encontrado'), findsNothing);
  });

  testWidgets('el aviso de QR enviado se muestra sin subrayados', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    AppFeedback.show(
      context,
      'El pase de Ana se envió a ana@example.com.',
      type: AppFeedbackType.success,
      title: 'QR enviado',
    );
    await tester.pumpAndSettle();

    expect(find.text('QR enviado'), findsOneWidget);
    final message = tester.widget<Text>(
      find.text('El pase de Ana se envió a ana@example.com.'),
    );
    expect(message.style?.decoration, TextDecoration.none);

    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pumpAndSettle();
  });
}
