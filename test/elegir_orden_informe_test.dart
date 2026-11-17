import 'package:fede/ui/widgets/elegir_orden_informe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brillo in Brightness.values) {
    for (final pantalla in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets('elige lote antes de confirmar en $pantalla y $brillo', (
        tester,
      ) async {
        tester.view.physicalSize = pantalla;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        OrdenInformes? resultado;
        var completado = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brillo),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    resultado = await elegirOrdenInforme(context);
                    completado = true;
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Orden de la lista'), findsOneWidget);
        expect(find.byType(RadioListTile<OrdenInformes>), findsNWidgets(2));
        expect(
          tester
              .widget<RadioGroup<OrdenInformes>>(
                find.byType(RadioGroup<OrdenInformes>),
              )
              .groupValue,
          OrdenInformes.apellidos,
        );
        await tester.ensureVisible(find.text('Número de lote'));
        await tester.tap(find.text('Número de lote'));
        await tester.pumpAndSettle();
        expect(completado, isFalse);
        expect(find.text('Generar').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Generar'));
        await tester.pumpAndSettle();
        expect(completado, isTrue);
        expect(resultado, OrdenInformes.numeroLote);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final accion in ['Generar', 'Cancelar', 'Atrás']) {
    testWidgets('$accion conserva el valor inicial o cancela sin elegir', (
      tester,
    ) async {
      OrdenInformes? resultado;
      var completado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await elegirOrdenInforme(context);
                  completado = true;
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      if (accion == 'Atrás') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(accion));
      }
      await tester.pumpAndSettle();
      expect(completado, isTrue);
      expect(resultado, accion == 'Generar' ? OrdenInformes.apellidos : isNull);
      expect(find.text('Orden de la lista'), findsNothing);
    });
  }
}
