@Tags(['integracion'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Importación contra el backend real, siempre en modo simulación.
///
/// Nunca escribe: todas las llamadas van con `simular: true`, y una de las
/// pruebas comprueba justamente que el padrón queda igual después.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/importacion_api_test.dart
/// ```
void main() {
  late Padron padron;
  late List<int> planilla;
  late int federacionId;

  setUpAll(() async {
    padron = Padron();
    planilla = File('test/fixtures/padron-prueba.xlsx').readAsBytesSync();
    final federaciones = await padron.federaciones.listar();
    federacionId = federaciones.first.id;
  });

  tearDownAll(() => padron.cerrar());

  Future<ImportacionResultado> analizar({bool crearJerarquia = true}) {
    return padron.importaciones.importar(
      bytes: planilla,
      nombreArchivo: 'padron-prueba.xlsx',
      federacionId: federacionId,
      simular: true,
      crearJerarquia: crearJerarquia,
    );
  }

  test('la subida multipart llega y devuelve un informe', () async {
    final informe = await analizar();

    expect(informe.simulacion, isTrue);
    expect(informe.federacionId, equals(federacionId));
    // 10 filas escritas en la planilla, una de ellas en blanco.
    expect(informe.filasLeidas, equals(9));
  });

  test('separa las filas válidas de las rechazadas', () async {
    final informe = await analizar();

    expect(informe.filasValidas, equals(7));
    expect(informe.filasRechazadas, equals(2));
    expect(informe.filasValidas + informe.filasRechazadas,
        equals(informe.filasLeidas));
  });

  test('los números de fila son los de Excel, no índices', () async {
    final informe = await analizar();

    // Las dos filas inválidas de la planilla están en las posiciones 8 y 9 tal
    // como las numera Excel. Si el backend devolviera el índice base cero,
    // acá aparecerían 7 y 8.
    expect(informe.errores.map((e) => e.fila), containsAll([8, 9]));
    expect(informe.errores.map((e) => e.columna),
        containsAll(['nombres', 'sindicato']));
  });

  test('cuenta los lotes, sin contar el marcador de dato ausente', () async {
    final informe = await analizar();

    // Cuatro filas traen número de lote; la que tiene "-" no cuenta, porque el
    // guion es el marcador de dato ausente del padrón.
    expect(informe.lotes, equals(4));
  });

  test('avisa qué jerarquía crearía', () async {
    final informe = await analizar();

    expect(informe.tocaLaJerarquia, isTrue);
    expect(informe.centralesNuevas, contains('SANTA FE'));
    // "1RO MAYO" ya existe como sindicato en la central homónima, pero dentro
    // de SANTA FE es otro distinto: el nombre solo no identifica a ninguno.
    expect(
      informe.sindicatosNuevos.any(
          (s) => s.central == 'SANTA FE' && s.sindicato == '1RO MAYO'),
      isTrue,
    );
  });

  test('sin crearJerarquia rechaza las filas de la central inexistente',
      () async {
    final informe = await analizar(crearJerarquia: false);

    expect(informe.centralesNuevas, isEmpty);
    expect(informe.filasRechazadas, greaterThan(2));
    expect(
      informe.errores.any((e) => e.mensaje.contains('SANTA FE')),
      isTrue,
      reason: 'el error debe nombrar la central que falta',
    );
  });

  test('la simulación no deja rastro en el padrón', () async {
    // Se cuenta antes y después la misma búsqueda acotada, en vez de mirar el
    // total de la base o de exigir que no haya ninguno. El total lo mueven los
    // otros archivos de prueba, que corren en paralelo; y «no haya ninguno»
    // fallaba en cuanto el padrón real sumó una CONSTANTINA de verdad —la
    // planilla de ejemplo salió del padrón, así que sus nombres existen—.
    final antes = await padron.productores.listar(texto: 'CONSTANTINA');

    await analizar();

    final despues = await padron.productores.listar(texto: 'CONSTANTINA');
    expect(despues.contenido.map((p) => p.id),
        unorderedEquals(antes.contenido.map((p) => p.id)),
        reason: 'ningún productor de la planilla debe haberse guardado');

    final centrales = await padron.centrales.listar();
    expect(
      centrales.map((c) => c.nombre),
      isNot(contains('SANTA FE')),
      reason: 'la central de la simulación no debe haberse creado',
    );
  });

  test('un archivo que no es xlsx da 400 con mensaje claro', () async {
    await expectLater(
      padron.importaciones.importar(
        bytes: 'esto no es un excel'.codeUnits,
        nombreArchivo: 'basura.txt',
        federacionId: federacionId,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.estado, 'estado', 400)
          .having((e) => e.mensaje, 'mensaje', contains('.xlsx'))),
    );
  });

  test('la plantilla de ejemplo se descarga como adjunto .xlsx', () async {
    final url = padron.importaciones.urlPlantilla;
    expect(url.path, endsWith('/importaciones/plantilla'));

    final respuesta = await http.get(url);

    expect(respuesta.statusCode, equals(200));
    expect(respuesta.headers['content-disposition'],
        contains('plantilla-padron.xlsx'));
    // Un .xlsx es un zip: empieza con "PK". Si el backend devolviera un JSON de
    // error, esto lo delata.
    expect(respuesta.bodyBytes.take(2), equals([0x50, 0x4B]));
  });

  test('la plantilla que se descarga la acepta el importador', () async {
    final descargada =
        await http.get(padron.importaciones.urlPlantilla);

    final informe = await padron.importaciones.importar(
      bytes: descargada.bodyBytes,
      nombreArchivo: 'plantilla-padron.xlsx',
      federacionId: federacionId,
      simular: true,
      crearJerarquia: true,
    );

    // El circuito completo desde la vista del usuario: descargar la plantilla,
    // subirla y que no la rechacen. Si el generador y el lector se
    // desincronizaran, acá aparecerían filas rechazadas.
    expect(informe.filasRechazadas, isZero);
    expect(informe.filasValidas, equals(2), reason: 'las dos filas de ejemplo');
  });

  test('una federación inexistente da 404', () async {
    await expectLater(
      padron.importaciones.importar(
        bytes: planilla,
        nombreArchivo: 'padron-prueba.xlsx',
        federacionId: 999999999,
      ),
      throwsA(isA<ApiException>().having((e) => e.esNoEncontrado,
          'esNoEncontrado', isTrue)),
    );
  });
}
