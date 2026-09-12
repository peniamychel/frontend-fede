import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

void main() {
  testWidgets('permite observar con motivo y quitar la observación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiObservacion();
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(home: ProductorDetallePagina(productorId: 42)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Marcar como observado'));
    await tester.pumpAndSettle();
    expect(find.text('Marcar como observado'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      'La fotografía no permite identificarlo',
    );
    await tester.tap(find.text('Guardar observación'));
    await tester.pumpAndSettle();

    expect(api.observacion, 'La fotografía no permite identificarlo');
    expect(find.text('Observación manual'), findsOneWidget);
    expect(find.text(api.observacion!), findsOneWidget);
    expect(find.textContaining('excluido de la impresión'), findsOneWidget);
    expect(find.byTooltip('Editar observación'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar observación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar observación'));
    await tester.pumpAndSettle();

    expect(api.observacion, isNull);
    expect(find.text('Observación manual'), findsNothing);
    expect(find.byTooltip('Marcar como observado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la lista muestra la observación y bloquea el icono de impresión',
    (tester) async {
      final productor = Productor.desdeJson({
        ..._ApiObservacion.productorJson,
        'observado': true,
        'observacion': 'REVISAR CÉDULA',
        'credencialLista': false,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilaProductor(productor: productor, alTocar: () {}),
          ),
        ),
      );

      expect(find.text('Observado: REVISAR CÉDULA'), findsOneWidget);
      expect(
        find.byTooltip('Observado: excluido de impresión'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la lista identifica al deshabilitado como excluido', (
    tester,
  ) async {
    final productor = Productor.desdeJson({
      ..._ApiObservacion.productorJson,
      'credencialLista': false,
      'auditoria': {'estado': false},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilaProductor(productor: productor, alTocar: () {}),
        ),
      ),
    );

    expect(
      find.byTooltip('Deshabilitado: excluido de impresión'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ApiObservacion extends ApiClient {
  String? observacion;

  static const productorJson = <String, dynamic>{
    'id': 42,
    'nombres': 'MARÍA',
    'apellidos': 'PÉREZ',
    'nombreCompleto': 'MARÍA PÉREZ',
    'ci': '1234567',
    'codigoPadron': '213J100',
    'sindicatoId': 7,
    'sindicatoNombre': '1RO DE MAYO',
    'centralId': 3,
    'centralNombre': '13 DE JUNIO',
    'auditoria': {'estado': true},
  };

  Map<String, dynamic> get _productor => {
    ...productorJson,
    'observado': observacion != null,
    'observacion': observacion,
    'credencialLista': observacion == null,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      return {
        'productor': _productor,
        'lotes': <dynamic>[],
        'imagenes': <dynamic>[],
      };
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    if (ruta == '/productores/42/observacion') {
      observacion = (cuerpo as Map<String, dynamic>)['texto'] as String;
      return _productor;
    }
    return const <String, dynamic>{};
  }

  @override
  Future<Object?> eliminarConRespuesta(
    String ruta, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta == '/productores/42/observacion') {
      observacion = null;
      return _productor;
    }
    return const <String, dynamic>{};
  }
}
