@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Informe en PDF del sindicato, contra el backend real.
///
/// Estas pruebas miran el transporte: que el endpoint responda un PDF, con el
/// nombre de archivo correcto, y que un sindicato inexistente dé 404. Lo que
/// dice el PDF por dentro se verifica en el backend, en
/// `InformeSindicatoPdfTest`, que puede leer el texto de la hoja; desde Dart
/// habría que descomprimir el PDF a mano.
///
/// Se trabaja sobre un sindicato propio, creado al empezar y borrado al
/// terminar. No se toca ningún registro del padrón.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/informe_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Sindicato sindicato;
  final productores = <Productor>[];

  setUpAll(() async {
    padron = Padron();
    final existentes = await padron.sindicatos.listar();
    expect(existentes, isNotEmpty,
        reason: 'hace falta al menos una central donde colgar el sindicato');

    sindicato = await padron.sindicatos.crear(SindicatoRequest(
      nombre: 'ZZZ PRUEBA INFORME',
      centralId: existentes.first.centralId,
    ));

    for (final nombre in ['ZZZ ANA', 'ZZZ BRUNO', 'ZZZ CARLA']) {
      productores.add(await padron.productores.crear(ProductorRequest(
        nombres: nombre,
        apellidos: 'DEL INFORME',
        sindicatoId: sindicato.id,
      )));
    }
    // Un lote y una observación, para que el informe tenga esas dos columnas
    // con algo adentro.
    await padron.lotes.crear(LoteRequest(
      productorId: productores.first.id,
      numero: '99',
    ));
    await padron.observaciones.crear(ObservacionRequest(
      mensaje: 'FALTA FOTO',
      productorId: productores.first.id,
    ));
  });

  tearDownAll(() async {
    for (final p in productores) {
      await padron.productores.eliminar(p.id);
    }
    await padron.sindicatos.eliminar(sindicato.id);
  });

  Future<http.Response> bajar(int id) =>
      http.get(padron.sindicatos.urlInforme(id));

  test('devuelve un PDF de verdad', () async {
    final respuesta = await bajar(sindicato.id);

    expect(respuesta.statusCode, 200);
    expect(respuesta.headers['content-type'], contains('application/pdf'));
    // Los cuatro bytes con los que arranca todo PDF. Si el backend devolviera
    // un JSON de error con estado 200, esto lo delata.
    expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
    expect(respuesta.bodyBytes.length, greaterThan(1000));
  });

  test('se baja como archivo, con un nombre que dice de quién es', () async {
    final respuesta = await bajar(sindicato.id);

    final disposicion = respuesta.headers['content-disposition'] ?? '';
    expect(disposicion, contains('attachment'));
    expect(disposicion, contains('padron-'));
    expect(disposicion, contains('zzz-prueba-informe'));
    expect(disposicion, endsWith('.pdf"'));
  });

  test('un sindicato que no existe da 404 y no un PDF vacío', () async {
    final respuesta = await bajar(999999);

    expect(respuesta.statusCode, 404);
    expect(respuesta.headers['content-type'], isNot(contains('pdf')));
  });

  test('un sindicato sin productores igual genera su informe', () async {
    final vacio = await padron.sindicatos.crear(SindicatoRequest(
      nombre: 'ZZZ PRUEBA VACIO',
      centralId: sindicato.centralId,
    ));
    try {
      final respuesta = await bajar(vacio.id);

      // Se entrega igual: el acta con cero afiliados también sirve.
      expect(respuesta.statusCode, 200);
      expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
    } finally {
      await padron.sindicatos.eliminar(vacio.id);
    }
  });
}
