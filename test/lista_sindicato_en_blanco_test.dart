import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/api_client.dart' show DescargaBinaria;
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/informe_impresion_sindicato_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

const _sindicato = Sindicato(
  id: 7,
  nombre: 'SINDICATO DE EJEMPLO',
  centralId: 3,
  centralNombre: 'CENTRAL DE EJEMPLO',
);

Future<void> _abrir(WidgetTester tester, _ApiLista api) async {
  await tester.pumpWidget(
    PadronScope(
      padron: Padron(api: api),
      child: const MaterialApp(
        home: InformeImpresionSindicatoPagina(sindicato: _sindicato),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Lista en blanco'));
  await tester.tap(find.text('Lista en blanco'));
  await tester.pumpAndSettle();
}

void main() {
  test('envía la cantidad por la API autenticada del sindicato', () async {
    final api = _ApiLista();
    addTearDown(api.cerrar);
    await expectLater(
      Padron(api: api).sindicatos.descargarListaEnBlanco(7, 65),
      throwsA(isA<ApiException>()),
    );
    expect(api.descargas, [
      {'ruta': '/sindicatos/7/informes/lista-en-blanco.pdf', 'filas': 65},
    ]);
  });

  for (final ancho in [390.0, 1024.0]) {
    testWidgets(
      'pide afiliados antes de generar y cancelar no descarga, $ancho px',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiLista();
        addTearDown(api.cerrar);
        await _abrir(tester, api);
        expect(find.text('Generar lista en blanco'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          '3',
        );
        expect(api.descargas, isEmpty);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(api.descargas, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        final boton = find.widgetWithText(FilledButton, 'Lista en blanco');
        expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'valida la cantidad y usa las filas elegidas, no el total del padrón',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiLista();
      addTearDown(api.cerrar);
      await _abrir(tester, api);
      for (final valor in ['', '0', '-1', '1.5', 'abc', '5001']) {
        await tester.enterText(find.byType(TextFormField), valor);
        await tester.tap(find.text('Generar PDF'));
        await tester.pumpAndSettle();
        expect(find.text('Ingresá un número entre 1 y 5000.'), findsOneWidget);
        expect(api.descargas, isEmpty);
      }
      await tester.enterText(find.byType(TextFormField), '17');
      await tester.tap(find.text('Generar PDF'));
      await tester.pumpAndSettle();
      expect(api.descargas, [
        {'ruta': '/sindicatos/7/informes/lista-en-blanco.pdf', 'filas': 17},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin productores registrados permite indicar afiliados manualmente',
    (tester) async {
      final api = _ApiLista(total: 0);
      addTearDown(api.cerrar);
      await _abrir(tester, api);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextFormField), '25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.descargas.single['filas'], 25);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ApiLista extends ApiClient {
  _ApiLista({this.total = 3});
  final int total;
  final descargas = <Map<String, dynamic>>[];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/sindicatos/7/informes/avance') {
      return {'sindicatoId': 7, 'sindicato': _sindicato.nombre, 'total': total};
    }
    if (ruta == '/sindicatos/7/informes/fases') return [];
    throw StateError('Consulta inesperada: $ruta');
  }

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    descargas.add({'ruta': ruta, 'filas': query?['filas']});
    // No se abre el diálogo nativo de archivos durante estas pruebas.
    throw const ApiException(
      estado: 503,
      mensaje: 'Descarga simulada para prueba',
    );
  }
}
