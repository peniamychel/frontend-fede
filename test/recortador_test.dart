import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/productores/recortador_imagen.dart';

/// El recortador, aislado. No necesita backend: trabaja sobre bytes.
void main() {
  late Uint8List foto;

  setUpAll(() {
    foto = File('test/fixtures/foto-prueba.png').readAsBytesSync();
  });

  Widget banco({
    ValueChanged<Recorte?>? alCambiar,
    Proporcion? proporcionFija,
    ValueChanged<bool>? alCambiarInteraccion,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 460,
            child: RecortadorImagen(
              bytes: foto,
              alCambiar: alCambiar ?? (_) {},
              proporcionFija: proporcionFija,
              alCambiarInteraccion: alCambiarInteraccion,
            ),
          ),
        ),
      ),
    );
  }

  /// Deja que termine la decodificación de la imagen.
  ///
  /// `pumpAndSettle` a secas no alcanza: decodificar es trabajo asíncrono real
  /// y en las pruebas no avanza fuera de `runAsync`. Sin esto el widget se
  /// queda mostrando la rueda de carga y la prueba se agota sin haber
  /// ejercitado nada.
  Future<void> esperarImagen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();
  }

  testWidgets('se dibuja sin lanzar excepciones', (tester) async {
    await tester.pumpWidget(banco());
    await esperarImagen(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(RecortadorImagen), findsOneWidget);
    // Si siguiera cargando, no habría llegado a dibujar los controles.
    expect(find.text('Libre'), findsOneWidget);
  });

  testWidgets('al cargar informa el recorte completo', (tester) async {
    Recorte? ultimo;
    await tester.pumpWidget(banco(alCambiar: (r) => ultimo = r));
    await esperarImagen(tester);

    // Arranca con la imagen entera: quien no quiera recortar no hace nada.
    expect(ultimo, isNotNull);
    expect(ultimo!.x, lessThanOrEqualTo(2));
    expect(ultimo!.y, lessThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar de proporción no rompe el árbol', (tester) async {
    await tester.pumpWidget(banco());
    await esperarImagen(tester);

    for (final etiqueta in ['3:4', '1:1', '4:3', 'Libre']) {
      await tester.tap(find.text(etiqueta));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'proporción $etiqueta');
    }
  });

  testWidgets('arrastrar el marco no rompe el árbol', (tester) async {
    Recorte? ultimo;
    await tester.pumpWidget(banco(alCambiar: (r) => ultimo = r));
    await esperarImagen(tester);

    await tester.drag(find.byType(RecortadorImagen), const Offset(-30, -30));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(ultimo, isNotNull);
  });

  testWidgets('la esquina cuadrada sigue un arrastre de un solo eje', (
    tester,
  ) async {
    Recorte? ultimo;
    await tester.pumpWidget(
      banco(alCambiar: (r) => ultimo = r, proporcionFija: Proporcion.cuadrada),
    );
    await esperarImagen(tester);
    final anchoInicial = ultimo!.ancho;

    await tester.drag(
      find.byKey(const ValueKey('recorte-inferiorDerecha')),
      const Offset(-60, 0),
    );
    await tester.pump();

    expect(ultimo!.ancho, lessThan(anchoInicial - 40));
    expect(ultimo!.alto, closeTo(ultimo!.ancho, 2));
  });

  testWidgets('avisa mientras el dedo manipula una esquina', (tester) async {
    final estados = <bool>[];
    await tester.pumpWidget(
      banco(
        proporcionFija: Proporcion.cuadrada,
        alCambiarInteraccion: estados.add,
      ),
    );
    await esperarImagen(tester);

    await tester.drag(
      find.byKey(const ValueKey('recorte-inferiorDerecha')),
      const Offset(-40, -40),
    );
    await tester.pump();

    expect(estados, containsAllInOrder([true, false]));
  });

  testWidgets('sobrevive a que lo quiten del árbol mientras decodifica', (
    tester,
  ) async {
    // Es lo que pasa al cerrar el diálogo enseguida: si el widget avisa a un
    // padre que ya no está, el árbol queda inconsistente.
    await tester.pumpWidget(banco());
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await esperarImagen(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un archivo que no es imagen muestra el aviso, no una excepción',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecortadorImagen(
              bytes: Uint8List.fromList('no soy una imagen'.codeUnits),
              alCambiar: (_) {},
            ),
          ),
        ),
      );
      await esperarImagen(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('no se puede mostrar'), findsOneWidget);
    },
  );
}
