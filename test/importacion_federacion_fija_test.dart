import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/importacion/importacion_pagina.dart';

void main() {
  test(
    'resuelve Carrasco por nombre aunque no sea la primera ni tenga ID 3',
    () async {
      final api = _ApiFederaciones([
        {'id': 3, 'nombre': 'OTRA FEDERACIÓN'},
        {'id': 91, 'nombre': '  Carrasco   Tropical  '},
      ]);
      expect((await FederacionRepository(api).deTrabajo()).id, 91);
    },
  );

  for (final lista in <List<Map<String, dynamic>>>[
    [],
    [
      {'id': 1, 'nombre': 'OTRA FEDERACIÓN'},
    ],
    [
      {'id': 2, 'nombre': 'CARRASCO TROPICAL'},
      {'id': 3, 'nombre': 'carrasco tropical'},
    ],
  ]) {
    test(
      'no adivina el destino si hay ${lista.length} filas sin coincidencia única',
      () async {
        await expectLater(
          FederacionRepository(_ApiFederaciones(lista)).deTrabajo(),
          throwsStateError,
        );
      },
    );
  }

  testWidgets('no muestra selector aunque existan otras federaciones', (
    tester,
  ) async {
    final api = _ApiFederaciones([
      {'id': 1, 'nombre': 'OTRA FEDERACIÓN'},
      {'id': 91, 'nombre': 'CARRASCO TROPICAL'},
    ]);
    await tester.pumpWidget(_pagina(api));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<Federacion>), findsNothing);
    expect(find.text('Federación destino'), findsNothing);
    expect(find.text('OTRA FEDERACIÓN'), findsNothing);
    expect(find.textContaining('Destino: CARRASCO TROPICAL'), findsOneWidget);
    expect(find.text('Elegir planilla .xlsx'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin Carrasco bloquea la carga y permite reintentar', (
    tester,
  ) async {
    final api = _ApiFederaciones([
      {'id': 1, 'nombre': 'OTRA FEDERACIÓN'},
    ]);
    await tester.pumpWidget(_pagina(api));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se encontró una única federación'),
      findsOneWidget,
    );
    expect(find.text('Elegir planilla .xlsx'), findsNothing);
    api.federaciones = [
      {'id': 91, 'nombre': 'CARRASCO TROPICAL'},
    ];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir planilla .xlsx'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _pagina(_ApiFederaciones api) => PadronScope(
  padron: Padron(api: api),
  child: const MaterialApp(home: ImportacionPagina()),
);

class _ApiFederaciones extends ApiClient {
  _ApiFederaciones(this.federaciones);
  List<Map<String, dynamic>> federaciones;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    expect(ruta, '/federaciones');
    return federaciones;
  }
}
