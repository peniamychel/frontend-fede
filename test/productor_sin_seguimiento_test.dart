import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/models/productor.dart';
import 'package:fede/ui/productores/fila_productor.dart';

void main() {
  test('alta y edición no envían la marca de seguimiento', () {
    const alta = ProductorRequest(nombres: 'MARÍA', sindicatoId: 7);
    final p = Productor.desdeJson({
      'id': 42,
      'nombres': 'MARÍA',
      'sindicatoId': 7,
      'observado': true,
      'observacion': 'Revisar identidad',
    });
    expect(alta.aJson().containsKey('marcado'), isFalse);
    expect(ProductorRequest.desde(p).aJson().containsKey('marcado'), isFalse);
    expect(p.observado, isTrue);
    expect(p.observacion, 'Revisar identidad');
  });

  testWidgets('la lista mantiene observado sin icono ni texto de seguimiento', (
    tester,
  ) async {
    final p = Productor.desdeJson({
      'id': 42,
      'nombres': 'MARÍA',
      'nombreCompleto': 'MARÍA',
      'ci': '12345',
      'sindicatoId': 7,
      'observado': true,
      'observacion': 'Revisar identidad',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilaProductor(productor: p, alTocar: () {}),
        ),
      ),
    );
    expect(find.byTooltip('Marcado en la revisión'), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(find.text('Observado: Revisar identidad'), findsOneWidget);
    expect(find.byTooltip('Observado: excluido de impresión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
