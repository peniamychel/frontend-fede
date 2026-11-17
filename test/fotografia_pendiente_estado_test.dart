import 'package:fede/models/productor.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la foto pendiente nunca se presenta como credencial lista', () {
    final pendiente = Productor.desdeJson({
      'id': 1,
      'credencialLista': true,
      'fotografiaPendienteEdicion': true,
    });
    expect(pendiente.fotografiaPendienteEdicion, isTrue);
    expect(pendiente.credencialLista, isFalse);
    final anterior = Productor.desdeJson({'id': 1, 'credencialLista': true});
    expect(anterior.fotografiaPendienteEdicion, isFalse);
    expect(anterior.credencialLista, isTrue);
  });

  testWidgets('reimpresión pendiente también muestra el bloqueo de foto', (
    tester,
  ) async {
    final productor = Productor.desdeJson({
      'id': 1,
      'nombres': 'ANA',
      'nombreCompleto': 'ANA PEREZ',
      'ci': '123',
      'fotografiaPendienteEdicion': true,
      'faseImpresionPendiente': true,
      'reimpresionFasePendiente': true,
      'credencialImpresiones': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilaProductor(
            productor: productor,
            alTocar: () {},
            mostrarRuta: false,
          ),
        ),
      ),
    );
    expect(find.text('Fotografía pendiente de edición'), findsOneWidget);
    expect(
      find.byTooltip('Fotografía pendiente de edición: impresión bloqueada'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Reimpresión pendiente para la fase actual o la próxima'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
