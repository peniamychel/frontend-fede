@Tags(['integracion'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// La vista previa de la credencial y su regla: sin datos completos no hay PDF.
///
/// Se arma una jerarquía propia desde la federación —con número y sigla, para
/// que el código del padrón no estorbe— y se completa una credencial paso a
/// paso, comprobando en cada paso que la previa diga qué falta y que el PDF
/// siga bloqueado. Recién cuando no falta nada, el PDF sale.
///
/// Las pruebas comparten estado y corren en orden: son etapas de una misma
/// historia, no casos sueltos.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/credencial_previa_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Uint8List imagen;

  late Federacion fede;
  late Central central;
  late Sindicato sindicato;
  late Productor productor;
  late Productor presidente;
  late Productor secretario;

  Future<int> estadoHttp(Uri url) async => (await http.get(url)).statusCode;

  setUpAll(() async {
    padron = Padron();
    imagen = File('test/fixtures/foto-prueba.png').readAsBytesSync();

    fede = await padron.federaciones.crear(
      const FederacionRequest(nombre: 'ZZZ PREVIA FEDE', numero: '88'),
    );
    central = await padron.centrales.crear(
      CentralRequest(
        nombre: 'ZZZ PREVIA CENTRAL',
        abreviatura: 'ZPV',
        federacionId: fede.id,
      ),
    );
    sindicato = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ PREVIA SIND', centralId: central.id),
    );

    // El protagonista arranca a propósito sin cédula y sin foto.
    productor = await padron.productores.crear(
      ProductorRequest(nombres: 'ZZZ INCOMPLETO', sindicatoId: sindicato.id),
    );
    // Los que van a firmar, completos desde el vamos.
    presidente = await padron.productores.crear(
      ProductorRequest(
        nombres: 'ZZZ PRESIDENTE',
        apellidos: 'FIRMANTE',
        ci: '111',
        sindicatoId: sindicato.id,
      ),
    );
    secretario = await padron.productores.crear(
      ProductorRequest(
        nombres: 'ZZZ SECRETARIO',
        apellidos: 'FIRMANTE',
        ci: '222',
        sindicatoId: sindicato.id,
      ),
    );
  });

  tearDownAll(() async {
    for (final id in [productor.id, presidente.id, secretario.id]) {
      try {
        await padron.productores.eliminar(id);
      } on ApiException {
        // Ya no estaba.
      }
    }
    try {
      await padron.sindicatos.eliminar(sindicato.id);
      await padron.centrales.eliminar(central.id);
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Si algo quedó a medias, lo que importa ya se limpió arriba.
    } finally {
      padron.cerrar();
    }
  });

  test(
    'la previa dice todo lo que falta, y cada cosa dice dónde se carga',
    () async {
      final previa = await padron.productores.previaCredencial(productor.id);

      expect(previa.completa, isFalse);
      final campos = previa.faltantes.map((f) => f.campo).toList();
      expect(campos, contains('Apellidos'));
      expect(campos, contains('Cédula'));
      expect(campos, contains('Fotografía'));
      expect(campos, contains('Ejecutivo de la federación'));
      expect(campos, contains('Secretario General de la central'));
      expect(campos, contains('Secretario General del sindicato'));
      expect(campos, contains('Sello de la federación'));
      expect(campos, contains('Sello de la central'));
      expect(campos, contains('Sello del sindicato'));

      for (final falta in previa.faltantes) {
        expect(
          falta.donde,
          isNotEmpty,
          reason: 'decir que falta sin decir dónde es la mitad del trabajo',
        );
      }

      // Lo que sí está, ya se muestra como va a salir.
      expect(previa.codigoPadron, '88-ZPV-1');
      expect(previa.federacion, contains('ZZZ PREVIA FEDE'));
    },
  );

  test('mientras falte algo, el PDF responde 409', () async {
    expect(
      await estadoHttp(padron.productores.urlCredencial(productor.id)),
      409,
    );
  });

  test('el pliego separa lo del sindicato de lo de cada productor', () async {
    final pliego = await padron.sindicatos.previaCredenciales(sindicato.id);

    expect(pliego.completa, isFalse);
    expect(pliego.productores, 3);
    // Sin firmantes ni sellos: le falta a la jerarquía, no a las personas.
    expect(
      pliego.faltantesDelSindicato.map((f) => f.campo),
      containsAll([
        'Ejecutivo de la federación',
        'Secretario General de la central',
        'Secretario General del sindicato',
        'Sello de la federación',
        'Sello de la central',
        'Sello del sindicato',
      ]),
    );
    // Cada uno con lo suyo: al protagonista le falta de todo, y a los
    // firmantes —que tienen apellidos y cédula— solamente la foto.
    expect(
      pliego.incompletos.map((p) => p.productorId),
      contains(productor.id),
    );
    final delPresidente = pliego.incompletos.firstWhere(
      (p) => p.productorId == presidente.id,
    );
    expect(delPresidente.faltantes.map((f) => f.campo), ['Fotografía']);

    expect(
      await estadoHttp(padron.sindicatos.urlCredenciales(sindicato.id)),
      409,
    );
  });

  test('completar los datos destraba el PDF', () async {
    // La ficha: apellidos y cédula.
    await padron.productores.actualizar(
      productor.id,
      ProductorRequest(
        nombres: productor.nombres,
        apellidos: 'YA COMPLETO',
        ci: '333',
        sindicatoId: sindicato.id,
      ),
    );
    // La foto.
    await padron.productores.subirImagen(
      productorId: productor.id,
      bytes: imagen,
      nombreArchivo: 'foto.png',
    );

    // Los tres firmantes del reverso. El pie se construye automáticamente.
    for (final (ambito, id, cargo, quien) in [
      (Ambito.federacion, fede.id, TipoCargo.ejecutivo, presidente),
      (Ambito.central, central.id, TipoCargo.secretarioGeneral, secretario),
      (Ambito.sindicato, sindicato.id, TipoCargo.secretarioGeneral, productor),
    ]) {
      final directorio = await padron.directorios.asignar(
        ambito: ambito,
        id: id,
        cargo: cargo,
        productorId: quien.id,
      );
      final periodo = directorio.cargoDe(cargo)!;
      await padron.directorios.subirImagen(
        cargoId: periodo.id,
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
    // Los firmantes también reciben su foto: sin ella sus propias credenciales
    // dejarían incompleto el pliego.
    for (final quien in [presidente, secretario]) {
      await padron.productores.subirImagen(
        productorId: quien.id,
        bytes: imagen,
        nombreArchivo: 'foto.png',
      );
    }

    final previa = await padron.productores.previaCredencial(productor.id);
    expect(
      previa.completa,
      isTrue,
      reason: 'no debería faltar nada: ${previa.faltantes.map((f) => f.campo)}',
    );
    expect(previa.faltantes, isEmpty);
    expect(previa.ejecutivoFederacion?.listo, isTrue);
    expect(previa.secretarioGeneralCentral?.listo, isTrue);
    expect(previa.secretarioGeneralSindicato?.listo, isTrue);
    expect(previa.selloFederacionUrl, isNotNull);
    expect(previa.selloCentralUrl, isNotNull);
    expect(previa.selloSindicatoUrl, isNotNull);

    expect(
      await estadoHttp(padron.productores.urlCredencial(productor.id)),
      200,
    );

    final pliego = await padron.sindicatos.previaCredenciales(sindicato.id);
    expect(pliego.completa, isTrue);
    expect(
      await estadoHttp(padron.sindicatos.urlCredenciales(sindicato.id)),
      200,
    );
  });

  test(
    'si el Secretario General del sindicato pierde su firma, todo se vuelve a trabar',
    () async {
      // La previa no es una foto de un momento: revisa el estado real cada vez.
      final directorio = await padron.directorios.obtener(
        Ambito.sindicato,
        sindicato.id,
      );
      await padron.directorios.eliminarImagen(
        directorio.cargoDe(TipoCargo.secretarioGeneral)!.id,
        TipoImagenCargo.firma,
      );

      final previa = await padron.productores.previaCredencial(productor.id);
      expect(previa.completa, isFalse);
      expect(
        previa.faltantes.map((f) => f.campo),
        contains('Firma del secretario general del sindicato'),
      );

      expect(
        await estadoHttp(padron.productores.urlCredencial(productor.id)),
        409,
      );
    },
  );
}
