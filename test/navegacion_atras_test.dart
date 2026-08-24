import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/inicio.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  late Padron padron;
  late PreferenciaTema tema;

  setUp(() {
    final cliente = MockClient((peticion) async {
      final ruta = peticion.url.path;
      final Object cuerpo;
      if (ruta.endsWith('/federaciones')) {
        cuerpo = [
          {'id': 10, 'nombre': 'Federación de prueba'},
        ];
      } else if (ruta.endsWith('/federaciones/10/centrales')) {
        cuerpo = [
          {
            'id': 20,
            'nombre': 'Central de prueba',
            'federacionId': 10,
            'federacionNombre': 'Federación de prueba',
          },
        ];
      } else if (ruta.endsWith('/productores')) {
        cuerpo = {
          'content': <Object>[],
          'page': {
            'size': 25,
            'number': 0,
            'totalElements': 0,
            'totalPages': 0,
          },
        };
      } else {
        cuerpo = <Object>[];
      }
      return http.Response(
        jsonEncode(cuerpo),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    padron = Padron(api: ApiClient(cliente: cliente));
    tema = PreferenciaTema();
  });

  tearDown(() {
    padron.cerrar();
    tema.dispose();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PadronScope(
        padron: padron,
        child: TemaScope(
          preferencia: tema,
          child: const MaterialApp(home: Inicio()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Atrás recorre Sindicato, Central, Federación y la raíz', (
    tester,
  ) async {
    await montar(tester);

    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Jerarquía')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Federación de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Sindicatos de Central de prueba'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Centrales de Federación de prueba'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Federaciones'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(barra).selectedIndex, 0);
  });

  testWidgets('Android pregunta antes de salir desde la raíz', (tester) async {
    await montar(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Salir de la aplicación?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la aplicación?'), findsNothing);
  });
}
