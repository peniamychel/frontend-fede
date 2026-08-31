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

  testWidgets('muestra las cantidades y las dos acciones de impresión', (
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
      expect(find.text('Imprimir reversos'), findsNothing);
      expect(find.textContaining('Impresora:'), findsNothing);
    },
  );
}

class _ApiPanel extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/configuracion/credencial') {
      return const {'diseno': <String, dynamic>{}, 'camposDisponibles': []};
    }
    if (ruta == '/sindicatos/13/credenciales/impresion') {
      return const {
        'sindicatoId': 13,
        'sindicato': '13 DE JUNIO',
        'total': 12,
        'impresos': 5,
        'faltantesConFoto': 4,
        'sinFoto': 3,
        'listosParaImprimir': 4,
        'faltantesDelSindicato': [],
        'candidatos': [],
      };
    }
    throw StateError('Ruta no simulada: $ruta');
  }
}
