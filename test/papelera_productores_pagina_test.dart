import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/papelera_productores_pagina.dart';

void main() {
  Future<void> abrir(WidgetTester tester, _ApiPapelera api) async {
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(home: PapeleraProductoresPagina()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abre y actualiza la papelera sin devolver Future en setState', (
    tester,
  ) async {
    final api = _ApiPapelera();
    await abrir(tester, api);
    expect(find.text('MARIA PEREZ'), findsOneWidget);
    expect(api.consultas, 1);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'pérez');
    await tester.pumpAndSettle();
    expect(find.text('MARIA PEREZ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '234');
    await tester.pumpAndSettle();
    expect(
      find.text('No se encontraron productores con esa búsqueda.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '123');
    await tester.pumpAndSettle();
    expect(find.text('MARIA PEREZ'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(api.consultas, 1);
    api.enPapelera = false;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(api.consultas, 2);
    expect(find.text('La papelera está vacía.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite reintentar una carga fallida', (tester) async {
    final api = _ApiPapelera()..fallar = true;
    await abrir(tester, api);
    expect(find.text('Reintentar'), findsOneWidget);
    api.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('MARIA PEREZ'), findsOneWidget);
    expect(api.consultas, 2);
    expect(tester.takeException(), isNull);
  });

  for (final accion in ['Restaurar', 'Eliminar definitivamente']) {
    testWidgets('$accion vuelve a cargar la lista', (tester) async {
      final api = _ApiPapelera();
      await abrir(tester, api);
      await tester.tap(find.widgetWithText(TextButton, accion));
      await tester.pumpAndSettle();
      expect(api.operaciones, 0);
      await tester.tap(find.widgetWithText(FilledButton, accion));
      await tester.pumpAndSettle();
      expect(api.operaciones, 1);
      expect(api.consultas, 2);
      expect(find.text('La papelera está vacía.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ApiPapelera extends ApiClient {
  int consultas = 0;
  int operaciones = 0;
  bool enPapelera = true;
  bool fallar = false;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    expect(ruta, '/productores/papelera');
    consultas++;
    if (fallar) throw const ApiException(estado: 503, mensaje: 'Sin conexión');
    return [
      if (enPapelera)
        {
          'id': 42,
          'nombre': 'MARIA PEREZ',
          'ci': '1234567',
          'sindicato': 'LIBERTAD',
          'central': 'IVIRGARZAMA',
          'eliminadoEn': '2026-10-19T08:00:00',
          'restaurable': true,
        },
    ];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    expect(ruta, '/productores/papelera/42/restaurar');
    operaciones++;
    enPapelera = false;
    return {'id': 42, 'nombres': 'MARIA', 'apellidos': 'PEREZ'};
  }

  @override
  Future<void> eliminar(String ruta) async {
    expect(ruta, '/productores/papelera/42');
    operaciones++;
    enPapelera = false;
  }
}
