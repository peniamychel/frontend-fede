import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/jerarquia_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('trabaja solo con Carrasco Tropical y muestra productores', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final api = _ApiJerarquia();
      await tester.pumpWidget(
        TemaScope(
          preferencia: PreferenciaTema(),
          child: PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(home: JerarquiaPagina()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Federaciones'), findsNothing);
      expect(find.text('OTRA FEDERACIÓN'), findsNothing);
      expect(find.text('Centrales de CARRASCO TROPICAL'), findsOneWidget);
      expect(find.byTooltip('Avance general de impresión'), findsOneWidget);
      expect(
        find.byTooltip('Informe de impresión de la central'),
        findsNWidgets(2),
      );

      final alfa = find.byKey(const ValueKey('central-19'));
      final central = find.byKey(const ValueKey('central-20'));
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );

      await tester.tap(
        find.descendant(of: central, matching: find.byTooltip('Fijar arriba')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(central).dy,
        lessThan(tester.getTopLeft(alfa).dy),
      );
      final preferencias = await SharedPreferences.getInstance();
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '20',
      ]);

      await tester.tap(
        find.descendant(of: alfa, matching: find.byTooltip('Fijar arriba')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 centrales fijadas arriba'), findsOneWidget);
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '20',
        '19',
      ]);

      await tester.tap(
        find.descendant(
          of: central,
          matching: find.byTooltip('Quitar de arriba'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '19',
      ]);

      await tester.tap(find.byTooltip('Restablecer orden alfabético'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );
      expect(
        preferencias.getStringList('jerarquia.central_fijada.carrasco'),
        isNull,
      );

      await tester.tap(find.text('CENTRAL DE PRUEBA'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lista física del sindicato'), findsNWidgets(2));
      expect(find.byTooltip('Parcelas del sindicato'), findsNothing);
      expect(find.textContaining('ubicación'), findsNothing);
      expect(find.text('2 sindicatos · 16 productores'), findsOneWidget);
      expect(find.text('Total: 10 · 40% Impresión'), findsOneWidget);
      expect(find.text('Total: 6 · 50% Impresión'), findsOneWidget);
      expect(find.text('Ver sus productores'), findsNothing);

      await tester.tap(find.byTooltip('Acciones').last);
      await tester.pumpAndSettle();
      expect(find.text('Parcelas'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SINDICATO UNO'));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Cambiar federación: CARRASCO TROPICAL'),
        findsNothing,
      );
      expect(
        find.byTooltip('Cambiar central: CENTRAL DE PRUEBA'),
        findsOneWidget,
      );
      expect(find.text('Sindicatos de CENTRAL DE PRUEBA'), findsOneWidget);
      expect(
        find.text('Buscar por nombre, apellido, cédula o carné'),
        findsOneWidget,
      );
      expect(
        find.text('Central CENTRAL DE PRUEBA · 10 productores'),
        findsOneWidget,
      );
      expect(api.ultimoSindicatoConsultado, 30);

      await tester.tap(find.text('SINDICATO DOS'));
      await tester.pumpAndSettle();
      expect(api.ultimoSindicatoConsultado, 31);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _ApiJerarquia extends ApiClient {
  int? ultimoSindicatoConsultado;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/federaciones') {
      return [
        {'id': 10, 'nombre': 'CARRASCO TROPICAL'},
        {'id': 99, 'nombre': 'OTRA FEDERACIÓN'},
      ];
    }
    if (ruta == '/federaciones/10/centrales') {
      return [
        {
          'id': 19,
          'nombre': 'ALFA CENTRAL',
          'federacionId': 10,
          'federacionNombre': 'CARRASCO TROPICAL',
        },
        {
          'id': 20,
          'nombre': 'CENTRAL DE PRUEBA',
          'federacionId': 10,
          'federacionNombre': 'CARRASCO TROPICAL',
        },
      ];
    }
    if (ruta == '/centrales/20/sindicatos') {
      return [
        {
          'id': 30,
          'nombre': 'SINDICATO UNO',
          'centralId': 20,
          'centralNombre': 'CENTRAL DE PRUEBA',
        },
        {
          'id': 31,
          'nombre': 'SINDICATO DOS',
          'centralId': 20,
          'centralNombre': 'CENTRAL DE PRUEBA',
        },
      ];
    }
    if (ruta == '/centrales/20/credenciales/impresion') {
      return {
        'centralId': 20,
        'central': 'CENTRAL DE PRUEBA',
        'federacion': 'CARRASCO TROPICAL',
        'sindicatos': 2,
        'sindicatosSinSello': 0,
        'total': 16,
        'impresos': 7,
        'pendientes': 9,
        'pendientesConFoto': 4,
        'sinFoto': 5,
        'listosParaImprimir': 4,
        'porcentajeAvance': 43.8,
        'detalle': [
          {
            'sindicatoId': 30,
            'sindicato': 'SINDICATO UNO',
            'selloCargado': true,
            'total': 10,
            'impresos': 4,
            'pendientes': 6,
            'pendientesConFoto': 3,
            'sinFoto': 3,
            'listosParaImprimir': 3,
            'porcentajeAvance': 40,
          },
          {
            'sindicatoId': 31,
            'sindicato': 'SINDICATO DOS',
            'selloCargado': true,
            'total': 6,
            'impresos': 3,
            'pendientes': 3,
            'pendientesConFoto': 1,
            'sinFoto': 2,
            'listosParaImprimir': 1,
            'porcentajeAvance': 50,
          },
        ],
      };
    }
    if (ruta == '/productores') {
      ultimoSindicatoConsultado = query?['sindicatoId'] as int?;
      return {
        'content': <dynamic>[],
        'page': {'size': 25, 'number': 0, 'totalElements': 0, 'totalPages': 0},
      };
    }
    return <dynamic>[];
  }
}
