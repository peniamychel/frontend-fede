@Tags(['integracion'])
library;

import 'dart:io';

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
/// El armado del principio no es decorativo: desde que existe la vista previa,
/// el PDF **exige los datos completos**. Acá se arma un sindicato con fotos,
/// los tres firmantes jerárquicos, sus firmas y sellos, y todo lo demás; qué pasa cuando
/// falta algo se prueba en `credencial_previa_api_test`.
///
/// Todo se hace sobre una jerarquía propia que se crea y se borra. No se toca
/// ningún registro del padrón.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/credencial_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fede;
  late Central central;
  late Sindicato sindicato;
  late Sindicato vacio;
  final productores = <Productor>[];

  setUpAll(() async {
    padron = Padron();
    final imagen = File('test/fixtures/foto-prueba.png').readAsBytesSync();

    // Jerarquía propia con número y sigla: el código del padrón es parte de la
    // credencial, y sin ellos la emisión se bloquearía.
    fede = await padron.federaciones.crear(
      const FederacionRequest(nombre: 'ZZZ CRED FEDE', numero: '89'),
    );
    central = await padron.centrales.crear(
      CentralRequest(
        nombre: 'ZZZ CRED CENTRAL',
        abreviatura: 'ZCR',
        federacionId: fede.id,
      ),
    );
    sindicato = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ CREDENCIALES', centralId: central.id),
    );
    vacio = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ CREDENCIALES VACIO', centralId: central.id),
    );

    for (final nombre in ['ZZZ ANA', 'ZZZ BRUNO', 'ZZZ CARLA']) {
      final creado = await padron.productores.crear(
        ProductorRequest(
          nombres: nombre,
          apellidos: 'DE LA CREDENCIAL',
          ci: '900${productores.length}',
          sindicatoId: sindicato.id,
        ),
      );
      productores.add(creado);
      await padron.productores.subirImagen(
        productorId: creado.id,
        bytes: imagen,
        nombreArchivo: 'foto.png',
      );
    }

    for (final (ambito, id, cargo, quien) in [
      (Ambito.federacion, fede.id, TipoCargo.ejecutivo, productores[0]),
      (Ambito.central, central.id, TipoCargo.secretarioGeneral, productores[1]),
      (
        Ambito.sindicato,
        sindicato.id,
        TipoCargo.secretarioGeneral,
        productores[2],
      ),
    ]) {
      final directorio = await padron.directorios.asignar(
        ambito: ambito,
        id: id,
        cargo: cargo,
        productorId: quien.id,
      );
      final cargoId = directorio.cargoDe(cargo)!.id;
      await padron.directorios.subirImagen(
        cargoId: cargoId,
        tipo: TipoImagenCargo.firma,
        bytes: imagen,
        nombreArchivo: 'firma.png',
      );
    }
    for (final (ambito, id) in [
      (Ambito.federacion, fede.id),
      (Ambito.central, central.id),
      (Ambito.sindicato, sindicato.id),
    ]) {
      await padron.directorios.subirSello(
        ambito: ambito,
        id: id,
        bytes: imagen,
        nombreArchivo: 'sello.png',
      );
    }
  });

  tearDownAll(() async {
    for (final p in productores) {
      await padron.productores.eliminar(p.id);
    }
    await padron.sindicatos.eliminar(sindicato.id);
    await padron.sindicatos.eliminar(vacio.id);
    await padron.centrales.eliminar(central.id);
    await padron.federaciones.eliminar(fede.id);
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

    test('sin los datos completos no se emite, y el motivo lo dice', () async {
      // Antes salía con los espacios en blanco. Desde la vista previa la regla
      // es la contraria: la credencial se plastifica y se reparte, así que se
      // completa primero y se imprime después.
      final sinFoto = await padron.productores.crear(
        ProductorRequest(
          nombres: 'ZZZ SIN FOTO',
          apellidos: 'DE LA CREDENCIAL',
          ci: '9099',
          sindicatoId: sindicato.id,
        ),
      );

      try {
        final respuesta = await credencial(sinFoto.id);

        expect(respuesta.statusCode, 409);
        expect(respuesta.headers['content-type'], isNot(contains('pdf')));
        expect(respuesta.body, contains('fotografía'));
      } finally {
        // Se borra acá y no en el tearDown: si quedara en el sindicato, el
        // pliego que se prueba después se bloquearía por su culpa.
        await padron.productores.eliminar(sinFoto.id);
      }
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
      expect(
        respuesta.headers['content-disposition'],
        contains('credenciales-zzz-credenciales'),
      );
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
