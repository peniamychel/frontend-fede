import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productores_pagina.dart';

void main() {
  const sindicato = Sindicato(
    id: 7,
    nombre: 'LIBERTAD',
    centralId: 3,
    centralNombre: 'IVIRGARZAMA',
  );

  testWidgets('ordena la lista del sindicato por apellidos o nombres', (
    tester,
  ) async {
    final api = _ApiOrden();
    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: SindicatoProductoresPagina(sindicato: sindicato),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.ultimaConsulta?['sort'], ['apellidos,asc', 'nombres,asc']);

    await tester.tap(find.byTooltip('Ordenar productores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nombres (A–Z)'));
    await tester.pumpAndSettle();

    expect(api.ultimaConsulta?['sort'], ['nombres,asc', 'apellidos,asc']);
  });

  testWidgets('busca dentro de todos los productores del sindicato', (
    tester,
  ) async {
    final api = _ApiOrden();
    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: SindicatoProductoresPagina(sindicato: sindicato),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Peña Muñoz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(api.ultimaConsulta?['sindicatoId'], 7);
    expect(api.ultimaConsulta?['texto'], 'Peña Muñoz');
  });

  testWidgets(
    'la lista general muestra primero los modificados recientemente',
    (tester) async {
      final api = _ApiOrden();
      final tema = PreferenciaTema();
      addTearDown(tema.dispose);

      await tester.pumpWidget(
        TemaScope(
          preferencia: tema,
          child: PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(home: ProductoresPagina()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.ultimaConsulta?['sort'], ['updatedAt,desc', 'id,desc']);
      expect(find.text('Modificados recientemente'), findsOneWidget);
    },
  );
}

class _ApiOrden extends ApiClient {
  Map<String, dynamic>? ultimaConsulta;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/centrales') return <dynamic>[];
    ultimaConsulta = query;
    return {
      'content': <dynamic>[],
      'page': {'size': 25, 'number': 0, 'totalElements': 0, 'totalPages': 0},
    };
  }
}
