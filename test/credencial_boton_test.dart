import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

/// Acceso a la impresión de credenciales, sin backend.
///
/// No se imprime nada acá: `flutter_test` bloquea las peticiones. Se comprueba
/// lo que se rompe en silencio, que es que el botón desaparezca de la pantalla
/// o que la URL apunte a otro lado.
void main() {
  const libertad = Sindicato(
    id: 16,
    nombre: 'LIBERTAD',
    centralId: 20,
    centralNombre: 'IVIRGARZAMA',
  );

  Widget envolver(Widget hijo) => PadronScope(
    padron: Padron(),
    child: MaterialApp(home: hijo),
  );

  IconButton botonCon(WidgetTester tester, IconData icono) {
    return tester.widget(
      find.ancestor(of: find.byIcon(icono), matching: find.byType(IconButton)),
    );
  }

  group('URLs', () {
    test('la credencial cuelga del productor', () {
      final url = Padron().productores.urlCredencial(812);

      expect(url.path, '/api/v1/productores/812/credencial.pdf');
      expect(url.query, isEmpty);
    });

    test('el pliego cuelga del sindicato, y no se pisa con el informe', () {
      final padron = Padron();

      expect(
        padron.sindicatos.urlCredenciales(16).path,
        '/api/v1/sindicatos/16/credenciales.pdf',
      );
      // Son dos documentos distintos: la nómina y las tarjetas.
      expect(
        padron.sindicatos.urlCredenciales(16),
        isNot(padron.sindicatos.urlInforme(16)),
      );
    });

    test('cada botón pide al backend una sola cara de la credencial', () async {
      final api = _ApiDescarga();
      final padron = Padron(api: api);

      await padron.productores.descargarLadoCredencial(
        812,
        LadoCredencial.anverso,
      );
      expect(api.ruta, '/productores/812/credencial.pdf');
      expect(api.query, {'cara': 'ANVERSO'});

      await padron.directorios.descargarLadoCredencial(
        91,
        LadoCredencial.reverso,
      );
      expect(api.ruta, '/cargos/91/credencial.pdf');
      expect(api.query, {'cara': 'REVERSO'});
    });
  });

  // La ficha del productor no se prueba acá. Al abrirse lanza dos consultas
  // —el detalle y el historial de cargos— y `flutter_test` las corta; el
  // historial queda con un error que nadie llega a mirar, porque su widget se
  // dibuja recién cuando el detalle cargó. Probarla necesitaría un backend
  // simulado, que este proyecto no tiene. Su botón de credencial usa la misma
  // URL que se verifica arriba.

  testWidgets('la pantalla del sindicato ofrece las dos impresiones', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(const SindicatoProductoresPagina(sindicato: libertad)),
    );
    await tester.pump();

    // La nómina y las credenciales son cosas distintas y conviven: cada una
    // con su icono y su explicación.
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);

    expect(
      botonCon(tester, Icons.picture_as_pdf_outlined).tooltip,
      contains('nómina'),
    );
    expect(
      botonCon(tester, Icons.badge_outlined).tooltip,
      contains('credenciales'),
    );
  });
}

class _ApiDescarga extends ApiClient {
  String? ruta;
  Map<String, dynamic>? query;

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    this.ruta = ruta;
    this.query = query;
    return const DescargaBinaria(
      bytes: [],
      nombreArchivo: 'credencial.pdf',
      tipoMime: 'application/pdf',
    );
  }
}
