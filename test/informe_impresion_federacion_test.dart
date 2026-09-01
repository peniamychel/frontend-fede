import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/informe_impresion_federacion_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  testWidgets('muestra tabla global y mantiene las centrales colapsadas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiInformeFederacion()),
        child: const MaterialApp(
          home: InformeImpresionFederacionPagina(
            federacion: Federacion(id: 1, nombre: 'CARRASCO TROPICAL'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avance general de impresión'), findsOneWidget);
    expect(
      find.text('2 centrales · 3 sindicatos · 20 productores'),
      findsOneWidget,
    );
    expect(find.text('Resumen por central'), findsOneWidget);
    expect(find.text('Productores'), findsOneWidget);
    expect(find.text('Impresos'), findsOneWidget);
    expect(find.text('No impresos'), findsOneWidget);
    expect(find.text('Generar informe PDF'), findsOneWidget);
    expect(find.text('60%'), findsWidgets);
    expect(find.text('Sindicatos sin sello'), findsNothing);

    await tester.tap(find.text('13 DE JUNIO').last);
    await tester.pumpAndSettle();

    expect(find.text('Sindicatos sin sello'), findsOneWidget);
    expect(find.text('Detalle por sindicato'), findsOneWidget);
    expect(find.text('1RO DE MAYO'), findsOneWidget);
    expect(find.text('Abrir informe completo'), findsOneWidget);
  });
}

class _ApiInformeFederacion extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/federaciones/1/credenciales/impresion') {
      return {
        'federacionId': 1,
        'federacion': 'CARRASCO TROPICAL',
        'centrales': 2,
        'sindicatos': 3,
        'sindicatosSinSello': 1,
        'total': 20,
        'impresos': 12,
        'pendientes': 8,
        'pendientesConFoto': 5,
        'sinFoto': 3,
        'listosParaImprimir': 5,
        'porcentajeAvance': 60,
        'detalle': [
          {
            'centralId': 10,
            'central': '13 DE JUNIO',
            'federacion': 'CARRASCO TROPICAL',
            'sindicatos': 1,
            'sindicatosSinSello': 1,
            'total': 12,
            'impresos': 9,
            'pendientes': 3,
            'pendientesConFoto': 2,
            'sinFoto': 1,
            'listosParaImprimir': 2,
            'porcentajeAvance': 75,
            'detalle': [
              {
                'sindicatoId': 100,
                'sindicato': '1RO DE MAYO',
                'selloCargado': false,
                'total': 12,
                'impresos': 9,
                'pendientes': 3,
                'pendientesConFoto': 2,
                'sinFoto': 1,
                'listosParaImprimir': 2,
                'porcentajeAvance': 75,
              },
            ],
          },
          {
            'centralId': 11,
            'central': 'CHIMORÉ',
            'federacion': 'CARRASCO TROPICAL',
            'sindicatos': 2,
            'sindicatosSinSello': 0,
            'total': 8,
            'impresos': 3,
            'pendientes': 5,
            'pendientesConFoto': 3,
            'sinFoto': 2,
            'listosParaImprimir': 3,
            'porcentajeAvance': 37.5,
            'detalle': <Object?>[],
          },
        ],
      };
    }
    return <Object?>[];
  }
}
