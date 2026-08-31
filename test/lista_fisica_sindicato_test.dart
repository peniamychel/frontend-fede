import 'package:flutter/material.dart';
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
}

class _ApiListaFisica extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/sindicatos/13/lista-fisica') {
      return const {
        'sindicatoId': 13,
        'sindicato': '13 DE JUNIO',
        'paginas': 0,
        'pdfUrl': null,
        'actualizadaEn': null,
        'detallePaginas': [],
      };
    }
    throw StateError('Ruta no simulada: $ruta');
  }
}
