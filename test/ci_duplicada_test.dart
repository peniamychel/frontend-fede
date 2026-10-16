import 'package:fede/models/productor.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final seleccionado in [false, true]) {
    testWidgets(
      'CI duplicada se muestra roja aunque esté pendiente SIE, seleccionada: $seleccionado',
      (tester) async {
        final p = Productor.desdeJson({
          'id': 8,
          'nombres': 'MARIA',
          'apellidos': 'PEREZ',
          'nombreCompleto': 'MARIA PEREZ',
          'ci': '123456',
          'ciDuplicada': true,
          'revisionSiePendiente': true,
          'revisionSieEstado': 'APROBADO_MANUAL',
          'credencialLista': true,
          'faseImpresionPendiente': true,
          'reimpresionFasePendiente': true,
        });
        expect(p.ciDuplicada, isTrue);
        expect(p.credencialLista, isFalse);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FilaProductor(
                productor: p,
                seleccionado: seleccionado,
                alTocar: () {},
                mostrarRuta: false,
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(FilaProductor));
        final rojo = Theme.of(context).colorScheme.error;
        final tile = tester.widget<ListTile>(
          find.byKey(const ValueKey('fila-productor-8')),
        );
        expect(tile.textColor, rojo);
        expect(tile.selectedColor, rojo);
        expect(find.text('Revisión CI · Cédula repetida'), findsOneWidget);
        expect(tester.widget<Icon>(find.byIcon(Icons.print)).color, rojo);
        expect(
          find.byTooltip('Revisión CI: cédula repetida, excluido de impresión'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('clientes sin indicador nuevo siguen interpretándose sin conflicto', () {
    final p = Productor.desdeJson({'id': 1, 'credencialLista': true});
    expect(p.ciDuplicada, isFalse);
    expect(p.credencialLista, isTrue);
  });
}
