import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/pagina.dart';
import 'package:fede/ui/widgets/lista_paginada.dart';

void main() {
  testWidgets('actualiza datos sin perder la posición del scroll', (
    tester,
  ) async {
    final clave = GlobalKey<ListaPaginadaState<int>>();
    var version = 0;

    Future<Pagina<int>> cargar(Paginacion paginacion) async => Pagina(
      contenido: List<int>.generate(100, (indice) => indice),
      tamano: 100,
      numero: 0,
      totalElementos: 100,
      totalPaginas: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListaPaginada<int>(
            key: clave,
            clave: 'productores',
            tamanoPagina: 100,
            cargar: cargar,
            constructor: (_, elemento) => SizedBox(
              height: 60,
              child: Text('Elemento $elemento · versión $version'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final desplazable = find.descendant(
      of: find.byType(ListaPaginada<int>),
      matching: find.byType(Scrollable),
    );
    final antes = tester.state<ScrollableState>(desplazable).position.pixels;
    expect(antes, greaterThan(0));

    version++;
    await clave.currentState!.refrescarConservandoPosicion();
    await tester.pumpAndSettle();

    final despues = tester.state<ScrollableState>(desplazable).position.pixels;
    expect(despues, closeTo(antes, 0.1));
    expect(find.textContaining('versión 1'), findsWidgets);
  });
}
