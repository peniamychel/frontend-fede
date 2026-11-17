import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:fede/ui/widgets/descargar_productores_excel_boton.dart';

void main() {
  const etiqueta = 'Lista de productores en Excel';
  const mime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  test(
    'ambos repositorios descargan XLSX autenticado y respetan nombre y MIME',
    () async {
      final rutas = <String>[];
      final api = ApiClient(
        cliente: MockClient((peticion) async {
          rutas.add(peticion.url.path);
          expect(peticion.method, 'GET');
          expect(peticion.headers['Authorization'], 'Bearer token-de-prueba');
          return http.Response.bytes(
            [80, 75, 3, 4],
            200,
            headers: {
              'content-type': mime,
              'content-disposition':
                  'attachment; filename="productores-prueba.xlsx"',
            },
          );
        }),
      );
      addTearDown(api.cerrar);
      api.usarToken('token-de-prueba');
      final padron = Padron(api: api);
      for (final archivo in [
        await padron.centrales.descargarProductoresExcel(3),
        await padron.sindicatos.descargarProductoresExcel(7),
      ]) {
        expect(archivo.bytes, [80, 75, 3, 4]);
        expect(archivo.nombreArchivo, 'productores-prueba.xlsx');
        expect(archivo.tipoMime, mime);
      }
      expect(rutas, [
        '/api/v1/centrales/3/credenciales/impresion/productores.xlsx',
        '/api/v1/sindicatos/7/informes/productores.xlsx',
      ]);
    },
  );

  for (final central in [true, false]) {
    for (final ancho in [320.0, 1024.0]) {
      testWidgets(
        'descarga del alcance correcto, sin duplicados y permite reintentar: $central, $ancho',
        (tester) async {
          tester.view.physicalSize = Size(ancho, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _ApiExcel();
          addTearDown(api.cerrar);
          await tester.pumpWidget(
            PadronScope(
              padron: Padron(api: api),
              child: MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: central
                        ? const DescargarProductoresExcelBoton.central(id: 3)
                        : const DescargarProductoresExcelBoton.sindicato(id: 7),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text(etiqueta));
          await tester.pump();
          final boton = find.widgetWithText(FilledButton, etiqueta);
          expect(tester.widget<FilledButton>(boton).onPressed, isNull);
          expect(api.rutas, isEmpty);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Generar'));
          await tester.pump();
          expect(api.rutas, [
            central
                ? '/centrales/3/credenciales/impresion/productores.xlsx'
                : '/sindicatos/7/informes/productores.xlsx',
          ]);
          api.pendiente.completeError(
            const ApiException(estado: 503, mensaje: 'Error simulado'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Error simulado'), findsOneWidget);
          expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('sin permiso de informes oculta la descarga', (tester) async {
    final api = ApiClient();
    final sesion = SesionControlador(AutenticacionRepository(api));
    addTearDown(sesion.dispose);
    addTearDown(api.cerrar);
    await tester.pumpWidget(
      SesionScope(
        controlador: sesion,
        child: const MaterialApp(
          home: Scaffold(body: DescargarProductoresExcelBoton.sindicato(id: 7)),
        ),
      ),
    );
    expect(find.text(etiqueta), findsNothing);
  });
}

class _ApiExcel extends ApiClient {
  final rutas = <String>[];
  final pendiente = Completer<DescargaBinaria>();

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) {
    rutas.add(ruta);
    return pendiente.future;
  }
}
