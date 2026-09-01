import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/impresion_credencial.dart';
import 'package:fede/ui/credenciales/pliego_previa_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const sindicato = Sindicato(
    id: 13,
    nombre: '13 DE JUNIO',
    centralId: 2,
    centralNombre: 'CENTRAL IVIRGARZAMA',
  );

  setUp(() => debugImpresionDeCredencialesDisponible = true);
  tearDown(() => debugImpresionDeCredencialesDisponible = null);

  testWidgets('muestra cantidades y acciones de impresión para Windows', (
    tester,
  ) async {
    final padron = Padron(api: _ApiPanel());
    await tester.pumpWidget(
      PadronScope(
        padron: padron,
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Ya impresos'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Faltan con foto'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Sin fotografía'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Impresiones faltantes (4)'), findsOneWidget);
    expect(find.text('Impresión selectiva'), findsOneWidget);
    expect(find.text('Revisar última impresión'), findsOneWidget);
    expect(find.text('Imprimir reversos'), findsOneWidget);
    expect(
      find.text('Impresora: se seleccionará antes de enviar'),
      findsOneWidget,
    );
  });

  testWidgets(
    'en web o Android muestra cantidades pero oculta acciones de impresión',
    (tester) async {
      debugImpresionDeCredencialesDisponible = false;
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: _ApiPanel()),
          child: const MaterialApp(
            home: PliegoPreviaPagina(sindicato: sindicato),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Ya impresos'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Faltan con foto'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Sin fotografía'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Vista informativa'), findsOneWidget);
      expect(find.textContaining('Impresiones faltantes'), findsNothing);
      expect(find.text('Impresión selectiva'), findsNothing);
      expect(find.text('Revisar última impresión'), findsNothing);
      expect(find.text('Imprimir reversos'), findsNothing);
      expect(find.textContaining('Impresora:'), findsNothing);
    },
  );

  testWidgets('permite revisar el último grupo contabilizado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiPanel(conUltimoGrupo: true)),
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Revisar última impresión'),
    );
    expect(boton.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Revisar última impresión'));
    await tester.tap(find.text('Revisar última impresión'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Marcá únicamente las tarjetas'),
      findsOneWidget,
    );
    expect(find.text('1 impresas'), findsOneWidget);
    expect(find.text('Cancelar todo el grupo'), findsOneWidget);
    expect(find.text('Guardar revisión (1)'), findsOneWidget);
  });
}

class _ApiPanel extends ApiClient {
  _ApiPanel({this.conUltimoGrupo = false});

  final bool conUltimoGrupo;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/configuracion/credencial') {
      return const {'diseno': <String, dynamic>{}, 'camposDisponibles': []};
    }
    if (ruta == '/sindicatos/13/credenciales/impresion') {
      return {
        'sindicatoId': 13,
        'sindicato': '13 DE JUNIO',
        'total': 12,
        'impresos': 5,
        'faltantesConFoto': 4,
        'sinFoto': 3,
        'listosParaImprimir': 4,
        'faltantesDelSindicato': const [],
        'candidatos': const [],
        if (conUltimoGrupo)
          'ultimoGrupo': {
            'id': 41,
            'enviadoEn': '2026-09-01T08:30:00',
            'total': 1,
            'productorIdsContabilizados': const [81],
            'candidatos': const [
              {
                'credencial': {
                  'productorId': 81,
                  'nombreCompleto': 'MARÍA PÉREZ',
                  'nombres': 'MARÍA',
                  'apellidos': 'PÉREZ',
                  'ci': '1234567',
                  'lotes': '22 A',
                  'codigoQr': '2-IVI-81',
                  'completa': true,
                  'faltantes': [],
                },
                'impresiones': 1,
                'ultimaImpresion': '2026-09-01T08:30:00',
                'seleccionable': true,
              },
            ],
          },
      };
    }
    throw StateError('Ruta no simulada: $ruta');
  }
}
