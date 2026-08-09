@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Credenciales, contra el backend real.
///
/// Verifican el transporte: que el endpoint responda un PDF, con el nombre de
/// archivo correcto, y qué pasa en los casos borde. La forma de la tarjeta
/// —que mida lo que una cédula, qué dice el anverso y qué el reverso— se
/// verifica en el backend, en `CredencialProductorPdfTest`, que puede leer el
/// contenido del PDF.
///
/// Todo se hace sobre un sindicato propio que se crea y se borra. No se toca
/// ningún registro del padrón.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/credencial_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Sindicato sindicato;
  late Sindicato vacio;
  final productores = <Productor>[];

  setUpAll(() async {
    padron = Padron();
    final existentes = await padron.sindicatos.listar();
    expect(existentes, isNotEmpty);
    final centralId = existentes.first.centralId;

    sindicato = await padron.sindicatos.crear(
        SindicatoRequest(nombre: 'ZZZ CREDENCIALES', centralId: centralId));
    vacio = await padron.sindicatos.crear(
        SindicatoRequest(nombre: 'ZZZ CREDENCIALES VACIO', centralId: centralId));

    for (final nombre in ['ZZZ ANA', 'ZZZ BRUNO', 'ZZZ CARLA']) {
      productores.add(await padron.productores.crear(ProductorRequest(
        nombres: nombre,
        apellidos: 'DE LA CREDENCIAL',
        ci: '900${productores.length}',
        sindicatoId: sindicato.id,
      )));
    }
  });

  tearDownAll(() async {
    for (final p in productores) {
      await padron.productores.eliminar(p.id);
    }
    await padron.sindicatos.eliminar(sindicato.id);
    await padron.sindicatos.eliminar(vacio.id);
  });

  Future<http.Response> credencial(int productorId) =>
      http.get(padron.productores.urlCredencial(productorId));

  Future<http.Response> pliego(int sindicatoId) =>
      http.get(padron.sindicatos.urlCredenciales(sindicatoId));

  group('credencial de un productor', () {
    test('devuelve un PDF de verdad', () async {
      final respuesta = await credencial(productores.first.id);

      expect(respuesta.statusCode, 200);
      expect(respuesta.headers['content-type'], contains('application/pdf'));
      expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
      expect(respuesta.bodyBytes.length, greaterThan(500));
    });

    test('se baja con el nombre del productor en el archivo', () async {
      final respuesta = await credencial(productores.first.id);

      final disposicion = respuesta.headers['content-disposition'] ?? '';
      expect(disposicion, contains('attachment'));
      expect(disposicion, contains('credencial-'));
      expect(disposicion, contains('zzz-ana-de-la-credencial'));
    });

    test('sale igual sin foto y sin directorio cargados', () async {
      // Estos productores no tienen foto ni presidente asignado. La credencial
      // se emite lo mismo, con los espacios en blanco.
      final respuesta = await credencial(productores.last.id);

      expect(respuesta.statusCode, 200);
      expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
    });

    test('un productor que no existe da 404 y no un PDF vacío', () async {
      final respuesta = await credencial(999999);

      expect(respuesta.statusCode, 404);
      expect(respuesta.headers['content-type'], isNot(contains('pdf')));
    });
  });

  group('pliego del sindicato', () {
    test('devuelve un PDF con todas las credenciales', () async {
      final respuesta = await pliego(sindicato.id);

      expect(respuesta.statusCode, 200);
      expect(respuesta.headers['content-type'], contains('application/pdf'));
      expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
      expect(respuesta.headers['content-disposition'],
          contains('credenciales-zzz-credenciales'));
    });

    test('un sindicato sin productores se rechaza con un motivo', () async {
      // Y no con un PDF de cero tarjetas, que solo confundiría a quien lo abra.
      final respuesta = await pliego(vacio.id);

      expect(respuesta.statusCode, 409);
      expect(respuesta.body, contains('no tiene productores'));
    });

    test('un sindicato que no existe da 404', () async {
      expect((await pliego(999999)).statusCode, 404);
    });
  });
}
