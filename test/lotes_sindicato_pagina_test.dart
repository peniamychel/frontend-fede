import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/lotes/lotes_sindicato_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  testWidgets('solo permite eliminar parcelas sin productor asignado', (
    tester,
  ) async {
    final api = _ApiParcelas();

    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(
          home: LotesSindicatoPagina(
            sindicato: Sindicato(
              id: 7,
              nombre: '1RO DE MAYO',
              centralId: 3,
              centralNombre: '13 DE JUNIO',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hay dos parcelas, pero el botón solo aparece en la que está libre.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.byTooltip('Eliminar parcela'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar parcela'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar parcela 12?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(api.eliminados, [12]);
    expect(find.text('12'), findsNothing);
    expect(find.text('13'), findsOneWidget);
    expect(find.byTooltip('Eliminar parcela'), findsNothing);
  });
}

class _ApiParcelas extends ApiClient {
  final List<int> eliminados = [];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta != '/lotes') return <dynamic>[];

    return [
      if (!eliminados.contains(12)) _lote(12),
      _lote(
        13,
        tenedor: {
          'productorId': 25,
          'nombre': 'JUAN QUISPE',
          'desde': '2026-08-01',
        },
      ),
    ];
  }

  @override
  Future<void> eliminar(String ruta) async {
    eliminados.add(int.parse(ruta.split('/').last));
  }

  Map<String, dynamic> _lote(int id, {Map<String, dynamic>? tenedor}) => {
    'id': id,
    'numero': '$id',
    'codigo': '$id',
    'estado': 'SIN_SISTEMA',
    'sindicatoId': 7,
    'sindicatoNombre': '1RO DE MAYO',
    'tenedor': tenedor,
  };
}
