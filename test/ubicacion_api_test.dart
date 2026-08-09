@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Ubicación de los sindicatos, contra el backend real.
///
/// Estas pruebas escriben, pero solo sobre el campo de ubicación de un
/// sindicato existente, y lo dejan como estaba al terminar. No tocan
/// productores ni la jerarquía.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/ubicacion_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Sindicato sindicato;

  // Un punto real del trópico de Cochabamba, con los 7 decimales que guarda
  // el backend.
  const lat = -16.8574321;
  const lon = -64.7891234;

  setUpAll(() async {
    padron = Padron();
    final sindicatos = await padron.sindicatos.listar();
    expect(sindicatos, isNotEmpty, reason: 'hace falta al menos un sindicato');
    sindicato = sindicatos.first;
  });

  tearDownAll(() async {
    try {
      // Devolver el sindicato a su estado original: sin ubicación, que es como
      // estaba antes de estas pruebas.
      await padron.sindicatos.borrarUbicacion(sindicato.id);
    } finally {
      padron.cerrar();
    }
  });

  test('marcar la ubicación conserva los siete decimales', () async {
    final guardado =
        await padron.sindicatos.marcarUbicacion(sindicato.id, lat, lon);

    expect(guardado.tieneUbicacion, isTrue);
    // La precisión importa: el backend guarda DECIMAL(10,7) justamente para
    // que un redondeo no mueva el punto varios metros.
    expect(guardado.latitud, closeTo(lat, 0.0000001));
    expect(guardado.longitud, closeTo(lon, 0.0000001));
    expect(guardado.ubicacionActualizadaEn, isNotNull);
  });

  test('la ubicación persiste y se lee de vuelta', () async {
    await padron.sindicatos.marcarUbicacion(sindicato.id, lat, lon);

    final leido = (await padron.sindicatos.listar())
        .firstWhere((s) => s.id == sindicato.id);

    expect(leido.latitud, closeTo(lat, 0.0000001));
    expect(leido.longitud, closeTo(lon, 0.0000001));
  });

  test('el listado con-ubicacion deja fuera a los que no tienen', () async {
    await padron.sindicatos.marcarUbicacion(sindicato.id, lat, lon);

    final todos = await padron.sindicatos.listar();
    final ubicados = await padron.sindicatos.conUbicacion();

    expect(ubicados.any((s) => s.id == sindicato.id), isTrue);
    expect(ubicados.every((s) => s.tieneUbicacion), isTrue);
    expect(ubicados.length, lessThanOrEqualTo(todos.length));

    // Y coincide con lo que dicen las banderas del listado completo.
    final esperados = todos.where((s) => s.tieneUbicacion).length;
    expect(ubicados.length, equals(esperados));
  });

  test('mover el punto actualiza la marca de tiempo', () async {
    final antes =
        await padron.sindicatos.marcarUbicacion(sindicato.id, lat, lon);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final despues = await padron.sindicatos
        .marcarUbicacion(sindicato.id, lat + 0.01, lon + 0.01);

    expect(despues.ubicacionActualizadaEn!
        .isAfter(antes.ubicacionActualizadaEn!), isTrue);
    expect(despues.latitud, closeTo(lat + 0.01, 0.0000001));
  });

  test('una latitud fuera de rango se rechaza con el campo señalado', () async {
    await expectLater(
      padron.sindicatos.marcarUbicacion(sindicato.id, 123.5, lon),
      throwsA(isA<ApiException>()
          .having((e) => e.estado, 'estado', 400)
          .having((e) => e.errores, 'errores', contains('latitud'))),
    );
  });

  test('una longitud fuera de rango también', () async {
    await expectLater(
      padron.sindicatos.marcarUbicacion(sindicato.id, lat, -500),
      throwsA(isA<ApiException>()
          .having((e) => e.errores, 'errores', contains('longitud'))),
    );
  });

  test('quitar la ubicación deja el sindicato intacto', () async {
    await padron.sindicatos.marcarUbicacion(sindicato.id, lat, lon);
    final sinUbicacion =
        await padron.sindicatos.borrarUbicacion(sindicato.id);

    expect(sinUbicacion.tieneUbicacion, isFalse);
    expect(sinUbicacion.latitud, isNull);
    expect(sinUbicacion.longitud, isNull);
    // Lo que se borra es el punto, no el sindicato.
    expect(sinUbicacion.id, equals(sindicato.id));
    expect(sinUbicacion.nombre, equals(sindicato.nombre));
    expect(sinUbicacion.centralId, equals(sindicato.centralId));
  });

  test('un sindicato inexistente da 404', () async {
    await expectLater(
      padron.sindicatos.marcarUbicacion(999999999, lat, lon),
      throwsA(isA<ApiException>()
          .having((e) => e.esNoEncontrado, 'esNoEncontrado', isTrue)),
    );
  });
}
