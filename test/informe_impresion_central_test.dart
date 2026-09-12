import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/informe_impresion_central_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const central = Central(
    id: 13,
    nombre: '13 DE JUNIO',
    federacionId: 1,
    federacionNombre: 'FEDERA',
  );

  testWidgets('muestra totales, porcentaje y detalle por sindicato', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiInforme()),
        child: const MaterialApp(
          home: InformeImpresionCentralPagina(central: central),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avance general'), findsOneWidget);
    expect(find.text('43.8%'), findsOneWidget);
    expect(find.text('7 de 16 carnets impresos'), findsOneWidget);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Sin foto'), findsOneWidget);
    expect(find.text('Observados'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Sin sistema'), findsOneWidget);
    expect(find.textContaining('con foto'), findsNothing);
    expect(find.textContaining('Con foto'), findsNothing);
    expect(find.textContaining('Listos'), findsNothing);
    expect(find.text('Sindicatos sin sello'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sindicatos que todavía no tienen sello'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sindicatos que todavía no tienen sello'), findsOneWidget);
    expect(find.text('NUEVA ESPERANZA'), findsWidgets);
    expect(find.text('Informe general'), findsOneWidget);
    expect(find.text('Planilla de sellos y firmas'), findsOneWidget);
    expect(find.text('Informe nominal completo'), findsNothing);
    expect(find.text('Informe nominal por sindicatos'), findsNothing);
    expect(find.text('Informe pre-impresión'), findsOneWidget);
    expect(find.text('Fases de impresión'), findsOneWidget);
    expect(find.text('1ra fase de impresión habilitada'), findsOneWidget);
    expect(find.byTooltip('Descargar informe en PDF'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('avance-sindicato-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1RO DE MAYO'), findsOneWidget);
    final avancePrimero = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('avance-sindicato-1')),
    );
    expect(avancePrimero.value, 0.4);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('avance-sindicato-2')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final avanceSegundo = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('avance-sindicato-2')),
    );
    expect(find.text('NUEVA ESPERANZA'), findsWidgets);
    expect(avanceSegundo.value, 0.5);
  });

  testWidgets('integra listas nominales colapsadas sin acciones redundantes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiInforme();
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(
          home: InformeImpresionCentralPagina(central: central),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MARÍA PÉREZ'), findsNothing);
    expect(api.ultimaSeleccion, [1, 2]);

    await tester.scrollUntilVisible(
      find.text('1RO DE MAYO'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1RO DE MAYO'));
    await tester.pumpAndSettle();
    expect(find.text('Carnets impresos (1)'), findsOneWidget);
    expect(find.text('No impresos por datos faltantes (1)'), findsOneWidget);
    expect(find.text('MARÍA PÉREZ'), findsOneWidget);
    expect(find.text('Fotografía, Cédula, Número de lote'), findsOneWidget);
    expect(find.text('Observados: 1'), findsOneWidget);
    expect(find.text('Sistema: 6'), findsOneWidget);
    expect(find.text('Sin sistema: 4'), findsOneWidget);
    expect(find.text('Avance: 40.0%'), findsOneWidget);

    expect(find.text('Informe nominal completo'), findsNothing);
    expect(find.text('Informe nominal por sindicatos'), findsNothing);
  });
}

class _ApiInforme extends ApiClient {
  List<int>? ultimaSeleccion;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/centrales/13/fases-impresion') {
      return const {
        'centralId': 13,
        'central': '13 DE JUNIO',
        'faseActiva': {
          'id': 7,
          'numero': 1,
          'estado': 'ABIERTA',
          'abiertaEn': '2026-09-11T08:00:00',
          'cerradaEn': null,
          'total': 16,
          'impresos': 7,
          'pendientes': 9,
        },
        'historial': [
          {
            'id': 7,
            'numero': 1,
            'estado': 'ABIERTA',
            'abiertaEn': '2026-09-11T08:00:00',
            'cerradaEn': null,
            'total': 16,
            'impresos': 7,
            'pendientes': 9,
          },
        ],
      };
    }
    if (ruta != '/centrales/13/credenciales/impresion') {
      throw StateError('Ruta no simulada: $ruta');
    }
    return const {
      'centralId': 13,
      'central': '13 DE JUNIO',
      'federacion': 'FEDERA',
      'sindicatos': 2,
      'sindicatosSinSello': 1,
      'total': 16,
      'impresos': 7,
      'pendientes': 9,
      'pendientesConFoto': 6,
      'sinFoto': 3,
      'listosParaImprimir': 4,
      'observados': 3,
      'sistema': 8,
      'sinSistema': 8,
      'porcentajeAvance': 43.8,
      'detalle': [
        {
          'sindicatoId': 1,
          'sindicato': '1RO DE MAYO',
          'selloCargado': true,
          'total': 10,
          'impresos': 4,
          'pendientes': 6,
          'pendientesConFoto': 5,
          'sinFoto': 1,
          'listosParaImprimir': 3,
          'observados': 1,
          'sistema': 6,
          'sinSistema': 4,
          'porcentajeAvance': 40,
        },
        {
          'sindicatoId': 2,
          'sindicato': 'NUEVA ESPERANZA',
          'selloCargado': false,
          'total': 6,
          'impresos': 3,
          'pendientes': 3,
          'pendientesConFoto': 1,
          'sinFoto': 2,
          'listosParaImprimir': 1,
          'observados': 2,
          'sistema': 2,
          'sinSistema': 4,
          'porcentajeAvance': 50,
        },
      ],
    };
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta != '/centrales/13/credenciales/impresion/informe-nominal') {
      throw StateError('Ruta no simulada: $ruta');
    }
    final ids = ((cuerpo as Map<String, dynamic>)['sindicatoIds'] as List)
        .cast<int>();
    ultimaSeleccion = [...ids];
    return {
      'centralId': 13,
      'central': '13 DE JUNIO',
      'federacion': 'FEDERA',
      'totalImpresos': ids.length,
      'totalFaltantesDatos': ids.length,
      'sindicatos': [
        if (ids.contains(1))
          {
            'sindicatoId': 1,
            'sindicato': '1RO DE MAYO',
            'impresos': [
              {
                'productorId': 8,
                'nombres': 'MARÍA',
                'apellidos': 'PÉREZ',
                'ci': '123',
                'lotes': '22 A',
                'codigoPadron': '213J8',
                'impresiones': 2,
                'ultimaImpresion': '2026-08-28T10:30:00',
                'datosFaltantes': <String>[],
              },
            ],
            'faltantesDatos': [
              {
                'productorId': 9,
                'nombres': 'JUAN',
                'apellidos': 'MAMANI',
                'ci': '',
                'lotes': '23',
                'codigoPadron': '213J9',
                'impresiones': 0,
                'ultimaImpresion': null,
                'datosFaltantes': ['Fotografía', 'Cédula', 'Número de lote'],
              },
            ],
          },
        if (ids.contains(2))
          {
            'sindicatoId': 2,
            'sindicato': 'NUEVA ESPERANZA',
            'impresos': <dynamic>[],
            'faltantesDatos': <dynamic>[],
          },
      ],
    };
  }
}
