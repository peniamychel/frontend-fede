import 'package:fede/ui/productores/visor_imagen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final pantalla in [
    const Size(1440, 900),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('visor cuadrado y centrado en $pantalla', (tester) async {
      tester.view.physicalSize = pantalla;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => VisorImagen.mostrar(
                  context,
                  url: 'https://example.invalid/foto.png',
                  titulo: 'Fotografía',
                  subtitulo: '384 × 384 · 201 KB',
                  alDescargar: () async {},
                  alEditar: () async {},
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final cuadro = tester.getRect(
        find.byKey(const ValueKey('visor-fotografia-cuadrado')),
      );
      expect(cuadro.width, cuadro.height);
      expect(cuadro.width, lessThanOrEqualTo(640));
      expect(cuadro.center.dx, closeTo(pantalla.width / 2, 1));
      expect(cuadro.center.dy, closeTo(pantalla.height / 2, 1));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Editar fotografía'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(VisorImagen), findsNothing);
    });
  }

  testWidgets(
    'editar cierra el visor y abre la edición existente una sola vez',
    (tester) async {
      var ediciones = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => VisorImagen.mostrar(
                  context,
                  url: 'https://example.invalid/foto.png',
                  titulo: 'Fotografía',
                  alEditar: () async {
                    ediciones++;
                  },
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar fotografía'));
      await tester.pumpAndSettle();
      expect(ediciones, 1);
      expect(find.byType(VisorImagen), findsNothing);
    },
  );

  testWidgets('sin permiso de edición no muestra el botón editar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => VisorImagen.mostrar(
                context,
                url: 'https://example.invalid/foto.png',
                titulo: 'Fotografía',
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Editar fotografía'), findsNothing);
  });
}
