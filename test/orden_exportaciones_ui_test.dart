import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/informe_impresion_central_pagina.dart';
import 'package:fede/ui/credenciales/informe_impresion_sindicato_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _central = Central(
  id: 3,
  nombre: 'CENTRAL',
  federacionId: 1,
  federacionNombre: 'FEDERA',
);
const _sindicato = Sindicato(
  id: 7,
  nombre: 'SINDICATO',
  centralId: 3,
  centralNombre: 'CENTRAL',
);

void main() {
  for (final ancho in [390.0, 1200.0]) {
    for (final central in [false, true]) {
      for (final informe in [
        (
          'Informe pre-impresión',
          central
              ? '/centrales/3/credenciales/impresion/informe-pre-impresion.pdf'
              : '/sindicatos/7/informes/pre-impresion.pdf',
        ),
        (
          'Preimpresión con observaciones',
          central
              ? '/centrales/3/credenciales/impresion/pre-impresion-observaciones.pdf'
              : '/sindicatos/7/informes/pre-impresion-observaciones.pdf',
        ),
        (
          'Informe de revisión del padrón',
          central
              ? '/centrales/3/credenciales/impresion/revision-padron.pdf'
              : '/sindicatos/7/informes/revision-padron.pdf',
        ),
        (
          'Lista de productores en Excel',
          central
              ? '/centrales/3/credenciales/impresion/productores.xlsx'
              : '/sindicatos/7/informes/productores.xlsx',
        ),
        if (!central) ('Nómina en PDF', '/sindicatos/7/informes/nomina.pdf'),
        (
          central
              ? '@Descargar informe de la fase'
              : '@Descargar informe de esta fase',
          central
              ? '/centrales/3/fases-impresion/9/informe.pdf'
              : '/sindicatos/7/informes/fases/9/informe.pdf',
        ),
      ]) {
        testWidgets(
          'elige orden antes de ${informe.$1}, central $central, $ancho px',
          (tester) async {
            tester.view.physicalSize = Size(ancho, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final api = _ApiInformes();
            addTearDown(api.cerrar);
            await tester.pumpWidget(
              PadronScope(
                padron: Padron(api: api),
                child: MaterialApp(
                  home: central
                      ? const InformeImpresionCentralPagina(central: _central)
                      : const InformeImpresionSindicatoPagina(
                          sindicato: _sindicato,
                        ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final accion = informe.$1.startsWith('@')
                ? find.byTooltip(informe.$1.substring(1))
                : find.text(informe.$1);
            Future<void> abrirPregunta() async {
              await tester.ensureVisible(accion);
              await tester.pumpAndSettle();
              await tester.tap(accion);
              await tester.pumpAndSettle();
              expect(find.text('Orden de la lista'), findsOneWidget);
              expect(find.text('Apellidos'), findsOneWidget);
              expect(find.text('Número de lote'), findsOneWidget);
            }

            await abrirPregunta();
            expect(api.descargas, isEmpty);
            await tester.tap(find.text('Cancelar'));
            await tester.pumpAndSettle();
            expect(api.descargas, isEmpty);

            await abrirPregunta();
            await tester.tap(find.text('Número de lote'));
            await tester.tap(find.text('Generar'));
            await tester.pumpAndSettle();
            expect(api.descargas, [(informe.$2, 'NUMERO_LOTE')]);

            // Cada exportación vuelve a preguntar y conserva apellidos como opción inicial.
            await abrirPregunta();
            await tester.tap(find.text('Generar'));
            await tester.pumpAndSettle();
            expect(api.descargas, [
              (informe.$2, 'NUMERO_LOTE'),
              (informe.$2, 'APELLIDOS'),
            ]);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _ApiInformes extends ApiClient {
  final descargas = <(String, String?)>[];
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/centrales/3/credenciales/impresion') {
      return {
        'centralId': 3,
        'central': 'CENTRAL',
        'federacion': 'FEDERA',
        'total': 3,
        'detalle': [],
      };
    }
    if (ruta == '/centrales/3/fases-impresion') {
      return {
        'centralId': 3,
        'central': 'CENTRAL',
        'historial': [
          {
            'id': 9,
            'numero': 1,
            'estado': 'CERRADA',
            'total': 3,
            'impresos': 2,
            'pendientes': 1,
          },
        ],
      };
    }
    if (ruta == '/sindicatos/7/informes/avance') {
      return {'sindicatoId': 7, 'sindicato': 'SINDICATO', 'total': 3};
    }
    if (ruta == '/sindicatos/7/informes/fases') {
      return [
        {'id': 9, 'numero': 1, 'abierta': false},
      ];
    }
    throw StateError('Consulta inesperada: $ruta');
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/centrales/3/credenciales/impresion/informe-nominal') {
      return {
        'centralId': 3,
        'central': 'CENTRAL',
        'federacion': 'FEDERA',
        'sindicatos': [],
      };
    }
    throw StateError('Solicitud inesperada: $ruta');
  }

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    descargas.add((ruta, query?['orden'] as String?));
    // Se prueba la petición, sin abrir el selector nativo de archivos.
    throw const ApiException(
      estado: 503,
      mensaje: 'Respuesta simulada de descarga',
    );
  }
}
