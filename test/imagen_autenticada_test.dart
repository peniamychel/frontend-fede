import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/imagen_autenticada.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  Widget pantalla(Padron padron, String url) => PadronScope(
    padron: padron,
    child: MaterialApp(home: Scaffold(body: ImagenAutenticada(url))),
  );

  testWidgets('descarga fotos con Bearer y cambia al cambiar URL', (
    tester,
  ) async {
    final peticiones = <http.Request>[];
    final png = File('test/fixtures/foto-prueba.png').readAsBytesSync();
    final api = ApiClient(
      cliente: MockClient((r) async {
        peticiones.add(r);
        return http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..usarToken('sesion-prueba');
    final padron = Padron(api: api);
    addTearDown(padron.cerrar);
    await tester.pumpWidget(
      pantalla(padron, '/api/v1/archivos/originales/prueba.png'),
    );
    await tester.pumpAndSettle();
    expect(peticiones.single.headers['Authorization'], 'Bearer sesion-prueba');
    expect(peticiones.single.url.queryParameters, {'accesoPrivado': '2'});
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    await tester.pumpWidget(
      pantalla(padron, '/api/v1/archivos/originales/otra.png'),
    );
    await tester.pumpAndSettle();
    expect(peticiones, hasLength(2));
    expect(peticiones.last.url.path, endsWith('/otra.png'));
  });

  testWidgets(
    'no envía token a otro servidor ni reintenta una foto prohibida como pública',
    (tester) async {
      var peticiones = 0;
      final padron = Padron(
        api: ApiClient(
          cliente: MockClient((_) async {
            peticiones++;
            return http.Response(
              '{"mensaje":"Sin acceso"}',
              403,
              headers: {'content-type': 'application/json'},
            );
          }),
        )..usarToken('sesion-prueba'),
      );
      addTearDown(padron.cerrar);
      await tester.pumpWidget(
        pantalla(padron, 'https://ajeno.invalid/api/v1/archivos/foto.png'),
      );
      await tester.pumpAndSettle();
      expect(peticiones, 0);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      await tester.pumpWidget(
        pantalla(padron, '/api/v1/archivos/originales/foto.png'),
      );
      await tester.pumpAndSettle();
      expect(peticiones, 1);
      expect(find.byType(Image), findsNothing);
    },
  );
}
