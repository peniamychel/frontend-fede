import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/ui/app.dart';
import 'package:fede/ui/widgets/boton_tema.dart';

/// El cambio de tema dentro de la app completa.
///
/// Aparte, estas pruebas ejercitan el árbol real —con sus InheritedWidget— que
/// es donde puede aparecer el fallo de "un InheritedWidget se desmonta con
/// dependientes vivos".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> arrancar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('cambiar el tema no rompe el árbol', (tester) async {
    await arrancar(tester);

    await tester.tap(find.byType(BotonTema).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('alternar varias veces seguidas tampoco', (tester) async {
    await arrancar(tester);

    for (final opcion in ['Oscuro', 'Claro', 'Igual que el sistema']) {
      await tester.tap(find.byType(BotonTema).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: opcion);
    }
  });

  testWidgets('cambiar de sección después de cambiar el tema', (tester) async {
    await arrancar(tester);

    await tester.tap(find.byType(BotonTema).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    // El IndexedStack conserva las cuatro secciones vivas: si el cambio de
    // tema dejó alguna en mal estado, se nota al mostrarla.
    for (final seccion in ['Jerarquía', 'Observaciones', 'Calidad']) {
      await tester.tap(find.text(seccion).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: seccion);
    }
  });

  testWidgets('desmontar la app entera con el tema cambiado', (tester) async {
    await arrancar(tester);

    await tester.tap(find.byType(BotonTema).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    // Acá es donde saltaría el assert de InheritedElement: al desmontar el
    // TemaScope mientras los botones de tema todavía dependen de él.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
