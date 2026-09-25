import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/informe_impresion_sindicato_pagina.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const libertad = Sindicato(
    id: 16,
    nombre: 'LIBERTAD',
    centralId: 20,
    centralNombre: 'IVIRGARZAMA',
  );

  test('la nómina se pide al endpoint del panel de informes', () async {
    final api = _ApiInforme();

    await Padron(api: api).sindicatos.descargarNomina(16);

    expect(api.rutaDescarga, '/sindicatos/16/informes/nomina.pdf');
  });

  testWidgets('la lista ya no muestra el botón antiguo de la nómina', (
    tester,
  ) async {
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiInforme()),
        child: const MaterialApp(
          home: SindicatoProductoresPagina(sindicato: libertad),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byTooltip('Descargar la nómina en PDF, lista para imprimir'),
      findsNothing,
    );
  });

  testWidgets('el panel de informes ofrece la nómina en PDF', (tester) async {
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiInforme()),
        child: const MaterialApp(
          home: InformeImpresionSindicatoPagina(sindicato: libertad),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nómina en PDF'), findsOneWidget);
    expect(find.text('Informe pre-impresión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ApiInforme extends ApiClient {
  String? rutaDescarga;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/sindicatos/16/informes/avance') {
      return {'sindicatoId': 16, 'sindicato': 'LIBERTAD', 'total': 0};
    }
    if (ruta == '/sindicatos/16/informes/fases') {
      return <Map<String, dynamic>>[];
    }
    if (ruta == '/productores') return <Map<String, dynamic>>[];
    throw StateError('Ruta no esperada: $ruta');
  }

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    rutaDescarga = ruta;
    return const DescargaBinaria(
      bytes: [37, 80, 68, 70],
      nombreArchivo: 'nomina.pdf',
      tipoMime: 'application/pdf',
    );
  }
}
