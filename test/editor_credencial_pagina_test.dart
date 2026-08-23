import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/editor_credencial_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  Widget pantalla() => PadronScope(
    padron: Padron(api: _ApiDiseno()),
    child: const MaterialApp(home: EditorCredencialPagina()),
  );

  testWidgets('permite cambiar de cara y agregar otro campo', (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    expect(find.text('Editor del carnet'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Reverso'), findsOneWidget);
    expect(find.text('Guardar diseño'), findsOneWidget);

    final antes = find.text('N° de padrón').evaluate().length;
    final agregar = find.byTooltip('Agregar campo');
    await tester.ensureVisible(agregar);
    await tester.tap(agregar);
    await tester.pump();
    expect(find.text('N° de padrón').evaluate().length, greaterThan(antes));

    final reverso = find.text('Reverso');
    await tester.ensureVisible(reverso);
    await tester.tap(reverso);
    await tester.pump();
    expect(find.text('Sello federación'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('la ruta conserva la barra después de /api/v1', () async {
    final api = _ApiDiseno();
    await DisenoCredencialRepository(api).obtener();
    expect(api.ultimaRuta, '/configuracion/credencial');
  });
}

class _ApiDiseno extends ApiClient {
  String? ultimaRuta;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    ultimaRuta = ruta;
    return {
      'diseno': DisenoCredencial.predeterminado().aJson(),
      'camposDisponibles': [
        {'campo': 'CODIGO_PADRON', 'etiqueta': 'N° de padrón', 'tipo': 'TEXTO'},
        {'campo': 'TEXTO_FIJO', 'etiqueta': 'Texto libre', 'tipo': 'TEXTO'},
      ],
    };
  }
}
