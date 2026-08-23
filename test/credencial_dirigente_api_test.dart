@Tags(['integracion'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Credencial de dirigente, contra el backend real.
///
/// Verifica el transporte y que se emita en los casos que importan. La forma
/// de la tarjeta —que sea vertical, qué dice cada cara— se verifica en el
/// backend, en `CredencialDirigentePdfTest`, que puede leer el PDF por dentro.
///
/// Se monta una jerarquía desechable y se borra al final.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/credencial_dirigente_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fed;
  late Central central;
  late Sindicato sindicato;
  late Productor ana;
  late Productor bruno;

  setUpAll(() async {
    padron = Padron();
    // Con número y sigla: la última prueba baja también la credencial de
    // productor, que desde la vista previa exige los datos completos.
    fed = await padron.federaciones.crear(
      const FederacionRequest(nombre: 'ZZZ FED CARNET DIR', numero: '86'),
    );
    central = await padron.centrales.crear(
      CentralRequest(
        nombre: 'ZZZ CEN CARNET',
        abreviatura: 'ZDR',
        federacionId: fed.id,
      ),
    );
    sindicato = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ SIN CARNET', centralId: central.id),
    );

    ana = await padron.productores.crear(
      ProductorRequest(
        nombres: 'ZZZ ANA',
        apellidos: 'DIRIGENTE',
        ci: '7001',
        sindicatoId: sindicato.id,
      ),
    );
    bruno = await padron.productores.crear(
      ProductorRequest(
        nombres: 'ZZZ BRUNO',
        apellidos: 'DIRIGENTE',
        ci: '7002',
        sindicatoId: sindicato.id,
      ),
    );
  });

  tearDownAll(() async {
    for (final p in [ana, bruno]) {
      await padron.productores.eliminar(p.id);
    }
    await padron.sindicatos.eliminar(sindicato.id);
    await padron.centrales.eliminar(central.id);
    await padron.federaciones.eliminar(fed.id);
  });

  Future<http.Response> bajar(int cargoId) =>
      http.get(padron.directorios.urlCredencial(cargoId));

  test('el Secretario General de un sindicato tiene credencial', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicato.id,
      cargo: TipoCargo.secretarioGeneral,
      productorId: ana.id,
    );
    final cargoId = directorio.cargoDe(TipoCargo.secretarioGeneral)!.id;

    final respuesta = await bajar(cargoId);

    expect(respuesta.statusCode, 200);
    expect(respuesta.headers['content-type'], contains('application/pdf'));
    expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
    expect(
      respuesta.headers['content-disposition'],
      contains('credencial-secretario-general-zzz-ana-dirigente'),
    );
  });

  test('el Secretario Relaciones también', () async {
    final directorio = await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicato.id,
      cargo: TipoCargo.secretarioRelaciones,
      productorId: bruno.id,
    );
    final cargoId = directorio.cargoDe(TipoCargo.secretarioRelaciones)!.id;

    final respuesta = await bajar(cargoId);

    expect(respuesta.statusCode, 200);
    expect(
      respuesta.headers['content-disposition'],
      contains('credencial-secretario-relaciones-'),
    );
  });

  test('un período ya cerrado también se puede imprimir', () async {
    // Sirve como constancia de que alguien ocupó el cargo. Si solo se pudiera
    // imprimir el vigente, al relevarse se perdería la prueba.
    await padron.directorios.terminar(
      ambito: Ambito.sindicato,
      id: sindicato.id,
      cargo: TipoCargo.secretarioGeneral,
    );

    final historial = await padron.directorios.historial(
      Ambito.sindicato,
      sindicato.id,
    );
    final cerrado = historial.firstWhere((c) => !c.vigente);

    final respuesta = await bajar(cerrado.id);

    expect(respuesta.statusCode, 200);
    expect(String.fromCharCodes(respuesta.bodyBytes.take(4)), '%PDF');
  });

  test('un cargo que no existe da 404 y no un PDF vacío', () async {
    final respuesta = await bajar(999999);

    expect(respuesta.statusCode, 404);
    expect(respuesta.headers['content-type'], isNot(contains('pdf')));
  });

  test('la del dirigente y la del productor son documentos distintos', () async {
    // Misma persona, dos credenciales: una la acredita como afiliada y otra
    // como dirigente. No pueden salir del mismo endpoint ni pesar lo mismo.
    //
    // La de productor exige los datos completos, así que primero se termina de
    // armar lo que las pruebas anteriores dejaron a medias: la foto de Bruno,
    // el Secretario General que la prueba del período cerrado dejó vacante, y las
    // firmas de los dos cargos.
    final imagen = File('test/fixtures/foto-prueba.png').readAsBytesSync();
    await padron.productores.subirImagen(
      productorId: bruno.id,
      bytes: imagen,
      nombreArchivo: 'foto.png',
    );
    await padron.directorios.asignar(
      ambito: Ambito.sindicato,
      id: sindicato.id,
      cargo: TipoCargo.secretarioGeneral,
      productorId: ana.id,
    );
    final directorio = await padron.directorios.obtener(
      Ambito.sindicato,
      sindicato.id,
    );
    for (final cargo in [
      TipoCargo.secretarioGeneral,
      TipoCargo.secretarioRelaciones,
    ]) {
      final cargoId = directorio.cargoDe(cargo)!.id;
      await padron.directorios.subirImagen(
        cargoId: cargoId,
        tipo: TipoImagenCargo.firma,
        bytes: imagen,
        nombreArchivo: 'firma.png',
      );
      await padron.directorios.actualizarPieFirma(
        cargoId,
        'FIRMANTE\n${cargo.etiqueta.toUpperCase()}',
      );
    }
    final cargoId = directorio.cargoDe(TipoCargo.secretarioRelaciones)!.id;

    final deDirigente = await bajar(cargoId);
    final deProductor = await http.get(
      padron.productores.urlCredencial(bruno.id),
    );

    expect(deDirigente.statusCode, 200);
    expect(deProductor.statusCode, 200);
    expect(deDirigente.bodyBytes, isNot(deProductor.bodyBytes));
    expect(
      deProductor.headers['content-disposition'],
      isNot(contains('secretario-relaciones')),
    );
  });
}
