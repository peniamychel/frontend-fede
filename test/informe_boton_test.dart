import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

/// Acceso a la descarga del informe, sin backend.
///
/// Acá no se baja nada: `flutter_test` bloquea las peticiones. Lo que se
/// comprueba es lo que se rompe en silencio, que es que el botón desaparezca de
/// la pantalla o que la URL apunte a otro lado.
void main() {
  const libertad = Sindicato(
    id: 16,
    nombre: 'LIBERTAD',
    centralId: 20,
    centralNombre: 'IVIRGARZAMA',
  );

  test('la URL del informe apunta al endpoint del sindicato', () {
    final url = Padron().sindicatos.urlInforme(16);

    expect(url.path, '/api/v1/sindicatos/16/informe.pdf');
    // Sin query: el informe no se parametriza, sale entero.
    expect(url.query, isEmpty);
  });

  testWidgets('la pantalla del sindicato ofrece bajar la nómina',
      (tester) async {
    await tester.pumpWidget(PadronScope(
      padron: Padron(),
      child: const MaterialApp(
        home: SindicatoProductoresPagina(sindicato: libertad),
      ),
    ));
    await tester.pump();

    final boton = find.byIcon(Icons.picture_as_pdf_outlined);
    expect(boton, findsOneWidget);

    // Con tooltip: el icono solo no dice que sale para imprimir.
    final IconButton widget = tester.widget(
      find.ancestor(of: boton, matching: find.byType(IconButton)),
    );
    expect(widget.tooltip, contains('PDF'));
    expect(widget.onPressed, isNotNull);
  });
}
