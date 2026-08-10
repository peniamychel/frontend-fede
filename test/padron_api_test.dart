@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Pruebas contra el backend real, no contra dobles.
///
/// Requieren que Spring Boot esté corriendo. Como `flutter_test` finge ser
/// Android, `ApiConfig` resolvería el host a `10.0.2.2`, que desde el equipo no
/// lleva a ninguna parte: hay que forzarlo.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/padron_api_test.dart
/// ```
void main() {
  late Padron padron;

  setUpAll(() => padron = Padron());
  tearDownAll(() => padron.cerrar());

  test('el backend responde y la jerarquía se deserializa', () async {
    final federaciones = await padron.federaciones.listar();

    expect(federaciones, isNotEmpty,
        reason: 'debería existir al menos la federación FEDERA');
    expect(federaciones.first.id, greaterThan(0));
    expect(federaciones.first.nombre, isNotEmpty);
  });

  test('las centrales de una federación se resuelven', () async {
    final federaciones = await padron.federaciones.listar();
    final centrales = await padron.centrales.listar(
      federacionId: federaciones.first.id,
    );

    // Puede venir vacía si aún no se cargaron datos; lo que se comprueba es
    // que la petición y el mapeo no revienten.
    for (final central in centrales) {
      expect(central.federacionId, equals(federaciones.first.id));
    }
  });

  test('el listado paginado devuelve metadatos coherentes', () async {
    final pagina = await padron.productores.listar(
      paginacion: const Paginacion(tamano: 5),
    );

    expect(pagina.numero, equals(0));
    expect(pagina.totalElementos, greaterThanOrEqualTo(0));
    expect(pagina.contenido.length, lessThanOrEqualTo(5));
    // Si el backend no mandara los metadatos, totalPaginas quedaría en 0 y
    // esUltima daría true por accidente. Esto ata las dos cosas.
    expect(pagina.esUltima, equals(pagina.numero + 1 >= pagina.totalPaginas));
  });

  test('el contador de pendientes llega como número', () async {
    final total = await padron.observaciones.totalPendientes();
    expect(total, greaterThanOrEqualTo(0));
  });

  test('un id inexistente produce ApiException 404, no un fallo de parseo',
      () async {
    await expectLater(
      padron.productores.obtener(999999999),
      throwsA(
        isA<ApiException>()
            .having((e) => e.estado, 'estado', 404)
            .having((e) => e.esNoEncontrado, 'esNoEncontrado', isTrue)
            .having((e) => e.mensaje, 'mensaje', isNotEmpty),
      ),
    );
  });

  test('los filtros opcionales nulos no ensucian la URL', () {
    final sinFiltros = ApiConfig.uri('/productores', {
      'sindicatoId': null,
      'centralId': null,
      'texto': '',
      'page': 0,
    });

    expect(sinFiltros.queryParameters.containsKey('sindicatoId'), isFalse);
    expect(sinFiltros.queryParameters.containsKey('centralId'), isFalse);
    expect(sinFiltros.queryParameters.containsKey('texto'), isFalse);
    expect(sinFiltros.queryParameters['page'], equals('0'));
  });

  test('el orden viaja como parámetros repetidos', () {
    final uri = ApiConfig.uri('/productores', const Paginacion(
      orden: ['apellidos,asc', 'nombres,asc'],
    ).query);

    expect(uri.queryParametersAll['sort'],
        equals(['apellidos,asc', 'nombres,asc']));
  });

  test('filtrar por sindicato acota de verdad, y la suma cuadra', () async {
    final sindicatos = await padron.sindicatos.listar();
    if (sindicatos.isEmpty) {
      markTestSkipped('no hay sindicatos cargados todavía');
      return;
    }

    const sonda = Paginacion(tamano: 100);
    var sumaPorSindicato = 0;

    for (final s in sindicatos) {
      final pagina =
          await padron.productores.listar(sindicatoId: s.id, paginacion: sonda);
      sumaPorSindicato += pagina.totalElementos;

      // Ninguna fila puede pertenecer a otro sindicato: es lo único que hace
      // creíble la pantalla que abre el sindicato desde la jerarquía.
      for (final p in pagina.contenido) {
        expect(p.sindicatoId, equals(s.id),
            reason: 'el productor ${p.id} no es del sindicato ${s.id}');
        expect(p.sindicatoNombre, equals(s.nombre));
      }
    }

    // Cada productor cuelga de exactamente un sindicato, así que las partes no
    // pueden sumar más que el total del padrón.
    //
    // Antes esto exigía igualdad exacta, y fallaba sin que hubiera nada roto:
    // los archivos de prueba corren en paralelo, y entre la suma y este conteo
    // otro archivo daba de alta los suyos. La igualdad solo se puede afirmar
    // sobre una foto fija de la base, y acá no hay ninguna.
    final todos = await padron.productores.listar(
      paginacion: const Paginacion(tamano: 1),
    );
    expect(sumaPorSindicato, lessThanOrEqualTo(todos.totalElementos));

    // Lo que sí se puede afirmar con certeza es sobre datos propios: un
    // sindicato recién creado con dos productores devuelve exactamente dos.
    final sindicato = await padron.sindicatos.crear(SindicatoRequest(
        nombre: 'ZZZ SIN CONTEO', centralId: sindicatos.first.centralId));
    final mios = <Productor>[];
    for (final nombre in ['ZZZ UNO', 'ZZZ DOS']) {
      mios.add(await padron.productores.crear(ProductorRequest(
          nombres: nombre, apellidos: 'CONTEO', sindicatoId: sindicato.id)));
    }

    final pagina =
        await padron.productores.listar(sindicatoId: sindicato.id, paginacion: sonda);
    expect(pagina.totalElementos, equals(2));

    for (final p in mios) {
      await padron.productores.eliminar(p.id);
    }
    await padron.sindicatos.eliminar(sindicato.id);
  });

  test('un sindicato inexistente devuelve vacío, no un error', () async {
    final pagina = await padron.productores.listar(sindicatoId: 999999999);
    expect(pagina.contenido, isEmpty);
    expect(pagina.totalElementos, equals(0));
  });
}
