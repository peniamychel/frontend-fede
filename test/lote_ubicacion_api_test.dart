@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Ubicación en el mapa y superficie de las parcelas, contra el backend real.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/lote_ubicacion_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fed;
  late Central central;
  late Sindicato sindicato;
  late Productor ana;

  final lotes = <int>[];

  /// El trópico de Cochabamba, que es donde está este padrón.
  const lat = -16.8574123;
  const lon = -64.7891456;

  Future<Lote> crearLote(String numero, {double? superficie}) async {
    final l = await padron.lotes.crear(LoteRequest(
      sindicatoId: sindicato.id,
      productorId: ana.id,
      numero: numero,
      superficie: superficie,
    ));
    lotes.add(l.id);
    return l;
  }

  setUpAll(() async {
    padron = Padron();
    fed = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ FED MAPA'));
    central = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ CEN MAPA', federacionId: fed.id));
    sindicato = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN MAPA', centralId: central.id));
    ana = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ ANA', apellidos: 'MAPA', sindicatoId: sindicato.id));
  });

  tearDownAll(() async {
    for (final id in lotes) {
      await padron.lotes
          .traspasar(id, const TraspasoRequest(motivo: MotivoTraspaso.otro));
      await padron.lotes.eliminar(id);
    }
    await padron.productores.eliminar(ana.id);
    await padron.sindicatos.eliminar(sindicato.id);
    await padron.centrales.eliminar(central.id);
    await padron.federaciones.eliminar(fed.id);
  });

  group('ubicación', () {
    test('un lote nuevo no tiene punto', () async {
      final lote = await crearLote('501');

      expect(lote.tieneUbicacion, isFalse);
      expect(lote.latitud, isNull);
      expect(lote.coordenadas, 'Sin ubicación');
    });

    test('se marca el punto y vuelve con las dos coordenadas', () async {
      final lote = await crearLote('502');

      final ubicado = await padron.lotes.marcarUbicacion(lote.id, lat, lon);

      expect(ubicado.tieneUbicacion, isTrue);
      expect(ubicado.latitud, closeTo(lat, 0.0000001));
      expect(ubicado.longitud, closeTo(lon, 0.0000001));
      expect(ubicado.ubicacionActualizadaEn, isNotNull);
    });

    test('conserva los siete decimales', () async {
      // Se guarda como DECIMAL y no como double justamente por esto: en
      // coordenadas, redondear el séptimo decimal son centímetros, y redondear
      // el quinto son metros sobre el terreno.
      final lote = await crearLote('503');

      final ubicado = await padron.lotes.marcarUbicacion(lote.id, lat, lon);

      expect(ubicado.latitud!.toStringAsFixed(7), lat.toStringAsFixed(7));
      expect(ubicado.longitud!.toStringAsFixed(7), lon.toStringAsFixed(7));
    });

    test('se puede mover a otro punto', () async {
      final lote = await crearLote('504');
      await padron.lotes.marcarUbicacion(lote.id, lat, lon);

      final movido =
          await padron.lotes.marcarUbicacion(lote.id, lat + 0.01, lon + 0.01);

      expect(movido.latitud, closeTo(lat + 0.01, 0.0000001));
    });

    test('quitar el punto no borra el lote', () async {
      final lote = await crearLote('505');
      await padron.lotes.marcarUbicacion(lote.id, lat, lon);

      final sinPunto = await padron.lotes.borrarUbicacion(lote.id);

      expect(sinPunto.tieneUbicacion, isFalse);
      // El lote sigue ahí, con su número y su tenedor.
      expect(sinPunto.numero, '505');
      expect(sinPunto.tenedor?.productorId, ana.id);
    });

    test('el listado del mapa trae solo los ubicados', () async {
      final ubicado = await crearLote('506');
      final sinUbicar = await crearLote('507');
      await padron.lotes.marcarUbicacion(ubicado.id, lat, lon);

      final enElMapa = await padron.lotes.conUbicacion(sindicato.id);

      expect(enElMapa.map((l) => l.id), contains(ubicado.id));
      expect(enElMapa.map((l) => l.id), isNot(contains(sinUbicar.id)));
      expect(enElMapa.every((l) => l.tieneUbicacion), isTrue);
    });

    test('una coordenada fuera de rango se rechaza', () async {
      final lote = await crearLote('508');

      await expectLater(
        padron.lotes.marcarUbicacion(lote.id, 200, lon),
        throwsA(isA<ApiException>()
            .having((e) => e.esValidacion, 'esValidacion', isTrue)),
      );
    });
  });

  group('superficie', () {
    test('se puede crear con la medida puesta', () async {
      final lote = await crearLote('601', superficie: 12.5);

      expect(lote.superficie, 12.5);
      expect(lote.superficieTexto, '12.5 ha');
    });

    test('sin medir no es lo mismo que cero', () async {
      // El padrón original no trae la superficie, y un cero se confundiría con
      // una parcela de tamaño nulo.
      final lote = await crearLote('602');

      expect(lote.superficie, isNull);
      expect(lote.superficieTexto, 'Sin medir');
    });

    test('se corrige sin tocar al tenedor', () async {
      final lote = await crearLote('603', superficie: 10);

      final medido = await padron.lotes.actualizar(
        lote.id,
        LoteRequest(
          sindicatoId: sindicato.id,
          numero: '603',
          superficie: 18.75,
        ),
      );

      expect(medido.superficie, 18.75);
      expect(medido.tenedor?.productorId, ana.id,
          reason: 'corregir la medida no puede cambiar de manos la parcela');
    });

    test('cero o negativo se rechazan', () async {
      for (final invalida in [0.0, -5.0]) {
        await expectLater(
          padron.lotes.crear(LoteRequest(
            sindicatoId: sindicato.id,
            numero: '604',
            superficie: invalida,
          )),
          throwsA(isA<ApiException>()
              .having((e) => e.esValidacion, 'esValidacion', isTrue)),
          reason: '$invalida no es una superficie',
        );
      }
    });

    test('conserva los decimales de hectárea', () async {
      final lote = await crearLote('605', superficie: 3.1416);

      expect(lote.superficie, closeTo(3.1416, 0.00001));
    });
  });
}
