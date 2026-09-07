import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/lotes/lote_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  for (final ubicado in [false, true]) {
    testWidgets('no ofrece mapa para lote con ubicación: $ubicado', (
      tester,
    ) async {
      final api = _ApiLote(ubicado: ubicado);
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: LotePagina(loteId: 66)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ubicar en el mapa'), findsNothing);
      expect(find.text('Mover en el mapa'), findsNothing);
      expect(find.text('Sin ubicación'), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.text('Cambiar número'), findsOneWidget);
      expect(find.text('Cambiar clasificación'), findsOneWidget);
      expect(find.text('Poner medida'), findsOneWidget);
      expect(find.text('Vender o traspasar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('elegir Sistema solo cambia la clasificación del lote', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiLote();

    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: LotePagina(loteId: 66)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cambiar clasificación'), findsOneWidget);
    await tester.tap(find.text('Cambiar clasificación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sistema').last);
    await tester.pumpAndSettle();

    expect(api.ultimaClasificacion, 'CON_SISTEMA');
    expect(api.consultoSistemas, isFalse);
    expect(find.text('Elegí el sistema que se instalará'), findsNothing);
  });

  testWidgets('permite cambiar el número del lote desde su ficha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiLote();

    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: LotePagina(loteId: 66)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar número'));
    await tester.pumpAndSettle();
    expect(find.text('Extensión'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nuevo número *'),
      '99',
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('se recalcularán automáticamente'),
      findsOneWidget,
    );
    expect(find.textContaining('OTRA PRODUCTORA'), findsOneWidget);
    await tester.tap(find.text('Guardar número'));
    await tester.pumpAndSettle();

    expect(api.ultimoNumero, '99');
    expect(find.text('Lote 99'), findsOneWidget);
  });
}

class _ApiLote extends ApiClient {
  _ApiLote({this.ubicado = false});
  final bool ubicado;
  bool consultoSistemas = false;
  String numero = '66';
  String estado = 'SIN_SISTEMA';
  String? ultimoNumero;
  String? ultimaClasificacion;

  Map<String, dynamic> get _lote => {
    'id': 66,
    'numero': numero,
    'codigo': numero,
    'estado': estado,
    'sindicatoId': 7,
    'sindicatoNombre': '1RO DE MAYO',
    if (ubicado) ...{'latitud': -17.2, 'longitud': -65.1},
    'tenedor': {
      'productorId': 5,
      'nombre': 'FABIAN ALEGRE SANCHEZ',
      'desde': '2026-08-01',
    },
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/lotes/66') return _lote;
    if (ruta == '/lotes') {
      return [
        {
          'id': 90,
          'numero': '99',
          // La subdivisión histórica ya no separa el grupo automático.
          'extension': 'B',
          'codigo': '99-B',
          'estado': 'BLANCO',
          'sindicatoId': 7,
          'sindicatoNombre': '1RO DE MAYO',
          'tenedor': {
            'productorId': 9,
            'nombre': 'OTRA PRODUCTORA',
            'desde': '2026-08-01',
          },
        },
      ];
    }
    if (ruta == '/lotes/66/historial') {
      return <dynamic>[];
    }
    if (ruta == '/sistemas') {
      consultoSistemas = true;
      return <dynamic>[];
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta == '/lotes/66') {
      final datos = cuerpo as Map<String, dynamic>;
      ultimoNumero = datos['numero'] as String?;
      numero = ultimoNumero ?? numero;
      ultimaClasificacion = datos['estado'] as String?;
      estado = ultimaClasificacion ?? estado;
      return _lote;
    }
    throw StateError('Ruta inesperada: $ruta');
  }
}
