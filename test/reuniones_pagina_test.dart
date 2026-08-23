import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/reuniones/reuniones_pagina.dart';

/// El listado de reuniones, con un servidor fingido.
///
/// Con los años la lista se hace larga, así que se entra por las solapas de
/// tipo o por el buscador. Lo que se verifica acá es que las dos cosas lleguen
/// al servidor como filtros —y no que se filtre en el cliente sobre una lista
/// completa, que es justamente lo que no escala— y que el conteo de las solapas
/// no cambie al moverse entre ellas.
void main() {
  Map<String, dynamic> reunion({
    required int id,
    required String titulo,
    String tipo = 'SINDICATO',
    String tipoEtiqueta = 'Reunión de sindicato',
    String? codigoActa,
  }) =>
      {
        'id': id,
        'tipo': tipo,
        'tipoEtiqueta': tipoEtiqueta,
        'tipoDetalle': 'Asisten los productores del sindicato.',
        'convoca': 'SINDICATO',
        'convocanteId': 16,
        'convocanteNombre': 'LIBERTAD',
        'titulo': titulo,
        'fecha': '2026-05-05',
        'cerrada': false,
        'convocados': 12,
        'presentes': 8,
        'tieneActa': codigoActa != null,
        'codigoActa': codigoActa,
        'vetosHabilitados': false,
        'hojasActa': const <Object>[],
      };

  const conteo = {
    'SINDICATO': 7,
    'AMPLIADO': 3,
    'DIRIGENTES_CENTRAL': 0,
    'DIRIGENTES_FEDERACION': 1,
  };

  Widget pantalla(_ApiEspia api) => TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: ReunionesPagina()),
        ),
      );

  /// Escribe en el buscador y espera el respiro de 350 ms.
  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField), texto);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('las solapas dicen cuántas hay de cada tipo', (tester) async {
    await tester.pumpWidget(pantalla(_ApiEspia(
      reuniones: [reunion(id: 1, titulo: 'Ordinaria de mayo')],
      conteo: conteo,
    )));
    await tester.pump();

    expect(find.text('Todas · 11'), findsOneWidget);
    expect(find.text('Sindicato · 7'), findsOneWidget);
    expect(find.text('Ampliado · 3'), findsOneWidget);
    // Los tipos sin ninguna se muestran igual, en cero: una solapa que aparece
    // y desaparece es más difícil de encontrar que una que dice cero.
    expect(find.text('Dirigentes central · 0'), findsOneWidget);
  });

  testWidgets('elegir un tipo lo manda al servidor, no filtra acá',
      (tester) async {
    final api = _ApiEspia(
      reuniones: [reunion(id: 1, titulo: 'Ordinaria de mayo')],
      conteo: conteo,
    );
    await tester.pumpWidget(pantalla(api));
    await tester.pump();

    await tester.ensureVisible(find.text('Ampliado · 3'));
    await tester.pump();
    await tester.tap(find.text('Ampliado · 3'));
    await tester.pump();
    await tester.pump();

    expect(api.tiposPedidos.last, 'AMPLIADO');
  });

  testWidgets('el conteo no lleva el tipo: la solapa no cambia al tocarla',
      (tester) async {
    // Si el conteo se filtrara también por tipo, la solapa de «Ampliado»
    // pasaría a decir 3 de 3 al entrar y no serviría para decidir adónde ir.
    final api = _ApiEspia(reuniones: const [], conteo: conteo);
    await tester.pumpWidget(pantalla(api));
    await tester.pump();

    await tester.ensureVisible(find.text('Ampliado · 3'));
    await tester.pump();
    await tester.tap(find.text('Ampliado · 3'));
    await tester.pump();
    await tester.pump();

    expect(api.conteosPedidos.every((q) => !q.containsKey('tipo')), isTrue);
  });

  testWidgets('lo que se escribe va al servidor como texto', (tester) async {
    final api = _ApiEspia(
      reuniones: [reunion(id: 9, titulo: 'Asamblea que sanciona')],
      conteo: conteo,
    );
    await tester.pumpWidget(pantalla(api));
    await tester.pump();

    await buscar(tester, 'MAMANI');

    expect(api.textosPedidos.last, 'MAMANI');
    // Y se explica por qué salió: la fila no menciona a MAMANI en ninguna
    // parte, la coincidencia vino del veto.
    expect(
        find.textContaining('coincide con «MAMANI», por su detalle o por un '
            'veto'),
        findsOneWidget);
  });

  testWidgets('no consulta por cada tecla', (tester) async {
    final api = _ApiEspia(reuniones: const [], conteo: conteo);
    await tester.pumpWidget(pantalla(api));
    await tester.pump();
    final antes = api.textosPedidos.length;

    await tester.enterText(find.byType(TextField), 'M');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'MA');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'MAM');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(api.textosPedidos.length - antes, 1);
    expect(api.textosPedidos.last, 'MAM');
  });

  testWidgets('sin resultados dice dónde se buscó y ofrece salir',
      (tester) async {
    final api = _ApiEspia(reuniones: const [], conteo: conteo);
    await tester.pumpWidget(pantalla(api));
    await tester.pump();

    await buscar(tester, 'NADIE');

    expect(find.textContaining('Ninguna reunión coincide con «NADIE»'),
        findsOneWidget);
    expect(find.textContaining('los vetos que se decidieron ahí'),
        findsOneWidget);
    expect(find.text('Limpiar la búsqueda'), findsOneWidget);
  });

  testWidgets('la fila muestra el número del acta cuando lo tiene',
      (tester) async {
    await tester.pumpWidget(pantalla(_ApiEspia(
      reuniones: [
        reunion(id: 1, titulo: 'Ordinaria de mayo', codigoActa: '12/2026'),
      ],
      conteo: conteo,
    )));
    await tester.pump();

    expect(find.text('Acta N° 12/2026'), findsOneWidget);
  });
}

/// Un ApiClient que responde por ruta y anota con qué lo llamaron.
class _ApiEspia extends ApiClient {
  _ApiEspia({required this.reuniones, required this.conteo});

  final List<Map<String, dynamic>> reuniones;
  final Map<String, int> conteo;

  final List<Map<String, dynamic>> conteosPedidos = [];
  final List<String?> tiposPedidos = [];
  final List<String?> textosPedidos = [];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    final limpio = <String, dynamic>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: e.value,
    };
    if (ruta.endsWith('/conteo')) {
      conteosPedidos.add(limpio);
      return conteo;
    }
    tiposPedidos.add(limpio['tipo'] as String?);
    textosPedidos.add(limpio['texto'] as String?);
    return reuniones;
  }
}
