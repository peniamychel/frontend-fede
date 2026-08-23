import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/ui/app.dart';

void main() {
  testWidgets('Escape vuelve aunque el foco esté en un campo de texto', (
    tester,
  ) async {
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navegador,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: TextField(autofocus: true)),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
        builder: (context, child) =>
            RetrocesoConEscape(navegador: navegador, child: child!),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget);
  });
}
