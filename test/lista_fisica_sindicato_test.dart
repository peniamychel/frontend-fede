import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/lista_fisica_sindicato_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const sindicato = Sindicato(
    id: 13,
    nombre: '13 DE JUNIO',
    centralId: 2,
    centralNombre: 'CENTRAL IVIRGARZAMA',
  );

  testWidgets('permite agregar fotos, usar cámara y muestra el estado vacío', (
    tester,
  ) async {
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiListaFisica()),
        child: const MaterialApp(
          home: ListaFisicaSindicatoPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista física'), findsOneWidget);
    expect(find.text('13 DE JUNIO'), findsOneWidget);
    expect(find.text('0 páginas'), findsOneWidget);
    expect(find.text('Agregar fotografías'), findsOneWidget);
    expect(find.text('Usar cámara'), findsOneWidget);
    expect(find.text('Todavía no hay páginas guardadas.'), findsOneWidget);
    expect(find.text('Ver PDF'), findsNothing);
    expect(find.text('Descargar PDF'), findsNothing);
  });

  testWidgets('arrastra las páginas en la lista y guarda el nuevo orden', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiListaFisica(conPaginas: true);
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: ListaFisicaSindicatoPagina(sindicato: sindicato),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tarjetas = find.byType(Draggable<int>);
      final origen = tester.getCenter(tarjetas.first);
      final destino = tester.getCenter(tarjetas.last);
      await tester.dragFrom(origen, destino - origen);
      await tester.pumpAndSettle();
      expect(api.ordenGuardado, [2, 1]);
      expect(tester.widget<Draggable<int>>(tarjetas.first).data, 2);
      expect(find.text('Ordenar páginas'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _ApiListaFisica extends ApiClient {
  _ApiListaFisica({this.conPaginas = false});
  final bool conPaginas;
  List<int> ids = [1, 2];
  List<int>? ordenGuardado;

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta != '/sindicatos/13/lista-fisica/orden') throw StateError(ruta);
    ids = List<int>.from((cuerpo as Map)['paginaIds'] as List);
    ordenGuardado = [...ids];
    return obtener('/sindicatos/13/lista-fisica');
  }

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/sindicatos/13/lista-fisica') {
      return {
        'sindicatoId': 13,
        'sindicato': '13 DE JUNIO',
        'paginas': conPaginas ? 2 : 0,
        'pdfUrl': null,
        'actualizadaEn': null,
        'detallePaginas': conPaginas
            ? [
                for (var indice = 0; indice < ids.length; indice++)
                  {
                    'id': ids[indice],
                    'orden': indice + 1,
                    'nombre': 'Página ${ids[indice]}.jpg',
                    'tipoMime': 'image/jpeg',
                    'tamanoBytes': 100,
                    'url': '/pagina-${ids[indice]}.jpg',
                  },
              ]
            : [],
      };
    }
    throw StateError('Ruta no simulada: $ruta');
  }
}
