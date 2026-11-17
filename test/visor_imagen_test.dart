import 'package:fede/ui/productores/visor_imagen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/models/imagen.dart';

void main() {
  Imagen foto({bool fechas = true, bool pendiente = false}) => Imagen(
    tipo: TipoImagen.original,
    url: '/foto.png',
    tipoMime: 'image/png',
    tamanoBytes: 1234,
    ancho: 400,
    alto: 400,
    nombreOriginal: 'fotografia-del-productor-con-nombre-largo.png',
    creadaEn: fechas ? DateTime(2026, 9, 10, 8, 30) : null,
    actualizadaEn: fechas ? DateTime(2026, 11, 3, 10, 45) : null,
    pendienteEdicion: pendiente,
  );

  for (final brillo in Brightness.values) {
    for (final pantalla in [
      const Size(1440, 900),
      const Size(390, 844),
      const Size(844, 390),
      const Size(320, 480),
    ]) {
      testWidgets('detalles y tema $brillo en $pantalla', (tester) async {
        tester.view.physicalSize = pantalla;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final tema = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: brillo,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: tema,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => VisorImagen.mostrar(
                    context,
                    url: 'https://example.invalid/foto.png',
                    titulo: 'Fotografía',
                    detalles: foto(pendiente: true),
                    alEditar: () async {},
                    alDescargar: () async {},
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Nombre del archivo'), findsOneWidget);
        expect(
          find.text('Pendiente de edición · Impresión bloqueada'),
          findsOneWidget,
        );
        expect(find.text(foto().nombreOriginal!), findsOneWidget);
        expect(find.text('Fecha de creación'), findsOneWidget);
        expect(find.text('10/09/2026 08:30'), findsOneWidget);
        expect(find.text('Última edición'), findsOneWidget);
        expect(find.text('03/11/2026 10:45'), findsOneWidget);
        expect(
          tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
          tema.colorScheme.surfaceContainerHigh,
        );
        final cerrar = tester.widget<Icon>(
          find.descendant(
            of: find.byTooltip('Cerrar'),
            matching: find.byType(Icon),
          ),
        );
        expect(cerrar.color, tema.colorScheme.onSurface);
        final cuadro = tester.getRect(
          find.byKey(const ValueKey('visor-fotografia-cuadrado')),
        );
        expect(cuadro.left, greaterThanOrEqualTo(0));
        expect(cuadro.right, lessThanOrEqualTo(pantalla.width));
        expect(cuadro.top, greaterThanOrEqualTo(0));
        expect(cuadro.bottom, lessThanOrEqualTo(pantalla.height));
        expect(
          find.byTooltip('Editar fotografía').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Descargar fotografía').hitTestable(),
          findsOneWidget,
        );
        expect(find.byTooltip('Cerrar').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.byType(VisorImagen), findsNothing);
      });
    }
  }

  test('metadata nueva y respuestas antiguas se leen sin inventar fechas', () {
    final nueva = Imagen.desdeJson({
      'tipo': 'ORIGINAL',
      'nombreOriginal': 'foto.png',
      'creadaEn': '2026-09-10T08:30:00',
      'actualizadaEn': '2026-11-03T10:45:00',
      'pendienteEdicion': true,
    });
    expect(nueva.creadaEn, DateTime(2026, 9, 10, 8, 30));
    expect(nueva.actualizadaEn, DateTime(2026, 11, 3, 10, 45));
    expect(nueva.pendienteEdicion, isTrue);
    final anterior = Imagen.desdeJson({
      'tipo': 'ORIGINAL',
      'actualizadaEn': '2026-11-03T10:45:00',
    });
    expect(anterior.creadaEn, isNull);
    expect(anterior.pendienteEdicion, isFalse);
    expect(anterior.actualizadaEn, DateTime(2026, 11, 3, 10, 45));
  });

  testWidgets('fechas desconocidas se muestran como sin registro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisorImagen(
          url: 'https://example.invalid/foto.png',
          titulo: 'Fotografía',
          detalles: foto(fechas: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin registro'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

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
