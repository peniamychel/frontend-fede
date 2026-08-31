import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

void main() {
  testWidgets('revisa al importado una sola vez al abrir su ficha', (
    tester,
  ) async {
    final api = _ApiRevisionSie();
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);

    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.revisiones, 1);
    expect(find.text('Datos corregidos con SIE'), findsOneWidget);
    expect(find.text('JOSÉ PEÑA MUÑOZ'), findsOneWidget);

    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();

    expect(
      api.revisiones,
      1,
      reason: 'una recarga no debe consultar SIE otra vez',
    );
  });
}

class _ApiRevisionSie extends ApiClient {
  int revisiones = 0;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      final revisado = revisiones > 0;
      return {
        'productor': {
          'id': 42,
          'nombres': revisado ? 'JOSÉ' : 'JOSE',
          'apellidos': revisado ? 'PEÑA MUÑOZ' : 'PENA MUNOZ',
          'nombreCompleto': revisado ? 'JOSÉ PEÑA MUÑOZ' : 'JOSE PENA MUNOZ',
          'ci': '123456',
          'sindicatoId': 7,
          'sindicatoNombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
          'revisionSiePendiente': !revisado,
        },
        'lotes': <dynamic>[],
        'imagenes': <dynamic>[],
      };
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/productores/42/revision-sie') {
      revisiones++;
      return {
        'estado': 'CORREGIDA',
        'completada': true,
        'datosModificados': true,
        'mensaje': 'SIE corrigió los nombres y apellidos.',
      };
    }
    return <String, dynamic>{};
  }
}
