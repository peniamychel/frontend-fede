import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const casos = <(String?, String, String)>[
    ('CON_SISTEMA', 'S', 'Sistema'),
    ('SIN_SISTEMA', 'N', 'Sin sistema'),
    ('BLANCO', 'B', 'Blanco'),
    ('FRACCIONADO', 'F', 'Fraccionado'),
    ('DETALLISTA', 'D', 'Detallista'),
    ('COMUNITARIO', 'C', 'Comunitario'),
  ];

  for (final (valor, letra, etiqueta) in casos) {
    testWidgets('muestra $letra para la clasificación $etiqueta', (
      tester,
    ) async {
      await _mostrarFila(tester, clasificacion: valor);

      final insignia = find.byKey(const ValueKey('clasificacion-productor-42'));
      expect(insignia, findsOneWidget);
      expect(
        find.descendant(of: insignia, matching: find.text(letra)),
        findsOneWidget,
      );
      expect(find.byTooltip('Clasificación: $etiqueta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra un círculo vacío cuando no tiene clasificación', (
    tester,
  ) async {
    await _mostrarFila(tester);

    final insignia = find.byKey(const ValueKey('clasificacion-productor-42'));
    expect(insignia, findsOneWidget);
    expect(
      find.descendant(of: insignia, matching: find.byType(Text)),
      findsNothing,
    );
    expect(find.byTooltip('Clasificación: Sin clasificación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resalta la fila del productor seleccionado', (tester) async {
    await _mostrarFila(tester, seleccionado: true);

    final fila = tester.widget<ListTile>(
      find.byKey(const ValueKey('fila-productor-42')),
    );
    expect(fila.selected, isTrue);
    expect(fila.selectedTileColor, isNotNull);
    expect(fila.shape, isA<RoundedRectangleBorder>());
  });
}

Future<void> _mostrarFila(
  WidgetTester tester, {
  String? clasificacion,
  bool seleccionado = false,
}) async {
  final productor = Productor.desdeJson({
    'id': 42,
    'nombres': 'MARÍA',
    'apellidos': 'PÉREZ',
    'nombreCompleto': 'MARÍA PÉREZ',
    'ci': '1234567',
    'sindicatoId': 7,
    'sindicatoNombre': '1RO DE MAYO',
    'centralId': 3,
    'centralNombre': '13 DE JUNIO',
    'clasificacion': clasificacion,
    'credencialLista': false,
    'auditoria': {'estado': true},
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FilaProductor(
          productor: productor,
          seleccionado: seleccionado,
          alTocar: () {},
        ),
      ),
    ),
  );
}
