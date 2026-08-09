@Tags(['integracion'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Directorio de los sindicatos, contra el backend real.
///
/// Escriben, pero sobre productores propios que se crean al empezar y se
/// borran al terminar. No tocan el padrón.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/directorio_api_test.dart
/// ```
void main() {
  late Padron padron;
  late int sindicatoId;
  late int otroSindicatoId;
  late Productor ana;
  late Productor bruno;
  late Productor carla;
  late Productor ajeno;
  late Uint8List fotoGrande;

  Future<Productor> crear(String nombres, String apellidos, int sindicato) {
    return padron.productores.crear(ProductorRequest(
      nombres: nombres,
      apellidos: apellidos,
      sindicatoId: sindicato,
    ));
  }

  setUpAll(() async {
    padron = Padron();
    fotoGrande = File('test/fixtures/foto-grande.jpg').readAsBytesSync();
    final sindicatos = await padron.sindicatos.listar();
    expect(sindicatos.length, greaterThanOrEqualTo(2),
        reason: 'hacen falta dos sindicatos para probar el cruce');
    sindicatoId = sindicatos.first.id;
    otroSindicatoId = sindicatos.last.id;

    ana = await crear('ZZZ ANA', 'PRIMERA', sindicatoId);
    bruno = await crear('ZZZ BRUNO', 'SEGUNDO', sindicatoId);
    carla = await crear('ZZZ CARLA', 'TERCERA', sindicatoId);
    ajeno = await crear('ZZZ DIEGO', 'AJENO', otroSindicatoId);
  });

  /// Cada prueba arranca con el directorio vacante.
  ///
  /// Sin esto una prueba hereda lo que dejó la anterior y falla por un estado
  /// que no eligió: el directorio es un recurso compartido entre todas.
  setUp(() async {
    for (final cargo in TipoCargo.values) {
      try {
        await padron.directorios
            .terminar(ambito: Ambito.sindicato, id: sindicatoId, cargo: cargo);
      } on ApiException catch (e) {
        // Ya estaba vacante, que es justo lo que se quería.
        if (!e.esNoEncontrado) rethrow;
      }
    }
  });

  tearDownAll(() async {
    try {
      // Borrar el productor arrastra sus cargos: el historial es suyo.
      for (final p in [ana, bruno, carla, ajeno]) {
        await padron.productores.eliminar(p.id);
      }
    } finally {
      padron.cerrar();
    }
  });

  test('un sindicato empieza sin directorio', () async {
    final directorio = await padron.directorios.obtener(Ambito.sindicato, sindicatoId);

    // Vacante no es un error: un sindicato nuevo no tiene autoridades.
    expect(directorio.cargoDe(TipoCargo.presidente), isNull);
    expect(directorio.cargoDe(TipoCargo.secretario), isNull);
    expect(directorio.estaVacio, isTrue);
  });

  test('asignar presidente y secretario deja los dos en funciones', () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: ana.id,
      desde: DateTime(2026, 3, 1),
    );
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.secretario,
      productorId: bruno.id,
    );

    expect(directorio.cargoDe(TipoCargo.presidente)!.productorId, equals(ana.id));
    expect(directorio.cargoDe(TipoCargo.secretario)!.productorId, equals(bruno.id));
    expect(directorio.estaCompleto, isTrue);
    expect(directorio.cargoDe(TipoCargo.presidente)!.vigente, isTrue);
  });

  test('reemplazar cierra el período anterior el día previo', () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: ana.id,
      desde: DateTime(2026, 3, 1),
    );
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: carla.id,
      desde: DateTime(2026, 8, 1),
    );

    final historial =
        await padron.directorios.historial(Ambito.sindicato, sindicatoId);
    final deAna = historial.firstWhere((c) => c.productorId == ana.id);

    // El día anterior, no el mismo: dos presidentes la misma fecha es una
    // contradicción que después nadie sabe interpretar.
    expect(deAna.hasta, equals(DateTime(2026, 7, 31)));
    expect(deAna.vigente, isFalse);

    final vigentes = historial.where((c) =>
        c.vigente && c.cargo == TipoCargo.presidente);
    expect(vigentes.length, equals(1), reason: 'un solo presidente a la vez');
    expect(vigentes.first.productorId, equals(carla.id));
  });

  test('nadie de otro sindicato puede ocupar el directorio', () async {
    await expectLater(
      padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindicatoId,
        cargo: TipoCargo.presidente,
        productorId: ajeno.id,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.esConflicto, 'esConflicto', isTrue)
          .having((e) => e.mensaje, 'mensaje', contains('no puede ocupar'))),
    );
  });

  test('asignar a quien ya ocupa el cargo se rechaza', () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.secretario,
      productorId: bruno.id,
    );

    await expectLater(
      padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindicatoId,
        cargo: TipoCargo.secretario,
        productorId: bruno.id,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', contains('ya es'))),
    );
  });

  test('no se puede empezar antes de que empezara el período en curso',
      () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: carla.id,
      desde: DateTime(2026, 8, 1),
    );

    await expectLater(
      padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindicatoId,
        cargo: TipoCargo.presidente,
        productorId: ana.id,
        desde: DateTime(2026, 1, 1),
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', contains('antes de'))),
    );
  });

  test('se puede dejar el cargo vacante sin nombrar reemplazo', () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.secretario,
      productorId: bruno.id,
    );

    final directorio = await padron.directorios.terminar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.secretario,
    );

    // Una renuncia sin sucesor es real; obligar a nombrar a alguien para poder
    // registrarla falsearía el historial.
    expect(directorio.cargoDe(TipoCargo.secretario), isNull);

    final historial =
        await padron.directorios.historial(Ambito.sindicato, sindicatoId);
    expect(historial.any((c) => c.productorId == bruno.id && !c.vigente),
        isTrue);
  });

  test('terminar un cargo vacante da 404', () async {
    // El setUp ya lo dejó vacante, así que esto es un segundo intento.
    await expectLater(
      padron.directorios.terminar(
        ambito: Ambito.sindicato,
        id: sindicatoId,
        cargo: TipoCargo.secretario,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.esNoEncontrado, 'esNoEncontrado', isTrue)),
    );
  });

  test('la firma se reduce a 200 px y queda atada al período', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: ana.id,
    );
    final cargoId = directorio.cargoDe(TipoCargo.presidente)!.id;

    // Una foto de 4032x3024 y 1,42 MB: se acepta y el servidor la reduce.
    final actualizado = await padron.directorios.subirImagen(
      cargoId: cargoId,
      tipo: TipoImagenCargo.firma,
      bytes: fotoGrande,
      nombreArchivo: 'firma.jpg',
    );

    expect(actualizado.firmaUrl, isNotNull);
    expect(actualizado.firmaUrl, startsWith('/api/v1/archivos/firmas/'));
    expect(actualizado.pieFirmaUrl, isNull,
        reason: 'subir una no debe tocar la otra');

    final respuesta = await http
        .get(Uri.parse(ApiConfig.urlAbsoluta(actualizado.firmaUrl!)));
    expect(respuesta.statusCode, equals(200));
    // El requisito es 200 KB; a 200 px de lado queda muy por debajo.
    expect(respuesta.bodyBytes.length, lessThan(200 * 1024));
  });

  test('las dos imágenes conviven y se borran por separado', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.secretario,
      productorId: bruno.id,
    );
    final cargoId = directorio.cargoDe(TipoCargo.secretario)!.id;

    await padron.directorios.subirImagen(
      cargoId: cargoId,
      tipo: TipoImagenCargo.firma,
      bytes: fotoGrande,
      nombreArchivo: 'firma.jpg',
    );
    final conAmbas = await padron.directorios.subirImagen(
      cargoId: cargoId,
      tipo: TipoImagenCargo.pieFirma,
      bytes: fotoGrande,
      nombreArchivo: 'pie.jpg',
    );
    expect(conAmbas.tieneFirmas, isTrue);

    final sinFirma = await padron.directorios
        .eliminarImagen(cargoId, TipoImagenCargo.firma);

    // La respuesta tiene que reflejar el estado nuevo, no el anterior.
    expect(sinFirma.firmaUrl, isNull);
    expect(sinFirma.pieFirmaUrl, isNotNull);
  });

  test('borrar una firma que no está da 404', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: carla.id,
    );

    await expectLater(
      padron.directorios.eliminarImagen(
          directorio.cargoDe(TipoCargo.presidente)!.id, TipoImagenCargo.firma),
      throwsA(isA<ApiException>()
          .having((e) => e.esNoEncontrado, 'esNoEncontrado', isTrue)),
    );
  });

  test('las firmas viajan en el historial', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: ana.id,
      desde: DateTime(2026, 3, 1),
    );
    await padron.directorios.subirImagen(
      cargoId: directorio.cargoDe(TipoCargo.presidente)!.id,
      tipo: TipoImagenCargo.firma,
      bytes: fotoGrande,
      nombreArchivo: 'firma.jpg',
    );

    // Se reemplaza: el período de ANA se cierra, pero su firma sigue con él.
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: carla.id,
      desde: DateTime(2026, 8, 1),
    );

    final historial =
        await padron.directorios.historial(Ambito.sindicato, sindicatoId);
    final deAna = historial.firstWhere((c) => c.productorId == ana.id);

    expect(deAna.vigente, isFalse);
    expect(deAna.firmaUrl, isNotNull,
        reason: 'la firma pertenece al período, no se pierde al terminar');
  });

  test('el productor conserva su historial de cargos', () async {
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: ana.id,
      desde: DateTime(2026, 3, 1),
    );
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicatoId,
      cargo: TipoCargo.presidente,
      productorId: carla.id,
      desde: DateTime(2026, 8, 1),
    );

    final cargos = await padron.productores.cargos(ana.id);

    // Aunque ya no presida, su paso por el cargo queda registrado con fechas.
    expect(cargos, isNotEmpty);
    final ultimo = cargos.first;
    expect(ultimo.cargo, equals(TipoCargo.presidente));
    expect(ultimo.vigente, isFalse);
    expect(ultimo.hasta, isNotNull);
    expect(ultimo.ambitoId, equals(sindicatoId));
  });
}
