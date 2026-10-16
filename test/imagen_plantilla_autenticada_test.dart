import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/imagen_plantilla_autenticada.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const ruta = '/api/v1/configuracion/credencial-operador/plantilla/CARA';
  final png = File('test/fixtures/foto-prueba.png').readAsBytesSync();

  Widget pantalla(Padron padron, String url) => PadronScope(
    padron: padron,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox.square(
          dimension: 300,
          child: ImagenPlantillaAutenticada(url: url),
        ),
      ),
    ),
  );

  testWidgets('envía Bearer y conserva la descarga hasta cambiar la versión', (
    tester,
  ) async {
    final peticiones = <http.Request>[];
    final api = ApiClient(
      cliente: MockClient((peticion) async {
        peticiones.add(peticion);
        return http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..usarToken('sesion-de-prueba');
    final padron = Padron(api: api);
    addTearDown(padron.cerrar);

    await tester.pumpWidget(pantalla(padron, '$ruta?v=1'));
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(1));
    expect(
      peticiones.single.headers['Authorization'],
      'Bearer sesion-de-prueba',
    );
    expect(peticiones.single.url.path, ruta);
    expect(peticiones.single.url.queryParameters, {'v': '1'});
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());

    await tester.pumpWidget(pantalla(padron, '$ruta?v=1'));
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(1));

    await tester.pumpWidget(pantalla(padron, '$ruta?v=2'));
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(2));
    expect(peticiones.last.url.queryParameters, {'v': '2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permite reintentar un fallo sin usar la plantilla del productor',
    (tester) async {
      var intentos = 0;
      final padron = Padron(
        api: ApiClient(
          cliente: MockClient((_) async {
            intentos++;
            return intentos == 1
                ? http.Response(
                    '{"mensaje":"Fallo"}',
                    503,
                    headers: {'content-type': 'application/json'},
                  )
                : http.Response.bytes(
                    png,
                    200,
                    headers: {'content-type': 'image/png'},
                  );
          }),
        )..usarToken('sesion-de-prueba'),
      );
      addTearDown(padron.cerrar);

      await tester.pumpWidget(pantalla(padron, ruta));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar plantilla'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.text('Reintentar plantilla'));
      await tester.pumpAndSettle();
      expect(intentos, 2);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
